//-----------------------------------------------------------------
// MEM stage
//
// Owns the whole memory-access datapath behind the EX/MEM boundary: the LSU,
// the MMU, and the fast path that lets a plain aligned cacheable access talk
// to dcache_pro.v directly instead of paying mmu_cache_ctrl's registered
// request/response FSM (~2 cycles).
//
// Unlike the previous version of this module, MEM.v owns no request register
// of its own any more -- EX_MEM_Reg IS the EX/MEM boundary register for the
// memory datapath too now (address/mask/store-data included), and
// PipelineCtrl.v freezes it (mem_busy_reg_i) for as long as this access is
// in flight, so it holds steady the whole time instead of being overwritten
// by a bubble the very next cycle. MEM.v is a pure consumer of that held
// output: everything below reads reg_* directly off EX_MEM_Reg, recomputing
// the fast-path classification and byte/sign extraction combinationally each
// cycle instead of latching a second copy.
//
//   fast path : EX_MEM_Reg -> dcache_pro.v            (aligned, cacheable ld/st)
//   slow path : EX_MEM_Reg -> lsu.v -> mmu.v -> dcache_pro.v / AXI-Lite
//               (misaligned accesses, Zicbom CMOs, fence.i, uncached addresses)
//
// Both paths share dcache_pro.v's request and response wires; mem_fast_active
// records which one the in-flight access belongs to so the response side knows
// whose completion dcache_resp_valid_i represents.
//
// req_i (EX's live one-shot mem_req pulse, same cycle the access departs EX)
// is still taken directly rather than through EX_MEM_Reg, for two things that
// genuinely need to fire before EX_MEM_Reg's held output is even valid:
// mem_busy_o (has to assert the cycle right after dispatch, not one cycle
// later, or PipelineCtrl.v's admission-freeze gap wouldn't be covered) and
// the one-shot dispatch pulse that tells the fast/slow path "the held fields
// are fresh this cycle, fire the actual request now" (without it, a
// multi-cycle miss would re-fire the dcache/lsu request every held cycle
// instead of once).
//-----------------------------------------------------------------

module MEM
(
     input           clk_i
    ,input           rst_i

    // ---- EX's live one-shot dispatch pulse (mem_req) -- NOT the held output,
    // see header comment for why this one signal still comes straight from EX
    ,input           req_i

    // ---- held request, straight off EX_MEM_Reg (valid for the entire
    // in-flight window, not just the dispatch cycle) --------------------
    ,input   [31:0]  reg_inst_i
    ,input   [31:0]  reg_rb_data_i
    ,input           reg_mem_rd_i
    ,input           reg_mem_wr_i
    ,input   [ 3:0]  reg_mem_ctrl_i
    ,input   [31:0]  reg_mem_addr_i
    ,input   [31:0]  reg_mem_data_wr_i
    ,input   [ 3:0]  reg_mem_mask_i
    ,input           reg_mem_cacheable_i // classified in Exec.v now, held by EX_MEM_Reg

    // ---- completion to WB -------------------------------------------------
    ,output  [31:0]  mem_writeback_value_o
    ,output          mem_writeback_valid_o
    ,output          mem_hit_o          // dcache hit_o, observability only

    // ---- occupancy, for PipelineCtrl.v's EX_MEM_Reg hold and Backend_top's
    // admission/load-use interlocks ------------------------------------
    ,output          mem_busy_o         // high from dispatch until mem_writeback_valid_o

    // High whenever the in-flight access is a fast-path op that is ALSO
    // known to be a cache hit -- i.e. guaranteed to retire on a fixed,
    // 1-cycle-away schedule, unlike a miss (unknown duration) or a slow-path
    // op. Lets PipelineCtrl.v admit a second mem op back-to-back instead of
    // fully serializing, without needing any new in-flight tracking: by the
    // time the second op's own request reaches dcache_pro.v, the first one
    // has already vacated EX_MEM_Reg on the exact same schedule (see
    // Backend_top.v's mem_writeback_valid_i-gated drain), so no extra buffer
    // slot is needed for this specific case the way an independent non-mem
    // instruction needs one.
    ,output          mem_confirmed_hit_o

    // ---- dcache_pro.v -----------------------------------------------------
    ,output  [31:0]  dcache_daddr_o
    ,output  [31:0]  dcache_data_o
    ,output  [ 3:0]  dcache_mask_o
    ,output          dcache_req_rd_o
    ,output          dcache_req_wr_o
    ,output          dcache_flush_o
    ,output          dcache_invalidate_o
    ,output          dcache_writeback_o
    ,input   [31:0]  dcache_resp_data_i
    ,input           dcache_resp_valid_i
    ,input           dcache_hit_i

    // ---- uncached path (AXI-Lite bridge) ----------------------------------
    ,output  [31:0]  cdma_addr_o
    ,output  [31:0]  cdma_data_o
    ,output          cdma_rd_o
    ,output          cdma_wr_o
    ,input   [31:0]  cdma_data_i
    ,input           cdma_valid_i
);

