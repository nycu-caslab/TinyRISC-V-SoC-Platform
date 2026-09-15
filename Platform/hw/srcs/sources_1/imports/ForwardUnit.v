// Forwarding for the 5-stage pipeline.
//
// The register file writes on negedge (Register.v), which gives WB->ID
// write-through for free, so only the two stages that sit between a producer
// and a consumer in EX need explicit forwarding paths:
//
//   MEM -> EX : producer one instruction ahead. Its result is already in the
//               EX/MEM register (or, for a multiply, in the DSP's output
//               register) -- except for a load, whose data does not exist yet.
//               Backend_top turns that case into a one-cycle load-use stall.
//   WB  -> EX : producer two instructions ahead, result in the MEM/WB register.
//
// MEM wins over WB when both match: it holds the newer value.
module ForwardUnit (
    input wire [4:0] EX_rs1,
    input wire [4:0] EX_rs2,
    input wire [4:0] EX_rs3,

    input wire [4:0] MEM_rd,
    input wire       MEM_reg_wr_en,

    input wire [4:0] WB_rd,
    input wire       WB_reg_wr_en,

    output reg [1:0] EX_fwd_sel1,   // 0 = WB, 1 = regfile, 2 = MEM
    output reg [1:0] EX_fwd_sel2
);

localparam SEL_WB = 2'd0, SEL_REG = 2'd1, SEL_MEM = 2'd2;

always @(*) begin
    EX_fwd_sel1 = SEL_REG;
    if (MEM_reg_wr_en && (MEM_rd != 5'd0) && (MEM_rd == EX_rs1))     EX_fwd_sel1 = SEL_MEM;
    else if (WB_reg_wr_en && (WB_rd != 5'd0) && (WB_rd == EX_rs1))   EX_fwd_sel1 = SEL_WB;

    EX_fwd_sel2 = SEL_REG;
    if (MEM_reg_wr_en && (MEM_rd != 5'd0) && (MEM_rd == EX_rs2))     EX_fwd_sel2 = SEL_MEM;
    else if (WB_reg_wr_en && (WB_rd != 5'd0) && (WB_rd == EX_rs2))   EX_fwd_sel2 = SEL_WB;
end

endmodule
