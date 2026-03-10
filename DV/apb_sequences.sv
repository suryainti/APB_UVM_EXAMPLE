// ============================================================
// APB Sequences: Base, Write, Read, Random, Burst, Error
// ============================================================

// ------------------------------------------------------------
// Base Sequence
// ------------------------------------------------------------
class apb_base_seq extends uvm_sequence #(apb_seq_item);
    `uvm_object_utils(apb_base_seq)

    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_type_name(), "Base sequence body - override in child", UVM_MEDIUM)
    endtask
endclass

// ------------------------------------------------------------
// Write Sequence - Single write transaction
// ------------------------------------------------------------
class apb_write_seq extends apb_base_seq;
    `uvm_object_utils(apb_write_seq)

    rand logic [31:0] wr_addr;
    rand logic [31:0] wr_data;
    rand logic [3:0]  wr_strb;

    constraint c_wr_addr { wr_addr[1:0] == 2'b00; wr_addr inside {[0:32'h3C]}; }
    constraint c_wr_strb { wr_strb != 4'b0000; }

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
            wr_rd == 1'b1;
            addr  == wr_addr;
            data  == wr_data;
            strb  == wr_strb;
        }) `uvm_fatal("WRITE_SEQ", "Randomization failed")
        finish_item(item);
        `uvm_info("WRITE_SEQ", item.convert2string(), UVM_MEDIUM)
    endtask
endclass

// ------------------------------------------------------------
// Read Sequence - Single read transaction
// ------------------------------------------------------------
class apb_read_seq extends apb_base_seq;
    `uvm_object_utils(apb_read_seq)

    rand logic [31:0] rd_addr;

    constraint c_rd_addr { rd_addr[1:0] == 2'b00; rd_addr inside {[0:32'h3C]}; }

    function new(string name = "apb_read_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
            wr_rd == 1'b0;
            addr  == rd_addr;
            strb  == 4'b0000;
        }) `uvm_fatal("READ_SEQ", "Randomization failed")
        finish_item(item);
        `uvm_info("READ_SEQ", item.convert2string(), UVM_MEDIUM)
    endtask
endclass

// ------------------------------------------------------------
// Random Sequence - Fully randomized mix of reads and writes
// ------------------------------------------------------------
class apb_rand_seq extends apb_base_seq;
    `uvm_object_utils(apb_rand_seq)

    int unsigned num_txns = 20;

    function new(string name = "apb_rand_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;
        repeat(num_txns) begin
            item = apb_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("RAND_SEQ", "Randomization failed")
            finish_item(item);
            `uvm_info("RAND_SEQ", item.convert2string(), UVM_HIGH)
        end
    endtask
endclass

// ------------------------------------------------------------
// Write-then-Read Sequence - Write data then read back
// ------------------------------------------------------------
class apb_wr_rd_seq extends apb_base_seq;
    `uvm_object_utils(apb_wr_rd_seq)

    int unsigned num_txns = 10;

    function new(string name = "apb_wr_rd_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item wr_item, rd_item;
        logic [31:0] addr_q[$];
        logic [31:0] data_q[$];

        // Phase 1: Write
        repeat(num_txns) begin
            wr_item = apb_seq_item::type_id::create("wr_item");
            start_item(wr_item);
            if (!wr_item.randomize() with { wr_rd == 1'b1; strb == 4'hF; })
                `uvm_fatal("WR_RD_SEQ", "Write randomization failed")
            addr_q.push_back(wr_item.addr);
            data_q.push_back(wr_item.data);
            finish_item(wr_item);
            `uvm_info("WR_RD_SEQ", {"WRITE: ", wr_item.convert2string()}, UVM_MEDIUM)
        end

        // Phase 2: Read back same addresses
        foreach(addr_q[i]) begin
            rd_item = apb_seq_item::type_id::create("rd_item");
            start_item(rd_item);
            if (!rd_item.randomize() with {
                wr_rd == 1'b0;
                addr  == addr_q[i];
                strb  == 4'b0000;
            }) `uvm_fatal("WR_RD_SEQ", "Read randomization failed")
            finish_item(rd_item);
            `uvm_info("WR_RD_SEQ", {"READ:  ", rd_item.convert2string()}, UVM_MEDIUM)
        end
    endtask
endclass

// ------------------------------------------------------------
// Burst Write Sequence - Sequential address writes
// ------------------------------------------------------------
class apb_burst_write_seq extends apb_base_seq;
    `uvm_object_utils(apb_burst_write_seq)

    rand logic [31:0] start_addr;
    int unsigned      burst_len = 8;

    constraint c_start { start_addr[1:0] == 2'b00; start_addr inside {[0:32'h1C]}; }

    function new(string name = "apb_burst_write_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;
        for (int i = 0; i < burst_len; i++) begin
            item = apb_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                wr_rd == 1'b1;
                addr  == (start_addr + (i * 4));
                strb  == 4'hF;
            }) `uvm_fatal("BURST_SEQ", "Randomization failed")
            finish_item(item);
        end
        `uvm_info("BURST_SEQ", $sformatf("Burst write: %0d txns from 0x%08h", burst_len, start_addr), UVM_MEDIUM)
    endtask
endclass

// ------------------------------------------------------------
// Error Sequence - Access out-of-range address to trigger PSLVERR
// ------------------------------------------------------------
class apb_error_seq extends apb_base_seq;
    `uvm_object_utils(apb_error_seq)

    function new(string name = "apb_error_seq");
        super.new(name);
    endfunction

    task body();
        apb_seq_item item;
        // Access invalid (out-of-range) address
        item = apb_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
            addr  == 32'hDEAD_BEF0;  // Invalid address
            wr_rd == 1'b1;
            strb  == 4'hF;
        }) `uvm_fatal("ERR_SEQ", "Randomization failed")
        finish_item(item);
        `uvm_info("ERR_SEQ", {"Error injection: ", item.convert2string()}, UVM_MEDIUM)
    endtask
endclass
