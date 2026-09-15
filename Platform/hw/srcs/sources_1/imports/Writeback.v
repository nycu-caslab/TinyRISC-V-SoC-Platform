// WB stage. With a single result bus arriving from MEM there is nothing left
// to select here -- the stage is just the MEM/WB register plus the guard that
// suppresses the register write for bubbles and illegal instructions.
module Writeback (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clear,

    input  wire        is_impl_i,
    input  wire        pc_valid_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] pc_p4_i,
    input  wire [ 4:0] rd_i,
    input  wire [31:0] result_i,
    input  wire        reg_wr_en_i,

    output wire        is_impl_o,
    output wire        pc_valid_o,
    output wire [31:0] pc_o,
    output wire [ 4:0] rd_o,
    output wire [31:0] wb_data_o,
    output wire        reg_wr_en_o
);

wire        WB_reg_wr_en_out;
wire        WB_is_impl_out, WB_pc_valid_out /* verilator public */;
wire [31:0] WB_pc_out /* verilator public */;
wire [31:0] WB_pc_p4_out;

WB_Reg m_WB_Reg(
    .clk(clk), .rst_n(rst_n), .en(en), .clear(clear),

    .is_impl_i(is_impl_i), .pc_valid_i(pc_valid_i), .pc_i(pc_i), .pc_p4_i(pc_p4_i),
    .rd_i(rd_i), .result_i(result_i),
    .reg_wr_en_i(reg_wr_en_i & pc_valid_i & is_impl_i),

    .is_impl_o(WB_is_impl_out), .pc_valid_o(WB_pc_valid_out), .pc_o(WB_pc_out),
    .pc_p4_o(WB_pc_p4_out), .rd_o(rd_o), .result_o(wb_data_o),
    .reg_wr_en_o(WB_reg_wr_en_out)
);

assign is_impl_o   = WB_is_impl_out;
assign pc_valid_o  = WB_pc_valid_out;
assign pc_o        = WB_pc_out;
assign reg_wr_en_o = WB_reg_wr_en_out;

endmodule
