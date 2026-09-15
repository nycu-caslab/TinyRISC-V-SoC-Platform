module PC(
    input clk,
    input rst_n,
    input pc_en,
    input [31:0] pc_i,
    output reg [31:0] pc_o
);

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) pc_o <= 32'b0;
    else if(pc_en) pc_o <= pc_i;
end

endmodule
