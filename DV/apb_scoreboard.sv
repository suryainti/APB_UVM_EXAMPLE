// ============================================================
// APB UVM Scoreboard
// - Maintains reference memory model
// - Compares DUT read data against expected
// - Checks PSLVERR for out-of-range accesses
// - Transaction cloning to prevent aliasing with monitor
// - Write-before-read ordering via pending queues
// ============================================================

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    // Analysis export - receives transactions from monitor
    uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

    // ----------------------------------------------------------
    // Reference Memory Model (mirrors slave memory)
    // ----------------------------------------------------------
    localparam MEM_DEPTH   = 16;
    localparam ADDR_BASE   = 32'h0000_0000;
    localparam ADDR_MAX    = 32'h0000_003C;

    logic [31:0] ref_mem [0:MEM_DEPTH-1];

    // ----------------------------------------------------------
    // Pending transaction queues
    //
    // APB is an in-order protocol (no transaction IDs, single master),
    // so simple FIFOs are sufficient.  Writes are committed to ref_mem
    // via drain_writes() before any read is verified, ensuring the
    // reference model is always up-to-date at the point of comparison.
    // ----------------------------------------------------------
    apb_seq_item wr_pend_q[$];   // pending write transactions
    apb_seq_item rd_pend_q[$];   // pending read  transactions

    // ----------------------------------------------------------
    // Scoreboard Statistics
    // ----------------------------------------------------------
    int unsigned total_checks;
    int unsigned passed_checks;
    int unsigned failed_checks;
    int unsigned error_checks;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------
    // build_phase
    // ----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        // Initialize reference memory to 0
        foreach (ref_mem[i])
            ref_mem[i] = 32'h0;
    endfunction

    // ----------------------------------------------------------
    // write: Called when monitor sends a transaction
    //
    // Fix 1 – Clone: prevents the scoreboard from holding a handle
    //          that the monitor may overwrite before processing is done.
    //
    // Fix 2 – Ordering: writes are queued and drained before any read
    //          is checked, so ref_mem always reflects all completed
    //          writes at the time of read verification.
    // ----------------------------------------------------------
    function void write(apb_seq_item item);
        apb_seq_item txn;
        $cast(txn, item.clone());    // FIX 1: clone before any use
        total_checks++;

        if (txn.wr_rd) begin
            // FIX 2: queue write; commit to ref_mem via drain_writes()
            wr_pend_q.push_back(txn);
            drain_writes();
        end else begin
            // Flush all pending writes before checking the read so the
            // reference model is up-to-date at the point of comparison
            drain_writes();
            rd_pend_q.push_back(txn);
            drain_reads();
        end
    endfunction

    // ----------------------------------------------------------
    // drain_writes: commit all pending writes to the reference model
    // ----------------------------------------------------------
    function void drain_writes();
        while (wr_pend_q.size() > 0) begin
            apb_seq_item w = wr_pend_q.pop_front();
            check_write(w);
        end
    endfunction

    // ----------------------------------------------------------
    // drain_reads: verify all pending reads against the reference model
    // ----------------------------------------------------------
    function void drain_reads();
        while (rd_pend_q.size() > 0) begin
            apb_seq_item r = rd_pend_q.pop_front();
            check_read(r);
        end
    endfunction

    // ----------------------------------------------------------
    // check_write: validate address, update ref model, check PSLVERR
    // ----------------------------------------------------------
    function void check_write(apb_seq_item item);
        logic [31:0] word_addr;
        logic        addr_valid;

        word_addr  = item.addr >> 2;
        addr_valid = (item.addr >= ADDR_BASE) &&
                     (item.addr <= ADDR_MAX)  &&
                     (item.addr[1:0] == 2'b00);

        if (!addr_valid) begin
            if (!item.slv_err) begin
                `uvm_error("SB",
                    $sformatf("PSLVERR expected for invalid addr=0x%08h but not asserted",
                    item.addr))
                failed_checks++;
            end else begin
                `uvm_info("SB",
                    $sformatf("PASS: PSLVERR correctly asserted for invalid addr=0x%08h",
                    item.addr), UVM_MEDIUM)
                error_checks++;
                passed_checks++;
            end
            return;
        end

        // Apply byte strobes to reference model
        for (int b = 0; b < 4; b++) begin
            if (item.strb[b])
                ref_mem[word_addr][b*8 +: 8] = item.data[b*8 +: 8];
        end

        if (item.slv_err) begin
            `uvm_error("SB", $sformatf(
                "Unexpected PSLVERR on valid WRITE addr=0x%08h", item.addr))
            failed_checks++;
        end else begin
            `uvm_info("SB", $sformatf(
                "PASS: WRITE addr=0x%08h data=0x%08h strb=%04b",
                item.addr, item.data, item.strb), UVM_HIGH)
            passed_checks++;
        end
    endfunction

    // ----------------------------------------------------------
    // check_read: validate address, compare RDATA vs ref model
    // ----------------------------------------------------------
    function void check_read(apb_seq_item item);
        logic [31:0] word_addr;
        logic        addr_valid;
        logic [31:0] expected;

        word_addr  = item.addr >> 2;
        addr_valid = (item.addr >= ADDR_BASE) &&
                     (item.addr <= ADDR_MAX)  &&
                     (item.addr[1:0] == 2'b00);

        if (!addr_valid) begin
            if (!item.slv_err) begin
                `uvm_error("SB",
                    $sformatf("PSLVERR expected for invalid addr=0x%08h but not asserted",
                    item.addr))
                failed_checks++;
            end else begin
                `uvm_info("SB",
                    $sformatf("PASS: PSLVERR correctly asserted for invalid addr=0x%08h",
                    item.addr), UVM_MEDIUM)
                error_checks++;
                passed_checks++;
            end
            return;
        end

        expected = ref_mem[word_addr];

        if (item.slv_err) begin
            `uvm_error("SB", $sformatf(
                "Unexpected PSLVERR on valid READ addr=0x%08h", item.addr))
            failed_checks++;
        end else if (item.rdata !== expected) begin
            `uvm_error("SB", $sformatf(
                "MISMATCH: READ addr=0x%08h | Expected=0x%08h | Got=0x%08h",
                item.addr, expected, item.rdata))
            failed_checks++;
        end else begin
            `uvm_info("SB", $sformatf(
                "PASS: READ addr=0x%08h data=0x%08h matches expected",
                item.addr, item.rdata), UVM_HIGH)
            passed_checks++;
        end
    endfunction

    // ----------------------------------------------------------
    // report_phase: drain any remaining transactions, then summarise
    // ----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        // Flush any transactions still pending at end-of-sim
        drain_writes();
        drain_reads();

        `uvm_info("SB", "============================================", UVM_MEDIUM)
        `uvm_info("SB", "         SCOREBOARD SUMMARY                ", UVM_MEDIUM)
        `uvm_info("SB", "============================================", UVM_MEDIUM)
        `uvm_info("SB", $sformatf("  Total Checks  : %0d", total_checks),  UVM_MEDIUM)
        `uvm_info("SB", $sformatf("  Passed        : %0d", passed_checks), UVM_MEDIUM)
        `uvm_info("SB", $sformatf("  Failed        : %0d", failed_checks), UVM_MEDIUM)
        `uvm_info("SB", $sformatf("  Error (SLVERR): %0d", error_checks),  UVM_MEDIUM)
        `uvm_info("SB", "============================================", UVM_MEDIUM)

        if (failed_checks > 0)
            `uvm_error("SB", "TEST FAILED - Scoreboard has mismatches!")
        else
            `uvm_info("SB", "TEST PASSED - All checks passed!", UVM_MEDIUM)
    endfunction

endclass
