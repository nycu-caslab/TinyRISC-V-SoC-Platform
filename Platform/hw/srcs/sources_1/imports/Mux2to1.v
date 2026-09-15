module Mux2to1 #(parameter size = 32)
(
    input sel,
    input signed [size-1:0] s0,
    input signed [size-1:0] s1,
    output signed [size-1:0] out
);

assign out = (sel) ? s1 : s0;

endmodule