// Note on hit_o: dcache_resp_valid_i already fires at the correct,
// naturally-variable time for both a hit (1 cycle, BRAM read latency) and a
// miss (many cycles, after cache-line fill) -- mem_busy_o (below) tracks
// exactly that duration for whoever downstream needs to wait on it. There's
// no separate branch needed on hit_i for the fast path's own correctness;
// it's exposed here for observability/testbench validation and as the
// documented hook point.
assign mem_hit_o = dcache_hit_i;

// ---- one-shot "the held fields are fresh this cycle" pulse ----
// req_i is EX's own one-shot mem_req, high for exactly the one cycle the
// access departs EX. Delaying it by one cycle lines it up with the first
// cycle EX_MEM_Reg's registered output actually reflects this access (the
// same edge that captures it) -- exactly the role the old req_p played, just
// no longer carrying any payload of its own.
reg req_p;
always @(posedge clk_i or negedge rst_i) begin
    if (~rst_i) req_p <= 1'b0;
    else        req_p <= req_i;
end

// ---- occupancy: high from dispatch until this access retires ----
// Triggered directly off req_i (not req_p / the held fields) so it asserts
// the cycle right after dispatch, not one cycle later -- PipelineCtrl.v needs
// this exact timing to freeze EX_MEM_Reg's en (mem_busy_reg_i) starting the
// very next cycle, matching how a textbook 5-stage pipeline's EX/MEM register
// holds through a MEM-stage stall instead of taking a bubble.
reg mem_busy_p;
always @(posedge clk_i or negedge rst_i) begin
    if (~rst_i)
        mem_busy_p <= 1'b0;
    else if (req_i)
        mem_busy_p <= 1'b1;
    else if (mem_writeback_valid_o)
        mem_busy_p <= 1'b0;
end

assign mem_busy_o = mem_busy_p;

// ---- fast-path eligibility (combinational off EX_MEM_Reg's held output) ---
// is_cacheable itself is no longer computed here -- it is classified in
// Exec.v (mem_cacheable_o, mirrors mmu.v's D_ADDR_MIN/D_ADDR_MAX range check)
// and arrives already held via reg_mem_cacheable_i, same as the address/mask.
wire is_plain_ldst = reg_mem_rd_i | reg_mem_wr_i; // CBO/fence.i never assert these
wire is_cacheable  = reg_mem_cacheable_i;
wire is_unaligned_half = (reg_mem_addr_i[1:0] == 2'b11) & (reg_mem_ctrl_i[2:0] == 3'b010); // lh/sh straddle
wire is_unaligned_word = (reg_mem_addr_i[1:0] != 2'b00) & (reg_mem_ctrl_i[2:0] == 3'b100); // lw/sw misaligned
wire is_misaligned = is_unaligned_half | is_unaligned_word;

wire dispatch_is_fast = req_p & is_plain_ldst & is_cacheable & ~is_misaligned;

// ---- slow path: LSU + MMU ------------------------------------------------
wire [31:0] lsu_mmu_addr, lsu_mmu_data;
wire        lsu_mmu_rd, lsu_mmu_wr;
wire [ 3:0] lsu_mmu_mask;
wire        lsu_mmu_dflush, lsu_mmu_dinvalidate, lsu_mmu_dwriteback;
wire        lsu_mmu_dzero, lsu_mmu_iinvalidate;
wire [31:0] mmu_lsu_data;
wire        mmu_lsu_valid;
wire [31:0] lsu_writeback_value, mmu_dcache_addr, mmu_dcache_data;
wire        lsu_writeback_valid;
wire [ 3:0] mmu_dcache_mask;
wire        mmu_dcache_rd, mmu_dcache_wr;

