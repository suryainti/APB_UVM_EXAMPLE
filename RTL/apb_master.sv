// ============================================================
// ARM APB (AMBA APB3) Master - Synthesizable SystemVerilog
// Supports: Read, Write, PREADY handshake, PSLVERR
// ============================================================

module apb_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    // Global Signals
    input  logic                   PCLK,
    input  logic                   PRESETn,

    // APB Master Output (to Slave)
    output logic [ADDR_WIDTH-1:0]  PADDR,
    output logic                   PSEL,
    output logic                   PENABLE,
    output logic                   PWRITE,
    output logic [DATA_WIDTH-1:0]  PWDATA,
    output logic [DATA_WIDTH/8-1:0] PSTRB,

    // APB Slave Response (from Slave)
    input  logic [DATA_WIDTH-1:0]  PRDATA,
    input  logic                   PREADY,
    input  logic                   PSLVERR,

    // User Interface (CPU / Controller side)
    input  logic                   start,       // Initiate transfer
    input  logic                   wr_rd,       // 1=Write, 0=Read
    input  logic [ADDR_WIDTH-1:0]  addr_in,
    input  logic [DATA_WIDTH-1:0]  wdata_in,
    input  logic [DATA_WIDTH/8-1:0] strb_in,

    output logic [DATA_WIDTH-1:0]  rdata_out,
    output logic                   done,        // Transfer complete
    output logic                   error        // Slave error
);

    // -------------------------------------------------------
    // APB State Machine States
    // -------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10
    } apb_state_t;

    apb_state_t curr_state, next_state;

    // -------------------------------------------------------
    // Registered Internal Signals
    // -------------------------------------------------------
    logic [ADDR_WIDTH-1:0]   addr_reg;
    logic [DATA_WIDTH-1:0]   wdata_reg;
    logic [DATA_WIDTH/8-1:0] strb_reg;
    logic                    wr_reg;

    // -------------------------------------------------------
    // State Register (Sequential)
    // -------------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    // -------------------------------------------------------
    // Latch inputs at start of transfer
    // -------------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            addr_reg  <= '0;
            wdata_reg <= '0;
            strb_reg  <= '0;
            wr_reg    <= 1'b0;
        end else if (start && curr_state == IDLE) begin
            addr_reg  <= addr_in;
            wdata_reg <= wdata_in;
            strb_reg  <= strb_in;
            wr_reg    <= wr_rd;
        end
    end

    // -------------------------------------------------------
    // Next State Logic (Combinational)
    // -------------------------------------------------------
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (start)
                    next_state = SETUP;
            end
            SETUP: begin
                next_state = ACCESS;
            end
            ACCESS: begin
                if (PREADY)
                    next_state = IDLE;
                else
                    next_state = ACCESS;
            end
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------
    // Output Logic (Combinational)
    // -------------------------------------------------------
    always_comb begin
        // Defaults
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PADDR   = '0;
        PWDATA  = '0;
        PSTRB   = '0;
        done    = 1'b0;
        error   = 1'b0;

        case (curr_state)
            IDLE: begin
                // All outputs deasserted
            end

            SETUP: begin
                PSEL   = 1'b1;
                PENABLE= 1'b0;
                PWRITE = wr_reg;
                PADDR  = addr_reg;
                PWDATA = wr_reg ? wdata_reg : '0;
                PSTRB  = wr_reg ? strb_reg  : '0;
            end

            ACCESS: begin
                PSEL    = 1'b1;
                PENABLE = 1'b1;
                PWRITE  = wr_reg;
                PADDR   = addr_reg;
                PWDATA  = wr_reg ? wdata_reg : '0;
                PSTRB   = wr_reg ? strb_reg  : '0;
                if (PREADY) begin
                    done  = 1'b1;
                    error = PSLVERR;
                end
            end

            default: begin end
        endcase
    end

    // -------------------------------------------------------
    // Read Data Capture
    // -------------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            rdata_out <= '0;
        else if (curr_state == ACCESS && PREADY && !wr_reg)
            rdata_out <= PRDATA;
    end

endmodule
