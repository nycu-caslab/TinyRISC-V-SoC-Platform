module Compressor42 #(
    parameter WIDTH = 64
) 
(
    input [(WIDTH-1):0] in1, in2, in3, in4,
    output [(WIDTH-1):0] out1, out2
);
        
    wire [(WIDTH-1):0] w1, w2, w3;

    assign w1 = in1 ^ in2 ^ in3 ^ in4;
    assign w2 = (in1 & in2) | (in3 & in4);
    assign w3 = (in1 | in2) & (in3 | in4);

    assign out1 = {w1} ^ {w3[(WIDTH-2):0], 1'b0};
    assign out2 = ((w1 & {w3[(WIDTH-2):0], 1'b0}) | ((~w1) & w2)) << 1;

endmodule  