// dispatch_is_fast gates lsu.v's opcode_valid_i so it does not also process an
// access the fast path has already claimed.
lsu u_lsu (
    .clk_i             (clk_i), .rst_i             (rst_i),
    .opcode_inst_i     (reg_inst_i), .opcode_rb_data_i  (reg_rb_data_i),
    .opcode_valid_i    (req_p & ~dispatch_is_fast),
    .ex_mem_rd_i       (reg_mem_rd_i), .ex_mem_wr_i       (reg_mem_wr_i),
    .ex_mem_ctrl_i     (reg_mem_ctrl_i), .mmu_value_i       (mmu_lsu_data),
    .ex_mem_addr_i     (reg_mem_addr_i), .ex_mem_data_wr_i  (reg_mem_data_wr_i),
    .ex_mem_mask_i     (reg_mem_mask_i), .mmu_valid_i       (mmu_lsu_valid),
    .mmu_addr_o        (lsu_mmu_addr), .mmu_data_o        (lsu_mmu_data),
    .mmu_rd_o          (lsu_mmu_rd), .mmu_wr_o          (lsu_mmu_wr), .mmu_mask_o        (lsu_mmu_mask),
    .mmu_dflush_o      (lsu_mmu_dflush), .mmu_dinvalidate_o (lsu_mmu_dinvalidate),
    .mmu_dwriteback_o  (lsu_mmu_dwriteback), .mmu_dzero_o       (lsu_mmu_dzero),
    .mmu_iinvalidate_o (lsu_mmu_iinvalidate),
    .writeback_value_o (lsu_writeback_value), .writeback_valid_o (lsu_writeback_valid)
);

