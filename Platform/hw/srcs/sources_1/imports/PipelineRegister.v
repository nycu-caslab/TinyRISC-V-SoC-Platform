module PipelineRegister #(
    parameter WIDTH = 32
)(
    input wire clk,
    input wire rst_n,

    input wire clear,
    input wire en,

    input wire [WIDTH-1:0] data_i,
    output reg [WIDTH-1:0] data_o
);

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) data_o <= {WIDTH{1'b0}};
    else if (en) begin
        if(clear) data_o <= {WIDTH{1'b0}};
        else data_o <= data_i;
    end
end

endmodule
