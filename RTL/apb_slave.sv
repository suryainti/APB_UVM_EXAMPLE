// ============================================================
// ARM APB (AMBA APB3) Slave - Synthesizable SystemVerilog
// Internal 16-entry memory, supports PREADY, PSLVERR
// ============================================================

module apb_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 16   // Number of 32-bit registers
)(
    // Global Signals
    input  logic                    PCLK,
    input  logic                    PRESETn,

    // APB Slave Interface
    input  logic [ADDR_WIDTH-1:0]   PADDR,
    input  logic                    PSEL,
    input  logic                    PENABLE,
    input  logic                    PWRITE,
    input  logic [DATA_WIDTH-1:0]   PWDATA,
    input  logic [DATA_WIDTH/8-1:0] PSTRB,

    output logic [DATA_WIDTH-1:0]   PRDATA,
    output logic                    PREADY,
    output logic                    PSLVERR
);

    // -------------------------------------------------------
    // Internal Memory (Registers)
    // -------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // -------------------------------------------------------
    // Address Decode
    // Word-aligned: PADDR[ADDR_WIDTH-1:2] used as index
    // -------------------------------------------------------
    logic [$clog2(MEM_DEPTH)-1:0] word_addr;
    logic                          addr_valid;

    assign word_addr  = PADDR[$clog2(MEM_DEPTH)+1:2];
    assign addr_valid = (PADDR[ADDR_WIDTH-1:$clog2(MEM_DEPTH)+2] == '0) &&
                        (PADDR[1:0] == 2'b00);  // Must be word-aligned

    // -------------------------------------------------------
    // PREADY: Always ready (no wait states)
    // Change to registered logic to add wait states
    // -------------------------------------------------------
    assign PREADY = 1'b1;

    // -------------------------------------------------------
    // PSLVERR: Assert on invalid address or unaligned access
    // -------------------------------------------------------
    assign PSLVERR = PSEL & PENABLE & ~addr_valid;

    // -------------------------------------------------------
    // Write Logic
    // -------------------------------------------------------
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (int i = 0; i < MEM_DEPTH; i++)
                mem[i] <= '0;
        end else begin
            if (PSEL && PENABLE && PWRITE && PREADY && addr_valid) begin
                // Byte-enable write using PSTRB
                for (int b = 0; b < DATA_WIDTH/8; b++) begin
                    if (PSTRB[b])
                        mem[word_addr][b*8 +: 8] <= PWDATA[b*8 +: 8];
                end
            end
        end
    end

    // -------------------------------------------------------
    // Read Logic (Combinational)
    // -------------------------------------------------------
    always_comb begin
        if (PSEL && !PWRITE && addr_valid)
            PRDATA = mem[word_addr];
        else
            PRDATA = '0;
    end

endmodule
