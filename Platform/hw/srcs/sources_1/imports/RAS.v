`include "riscv_defs.v"
// Return Address Stack -- predicts jalr-return targets at ID so front-end
// fetch can redirect a cycle earlier than waiting for EX to resolve the real
// target, instead of unconditionally flushing on every jal/jalr like today.
//
// Call/return classification follows the RISC-V hint table (unprivileged
// ISA manual): push on any jal/jalr whose rd is a link register (x1/x5) --
// covers direct calls (jal) and indirect/far calls (jalr rd=link, e.g. the
// `call` pseudo-op's rd=x1,rs1=x1 far-call jalr); predict-pop on jalr whose
// rs1 is a link register AND rd is NOT a link register -- covers `ret`
// (jalr x0,x1,0). is_call and is_return are mutually exclusive by
// construction (is_call requires rd_is_link, is_return requires
// ~rd_is_link), so the "rd=link AND rs1=link" far-call case falls cleanly
// into is_call only, never mistaken for a return.
//
// en/clear are the SAME EX_en/EX_clear Exec.v's own PipelineRegisters use --
// reusing them (rather than re-deriving a departure condition) guarantees
// the stack only mutates, and predict_valid_o only pulses, on the exact
// cycle ID's content is genuinely captured into EX: never repeated across a
// stall cycle (en=0 holds), and never fired for a wrong-path instruction
// about to be squashed (redirect_flush forces clear=1, which also blocks
// mem-busy-blocked admission via the same EX_clear expression -- see
// PipelineCtrl.v). This is also what keeps predict_valid_o mutually
// exclusive with the same-cycle EX-side redirect_flush in Backend_top.v: a
// real redirect_flush this cycle implies clear=1, which forces
// predict_valid_o=0 here regardless of what ID currently holds.
module RAS #(
    parameter DEPTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clear,

    input  wire        id_valid,
    input  wire [31:0] id_inst,
    input  wire [4:0]  id_rd,
    input  wire [4:0]  id_rs1,
    input  wire [31:0] id_pc_p4,

    output wire        predict_valid_o,
    output wire [31:0] predict_pc_o
);

localparam PTR_W = $clog2(DEPTH + 1);

reg [31:0] stack [0:DEPTH-1];
reg [PTR_W-1:0] sp; // number of entries currently on the stack

wire is_jal      = (id_inst & `INST_JAL_MASK)  == `INST_JAL;
wire is_jalr     = (id_inst & `INST_JALR_MASK) == `INST_JALR;
wire rd_is_link  = (id_rd  == 5'd1) | (id_rd  == 5'd5);
wire rs1_is_link = (id_rs1 == 5'd1) | (id_rs1 == 5'd5);

wire is_call   = id_valid & (is_jal | is_jalr) & rd_is_link;
wire is_return = id_valid & is_jalr & rs1_is_link & ~rd_is_link;

wire fire = en & ~clear;

assign predict_valid_o = fire & is_return & (sp != {PTR_W{1'b0}});
assign predict_pc_o    = stack[sp - 1'b1];

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        sp <= {PTR_W{1'b0}};
    end else if (fire) begin
        if (is_call) begin
            // Silently saturate on overflow (deeper call nesting than
            // DEPTH): the newest call's return address is simply not
            // tracked, so its eventual return falls back to the normal
            // EX-verified flush -- a missed prediction opportunity, not a
            // correctness risk.
            if (sp != DEPTH[PTR_W-1:0]) begin
                stack[sp] <= id_pc_p4;
                sp <= sp + 1'b1;
            end
        end else if (is_return & (sp != {PTR_W{1'b0}})) begin
            sp <= sp - 1'b1;
        end
    end
end

endmodule
