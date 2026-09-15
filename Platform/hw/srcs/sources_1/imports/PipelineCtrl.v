//-----------------------------------------------------------------
// Pipeline control
//
// Every stall, every pipeline-register enable and every bubble insertion for
// IF -> ID -> EX -> MEM -> WB lives here. Backend_top supplies the raw
// conditions (computed from wires it already has, but not combined into a
// stall decision) and wires the results to the stage registers; it decides
// nothing about flow control itself.
//
// PipelineRegister gates clear by en, so a clear only lands on a cycle the
// stage is actually advancing. That is what makes "hold beats bubble" fall out
// automatically instead of needing explicit priority.
//-----------------------------------------------------------------

module PipelineCtrl(
    // ---- raw conditions ----
    input  wire redirect_flush,   // branch / jump / fence.i redirect, resolved in EX
    input  wire inst_rdy_i,       // the frontend FIFO has an instruction to pop
    input  wire EX_done,          // EX has finished its own work (or holds a bubble)
    input  wire EX_has_result,    // ...and it is a real instruction, not a bubble

    // mem_busy_reg | mem_req -- "now or soon". Only actually blocks admission
    // in combination with buffer_valid_i/ID_is_mem_op_i below (see admit_stall):
    // an independent, non-mem instruction is now allowed to run ahead of a
    // still-in-flight mem access instead of waiting for it, one instruction's
    // worth at a time.
    input  wire mem_busy_i,

    // Raw, un-OR'd MEM.v occupancy (mem_busy_o only, NOT mem_busy_i): gates
    // EX_MEM_Reg's own en so it HOLDS the in-flight mem access's address/
    // mask/store-data/rd/pc/is_impl steady, matching how a textbook 5-stage
    // pipeline's EX/MEM register freezes during a MEM-stage stall.
    input  wire mem_busy_reg_i,

    // High on the exact cycle the in-flight mem op's data becomes valid
    // (MEM.v's mem_writeback_valid_o). mem_busy_reg_i is still 1 on this same
    // cycle (registered, one cycle behind) -- but a PipelineRegister's output
    // only changes on the clock edge, so letting drain/normal_capture's en
    // fire on this cycle too does not corrupt what WB reads this cycle (still
    // the retiring mem op's pre-edge rd/pc_valid). Without this, the pending
    // buffer's drain (and any fresh EX result landing the same cycle mem
    // completes) waited a needless extra cycle past the point it was actually
    // safe to proceed.
    input  wire mem_writeback_valid_i,

    // "Now or soon" for the 1-slot pending buffer (Backend_top.v's
    // m_EX_pending), same idea as mem_busy_i above: buffer_valid itself is
    // registered, so it reads 0 for the entire cycle a result is actually
    // being captured into the buffer (buffer_wr_en) -- without covering that
    // cycle too, a THIRD instruction could sneak into EX right then, since
    // admission would see an (about-to-be-wrong) empty buffer. With the
    // buffer full, a second independent instruction has nowhere to go, so
    // admission has to block same as the traditional model until it drains.
    // Safe to reuse this same "now or soon" signal for drain/normal_capture/
    // MEM_clear below too, not just admit_stall/EX_clear: buffer_wr_en can
    // only ever be 1 while mem_busy_reg_i is ALSO 1 (see Backend_top.v), so
    // wherever mem_busy_reg_i is low -- the only place drain/normal_capture
    // care about this signal's value -- the "soon" term is always already 0
    // and this collapses to plain buffer_valid.
    input  wire buffer_valid_i,

    // Whether the instruction currently sitting in ID (about to be admitted)
    // is itself a mem op. MEM.v can only ever have one request in flight --
    // buffer or no buffer, a second mem op can never be let through while an
    // earlier one is still draining.
    input  wire ID_is_mem_op_i,

    // High while the in-flight mem access is a fast-path op confirmed to be
    // a cache hit (MEM.v's mem_confirmed_hit_o): it retires on a fixed,
    // known schedule (one cycle away), so a second mem op can be admitted
    // right behind it instead of waiting for the full round trip -- riding
    // the same drain timing mem_writeback_valid_i already gives EX_MEM_Reg,
    // no separate buffer slot needed. A miss (unknown duration) or a
    // slow-path op never sets this, so they still fully serialize.
    input  wire mem_confirmed_hit_i,

    // Whether the candidate in ID reads the pending load's own destination
    // register (a genuine load-use hazard): letting it into EX now would read
    // a stale regfile value with no forwarding source, since EX_MEM_Reg's
    // reg_wr_en for the pending load is held at 0 the whole in-flight window
    // (see EX_result_r/EX_MEM_Reg comments in Backend_top.v) and the buffer
    // machinery only knows about EX's own already-computed results, not
    // regfile hazards against a load that hasn't completed yet.
    input  wire ID_load_use_hazard_i,

    // High the same cycle a RAS-predicted return departs ID into EX (see
    // RAS.v/Backend_top.v): the front end is being speculatively redirected
    // this cycle, so whatever ID currently holds from the OLD (pre-redirect)
    // fetch stream is wrong-path and must be squashed/not-consumed exactly
    // like a real redirect_flush -- this is never 1 on the same cycle as
    // redirect_flush (RAS.v's predict_valid_o is gated by the same EX_clear
    // that redirect_flush drives, so a real flush this cycle forces it low).
    input  wire ras_redirect_valid_i,

    // ---- frontend handshake ----
    output wire req_inst_o,

    // ---- stage registers ----
    output wire pc_en,
    output wire ID_en,
    output wire ID_clear,
    output wire EX_en,
    output wire EX_clear,
    output wire MEM_en,
    output wire MEM_clear,
    output wire WB_en,
    output wire WB_clear,

    // RAS-only clear -- see the ras_clear assign below.
    output wire ras_clear_o
);

