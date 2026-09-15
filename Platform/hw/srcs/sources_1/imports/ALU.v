//-----------------------------------------------------------------
// ALU
//-----------------------------------------------------------------
module ALU(
    input  [31:0] InA,
    input  [31:0] InB,
    input         Cin,
    input  [2:0]  Oper,
    input         invA,
    input         invB,
    input         Sign,
    output [31:0] Out,
    output        Ofl,
    output        Zero
);

wire [31:0] shift_out; 
wire [31:0] invertA, invertB, A, B;
wire signA, signB, sign_result;
wire sign_ofl, unsign_ofl;

reg [31:0] result;
reg Ofl_result, Zero_result;

ALU_barrel_shifter shifter(
    .In(A),
    .ShAmt(B[4:0]),
    .Oper(Oper[1:0]),
    .Out(shift_out)
);

// First Bit of A, B, result
assign signA = A[31];
assign signB = B[31];
assign sign_result = result[31];

// Inverter
assign invertA = ~InA + 1;
assign invertB = ~InB + 1;
assign A = (invA)?invertA:InA;
assign B = (invB)?invertB:InB;

// Overflow Detection
assign sign_ofl = (~signA & ~signB & sign_result) | (signA & signB & ~sign_result);
assign unsign_ofl = (signA & signB) | (signA & ~sign_result) | (signB & ~sign_result); 

// Result Assign
assign Out = result;
assign Ofl = Ofl_result; 
assign Zero = Zero_result;

always @(*)begin
    case(Oper)
        3'b100: result = A + B + {31'h0, Cin};
        3'b101: result = A & B;
        3'b110: result = A | B;
        3'b111: result = A ^ B;
        default: result = shift_out;
    endcase

    case (Oper)
        3'b100:  Ofl_result = (Sign)?sign_ofl:unsign_ofl;
        default: Ofl_result = 1'b0;
    endcase
    
    Zero_result = (Out == 32'b0);
end

endmodule
