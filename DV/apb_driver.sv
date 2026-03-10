// ============================================================
// APB UVM Driver
// Drives APB master signals via clocking block
// ============================================================

class apb_driver extends uvm_driver #(apb_seq_item);
    `uvm_component_utils(apb_driver)

    // Virtual interface handle
    virtual apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------
    // build_phase: Get virtual interface from config_db
    // ----------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", vif))
            `uvm_fatal("DRV", "Could not get apb_vif from config_db")
    endfunction

    // ----------------------------------------------------------
    // run_phase: Fetch items and drive
    // ----------------------------------------------------------
    task run_phase(uvm_phase phase);
        apb_seq_item item;
        drive_reset();
        forever begin
            seq_item_port.get_next_item(item);
            drive_transfer(item);
            seq_item_port.item_done();
        end
    endtask

    // ----------------------------------------------------------
    // drive_reset: Deassert all signals
    // ----------------------------------------------------------
    task drive_reset();
        @(vif.master_cb);
        vif.master_cb.PADDR   <= '0;
        vif.master_cb.PSEL    <= 1'b0;
        vif.master_cb.PENABLE <= 1'b0;
        vif.master_cb.PWRITE  <= 1'b0;
        vif.master_cb.PWDATA  <= '0;
        vif.master_cb.PSTRB   <= '0;
        // Wait for reset deassertion
        @(posedge vif.PRESETn);
        @(vif.master_cb);
        `uvm_info("DRV", "Reset complete, starting transfers", UVM_MEDIUM)
    endtask

    // ----------------------------------------------------------
    // drive_transfer: Execute one APB transaction
    // ----------------------------------------------------------
    task drive_transfer(apb_seq_item item);
        `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_HIGH)

        // ---- SETUP Phase ----
        @(vif.master_cb);
        vif.master_cb.PSEL    <= 1'b1;
        vif.master_cb.PENABLE <= 1'b0;
        vif.master_cb.PADDR   <= item.addr;
        vif.master_cb.PWRITE  <= item.wr_rd;
        vif.master_cb.PWDATA  <= item.wr_rd ? item.data : '0;
        vif.master_cb.PSTRB   <= item.wr_rd ? item.strb : '0;

        // ---- ACCESS Phase ----
        @(vif.master_cb);
        vif.master_cb.PENABLE <= 1'b1;

        // Wait for PREADY
        while (!vif.master_cb.PREADY) begin
            @(vif.master_cb);
        end

        // Capture read data
        if (!item.wr_rd) begin
            item.rdata   = vif.master_cb.PRDATA;
            item.slv_err = vif.master_cb.PSLVERR;
        end else begin
            item.slv_err = vif.master_cb.PSLVERR;
        end

        // ---- IDLE Phase ----
        @(vif.master_cb);
        vif.master_cb.PSEL    <= 1'b0;
        vif.master_cb.PENABLE <= 1'b0;
        vif.master_cb.PADDR   <= '0;
        vif.master_cb.PWRITE  <= 1'b0;
        vif.master_cb.PWDATA  <= '0;
        vif.master_cb.PSTRB   <= '0;

        `uvm_info("DRV", $sformatf("Transfer complete: %s", item.convert2string()), UVM_HIGH)
    endtask

endclass
