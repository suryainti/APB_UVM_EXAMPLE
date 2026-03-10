// ============================================================
// APB Sequence Item (Transaction) with Constraints
// ============================================================

class apb_seq_item extends uvm_sequence_item;

    `uvm_object_utils(apb_seq_item)

    // ----------------------------------------------------------
    // Transaction Fields
    // ----------------------------------------------------------
    rand logic [31:0]  addr;
    rand logic [31:0]  data;
    rand logic [3:0]   strb;
    rand logic         wr_rd;      // 1=Write, 0=Read

    // Response fields (driven by monitor/scoreboard)
    logic [31:0]       rdata;
    logic              slv_err;

    // ----------------------------------------------------------
    // Enums for transaction type
    // ----------------------------------------------------------
    typedef enum { WRITE, READ } xfer_type_e;
    xfer_type_e xfer_type;

    // ----------------------------------------------------------
    // Constraints
    // ----------------------------------------------------------

    // C1: Address must be word-aligned (bits [1:0] = 00)
    constraint c_word_aligned {
        addr[1:0] == 2'b00;
    }

    // C2: Address within valid slave memory range (16 words = 64 bytes)
    constraint c_addr_range {
        addr inside {[32'h0000_0000 : 32'h0000_003C]};
    }

    // C3: Valid byte strobes for write (at least one byte enabled)
    constraint c_strb_write {
        if (wr_rd == 1'b1)
            strb inside {4'b0001, 4'b0010, 4'b0100, 4'b1000,
                         4'b0011, 4'b0110, 4'b1100, 4'b1111,
                         4'b0111, 4'b1110};
    }

    // C4: Read transfers must have strb = 0
    constraint c_strb_read {
        if (wr_rd == 1'b0)
            strb == 4'b0000;
    }

    // C5: Weighted distribution - more writes than reads
    constraint c_xfer_dist {
        wr_rd dist { 1'b1 := 60, 1'b0 := 40 };
    }

    // C6: Full data range (no restriction by default)
    constraint c_data_range {
        data inside {[32'h0000_0000 : 32'hFFFF_FFFF]};
    }

    // ----------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------
    function new(string name = "apb_seq_item");
        super.new(name);
    endfunction

    // ----------------------------------------------------------
    // do_copy
    // ----------------------------------------------------------
    function void do_copy(uvm_object rhs);
        apb_seq_item rhs_cast;
        super.do_copy(rhs);
        if (!$cast(rhs_cast, rhs))
            `uvm_fatal("SEQ_ITEM", "do_copy cast failed")
        this.addr    = rhs_cast.addr;
        this.data    = rhs_cast.data;
        this.strb    = rhs_cast.strb;
        this.wr_rd   = rhs_cast.wr_rd;
        this.rdata   = rhs_cast.rdata;
        this.slv_err = rhs_cast.slv_err;
    endfunction

    // ----------------------------------------------------------
    // do_compare
    // ----------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_seq_item rhs_cast;
        if (!$cast(rhs_cast, rhs))
            `uvm_fatal("SEQ_ITEM", "do_compare cast failed")
        return (super.do_compare(rhs, comparer) &&
                (this.addr  == rhs_cast.addr)   &&
                (this.data  == rhs_cast.data)   &&
                (this.strb  == rhs_cast.strb)   &&
                (this.wr_rd == rhs_cast.wr_rd));
    endfunction

    // ----------------------------------------------------------
    // convert2string
    // ----------------------------------------------------------
    function string convert2string();
        return $sformatf(
            "APB_ITEM: %s ADDR=0x%08h DATA=0x%08h STRB=%04b RDATA=0x%08h ERR=%0b",
            (wr_rd ? "WRITE" : "READ"), addr, data, strb, rdata, slv_err
        );
    endfunction

    // ----------------------------------------------------------
    // do_print
    // ----------------------------------------------------------
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_string("xfer_type", wr_rd ? "WRITE" : "READ");
        printer.print_field_int("addr",    addr,    32, UVM_HEX);
        printer.print_field_int("data",    data,    32, UVM_HEX);
        printer.print_field_int("strb",    strb,     4, UVM_BIN);
        printer.print_field_int("rdata",   rdata,   32, UVM_HEX);
        printer.print_field_int("slv_err", slv_err,  1, UVM_BIN);
    endfunction

endclass
