// ============================================================
// APB Testbench Top Module
// Instantiates DUT, Interface, and starts UVM test
// ============================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// Include all TB files
`include "apb_if.sv"
`include "apb_seq_item.sv"
`include "apb_sequences.sv"
`include "apb_driver.sv"
`include "apb_monitor.sv"
`include "apb_sequencer.sv"
`include "apb_agent.sv"
`include "apb_scoreboard.sv"
`include "apb_coverage.sv"
`include "apb_env.sv"
`include "apb_test.sv"

// Include RTL (DUT: Slave only — UVM driver acts as APB master)
`include "../RTL/apb_slave.sv"

module apb_tb_top;

    // ----------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz

    // ----------------------------------------------------------
    // Clock and Reset
    // ----------------------------------------------------------
    logic PCLK;
    logic PRESETn;

    // Clock generation
    initial PCLK = 1'b0;
    always #(CLK_PERIOD/2) PCLK = ~PCLK;

    // Reset generation
    initial begin
        PRESETn = 1'b0;
        repeat(5) @(posedge PCLK);
        PRESETn = 1'b1;
        `uvm_info("TB_TOP", "Reset deasserted", UVM_MEDIUM)
    end

    // ----------------------------------------------------------
    // Interface Instantiation
    // ----------------------------------------------------------
    apb_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) apb_vif (
        .PCLK    (PCLK),
        .PRESETn (PRESETn)
    );

    // ----------------------------------------------------------
    // DUT: APB Slave
    // UVM driver (acting as master) drives PADDR/PSEL/PENABLE
    // directly via the clocking block — no master RTL needed here
    // ----------------------------------------------------------
    apb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DEPTH (16)
    ) dut_slave (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PADDR   (apb_vif.PADDR),
        .PSEL    (apb_vif.PSEL),
        .PENABLE (apb_vif.PENABLE),
        .PWRITE  (apb_vif.PWRITE),
        .PWDATA  (apb_vif.PWDATA),
        .PSTRB   (apb_vif.PSTRB),
        .PRDATA  (apb_vif.PRDATA),
        .PREADY  (apb_vif.PREADY),
        .PSLVERR (apb_vif.PSLVERR)
    );

    // ----------------------------------------------------------
    // UVM Setup
    // ----------------------------------------------------------
    initial begin
        // Pass virtual interface to UVM config_db
        uvm_config_db #(virtual apb_if)::set(
            uvm_root::get(), "*", "apb_vif", apb_vif);

        // Run the test (pass test name via +UVM_TESTNAME=<test>)
        run_test();
    end

    // ----------------------------------------------------------
    // Timeout Watchdog
    // ----------------------------------------------------------
    initial begin
        #1_000_000;
        `uvm_fatal("TB_TOP", "TIMEOUT: Simulation exceeded 1ms")
    end

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        $dumpfile("apb_tb.vcd");
        $dumpvars(0, apb_tb_top);
    end

endmodule
