// ============================================================
// APB Functional Coverage Collector
// ============================================================

class apb_coverage extends uvm_subscriber #(apb_seq_item);
    `uvm_component_utils(apb_coverage)

    apb_seq_item item;

    // ----------------------------------------------------------
    // Covergroup: APB Transfer Type
    // ----------------------------------------------------------
    covergroup cg_apb_transfer;

        // Transfer direction
        cp_xfer_type: coverpoint item.wr_rd {
            bins WRITE = {1'b1};
            bins READ  = {1'b0};
        }

        // Address range bins
        cp_addr: coverpoint item.addr {
            bins low_range  = {[32'h0000_0000 : 32'h0000_000F]};
            bins mid_range  = {[32'h0000_0010 : 32'h0000_001F]};
            bins high_range = {[32'h0000_0020 : 32'h0000_003C]};
            bins illegal    = default;
        }

        // Byte strobe patterns (for writes)
        cp_strb: coverpoint item.strb {
            bins full_word    = {4'b1111};
            bins byte0_only   = {4'b0001};
            bins byte1_only   = {4'b0010};
            bins byte2_only   = {4'b0100};
            bins byte3_only   = {4'b1000};
            bins lower_half   = {4'b0011};
            bins upper_half   = {4'b1100};
            bins no_strb      = {4'b0000};
            bins other_strb   = default;
        }

        // Slave error response
        cp_slverr: coverpoint item.slv_err {
            bins no_error = {1'b0};
            bins error    = {1'b1};
        }

        // Write data value ranges
        cp_wdata: coverpoint item.data {
            bins zero       = {32'h0000_0000};
            bins all_ones   = {32'hFFFF_FFFF};
            bins low_byte   = {[32'h0000_0001 : 32'h0000_00FF]};
            bins mid_range  = {[32'h0000_0100 : 32'h7FFF_FFFE]};
            bins high_range = {[32'h7FFF_FFFF : 32'hFFFE_FFFF]};
        }

        // Cross: Transfer type x Address range
        cx_type_addr: cross cp_xfer_type, cp_addr;

        // Cross: Transfer type x Byte strobe
        cx_type_strb: cross cp_xfer_type, cp_strb {
            // READ should always have no strb
            ignore_bins illegal_read_strb = cx_type_strb with
                (cp_xfer_type == 0 && cp_strb != 8);
        }

        // Cross: Transfer type x Slave error
        cx_type_error: cross cp_xfer_type, cp_slverr;

    endgroup

    // ----------------------------------------------------------
    // Covergroup: APB Protocol State Transitions
    // ----------------------------------------------------------
    covergroup cg_apb_protocol;

        // Transfer type
        cp_xfer: coverpoint item.wr_rd {
            bins write_xfer = {1};
            bins read_xfer  = {0};
        }

        // Error occurrence
        cp_err: coverpoint item.slv_err {
            bins ok  = {0};
            bins err = {1};
        }

        // Address alignment
        cp_align: coverpoint item.addr[1:0] {
            bins aligned   = {2'b00};
            bins unaligned = {[2'b01:2'b11]};
        }

    endgroup

    // ----------------------------------------------------------
    // Covergroup: Address Hit Coverage
    // All 16 registers should be accessed
    // ----------------------------------------------------------
    covergroup cg_register_access;
        cp_reg: coverpoint (item.addr >> 2) {
            bins reg0  = {0};
            bins reg1  = {1};
            bins reg2  = {2};
            bins reg3  = {3};
            bins reg4  = {4};
            bins reg5  = {5};
            bins reg6  = {6};
            bins reg7  = {7};
            bins reg8  = {8};
            bins reg9  = {9};
            bins reg10 = {10};
            bins reg11 = {11};
            bins reg12 = {12};
            bins reg13 = {13};
            bins reg14 = {14};
            bins reg15 = {15};
        }

        cp_rw: coverpoint item.wr_rd {
            bins write = {1};
            bins read  = {0};
        }

        cx_reg_rw: cross cp_reg, cp_rw;
    endgroup

    // ----------------------------------------------------------
    // Constructor
    // ----------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_apb_transfer   = new();
        cg_apb_protocol   = new();
        cg_register_access = new();
    endfunction

    // ----------------------------------------------------------
    // write: Called by analysis port
    // ----------------------------------------------------------
    function void write(apb_seq_item t);
        item = t;
        cg_apb_transfer.sample();
        cg_apb_protocol.sample();
        cg_register_access.sample();
    endfunction

    // ----------------------------------------------------------
    // report_phase: Print coverage
    // ----------------------------------------------------------
    function void report_phase(uvm_phase phase);
        `uvm_info("COV", "============================================", UVM_MEDIUM)
        `uvm_info("COV", "         COVERAGE REPORT                   ", UVM_MEDIUM)
        `uvm_info("COV", "============================================", UVM_MEDIUM)
        `uvm_info("COV", $sformatf("  Transfer Coverage  : %0.2f%%",
            cg_apb_transfer.get_coverage()),    UVM_MEDIUM)
        `uvm_info("COV", $sformatf("  Protocol Coverage  : %0.2f%%",
            cg_apb_protocol.get_coverage()),    UVM_MEDIUM)
        `uvm_info("COV", $sformatf("  Register Coverage  : %0.2f%%",
            cg_register_access.get_coverage()), UVM_MEDIUM)
        `uvm_info("COV", "============================================", UVM_MEDIUM)
    endfunction

endclass
