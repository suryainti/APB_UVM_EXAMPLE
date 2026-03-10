// ============================================================
// APB UVM Scoreboard
// - Maintains reference memory model
// - Compares DUT read data against expected
// - Checks PSLVERR for out-of-range accesses
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
    // ----------------------------------------------------------
    function void write(apb_seq_item item);
        logic [31:0] word_addr;
        logic        addr_valid;

        total_checks++;

        // Decode address
        word_addr  = item.addr >> 2;  // Word index
        addr_valid = (item.addr >= ADDR_BASE) &&
                     (item.addr <= ADDR_MAX)  &&
                     (item.addr[1:0] == 2'b00);

        // --------------------------------------------------
        // Check PSLVERR for invalid addresses
        // --------------------------------------------------
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

        // --------------------------------------------------
        // Write: Update reference model
        // --------------------------------------------------
        if (item.wr_rd) begin
            // Apply byte strobes
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
        end

        // --------------------------------------------------
        // Read: Compare DUT output vs reference model
        // --------------------------------------------------
        else begin
            logic [31:0] expected;
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
        end
    endfunction

    // ----------------------------------------------------------
    // report_phase: Final summary
    // ----------------------------------------------------------
    function void report_phase(uvm_phase phase);
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
