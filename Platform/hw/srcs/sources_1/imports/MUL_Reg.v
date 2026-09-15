module MUL_Reg #(
    parameter SIZE = 16
)
(
    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire [((64 * SIZE) - 1):0] partial_i,
    input wire [1:0] sign_i,
    input wire higher_i,

    output wire start_o,
    output wire [((64 * SIZE) - 1):0] partial_o,
    output wire [1:0] sign_o,
    output wire higher_o
);

    genvar g_i;
    generate
        for (g_i = 0; g_i < SIZE; g_i = g_i + 1) begin: reg_partial_products
            PipelineRegister #(.WIDTH(64)) reg_partial (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(partial_i[(64 * (g_i + 1) - 1):(64 * g_i)]), .data_o(partial_o[(64 * (g_i + 1) - 1):(64 * g_i)]));
        end
    endgenerate

    PipelineRegister #(.WIDTH( 1)) reg_start    (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(start_i),    .data_o(start_o));
    PipelineRegister #(.WIDTH( 2)) reg_sign     (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(sign_i),     .data_o(sign_o));
    PipelineRegister #(.WIDTH( 1)) reg_higher   (.clk(clk), .rst_n(rst_n), .clear(1'b0), .en(1'b1), .data_i(higher_i),   .data_o(higher_o));

endmodule
