// ============================================================
// APB UVM Monitor
// Observes bus and broadcasts transactions via analysis port
// ============================================================

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    // Virtual interface
    virtual apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) vif;

    // Analysis port - sends complete transaction to scoreboard/coverage
    uvm_analysis_port #(apb_seq_item) ap;

    // Timeout: max clock cycles to wait for PREADY
    int unsigned pready_timeout = 1000;

    // Statistics
    int unsigned num_writes;
    int unsigned num_reads;
    int unsigned num_errors;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------
    // build_phase
    // ----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("MON", "Could not get apb_vif from config_db")
    endfunction

    // ----------------------------------------------------------
    // run_phase: Monitor bus forever
    // ----------------------------------------------------------
    task run_phase(uvm_phase phase);
        apb_seq_item item;
        // Wait for reset
        @(posedge vif.PRESETn);
        `uvm_info("MON", "Reset deasserted - monitoring started", UVM_MEDIUM)

        forever begin
            collect_transaction(item);
            ap.write(item);
        end
    endtask

    // ----------------------------------------------------------
    // collect_transaction: Wait for SETUP then ACCESS phases
    // ----------------------------------------------------------
    task collect_transaction(output apb_seq_item item);
        item = apb_seq_item::type_id::create("mon_item");

        // Wait for SETUP phase: PSEL=1, PENABLE=0
        do begin
            @(vif.monitor_cb);
        end while (!(vif.monitor_cb.PSEL && !vif.monitor_cb.PENABLE));

        // Capture setup phase signals
        item.addr  = vif.monitor_cb.PADDR;
        item.wr_rd = vif.monitor_cb.PWRITE;
        item.data  = vif.monitor_cb.PWDATA;
        item.strb  = vif.monitor_cb.PSTRB;

        // Wait for ACCESS phase: PSEL=1, PENABLE=1
        @(vif.monitor_cb);
        if (!(vif.monitor_cb.PSEL && vif.monitor_cb.PENABLE))
            `uvm_error("MON", "Expected ACCESS phase not seen after SETUP")

        // Wait for PREADY with timeout
        begin
            int unsigned timeout_cnt = 0;
            while (!vif.monitor_cb.PREADY) begin
                @(vif.monitor_cb);
                timeout_cnt++;
                if (timeout_cnt >= pready_timeout)
                    `uvm_fatal("MON", $sformatf(
                        "PREADY timeout after %0d cycles at addr=0x%08h",
                        pready_timeout, item.addr))
            end
        end

        // Capture response
        item.rdata   = vif.monitor_cb.PRDATA;
        item.slv_err = vif.monitor_cb.PSLVERR;

        // Update stats
        if (item.wr_rd) num_writes++;
        else            num_reads++;
        if (item.slv_err) begin
            num_errors++;
            `uvm_warning("MON", $sformatf("PSLVERR detected: %s", item.convert2string()))
        end

        `uvm_info("MON", $sformatf("Captured: %s", item.convert2string()), UVM_HIGH)
    endtask

    // ----------------------------------------------------------
    // report_phase: Print statistics
    // ----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("MON", $sformatf(
            "Monitor Stats: WRITES=%0d READS=%0d ERRORS=%0d",
            num_writes, num_reads, num_errors), UVM_MEDIUM)
    endfunction

endclass
