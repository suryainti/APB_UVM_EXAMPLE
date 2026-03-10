// ============================================================
// APB Interface with Clocking Blocks and SVA Assertions
// ============================================================

interface apb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic PCLK,
    input logic PRESETn
);

    // APB Signals
    logic [ADDR_WIDTH-1:0]    PADDR;
    logic                     PSEL;
    logic                     PENABLE;
    logic                     PWRITE;
    logic [DATA_WIDTH-1:0]    PWDATA;
    logic [DATA_WIDTH/8-1:0]  PSTRB;
    logic [DATA_WIDTH-1:0]    PRDATA;
    logic                     PREADY;
    logic                     PSLVERR;

    // ----------------------------------------------------------
    // Clocking Block - Driver (Master drives)
    // ----------------------------------------------------------
    clocking master_cb @(posedge PCLK);
        default input  #1step;
        default output #1;
        output PADDR;
        output PSEL;
        output PENABLE;
        output PWRITE;
        output PWDATA;
        output PSTRB;
        input  PRDATA;
        input  PREADY;
        input  PSLVERR;
    endclocking

    // ----------------------------------------------------------
    // Clocking Block - Monitor (observe only)
    // ----------------------------------------------------------
    clocking monitor_cb @(posedge PCLK);
        default input #1step;
        input PADDR;
        input PSEL;
        input PENABLE;
        input PWRITE;
        input PWDATA;
        input PSTRB;
        input PRDATA;
        input PREADY;
        input PSLVERR;
    endclocking

    // ----------------------------------------------------------
    // Modports
    // ----------------------------------------------------------
    modport MASTER (clocking master_cb, input PCLK, PRESETn);
    modport MONITOR(clocking monitor_cb, input PCLK, PRESETn);

    // ==========================================================
    // SVA - SystemVerilog Assertions
    // ==========================================================

    // A1: PENABLE must be asserted only after PSEL
    property p_penable_after_psel;
        @(posedge PCLK) disable iff (!PRESETn)
        PENABLE |-> PSEL;
    endproperty
    A_PENABLE_AFTER_PSEL: assert property (p_penable_after_psel)
        else $error("[APB ASSERT] PENABLE asserted without PSEL");

    // A2: PSEL must be asserted for at least 1 cycle before PENABLE
    property p_setup_phase;
        @(posedge PCLK) disable iff (!PRESETn)
        $rose(PSEL) |=> PENABLE;
    endproperty
    A_SETUP_PHASE: assert property (p_setup_phase)
        else $error("[APB ASSERT] PENABLE not asserted cycle after PSEL rose");

    // A3: PADDR, PWRITE, PWDATA must be stable during ACCESS phase
    property p_paddr_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PADDR);
    endproperty
    A_PADDR_STABLE: assert property (p_paddr_stable)
        else $error("[APB ASSERT] PADDR changed during ACCESS phase");

    property p_pwrite_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PWRITE);
    endproperty
    A_PWRITE_STABLE: assert property (p_pwrite_stable)
        else $error("[APB ASSERT] PWRITE changed during ACCESS phase");

    property p_pwdata_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PWRITE && !PREADY) |=> $stable(PWDATA);
    endproperty
    A_PWDATA_STABLE: assert property (p_pwdata_stable)
        else $error("[APB ASSERT] PWDATA changed during ACCESS write phase");

    // A4: PSEL deasserted after successful transfer (PREADY high)
    property p_psel_deassert_after_ready;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && PREADY) |=> !PENABLE;
    endproperty
    A_PENABLE_DEASSERT: assert property (p_psel_deassert_after_ready)
        else $error("[APB ASSERT] PENABLE not deasserted after PREADY");

    // A5: PSTRB must be 0 during reads
    property p_pstrb_read_zero;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PWRITE) |-> (PSTRB == '0);
    endproperty
    A_PSTRB_READ_ZERO: assert property (p_pstrb_read_zero)
        else $error("[APB ASSERT] PSTRB non-zero during READ transfer");

    // A6: No X/Z on control signals when PSEL is asserted
    property p_no_x_on_paddr;
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL |-> !$isunknown(PADDR);
    endproperty
    A_NO_X_PADDR: assert property (p_no_x_on_paddr)
        else $error("[APB ASSERT] X/Z detected on PADDR during PSEL");

    property p_no_x_on_pwrite;
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL |-> !$isunknown(PWRITE);
    endproperty
    A_NO_X_PWRITE: assert property (p_no_x_on_pwrite)
        else $error("[APB ASSERT] X/Z detected on PWRITE during PSEL");

    // A7: Reset check - all master outputs deasserted during reset
    property p_reset_state;
        @(posedge PCLK)
        !PRESETn |-> (!PSEL && !PENABLE);
    endproperty
    A_RESET_STATE: assert property (p_reset_state)
        else $error("[APB ASSERT] PSEL/PENABLE not deasserted during reset");

    // ----------------------------------------------------------
    // Cover Properties
    // ----------------------------------------------------------
    COV_WRITE_TRANSFER: cover property (
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL && PENABLE && PWRITE && PREADY
    );

    COV_READ_TRANSFER: cover property (
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL && PENABLE && !PWRITE && PREADY
    );

    COV_SLAVE_ERROR: cover property (
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL && PENABLE && PREADY && PSLVERR
    );

    COV_WAIT_STATES: cover property (
        @(posedge PCLK) disable iff (!PRESETn)
        PSEL && PENABLE && !PREADY
    );

endinterface