// EX's own stall: purely "has EX finished the instruction it is holding",
// unaffected by mem_busy_i. A mem op that just finished dispatching (its own
// EX_done fires the same cycle mem_busy_i asserts, since mem_busy_i also
// covers "about to become busy") still has to be free to leave EX on that
// cycle -- otherwise it would never depart at all.
wire EX_own_stall = ~EX_done;

assign EX_en    = ~EX_own_stall;

// Admission blocks on a live mem access if there is nowhere for a second
// result to go (buffer already full), OR if the candidate genuinely needs
// the pending load's not-yet-existing result (ID_load_use_hazard_i), OR if
// the candidate is itself a mem op AND the in-flight one isn't a confirmed
// hit -- MEM.v admits only one request at a time regardless of the buffer,
// UNLESS mem_confirmed_hit_i says the in-flight one is retiring on a known,
// fixed schedule, in which case a second mem op can ride that same timing
// (see mem_confirmed_hit_i above). Otherwise (buffer empty, candidate is
// non-mem and independent, or candidate is mem and the in-flight one is a
// confirmed hit) admission proceeds even with mem_busy_i high.
wire admit_stall = EX_own_stall |
    (mem_busy_i & (buffer_valid_i | (ID_is_mem_op_i & ~mem_confirmed_hit_i) | ID_load_use_hazard_i));

// EX_clear normally only squashes a wrong-path instruction after a redirect.
// It also has to fire here whenever admission is blocked (above): with
// EX_en=1 (the current occupant is leaving) but ID frozen (nothing new is
// allowed in), Exec.v's own registers would otherwise still capture whatever
// ID_pc_valid_out/ID_inst_out currently show -- ID_en=0 only stops ID's OWN
// register from advancing, it does not blank ID's output port. Without this,
// the not-yet-admitted instruction slips into EX anyway and immediately
// fires its own EX_start_o-derived pulses, corrupting whatever MEM.v is
// still working on. Deliberately mirrors admit_stall's condition, not plain
// mem_busy_i: EX must NOT bubble merely because mem is busy any more, since
// an admitted independent instruction has to be free to keep computing.
assign EX_clear = redirect_flush |
    (mem_busy_i & (buffer_valid_i | (ID_is_mem_op_i & ~mem_confirmed_hit_i) | ID_load_use_hazard_i));

