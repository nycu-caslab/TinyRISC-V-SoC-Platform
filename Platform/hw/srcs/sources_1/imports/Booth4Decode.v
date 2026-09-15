module Booth4Decode (
    input [2:0] code,
    input [31:0] multiplicand,
    input unsign,
    output reg [33:0] booth_out //sign + 32 bits << 1/0 = 34 bits
);

    wire [32:0] pos_multiplicand;
    wire [32:0] neg_multiplicand;
    
    // unsigned or signed are handled here
    assign pos_multiplicand = {(unsign ? 1'b0 : multiplicand[31]), multiplicand};   // for signed multiplicand, neg_multiplicand = multiplicand may happen
    assign neg_multiplicand = -pos_multiplicand;                                    // ex: 10000000 -> 10000000, append to 33 bit to avoid this: 110000000 -> 010000000

    always @(*) begin

        case(code)
            3'b000: booth_out = 34'b0;
            3'b001: booth_out = {pos_multiplicand[32], pos_multiplicand}; // m
            3'b010: booth_out = {pos_multiplicand[32], pos_multiplicand};
            3'b011: booth_out = {pos_multiplicand, 1'b0}; // 2m
            3'b100: booth_out = {neg_multiplicand, 1'b0}; // -2m
            3'b101: booth_out = {neg_multiplicand[32], neg_multiplicand}; // -m
            3'b110: booth_out = {neg_multiplicand[32], neg_multiplicand};
            3'b111: booth_out = 34'b0;

            default: booth_out = 34'bx;
        endcase
    end

endmodule
