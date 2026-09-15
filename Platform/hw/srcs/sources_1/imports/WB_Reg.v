// MEM/WB pipeline register.
//
// Carries one already-selected result instead of the six parallel result buses
// the 4-stage version needed: the EX/MEM boundary picks the EX-computed result,
// and the MEM stage substitutes the multiply and load values that only become
// readable there. By the time anything reaches here there is exactly one value.
module WB_Reg (
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
    output wire [31:0] pc_p4_o,
    output wire [ 4:0] rd_o,
    output wire [31:0] result_o,
    output wire        reg_wr_en_o
);
    PipelineRegister #(.WIDTH( 1)) r_is_impl   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(is_impl_i),   .data_o(is_impl_o));
    PipelineRegister #(.WIDTH( 1)) r_pc_valid  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_valid_i),  .data_o(pc_valid_o));
    PipelineRegister #(.WIDTH(32)) r_pc        (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_i),        .data_o(pc_o));
    PipelineRegister #(.WIDTH(32)) r_pc_p4     (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_p4_i),     .data_o(pc_p4_o));
    PipelineRegister #(.WIDTH( 5)) r_rd        (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(rd_i),        .data_o(rd_o));
    PipelineRegister #(.WIDTH(32)) r_result    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(result_i),    .data_o(result_o));
    PipelineRegister #(.WIDTH( 1)) r_reg_wr_en (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(reg_wr_en_i), .data_o(reg_wr_en_o));
endmodule