// dcache_zero_o and icache_invalidate_o are left unconnected: dcache_pro.v has
// no zero port (cbo.zero is decoded but never reaches the cache), and the
// I-cache invalidate now travels through Backend_top's redirect path instead.
mmu u_mmu (
    .clk_i               (clk_i), .rst_i               (rst_i), .priv_i              (2'b00),
    .lsu_in_addr_i       (lsu_mmu_addr), .lsu_in_data_i       (lsu_mmu_data),
    .lsu_in_rd_i         (lsu_mmu_rd), .lsu_in_wr_i         (lsu_mmu_wr),
    .lsu_in_mask_i       (lsu_mmu_mask), .lsu_in_flush_i      (lsu_mmu_dflush),
    .lsu_in_invalidate_i (lsu_mmu_dinvalidate), .lsu_in_writeback_i  (lsu_mmu_dwriteback),
    .lsu_in_zero_i       (lsu_mmu_dzero), .lsu_in_i_invalidate_i(lsu_mmu_iinvalidate),
    .lsu_out_value_o     (mmu_lsu_data), .lsu_out_valid_o     (mmu_lsu_valid),
    .dcache_in_value_i   (dcache_resp_data_i), .dcache_in_valid_i   (dcache_resp_valid_i),
    .dcache_addr_o       (mmu_dcache_addr), .dcache_value_o      (mmu_dcache_data),
    .dcache_rd_o         (mmu_dcache_rd), .dcache_wr_o         (mmu_dcache_wr),
    .dcache_mask_o       (mmu_dcache_mask), .dcache_flush_o      (dcache_flush_o),
    .dcache_invalidate_o (dcache_invalidate_o), .dcache_writeback_o  (dcache_writeback_o),
    .dcache_zero_o       (), .cdma_data_i         (cdma_data_i),
    .cdma_valid_i        (cdma_valid_i), .cdma_wr_o           (cdma_wr_o), .cdma_rd_o           (cdma_rd_o),
    .icache_invalidate_o ()
);

// The AXI-Lite bridge is driven from the MMU's dcache-facing address/data.
assign cdma_addr_o = mmu_dcache_addr;
assign cdma_data_o = mmu_dcache_data;

// ---- track which path the currently in-flight op belongs to, so the
// response side knows whose completion dcache_resp_valid_i represents ----
reg mem_fast_active;
always @(posedge clk_i or negedge rst_i) begin
    if (~rst_i)
        mem_fast_active <= 1'b0;
    else if (dispatch_is_fast)
        mem_fast_active <= 1'b1;
    else if (mem_fast_active & dcache_resp_valid_i)
        mem_fast_active <= 1'b0;
end

// ---- confirmed-hit pulse for the back-to-back-mem-op admission relax ------
// Deliberately a single-cycle pulse, exactly the one cycle dcache_hit_i
// genuinely describes *this* access (dispatch_is_fast; a miss immediately
// takes cs out of IDLE and hit_i stops being meaningful afterward) -- NOT
// held for the rest of the in-flight window the way mem_fast_active is.
//
// This matters for more than just "when is it known": EX_MEM_Reg only has
// one slot, so at most ONE second mem op can ever be let in ahead of the
// first one's own drain. A second mem op admitted off this pulse lands in EX
// exactly one cycle later, i.e. on the very cycle the first op's
// mem_writeback_valid_i fires and frees EX_MEM_Reg (see PipelineCtrl.v's
// mem_hold) -- a perfect handoff. If this stayed asserted for the whole
// mem_fast_active window instead, it would keep admitting a THIRD, FOURTH...
// mem op on every subsequent cycle before the second one has even reached
// EX_MEM_Reg, with nowhere for their results to go (mem ops are deliberately
// excluded from the pending buffer -- see buffer_wr_en's ~EX_is_mem_op mask
// in Backend_top.v) -- silently dropping them. Confirmed by simulation: the
// held version does exactly this and loses a third back-to-back load's
// result; the single-cycle pulse throttles to one admission per handoff.
assign mem_confirmed_hit_o = dispatch_is_fast & dcache_hit_i;

// ---- request-side mux: fast path drives dcache_pro.v, holding the address
// for the whole in-flight window (needed for a HIT specifically: dcache_pro's
// cs never leaves IDLE on a hit, so its word-select mux re-reads cpu_daddr_i
// live on the very cycle the read data appears) -- otherwise mmu.v's existing
// request passes through unchanged. reg_mem_addr_i/reg_mem_data_wr_i/
// reg_mem_mask_i/reg_mem_rd_i/reg_mem_wr_i are already held steady by
// EX_MEM_Reg for the whole window, so no separate latch is needed here the
// way the old mem_fast_addr_p/mem_fast_mask_p family required.
wire mem_fast_hold = dispatch_is_fast | mem_fast_active;
assign dcache_daddr_o  = mem_fast_hold ? reg_mem_addr_i    : mmu_dcache_addr;
assign dcache_data_o   = mem_fast_hold ? reg_mem_data_wr_i : mmu_dcache_data;
assign dcache_mask_o   = mem_fast_hold ? reg_mem_mask_i    : mmu_dcache_mask;
assign dcache_req_rd_o = dispatch_is_fast ? reg_mem_rd_i   : mmu_dcache_rd;
assign dcache_req_wr_o = dispatch_is_fast ? reg_mem_wr_i   : mmu_dcache_wr;

// fast path's own value extraction -- mirrors lsu.v's, computed combinationally
// off the held fields (already stable for the whole window, no latch needed).
// Misalignment is already excluded from the fast path, so no resp_u_type
// stitching is needed.
wire mem_fast_sign = reg_mem_ctrl_i[3] & (reg_mem_ctrl_i[1:0] != 2'b11) & reg_mem_rd_i; // mirrors lsu.v's sign_inst
wire mem_fast_lb   = (reg_mem_ctrl_i[2:0] == 3'b001) & reg_mem_rd_i;                    // mirrors lsu.v's lb_inst
wire mem_fast_lh   = (reg_mem_ctrl_i[2:0] == 3'b010) & reg_mem_rd_i;                    // mirrors lsu.v's lh_inst

reg [31:0] mem_fast_value_r;
always @(*) begin
    case (reg_mem_mask_i)
        4'b0001: mem_fast_value_r = {24'b0, dcache_resp_data_i[ 7: 0]};
        4'b0010: mem_fast_value_r = {24'b0, dcache_resp_data_i[15: 8]};
        4'b0100: mem_fast_value_r = {24'b0, dcache_resp_data_i[23:16]};
        4'b1000: mem_fast_value_r = {24'b0, dcache_resp_data_i[31:24]};
        4'b0011: mem_fast_value_r = {16'b0, dcache_resp_data_i[15: 0]};
        4'b0110: mem_fast_value_r = {16'b0, dcache_resp_data_i[23: 8]};
        4'b1100: mem_fast_value_r = {16'b0, dcache_resp_data_i[31:16]};
        4'b1111: mem_fast_value_r = dcache_resp_data_i;
        default: mem_fast_value_r = dcache_resp_data_i;
    endcase
    if (mem_fast_sign && mem_fast_lh && mem_fast_value_r[15])
        mem_fast_value_r = {16'hFFFF, mem_fast_value_r[15:0]};
    else if (mem_fast_sign && mem_fast_lb && mem_fast_value_r[7])
        mem_fast_value_r = {24'hFFFFFF, mem_fast_value_r[7:0]};
end

// ---- merged completion: single source of truth for Backend_top.v ----
assign mem_writeback_valid_o = mem_fast_active ? dcache_resp_valid_i : lsu_writeback_valid;
assign mem_writeback_value_o = mem_fast_active ? mem_fast_value_r    : lsu_writeback_value;

endmodule
