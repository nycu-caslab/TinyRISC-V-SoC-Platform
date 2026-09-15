/* verilator lint_off UNUSEDSIGNAL */
`include "riscv_defs.v"
module ALU_top(
    input [3:0] ALU_ctrl,
    input [31:0] a,
    input [31:0] b,
    input        is_imm_i,
    output reg [31:0] out
);

reg [2:0]  Oper;
reg        invB;
wire [31:0] ALU_out;
wire        Overflow;
wire        Zero;
reg         Sign;

ALU m_ALU(
    .InA(a),
    .InB(b),
    .Cin(0),
    .Oper(Oper),
    .invA(0),
    .invB(invB),
    .Sign(1),

    .Out(ALU_out),
    .Ofl(Overflow),
    .Zero(Zero)
);

always @(*) begin
    Oper=3'b100;
    invB=0;
    out = 32'h0;
    Sign = 0;
    
    case (ALU_ctrl)
        `ALU_ADD: begin
            Oper = 3'b100; // ADD
            out = ALU_out;
        end
        `ALU_SUB: begin
            Oper = 3'b100; // ADD
            invB = 1; // -B
            out = ALU_out;
        end
        `ALU_AND: begin
            Oper = 3'b101; // AND
            out = ALU_out;
        end
        `ALU_OR: begin
            Oper = 3'b110; // OR
            out = ALU_out;
        end
        `ALU_XOR: begin
            Oper = 3'b111; // XOR
            out = ALU_out;
        end
        `ALU_SHIFTL: begin
            Oper = 3'b001; // SLL
            out = ALU_out;
        end
        `ALU_SHIFTR: begin
            Oper = 3'b011; // SRL
            out = ALU_out;
        end
        `ALU_SHIFTR_ARITH: begin
            Oper = 3'b010; // SRA
            out = ALU_out;
        end
        `ALU_LESS_THAN: begin
            out = {31'b0, a < b};
        end
        `ALU_LESS_THAN_SIGNED: begin
            Oper = 3'b100; // ADD
            invB=1; // -B
            out = {31'b0, $signed(a) < $signed(b)}; // Set result to 1 if less than
        end
        `ALU_NONE: begin
            out = 32'b0;
        end
        default:;
    endcase
end


endmodule
