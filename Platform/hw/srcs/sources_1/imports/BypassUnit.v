module BypassUnit (
    input  [31:0] reg_data1,
    input  [31:0] imm,
    input  [1:0]  bypass_sel,
    output [31:0] result_o
);

reg [31:0] result_r;
always @(*) begin
    case (bypass_sel)
        2'b00:   result_r = 32'b0;       // No bypass
        2'b01:   result_r = imm;         // lui
        2'b10:   result_r = reg_data1;   // mv.w.x
        default: result_r = 32'b0;       // No bypass
    endcase
end

assign result_o = result_r;

endmodule
