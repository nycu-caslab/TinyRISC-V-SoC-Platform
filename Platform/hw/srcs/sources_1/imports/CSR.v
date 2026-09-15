/* verilator lint_off UNUSEDSIGNAL */
`include "riscv_defs.v"
module CSR (
    input                       clk,
    input                       rst_n,
    input  [11:0]               csr_rd_addr_i,

    output [31:0]               csr_rd_data_o
);

reg [63:0] mcycle;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        mcycle <= 64'd0;
    else
        mcycle <= mcycle + 64'd1;
end

reg [31:0] csr_rd_data;
always @(*) begin
    case (csr_rd_addr_i)
        `CSR_MCYCLE:
            csr_rd_data = mcycle[31:0];
        `CSR_MCYCLEH:
            csr_rd_data = mcycle[63:32];
        default:
            csr_rd_data = 32'd0;
    endcase
end

assign csr_rd_data_o = csr_rd_data;

endmodule
