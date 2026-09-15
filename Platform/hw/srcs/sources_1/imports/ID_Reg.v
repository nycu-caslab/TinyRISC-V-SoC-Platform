module ID_Reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clear,
    input  wire        pc_valid_i,
    input  wire [31:0] pc_i,
    input  wire [31:0] pc_p4_i,
    output wire        pc_valid_o,
    output wire [31:0] pc_o,
    output wire [31:0] pc_p4_o,
    input  wire [31:0] inst_i,
    output wire [31:0] inst_o
);
    PipelineRegister #(.WIDTH( 1)) reg_pc_valid (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_valid_i),   .data_o(pc_valid_o));
    PipelineRegister #(.WIDTH(32)) reg_pc       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_i),   .data_o(pc_o));
    PipelineRegister #(.WIDTH(32)) reg_pc4      (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_p4_i), .data_o(pc_p4_o));
    PipelineRegister #(.WIDTH(32)) reg_inst     (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(inst_i), .data_o(inst_o));
endmodule