// RAS-only clear: a pessimistic (never-less-restrictive) version of EX_clear
// that drops the ~mem_confirmed_hit_i qualifier. mem_confirmed_hit_i only
// ever RELAXES admission (lets a second mem op ride a confirmed hit's known,
// fixed schedule) -- treating it as always-0 here can only make ras_clear_o
// fire on a superset of the cycles the real EX_clear does, so RAS can never
// double-fire (push/pop/predict twice) on a stale/frozen ID cycle the real
// admission would have allowed through (see RAS.v's header comment for why
// that would be unsafe). The only cost is a missed RAS push/predict on the
// rare cycle a genuine call/return sits in ID at the exact moment a second
// mem op is riding the confirmed-hit relaxation -- Backend_top.v's
// EX_jalr_mispredicted already treats a stale/wrong RAS stack entry as a
// safe, guaranteed-flush fallback, so this can only ever cost a prediction
// opportunity, never a wrong execution result.
//
// The real payoff: mem_confirmed_hit_i is computed off dcache_hit_i, which
// has to walk the dcache's tag/valid-array compare first -- the one deep,
// slow term in this whole expression. Every other term here (buffer_valid_i,
// ID_is_mem_op_i, ID_load_use_hazard_i, mem_busy_i) is a plain registered
// bit. Dropping it removes that entire dcache-tag-compare depth from RAS's
// clear/predict_valid_o/redirect_valid_o cone, which otherwise lands
// directly on the frontend instruction buffer's wide CE fanout.
assign ras_clear_o = redirect_flush |
    (mem_busy_i & (buffer_valid_i | ID_is_mem_op_i | ID_load_use_hazard_i));

// ID_en must also assert on a flush for the usual reason: PipelineRegister's
// clear is subordinate to en, so without this a wrong-path instruction
// sitting in ID while otherwise stalled would never actually be squashed --
// it would just sit frozen and be admitted once the unrelated stall cleared.
assign pc_en    = ~admit_stall;
assign ID_en    = (~admit_stall) | redirect_flush;
assign ID_clear = redirect_flush | ras_redirect_valid_i;

// EX_MEM_Reg is the EX/MEM boundary register for three cases now, not two:
//  - hold:   mem_busy_reg_i high -- frozen, same as before (the in-flight mem
//            access's own address/mask/store-data/rd/pc/is_impl must stay put
//            regardless of what EX itself is doing meanwhile).
//  - drain:  mem_busy_reg_i has just gone low AND the pending buffer holds an
//            undrained result -- capture that buffer's content this cycle
//            (Backend_top.v muxes EX_MEM_Reg's input on buffer_valid_i).
//            Never a bubble here: buffer_valid_i only ever holds an already-
//            genuine EX_has_result, captured back when it was produced.
//  - normal: mem not holding EX_MEM_Reg hostage and the buffer is empty --
//            plain flow-through keyed off EX_en, bubbling on any cycle EX has
//            no real result to offer, exactly as before this round.
// drain and normal_capture are mutually exclusive by construction (one
// requires buffer_valid_i, the other requires ~buffer_valid_i), so MEM_en's
// two terms never fire together.
// mem_hold: truly frozen this cycle -- busy AND not the completion cycle
// itself (see mem_writeback_valid_i above for why en can safely fire on the
// completion cycle).
wire mem_hold = mem_busy_reg_i & ~mem_writeback_valid_i;

wire drain          = buffer_valid_i & ~mem_hold;
wire normal_capture = ~mem_hold & ~buffer_valid_i & EX_en;

assign MEM_en    = drain | normal_capture;
assign MEM_clear = buffer_valid_i ? 1'b0 : ~EX_has_result;

// Bubbles reach WB as MEM_pc_valid = 0, which Writeback already uses to
// suppress the register write, so WB needs no bubble of its own.
assign WB_en    = 1'b1;
assign WB_clear = 1'b0;

// Do not pop the frontend on the cycle a redirect is issued: that entry is
// from the wrong path and is about to be flushed anyway.
//
// Deliberately NOT also gated on ras_redirect_valid_i here (unlike
// ID_clear below): req_inst_o fans out to every entry of the frontend's
// 16-deep instruction buffer (Inst_buf.v's pop_i), so tying it to
// ras_redirect_valid_i -- which depends on EX_clear's full mem-busy/hazard
// chain -- created a 21-logic-level, ~17ns critical path and blew timing
// by -2.8ns (1808 failing endpoints) the first time this was tried. Safe
// to omit: if req_inst_o wrongly pops one stale entry on a RAS-redirect
// cycle, that entry is discarded harmlessly -- ID_clear (below) still
// squashes it from ever becoming a real instruction, and the frontend's
// own ibuf_flush_o (driven by the same redirect_valid_o that carries this
// RAS pulse) discards the rest of the buffer's wrong-path contents anyway.
assign req_inst_o = inst_rdy_i & ID_en & ~redirect_flush;

endmodule
