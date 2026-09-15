`timescale 1ns / 1ps
`include "riscv_defs.v"

module Backend_top (
    input         clk,
    input         rst_n,

    // Frontend Interface
    input         inst_rdy_i,
    input  [31:0] inst_pc_i,
    input  [31:0] inst_i,
    input         inst_pred_taken_i,
    output        req_inst_o,
    output        redirect_valid_o,
    output [31:0] redirect_pc_o,
    output        invalidate_o,
    input         invalid_complete_i,

    // Control-flow resolution feedback to the frontend predictor/BTB
    output        resolve_valid_o,
    output        resolve_is_branch_o,
    output        resolve_is_jump_o,
    output        resolve_taken_o,
    output [31:0] resolve_pc_o,
    output [31:0] resolve_target_o,

    // D-Cache & AXI Interfaces
    output [31:0] dbus_rm_addr, 
	input dbus_rm_rdy, 
	input [255:0] dbus_rm_data,
    input dbus_rm_success, 
	input dbus_rm_complete, 
	output dbus_rm_vld,
    input dbus_wm_rdy, 
	output [255:0] dbus_wm_data, 
	output dbus_wm_vld,
    input dbus_wm_success, 
	input dbus_wm_complete,

    output m_axi_lite_awvalid, 
	input m_axi_lite_awready, 
	output [31:0] m_axi_lite_awaddr,
    output m_axi_lite_wvalid, 
	input m_axi_lite_wready, 
	output [31:0] m_axi_lite_wdata,
    output [ 3:0] m_axi_lite_wstrb, 
	input m_axi_lite_bvalid, 
	output m_axi_lite_bready,
    input [ 1:0] m_axi_lite_bresp, 
	output m_axi_lite_arvalid, 
	input m_axi_lite_arready,
    output [31:0] m_axi_lite_araddr, 
	input m_axi_lite_rvalid, 
	output m_axi_lite_rready,
    input [31:0] m_axi_lite_rdata, 
	input [ 1:0] m_axi_lite_rresp,

    // NPU Interface
    output [31:0] rs1_o, 
	output [31:0] rs2_o, 
	input [31:0] NPU_out,
    output NPU_start, 
	input NPU_done, 
	output [ 3:0] funct3_o, 
	output [31:0] funct7_o
);

wire EX_done, EX_pc_valid_out, EX_is_br_out, EX_is_j_out, br_taken, EX_fetch_invalid_out;
wire [31:0] ALU_out, EX_pc_out, EX_pc_p4_out;
wire        ID_pred_taken_out, EX_pred_taken_out;
wire EX_ras_predicted_out;
wire [31:0] EX_ras_predicted_pc_out;
wire EX_jalr_target_valid_out;
wire [31:0] EX_jalr_target_out;

wire EX_is_impl_out, EX_reg_wr_en_out, EX_mem_rd_en_out, EX_mem_wr_en_out;
wire EX_is_MUL_DIV_out, EX_is_csr_out, EX_is_npu_out;
wire [31:0] EX_inst_out, EX_imm_out, EX_fwd_data1, EX_fwd_data2;
wire [4:0]  EX_rd_out, EX_rs1_out, EX_rs2_out, EX_rs3_out;
wire [2:0]  EX_reg_w_sel_out, EX_cmp_op_out, EX_MUL_DIV_ctrl_out;
wire [3:0]  EX_mem_ctrl_out, EX_ALU_ctrl_out;
wire [11:0] EX_csr_addr_out;
wire [1:0]  EX_bypass_sel_out;
wire EX_start, MUL_DIV_start, mem_req, MUL_done, DIV_done;
wire NPU_start_raw;
wire [31:0] MUL_DIV_out, bypass_out, csr_rd_data;
wire [31:0] EX_mem_addr_out, EX_mem_data_wr_out;
wire [3:0]  EX_mem_mask_out;
wire        EX_mem_cacheable_out;

wire        MEM_reg_wr_en, MEM_mem_rd_en;
wire [31:0] MEM_result;
wire [4:0]  MEM_rd;

wire ID_reads_pending_load;
wire mem_pending_now_or_soon, buffer_valid, buffer_pending_now_or_soon;

// A RAS-predicted jalr (see RAS.v) only needs the real EX-verified flush
// when the prediction was actually wrong. A non-predicted jal/jalr
// (ras_predicted_out=0, e.g. no RAS entry, RAS overflow, or a plain jal)
// keeps today's unconditional-flush behavior exactly as before -- this
// only ever *removes* flushes RAS already verified were unnecessary, never
// adds new ones.
//
// Deliberately compares against EX_jalr_target_out (ID's cheap,
// hazard-checked speculative target -- see id_jalr_target/id_rs1_hazard
// above), NOT ALU_out/control_target: the first version of this compared
// against ALU_out directly, which needs ForwardUnit's compare + the ALU's
// carry-chain adder to settle first. Since this feeds br_flush's
// *condition* (not just redirect_pc_o's value, which already tolerated
// ALU_out's latency safely), that put ALU_out on the path to
// redirect_valid_o -- which fans out to the whole 16-deep frontend
// instruction buffer's flush logic -- and blew timing by -2.8ns (1808
// failing endpoints) when first tried. When EX_jalr_target_valid_out is 0
// (ID detected a same-cycle rs1 hazard, so its early read couldn't be
// trusted), force a flush rather than trust a possibly-stale target --
// exactly the "unsure -> fall back to always flush" rule this was designed
// around. redirect_pc_o's actual VALUE still comes from control_target
// (ALU_out) either way (see below) -- only the flush *decision* changed,
// and only for RAS-predicted returns.
// EX_done is a 1-cycle pulse, and EX_en is derived straight from it
// (PipelineCtrl.v: EX_en = ~EX_own_stall = EX_done) -- mem_busy only ever
// gates admission (pc_en/ID_en) and EX_clear, never EX_en itself, so the
// instruction always departs EX on the exact cycle EX_done fires. No latch
// is needed here.
wire        control_resolved = EX_pc_valid_out && EX_done &&
                               (EX_is_br_out || EX_is_j_out);
