module DIV_Reg (
    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire [31:0] r_i,
    input wire [33:0] d_i,
    input wire [33:0] neg_d_i,
    input wire [65:0] r_1_i,
    input wire [65:0] r_2_i,
    input wire [31:0] pos_q_i,
    input wire [31:0] neg_q_i,
    input wire [4:0] shift_i,
    input wire r_sign_i, 
    input wire d_sign_i,
    input wire unsign_i,
    input wire rem_i,

    output wire start_o,
    output wire [31:0] r_o,
    output wire [33:0] d_o,
    output wire [33:0] neg_d_o,
    output wire [65:0] r_1_o,
    output wire [65:0] r_2_o,
    output wire [31:0] pos_q_o,
    output wire [31:0] neg_q_o,
    output wire [4:0] shift_o,
    output wire r_sign_o, 
    output wire d_sign_o,
    output wire unsign_o,
    output wire rem_o
);

    PipelineRegister #(.WIDTH( 1)) reg_start    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(start_i),    .data_o(start_o));
    PipelineRegister #(.WIDTH(32)) reg_r        (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(r_i),        .data_o(r_o));
    PipelineRegister #(.WIDTH(34)) reg_d        (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(d_i),        .data_o(d_o));
    PipelineRegister #(.WIDTH(34)) reg_neg_d    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(neg_d_i),    .data_o(neg_d_o));
    PipelineRegister #(.WIDTH(66)) reg_r_1      (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(r_1_i),      .data_o(r_1_o));
    PipelineRegister #(.WIDTH(66)) reg_r_2      (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(r_2_i),      .data_o(r_2_o));
    PipelineRegister #(.WIDTH(32)) reg_pos_q    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(pos_q_i),    .data_o(pos_q_o));
    PipelineRegister #(.WIDTH(32)) reg_neg_q    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(neg_q_i),    .data_o(neg_q_o));
    PipelineRegister #(.WIDTH( 5)) reg_shift    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(shift_i),    .data_o(shift_o));
    PipelineRegister #(.WIDTH( 1)) reg_r_sign   (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(r_sign_i),   .data_o(r_sign_o));
    PipelineRegister #(.WIDTH( 1)) reg_d_sign   (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(d_sign_i),   .data_o(d_sign_o));
    PipelineRegister #(.WIDTH( 1)) reg_unsign   (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(unsign_i),   .data_o(unsign_o));
    PipelineRegister #(.WIDTH( 1)) reg_rem      (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(rem_i),      .data_o(rem_o));
    

endmodule
