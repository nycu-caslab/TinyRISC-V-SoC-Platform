module Compressor32 #(
    parameter WIDTH = 64
)  
(
    input [(WIDTH-1):0] in1, in2, in3,
    output [(WIDTH-1):0] out1, out2
);

    assign out1 = in1 ^ in2 ^ in3;
    assign out2 = ((in1 & in2) | (in1 & in3) | (in2 & in3)) << 1;

endmodule  