wire        EX_is_jalr = EX_is_j_out &&
                         ((EX_inst_out & `INST_JALR_MASK) == `INST_JALR);
wire        control_taken = EX_is_j_out || (EX_is_br_out && br_taken);
wire [31:0] control_target = {ALU_out[31:2], 2'b00};
wire [31:0] control_next_pc = control_taken ? control_target : EX_pc_p4_out;

// Conditional branches compare only the predicted and resolved directions.
// Direct JAL targets are invariant, so a BTB hit needs no EX target compare.
// JALR is excluded from the BTB and uses the separate RAS prediction.
wire EX_jalr_mispredicted = EX_ras_predicted_out &&
    (!EX_jalr_target_valid_out ||
     ({EX_jalr_target_out[31:2], 2'b0} != EX_ras_predicted_pc_out));
wire EX_jalr_needs_flush = EX_is_jalr &&
    (!EX_ras_predicted_out || EX_jalr_mispredicted);
wire control_direction_miss =
    (EX_is_br_out && (EX_pred_taken_out != br_taken)) ||
    (EX_is_j_out && !EX_is_jalr && !EX_pred_taken_out) ||
    EX_jalr_needs_flush;
wire control_mispredict = control_resolved &&
                          control_direction_miss;

wire fencei_flush = EX_pc_valid_out && EX_done && EX_fetch_invalid_out;

wire redirect_flush = control_mispredict | fencei_flush;

// RAS speculative redirect -- see RAS.v's header comment for why this is
// guaranteed mutually exclusive with redirect_flush firing the same cycle.
wire ras_predict_valid;
wire [31:0] ras_predict_pc;

// EX_done says three things at once: "my unit finished", "I am a bubble" and
// "I am an illegal instruction" -- see Exec.v's EX_done_o. EX_has_result pulls
// the first meaning back out, which is what the EX/MEM boundary needs so a
// bubble is never captured as a valid instruction.
wire EX_has_result = EX_done && EX_pc_valid_out && EX_is_impl_out;

// All flow control lives in PipelineCtrl; these are the raw conditions it
// works from, and the enables/clears it hands back.
wire pc_en, ID_en, ID_clear, EX_en, EX_clear, MEM_en, MEM_clear, WB_en, WB_clear;
wire ras_clear;

assign redirect_valid_o = redirect_flush | ras_predict_valid;
assign redirect_pc_o    = redirect_flush
    ? (control_mispredict ? control_next_pc : EX_pc_p4_out)
    : ras_predict_pc;

assign invalidate_o = fencei_flush;

// Never allocate/train JALR in the predictor or BTB. Its dynamic target is
// resolved by the forwarded ALU operands in EX on every execution.
assign resolve_valid_o     = control_resolved && !EX_is_jalr;
assign resolve_is_branch_o = control_resolved && EX_is_br_out;
assign resolve_is_jump_o   = control_resolved && EX_is_j_out && !EX_is_jalr;
assign resolve_taken_o     = control_taken;
assign resolve_pc_o        = EX_pc_out;
assign resolve_target_o    = control_target;

PipelineCtrl m_PipelineCtrl(
    .redirect_flush (redirect_flush), .inst_rdy_i     (inst_rdy_i),
    .EX_done        (EX_done), .EX_has_result  (EX_has_result),
    .mem_busy_i     (mem_pending_now_or_soon), .mem_busy_reg_i (mem_busy),
    .mem_writeback_valid_i (mem_writeback_valid),
    .buffer_valid_i (buffer_pending_now_or_soon), .ID_is_mem_op_i (ID_is_mem_op),
    .mem_confirmed_hit_i (mem_confirmed_hit),
    .ID_load_use_hazard_i (ID_reads_pending_load),
    .ras_redirect_valid_i (ras_predict_valid),

    .req_inst_o (req_inst_o),
    .pc_en      (pc_en),
    .ID_en      (ID_en),  .ID_clear  (ID_clear),
    .EX_en      (EX_en),  .EX_clear  (EX_clear),
    .MEM_en     (MEM_en), .MEM_clear (MEM_clear),
    .WB_en      (WB_en),  .WB_clear  (WB_clear),
    .ras_clear_o (ras_clear)
);

wire        ID_pc_valid_out;
wire [31:0] ID_pc_out, ID_pc_p4_out, ID_inst_out, decode_imm;
wire [4:0]  decode_rs1, decode_rs2, decode_rs3, decode_rd;
wire [11:0] decode_csr_addr;
wire        is_impl, reg_wr_en, mem_wr_en, mem_rd_en, is_j, is_br, ALU_sel1, ALU_sel2, is_MUL_DIV, is_csr, is_npu, fetch_invalid;
wire [2:0]  reg_w_sel, cmp_op, MUL_DIV_ctrl;
wire [3:0]  mem_ctrl, ALU_ctrl;
wire [1:0]  bypass_sel;

wire [31:0] inst_pc_p4 = inst_pc_i + 32'd4;

Decode m_ID(
    .clk             (clk), .rst_n           (rst_n), .en              (ID_en), .clear           (ID_clear),
    .inst_valid_i    (inst_rdy_i), .pc_i            (inst_pc_i), .pc_p4_i         (inst_pc_p4), .inst_i          (inst_i),
    .pc_valid_o      (ID_pc_valid_out), .pc_o            (ID_pc_out), .pc_p4_o         (ID_pc_p4_out), .inst_o          (ID_inst_out),
    .rs1_o           (decode_rs1), .rs2_o           (decode_rs2), .rs3_o           (decode_rs3), .rd_o            (decode_rd),
    .csr_addr_o      (decode_csr_addr), .imm_o           (decode_imm), .reg_wr_en_o     (reg_wr_en), .reg_w_sel_o     (reg_w_sel),
    .mem_wr_en_o     (mem_wr_en), .mem_rd_en_o     (mem_rd_en), .mem_ctrl_o      (mem_ctrl), .is_j_o          (is_j),
    .is_br_o         (is_br), .cmp_op_o        (cmp_op), .ALU_ctrl_o      (ALU_ctrl), .ALU_sel1_o      (ALU_sel1),
    .ALU_sel2_o      (ALU_sel2), .is_MUL_DIV_o    (is_MUL_DIV), .MUL_DIV_ctrl_o  (MUL_DIV_ctrl), .is_csr_o        (is_csr),
    .is_npu_o        (is_npu), .bypass_sel_o    (bypass_sel), .fetch_invalid_o (fetch_invalid), .is_impl_o       (is_impl)
);

// en reuses EX_en so the stack only mutates -- and ras_predict_valid only
// pulses -- on the exact cycle ID's content is genuinely captured into EX
// (see RAS.v's header comment). clear uses ras_clear, a pessimistic version
// of EX_clear with the mem_confirmed_hit_i-dependent (dcache-tag-compare-
// depth) term dropped -- see PipelineCtrl.v's ras_clear_o comment for the
// safety argument (never less restrictive than EX_clear, so no double-fire
// risk; the only cost is an occasional missed prediction, never a wrong
// execution result, since EX_jalr_mispredicted's fallback still applies).
RAS m_RAS(
    .clk        (clk), .rst_n      (rst_n),
    .en         (EX_en), .clear      (ras_clear),
    .id_valid   (ID_pc_valid_out), .id_inst    (ID_inst_out),
    .id_rd      (decode_rd), .id_rs1     (decode_rs1),
    .id_pc_p4   (ID_pc_p4_out),
    .predict_valid_o (ras_predict_valid), .predict_pc_o    (ras_predict_pc)
);

// Prediction metadata follows the same enables and clears as the instruction
// itself through ID and EX.  The EX copy is therefore the prediction that was
// actually made when this exact control-flow instruction was fetched.
PipelineRegister #(.WIDTH(1)) m_ID_pred_taken (
    .clk(clk), .rst_n(rst_n), .clear(ID_clear), .en(ID_en),
    .data_i(inst_pred_taken_i), .data_o(ID_pred_taken_out)
);

// Whether the instruction currently sitting in ID (the next admission
// candidate) is itself a mem op -- PipelineCtrl needs this to keep blocking
// admission of a second mem op while an earlier one is still in flight,
// UNLESS the earlier one is a confirmed cache hit (mem_confirmed_hit, see
// MEM.v): a hit retires on a fixed, known schedule, so a second mem op can
// ride the exact same drain timing the buffer-based non-mem relaxation
// already uses, without needing its own buffer slot. A miss still fully
// serializes, since its duration is unknown. Gated on ID_pc_valid_out so a
// bubble/invalid ID slot never reads as a false positive.
wire ID_is_mem_op = ID_pc_valid_out & (mem_wr_en | mem_rd_en |
    (mem_ctrl[1:0] == 2'b11) | (mem_ctrl[2:1] == 2'b11));

// Whether the ID candidate has a genuine load-use hazard against a pending
// load, checked against BOTH of the two places that load's rd can be sitting
// depending on the exact cycle:
//   - EX_rd_out/EX_mem_rd_en_out: the load is STILL live in EX this cycle,
//     about to depart into EX_MEM_Reg on this same edge -- the same "now or
//     soon" gap as mem_pending_now_or_soon/buffer_pending_now_or_soon (see
//     PipelineCtrl.v): a candidate sitting in ID gets admitted on the exact
//     cycle the load departs, one cycle before MEM_rd below would show it.
//   - MEM_rd/MEM_mem_rd_en: EX_MEM_Reg's held output, once the load has
//     actually moved there and is being held for the rest of its in-flight
//     window.
// Both gated on "is this actually a load" (mem_rd_en, not mem_wr_en/CBO/
// fence.i -- those never write a register, matching the same "was this a
// load" test the wb_* mux uses on completion) and rd!=x0 (reading x0 is
// never a real dependency). The traditional model never had to check this at
// all, since nothing could reach EX while a mem op was in flight; the buffer
// scheme's admission relaxation is exactly what can now put a genuinely
// dependent instruction in front of EX.
assign ID_reads_pending_load = ID_pc_valid_out & (
    (EX_mem_rd_en_out & (EX_rd_out != 5'd0) &
        ((decode_rs1 == EX_rd_out) | (decode_rs2 == EX_rd_out) | (decode_rs3 == EX_rd_out))) |
    (MEM_mem_rd_en & (MEM_rd != 5'd0) &
        ((decode_rs1 == MEM_rd) | (decode_rs2 == MEM_rd) | (decode_rs3 == MEM_rd)))
);

wire [31:0] wb_data_in, reg_data1_out, reg_data2_out;
wire        WB_reg_wr_en_out;
wire [4:0]  WB_rd_out;

Register m_Register(
    .clk        (clk), .rst_n      (rst_n), .wr_en      (WB_reg_wr_en_out),
    .rs1        (decode_rs1), .rs2        (decode_rs2), .rd         (WB_rd_out),
    .data_i     (wb_data_in), .rd_data1_o (reg_data1_out), .rd_data2_o (reg_data2_out)
);

PipelineRegister #(.WIDTH(1)) m_EX_pred_taken (
    .clk(clk), .rst_n(rst_n), .clear(EX_clear), .en(EX_en),
    .data_i(ID_pred_taken_out), .data_o(EX_pred_taken_out)
);

Exec m_EX(
    .clk              (clk), .rst_n            (rst_n), .en               (EX_en), .clear            (EX_clear),
    .is_impl_i        (is_impl), .pc_valid_i       (ID_pc_valid_out), .inst_i           (ID_inst_out),
    .pc_i             (ID_pc_out), .pc_p4_i          (ID_pc_p4_out), .reg_rd_data1_i   (reg_data1_out),
    .reg_rd_data2_i   (reg_data2_out), .imm_i            (decode_imm), .rd_i             (decode_rd),
    .rs1_i            (decode_rs1), .rs2_i            (decode_rs2), .rs3_i            (decode_rs3),
    .reg_wr_en_i      (reg_wr_en), .reg_w_sel_i      (reg_w_sel), .mem_rd_en_i      (mem_rd_en),
    .mem_wr_en_i      (mem_wr_en), .mem_ctrl_i       (mem_ctrl), .is_j_i           (is_j),
    .is_br_i          (is_br), .ras_predicted_i (ras_predict_valid), .ras_predicted_pc_i (ras_predict_pc),
    .jalr_target_valid_i (id_jalr_target_valid), .jalr_target_i (id_jalr_target),
    .cmp_op_i         (cmp_op), .ALU_sel1_i       (ALU_sel1),
    .ALU_sel2_i       (ALU_sel2), .ALU_ctrl_i       (ALU_ctrl), .is_MUL_DIV_i     (is_MUL_DIV),
    .MUL_DIV_ctrl_i   (MUL_DIV_ctrl), .csr_addr_i       (decode_csr_addr), .is_csr_i         (is_csr),
    .is_npu_i         (is_npu), .bypass_sel_i     (bypass_sel), .fetch_invalid_i  (fetch_invalid),
    .MEM_rd_i         (MEM_rd), .MEM_reg_wr_en_i  (MEM_reg_wr_en), .MEM_fwd_data_i   (MEM_result),
    .WB_rd_i          (WB_rd_out), .WB_reg_wr_en_i   (WB_reg_wr_en_out), .wb_data_i        (wb_data_in),

    .is_impl_o        (EX_is_impl_out), .pc_valid_o       (EX_pc_valid_out), .inst_o           (EX_inst_out),
    .pc_o             (EX_pc_out), .pc_p4_o          (EX_pc_p4_out), .reg_fwd_data1_o  (EX_fwd_data1), .reg_fwd_data2_o  (EX_fwd_data2),
    .imm_o            (EX_imm_out), .rd_o             (EX_rd_out), .rs1_o            (EX_rs1_out),
    .rs2_o            (EX_rs2_out), .rs3_o            (EX_rs3_out), .reg_wr_en_o      (EX_reg_wr_en_out),
    .reg_w_sel_o      (EX_reg_w_sel_out), .mem_rd_en_o      (EX_mem_rd_en_out), .mem_wr_en_o      (EX_mem_wr_en_out),
    .mem_ctrl_o       (EX_mem_ctrl_out), .is_j_o           (EX_is_j_out), .is_br_o          (EX_is_br_out),
    .ras_predicted_o  (EX_ras_predicted_out), .ras_predicted_pc_o (EX_ras_predicted_pc_out),
    .jalr_target_valid_o (EX_jalr_target_valid_out), .jalr_target_o (EX_jalr_target_out),
    .br_taken_o       (br_taken), .ALU_ctrl_o       (EX_ALU_ctrl_out), .ALU_o            (ALU_out),
    .is_MUL_DIV_o     (EX_is_MUL_DIV_out), .MUL_DIV_ctrl_o   (EX_MUL_DIV_ctrl_out), .csr_rd_data_o    (csr_rd_data),
    .is_npu_o         (EX_is_npu_out), .bypass_sel_o     (EX_bypass_sel_out), .bypass_o         (bypass_out),
    .fetch_invalid_o  (EX_fetch_invalid_out),
    .mem_addr_o       (EX_mem_addr_out), .mem_mask_o       (EX_mem_mask_out), .mem_data_wr_o    (EX_mem_data_wr_out),
    .mem_cacheable_o  (EX_mem_cacheable_out),

    .EX_start_o       (EX_start), .MUL_DIV_start_o  (MUL_DIV_start), .NPU_start_o      (NPU_start_raw),
    .mem_req_o        (mem_req), .MUL_done_i       (MUL_done), .DIV_done_i       (DIV_done),
    .NPU_done_i       (NPU_done),
    .EX_done_o        (EX_done)
);

// ---- EX/MEM boundary ----
// Whether EX currently holds a load/store/CBO/fence.i, straight off Exec.v's
// own registered decode -- stable for as long as that instruction sits in EX,
// unlike mem_req (which only pulses on the one cycle it was admitted). This
// is what reg_wr_en_i below needs: "is the thing departing EX *right now* a
// mem op", not "did a mem op get admitted at some point in the past".
wire EX_is_mem_op = EX_mem_rd_en_out || EX_mem_wr_en_out ||
    (EX_mem_ctrl_out[1:0] == 2'b11) || (EX_mem_ctrl_out[2:1] == 2'b11);

// Every non-mem result is resolved by the time an instruction leaves EX, so
// the other six result buses still collapse into one here. A load/store is
// different now: EX reports done at request time (mem_req), before
// mem_writeback_value exists, so case 3'b010 below is never actually read --
// reg_wr_en_i is forced off for that departure cycle (see below), and the
// real mem result is picked up later, straight from MEM.v, by the wb_* mux
// further down instead of ever passing through this register.
reg [31:0] EX_result_r;
always @(*) begin
    case (EX_reg_w_sel_out)
        3'b000:  EX_result_r = EX_pc_p4_out;
        3'b001:  EX_result_r = ALU_out;
        3'b010:  EX_result_r = 32'b0; // mem: not ready yet at this cycle, see comment above
        3'b011:  EX_result_r = csr_rd_data;
        3'b101:  EX_result_r = bypass_out;
        3'b110:  EX_result_r = MUL_DIV_out;
        3'b111:  EX_result_r = NPU_out;
        default: EX_result_r = 32'b0;
    endcase
end

wire        MEM_pc_valid, MEM_is_impl;
wire [31:0] MEM_pc_p4;
wire        MEM_mem_wr_en;
wire [ 3:0] MEM_mem_ctrl;
wire [31:0] MEM_mem_addr, MEM_mem_data_wr, MEM_inst, MEM_rb_data;
wire [ 3:0] MEM_mem_mask;
wire        MEM_mem_cacheable;

// RAS timing fix: whether decode_rs1 is safe to trust as already-correct in
// ID's raw (unforwarded) regfile read. Only EX and MEM producers are
// hazards -- ForwardUnit.v's own header comment documents that the register
// file's negedge write (Register.v) gives WB->ID write-through for free, so
// a producer currently in WB has already committed by the time this same
// cycle's combinational read is captured at the next posedge (matches why
// ID_reads_pending_load above never checks WB_rd either).
wire id_rs1_hazard = (decode_rs1 != 5'd0) &
    ((EX_reg_wr_en_out & (decode_rs1 == EX_rd_out)) |
     (MEM_reg_wr_en    & (decode_rs1 == MEM_rd)));

// Speculative jalr target computed straight off ID's raw register read
// (reg_data1_out, not EX's forwarded reg_fwd_data1_o) -- cheap (one adder,
// no ForwardUnit compare first), but only trustworthy when id_rs1_hazard is
// clear. Only meaningful for a RAS-predicted return (same condition RAS.v
// checks internally); computed unconditionally since gating it would just
// relocate the same mux, not remove it. See EX_jalr_mispredicted below for
// why this exists: comparing against ALU_out directly put ForwardUnit's
// compare + the ALU's carry-chain adder on the path feeding
// redirect_valid_o, which fans out to the whole frontend instruction
// buffer's flush logic and blew timing by -2.8ns when first tried.
wire [31:0] id_jalr_target = reg_data1_out + decode_imm;
wire        id_jalr_target_valid = ~id_rs1_hazard;

// EX's own live-signal-derived reg_wr_en, shared by both the pending buffer
// (below) and the direct/normal path -- ~EX_is_mem_op: a load/store/CBO/
// fence.i departing EX has no result yet, its eventual write-enable is
// derived from mem_rd_en_o itself (a load reads, a store/CBO/fence.i does
// not) once mem_writeback_valid fires. A mem op is never the one buffered
// (ID_is_mem_op keeps a second mem op from ever being admitted while an
// earlier one is still in flight), so this mask is only load-bearing on the
// direct path in practice, but is kept identical on both for consistency.
wire EX_live_reg_wr_en = EX_reg_wr_en_out & EX_pc_valid_out & EX_is_impl_out & ~EX_is_mem_op;

// ---- 1-slot pending buffer ----
// Lets one independent, non-mem instruction (op2) run ahead of a still-
// in-flight mem access (op1) instead of waiting for it: EX keeps computing
// op2 while EX_MEM_Reg is held hostage by op1 (PipelineCtrl.v's mem_busy_reg_i
// freeze), and this buffer catches op2's result the moment EX produces it so
// EX itself can go back to idle/bubble rather than stalling a second time.
// Reuses EX_MEM_Reg itself (same field set, same shape) rather than hand-
// rolling a parallel set of registers.
wire        pending_pc_valid, pending_is_impl, pending_reg_wr_en;
wire [31:0] pending_pc_p4, pending_result;
wire [ 4:0] pending_rd;
wire        pending_mem_rd_en, pending_mem_wr_en;
wire [ 3:0] pending_mem_ctrl;
wire [31:0] pending_mem_addr, pending_mem_data_wr, pending_inst, pending_rb_data;
wire [ 3:0] pending_mem_mask;
wire        pending_mem_cacheable;

// Capture into the buffer only while EX_MEM_Reg can't take the result
// directly (mem_busy, i.e. op1 still in flight) and the buffer isn't already
// holding something (admit_stall/EX_clear already guarantee EX can't produce
// a second result while buffer_valid is set, so this is defensive, not
// load-bearing). Drain the moment mem frees EX_MEM_Reg back up.
//
// ~EX_is_mem_op: a second mem op admitted via the confirmed-hit relaxation
// (see ID_is_mem_op_i/mem_confirmed_hit_i in PipelineCtrl.v) also produces a
// genuine EX_has_result while mem_busy is still 1 for the FIRST op -- but it
// must never land in this buffer. It has its own dedicated drain timing
// (rides mem_writeback_valid_i straight into normal_capture, see
// PipelineCtrl.v's mem_hold), and this buffer only ever holds one slot's
// worth of a non-mem result at a time; without this mask the second mem op
// would wrongly consume that slot instead.
wire buffer_wr_en = mem_busy & EX_has_result & ~buffer_valid & ~EX_is_mem_op;
wire buffer_drain = buffer_valid & ~mem_busy;

reg buffer_valid_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)            buffer_valid_r <= 1'b0;
    else if (buffer_wr_en) buffer_valid_r <= 1'b1;
    else if (buffer_drain) buffer_valid_r <= 1'b0;
end
assign buffer_valid = buffer_valid_r;

// "Now or soon", same gap as mem_pending_now_or_soon below: buffer_valid is
// registered, so on the exact cycle op2 is departing EX into the buffer
// (buffer_wr_en=1), buffer_valid itself is still 0 for that whole cycle --
// without covering it too, a THIRD instruction could sneak into EX on that
// same cycle (admit_stall would see an empty buffer that is, in fact, about
// to be full one edge later), corrupting the one-slot invariant. Only the
// admission-blocking use needs this; EX_MEM_Reg's drain mux/MEM_en below
// deliberately keep using the raw, registered buffer_valid.
assign buffer_pending_now_or_soon = buffer_valid | buffer_wr_en;

EX_MEM_Reg m_EX_pending(
    .clk (clk), .rst_n (rst_n),
    .en    (buffer_wr_en), .clear (1'b0),

    .pc_valid_i  (EX_pc_valid_out), .is_impl_i   (EX_is_impl_out),
    .pc_p4_i     (EX_pc_p4_out), .rd_i        (EX_rd_out),
    .reg_wr_en_i (EX_live_reg_wr_en), .result_i    (EX_result_r),

    .mem_rd_en_i    (EX_mem_rd_en_out), .mem_wr_en_i    (EX_mem_wr_en_out),
    .mem_ctrl_i     (EX_mem_ctrl_out), .mem_addr_i     (EX_mem_addr_out),
    .mem_mask_i     (EX_mem_mask_out), .mem_data_wr_i  (EX_mem_data_wr_out),
    .inst_i         (EX_inst_out), .rb_data_i      (EX_fwd_data2),
    .mem_cacheable_i (EX_mem_cacheable_out),

    .pc_valid_o  (pending_pc_valid), .is_impl_o   (pending_is_impl),
    .pc_p4_o     (pending_pc_p4), .rd_o        (pending_rd),
    .reg_wr_en_o (pending_reg_wr_en), .result_o    (pending_result),

    .mem_rd_en_o    (pending_mem_rd_en), .mem_wr_en_o    (pending_mem_wr_en),
    .mem_ctrl_o     (pending_mem_ctrl), .mem_addr_o     (pending_mem_addr),
    .mem_mask_o     (pending_mem_mask), .mem_data_wr_o  (pending_mem_data_wr),
    .inst_o         (pending_inst), .rb_data_o      (pending_rb_data),
    .mem_cacheable_o (pending_mem_cacheable)
);

// EX_MEM_Reg's real input: the buffer's held content on a drain cycle
// (PipelineCtrl.v's MEM_en only fires via "drain" when buffer_valid is set,
// see PipelineCtrl.v), otherwise EX's live output exactly as before.
EX_MEM_Reg m_EX_MEM(
    .clk (clk), .rst_n (rst_n),
    .en    (MEM_en), .clear (MEM_clear),

    .pc_valid_i  (buffer_valid ? pending_pc_valid  : EX_pc_valid_out),
    .is_impl_i   (buffer_valid ? pending_is_impl   : EX_is_impl_out),
    .pc_p4_i     (buffer_valid ? pending_pc_p4     : EX_pc_p4_out),
    .rd_i        (buffer_valid ? pending_rd        : EX_rd_out),
    .reg_wr_en_i (buffer_valid ? pending_reg_wr_en : EX_live_reg_wr_en),
    .result_i    (buffer_valid ? pending_result    : EX_result_r),

    // mem request payload -- held steady by MEM_en's mem_busy_reg_i freeze
    // (see PipelineCtrl.v) for as long as this access is in flight.
    .mem_rd_en_i    (buffer_valid ? pending_mem_rd_en   : EX_mem_rd_en_out),
    .mem_wr_en_i    (buffer_valid ? pending_mem_wr_en   : EX_mem_wr_en_out),
    .mem_ctrl_i     (buffer_valid ? pending_mem_ctrl    : EX_mem_ctrl_out),
    .mem_addr_i     (buffer_valid ? pending_mem_addr    : EX_mem_addr_out),
    .mem_mask_i     (buffer_valid ? pending_mem_mask    : EX_mem_mask_out),
    .mem_data_wr_i  (buffer_valid ? pending_mem_data_wr : EX_mem_data_wr_out),
    .inst_i         (buffer_valid ? pending_inst        : EX_inst_out),
    .rb_data_i      (buffer_valid ? pending_rb_data     : EX_fwd_data2),
    .mem_cacheable_i (buffer_valid ? pending_mem_cacheable : EX_mem_cacheable_out),

    .pc_valid_o  (MEM_pc_valid), .is_impl_o   (MEM_is_impl),
    .pc_p4_o     (MEM_pc_p4), .rd_o        (MEM_rd),
    .reg_wr_en_o (MEM_reg_wr_en), .result_o    (MEM_result),

    .mem_rd_en_o    (MEM_mem_rd_en), .mem_wr_en_o    (MEM_mem_wr_en),
    .mem_ctrl_o     (MEM_mem_ctrl), .mem_addr_o     (MEM_mem_addr),
    .mem_mask_o     (MEM_mem_mask), .mem_data_wr_o  (MEM_mem_data_wr),
    .inst_o         (MEM_inst), .rb_data_o      (MEM_rb_data),
    .mem_cacheable_o (MEM_mem_cacheable)
);

// NPU dispatch is decoupled from NPU_start_raw by one cycle so NPU always
// samples registered, forward-mux-free operands. Root cause: NPU's own
// multiply-accumulate is un-pipelined, and its critical path used to run
// straight from EX's forward mux (WB_Reg/r_rd -> EX forward mux, ~5.8ns)
// through NPU's DSP+carry-chain accumulate (~9.8ns) in one shared cycle --
// measured WNS=-2.421ns at 75MHz (Backend_top/m_EX/reg_rs2 ->
// NPU_0/new_sum_prods_reg[30], 15.612ns/22 logic levels). Registering
// EX_fwd_data1/2 (+funct3/funct7) here, and delaying NPU_start to match,
// splits that into two independent register-to-register hops, each within
// budget on its own, without touching NPU.v. EX_done_o's NPU_done_i term
// (Exec.v) is unqualified by is_npu_o and EX just keeps stalling until
// NPU_done_i pulses, so the extra cycle needs no change there -- the
// existing blocking-stall interlock absorbs it transparently.
reg [31:0] npu_rs1_r, npu_rs2_r, npu_funct7_r;
reg [ 3:0] npu_funct3_r;
reg        npu_start_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        npu_rs1_r    <= 32'd0;
        npu_rs2_r    <= 32'd0;
        npu_funct3_r <= 4'd0;
        npu_funct7_r <= 32'd0;
        npu_start_r  <= 1'b0;
    end else begin
        if (NPU_start_raw) begin
            npu_rs1_r    <= EX_fwd_data1;
            npu_rs2_r    <= EX_fwd_data2;
            npu_funct3_r <= EX_inst_out[14:12];
            npu_funct7_r <= EX_inst_out[31:25];
        end
        npu_start_r <= NPU_start_raw;
    end
end
assign rs1_o     = npu_rs1_r;
assign rs2_o     = npu_rs2_r;
assign funct3_o  = npu_funct3_r;
assign funct7_o  = npu_funct7_r;
assign NPU_start = npu_start_r;

MUL_DIV_top m_MUL_DIV_top(
    .clk           (clk), .rst_n         (rst_n), .data1         (EX_fwd_data1),
    .data2         (EX_fwd_data2), .MUL_DIV_start (MUL_DIV_start), .MUL_DIV_ctrl  (EX_MUL_DIV_ctrl_out),
    .MUL_DIV_out   (MUL_DIV_out), .MUL_done_o    (MUL_done), .DIV_done_o    (DIV_done)
);

// MEM stage: LSU + MMU + the dcache fast path all live in MEM.v now, so this
// is the whole memory subsystem interface -- one request in, one completion out.
wire        mem_hit;
wire [31:0] mem_dcache_daddr, mem_dcache_data;
wire [ 3:0] mem_dcache_mask;
wire        mem_dcache_req_rd, mem_dcache_req_wr;
wire        mem_dcache_flush, mem_dcache_invalidate, mem_dcache_writeback;
wire [31:0] mem_writeback_value;
wire        mem_writeback_valid;

// MEM.v's own occupancy -- valid for however long a dispatched access is
// still in flight, since EX itself no longer waits. Retirement info (rd/
// is_impl/pc_valid/pc_p4) no longer needs a shadow copy of its own: it's read
// straight off EX_MEM_Reg's own held output (MEM_rd/MEM_is_impl/...) instead,
// since EX_MEM_Reg now stays frozen on that same info for the whole window.
wire        mem_busy;

// High while the in-flight access is a fast-path op confirmed to be a cache
// hit -- lets PipelineCtrl.v admit a second mem op back-to-back instead of
// fully serializing (see MEM.v's mem_confirmed_hit_o header comment).
wire        mem_confirmed_hit;
wire [31:0] dcache_in_value_i;
wire        dcache_in_valid_i;
wire        dcache_hit_o;

wire [31:0] cdma_addr, cdma_wdata, cdma_data_i;
wire        cdma_valid_i, cdma_rd_o, cdma_wr_o;

MEM m_MEM (
    .clk_i (clk), .rst_i (rst_n),

    .req_i               (mem_req),

    .reg_inst_i          (MEM_inst), .reg_rb_data_i       (MEM_rb_data),
    .reg_mem_rd_i        (MEM_mem_rd_en), .reg_mem_wr_i        (MEM_mem_wr_en),
    .reg_mem_ctrl_i      (MEM_mem_ctrl), .reg_mem_addr_i      (MEM_mem_addr),
    .reg_mem_data_wr_i   (MEM_mem_data_wr), .reg_mem_mask_i      (MEM_mem_mask),
    .reg_mem_cacheable_i (MEM_mem_cacheable),

    .mem_writeback_value_o (mem_writeback_value), .mem_writeback_valid_o (mem_writeback_valid),
    .mem_hit_o             (mem_hit),

    .mem_busy_o          (mem_busy),
    .mem_confirmed_hit_o (mem_confirmed_hit),

    .dcache_daddr_o      (mem_dcache_daddr), .dcache_data_o       (mem_dcache_data),
    .dcache_mask_o       (mem_dcache_mask), .dcache_req_rd_o     (mem_dcache_req_rd),
    .dcache_req_wr_o     (mem_dcache_req_wr), .dcache_flush_o      (mem_dcache_flush),
    .dcache_invalidate_o (mem_dcache_invalidate), .dcache_writeback_o  (mem_dcache_writeback),
    .dcache_resp_data_i  (dcache_in_value_i), .dcache_resp_valid_i (dcache_in_valid_i),
    .dcache_hit_i        (dcache_hit_o),

    .cdma_addr_o (cdma_addr), .cdma_data_o  (cdma_wdata),
    .cdma_rd_o   (cdma_rd_o), .cdma_wr_o    (cdma_wr_o),
    .cdma_data_i (cdma_data_i), .cdma_valid_i (cdma_valid_i)
);

// ---- MEM occupancy ----
// Traditional/simple model: this alone freezes admission at PC/ID/EX (see
// PipelineCtrl's mem_busy_i), the same way a cache miss would stall a
// textbook 5-stage pipeline. Nothing new is admitted into EX while a mem
// access is in flight, so this single flag also stands in for admission
// (no second mem op can start) and load-use (a dependent instruction can't
// even get into EX yet). Trades the "unrelated instructions keep going
// during a miss" throughput win for not needing any separate hazard checks.
//
// mem_busy | mem_req, not mem_busy alone: mem_req (the dispatch pulse) fires
// the same cycle a mem op leaves EX, one cycle before MEM.v's own registered
// mem_busy_o catches up -- without covering that cycle too, the *next*
// instruction could still be admitted into EX on the dispatch cycle itself
// and immediately fire its own EX_start_o-derived mem_req, corrupting the
// request MEM.v just latched.
assign mem_pending_now_or_soon = mem_busy | mem_req;

// ---- WB input mux ----
// is_impl/pc_valid/pc_p4/rd no longer need a branch at all: EX_MEM_Reg is now
// held frozen on this exact instruction's identity for the whole in-flight
// window (mem_busy_reg_i, see PipelineCtrl.v), including the completion
// cycle itself (mem_busy_o only drops the cycle AFTER mem_writeback_valid_o
// fires), so MEM_* is already correct on that cycle -- no separate shadow
// copy from MEM.v needed any more.
//
// reg_wr_en/result still need the branch: a load's value only exists once
// mem_writeback_value arrives (EX_MEM_Reg's own result_i/reg_wr_en_i were
// forced to 0/dummy at capture, see EX_result_r above and the ~EX_is_mem_op
// mask on reg_wr_en_i). MEM_mem_rd_en (held) stands in for "was this a load":
// true for a load, false for a store/CBO/fence.i, exactly matching what the
// completing access's own reg_wr_en should be. mem_busy_reg_i freezing
// EX_MEM_Reg guarantees these two cases can never collide -- EX_MEM_Reg only
// ever has something NEW to offer on the one cycle a mem access is not in
// flight, which cannot coincide with mem_writeback_valid completing one.
wire        wb_is_impl    = MEM_is_impl;
wire        wb_pc_valid   = MEM_pc_valid;
wire [31:0] wb_pc_p4      = MEM_pc_p4;
wire [4:0]  wb_rd         = MEM_rd;
wire        wb_reg_wr_en  = mem_writeback_valid ? MEM_mem_rd_en : MEM_reg_wr_en;
wire [31:0] wb_result     = mem_writeback_valid ? mem_writeback_value : MEM_result;

dcache_pro m_dcache (
    .clk               (clk), .rst_n             (rst_n), .cpu_daddr_i       (mem_dcache_daddr),
    .cpu_data_i        (mem_dcache_data), .mask_i            (mem_dcache_mask), .cpu_req_wr        (mem_dcache_req_wr),
    .cpu_req_rd        (mem_dcache_req_rd), .cpu_data_o        (dcache_in_value_i), .dcache_rdy_o      (),
    .dcache_data_vld_o (dcache_in_valid_i), .d_exception       (), .hit_o             (dcache_hit_o), .invalidate_i      (mem_dcache_invalidate),
    .flush_i           (mem_dcache_flush), .writeback_i       (mem_dcache_writeback), .mem_addr          (dbus_rm_addr),
    .rm_rdy            (dbus_rm_rdy), .rm_data           (dbus_rm_data), .rm_success        (dbus_rm_success),
    .rm_complete       (dbus_rm_complete), .rm_vld            (dbus_rm_vld), .wm_rdy            (dbus_wm_rdy),
    .wm_data           (dbus_wm_data), .wm_vld            (dbus_wm_vld), .wm_success        (dbus_wm_success),
    .wm_complete       (dbus_wm_complete)
);

cpu_axiLite_bridge m_axi_lite_bridge (
    .aclk               (clk), .aresetn            (rst_n), .req_rd_mm          (cdma_rd_o),
    .req_wr_mm          (cdma_wr_o), .mm_addr_i          (cdma_addr), .mm_data_i          (cdma_wdata),
    .mm_data_out        (cdma_data_i), .mm_exception       (), .mm_rdy             (), .mm_vld             (cdma_valid_i),
    .m_axi_lite_awvalid (m_axi_lite_awvalid), .m_axi_lite_awready (m_axi_lite_awready), .m_axi_lite_awaddr  (m_axi_lite_awaddr),
    .m_axi_lite_wvalid  (m_axi_lite_wvalid), .m_axi_lite_wready  (m_axi_lite_wready), .m_axi_lite_wdata   (m_axi_lite_wdata),
    .m_axi_lite_wstrb   (m_axi_lite_wstrb), .m_axi_lite_bvalid  (m_axi_lite_bvalid), .m_axi_lite_bready  (m_axi_lite_bready),
    .m_axi_lite_bresp   (m_axi_lite_bresp), .m_axi_lite_arvalid (m_axi_lite_arvalid), .m_axi_lite_arready (m_axi_lite_arready),
    .m_axi_lite_araddr  (m_axi_lite_araddr), .m_axi_lite_rvalid  (m_axi_lite_rvalid), .m_axi_lite_rready  (m_axi_lite_rready),
    .m_axi_lite_rdata   (m_axi_lite_rdata), .m_axi_lite_rresp   (m_axi_lite_rresp)
);

wire        WB_is_impl_out, WB_pc_valid_out;
wire [31:0] WB_pc_out;

Writeback m_WB(
    .clk (clk), .rst_n (rst_n), .en (WB_en), .clear (WB_clear),

    .is_impl_i   (wb_is_impl), .pc_valid_i  (wb_pc_valid),
    .pc_i        (wb_pc_p4 - 32'd4), .pc_p4_i     (wb_pc_p4),
    .rd_i        (wb_rd), .result_i    (wb_result),
    .reg_wr_en_i (wb_reg_wr_en),

    .is_impl_o   (WB_is_impl_out), .pc_valid_o  (WB_pc_valid_out),
    .pc_o        (WB_pc_out), .rd_o        (WB_rd_out),
    .wb_data_o   (wb_data_in), .reg_wr_en_o (WB_reg_wr_en_out)
);
endmodule
