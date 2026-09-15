`include "riscv_defs.v"
module Exec(
    input clk
    ,input rst_n
    
    ,input en
    ,input clear
    
    ,input is_impl_i
    ,input pc_valid_i
    ,input [31:0] pc_i
    ,input [31:0] pc_p4_i
    ,input [31:0] inst_i
    ,input  wire [31:0] reg_rd_data1_i
    ,input  wire [31:0] reg_rd_data2_i
    
    ,input  wire [31:0] imm_i
    
    ,input  wire [4:0]  rd_i
    ,input  wire [4:0]  rs1_i
    ,input  wire [4:0]  rs2_i
    ,input  wire [4:0]  rs3_i
    // reg
    ,input wire        reg_wr_en_i
    ,input wire [2:0]  reg_w_sel_i
    // mem
    ,input wire        mem_wr_en_i
    ,input wire        mem_rd_en_i
    ,input wire [3:0]  mem_ctrl_i
    // Br and Jump
    ,input wire        is_j_i
    ,input wire        is_br_i
    // RAS: whether ID's departing instruction had a speculative return
    // prediction, and what it was -- carried through so EX can compare
    // against the real ALU-computed target (see Backend_top.v's br_flush)
    ,input wire        ras_predicted_i
    ,input wire [31:0] ras_predicted_pc_i
    // ID-computed jalr target + whether it was safe to compute (no rs1
    // hazard) -- see Backend_top.v's id_jalr_target/id_rs1_hazard comment
    ,input wire        jalr_target_valid_i
    ,input wire [31:0] jalr_target_i
    // ALU
    ,input wire        ALU_sel1_i
    ,input wire        ALU_sel2_i
    ,input wire [3:0]  ALU_ctrl_i
    // cmp
    ,input wire [2:0]  cmp_op_i
    
    // MUL/DIV
    ,input wire is_MUL_DIV_i
    ,input wire [2:0] MUL_DIV_ctrl_i

    // csr
    ,input wire [11:0] csr_addr_i

    ,input wire is_csr_i

    // npu
    ,input wire is_npu_i

    // bypass
    ,input wire [1:0] bypass_sel_i
    // fence
    ,input wire fetch_invalid_i

    // forwarding
    ,input [4:0]  MEM_rd_i
    ,input        MEM_reg_wr_en_i
    ,input [31:0] MEM_fwd_data_i
    ,input [4:0] WB_rd_i
    ,input WB_reg_wr_en_i
    ,input [31:0] wb_data_i
//=================================
    // output
    // data
    ,output wire         is_impl_o
    ,output  wire        pc_valid_o
    ,output  wire [31:0] pc_o
    ,output  wire [31:0] pc_p4_o
    ,output wire [31:0] inst_o
    
    ,output wire [31:0] reg_fwd_data1_o
    ,output wire [31:0] reg_fwd_data2_o
    
    ,output wire [31:0] imm_o
    
    ,output wire [4:0]  rd_o
    ,output wire [4:0]  rs1_o
    ,output wire [4:0]  rs2_o
    ,output wire [4:0]  rs3_o
    
    // reg
    ,output wire        reg_wr_en_o
    ,output wire [2:0]  reg_w_sel_o
    // mem
    ,output wire        mem_wr_en_o
    ,output wire        mem_rd_en_o
    ,output wire [3:0]  mem_ctrl_o
    // Br and Jump
    ,output wire        is_j_o
    ,output wire        is_br_o
    ,output wire        ras_predicted_o
    ,output wire [31:0] ras_predicted_pc_o
    ,output wire        jalr_target_valid_o
    ,output wire [31:0] jalr_target_o
    // ALU
    ,output wire [3:0]  ALU_ctrl_o
    ,output wire [31:0] ALU_o
    // Branch
    ,output wire        br_taken_o

    // load/store address + mask + rotated store-data, computed here instead of lsu.v (Phase 1 roadmap)
    ,output wire [31:0] mem_addr_o
    ,output wire [ 3:0] mem_mask_o
    ,output wire [31:0] mem_data_wr_o
    // cacheable-address classification, computed here instead of MEM.v (Phase 1 roadmap)
    ,output wire         mem_cacheable_o

    // MUL/DIV
    ,output wire is_MUL_DIV_o
    ,output wire [2:0] MUL_DIV_ctrl_o

    // csr
    ,output wire [31:0] csr_rd_data_o

    // npu
    ,output wire is_npu_o

    ,output wire [1:0] bypass_sel_o
    ,output wire [31:0] bypass_o

    ,output wire fetch_invalid_o
// EX control
    ,output wire EX_start_o
    ,output wire MUL_DIV_start_o
    ,output wire NPU_start_o
    ,output wire mem_req_o
    
    ,input wire MUL_done_i
    ,input wire DIV_done_i
    ,input wire NPU_done_i
    //,input wire SYS_done_i
    
    ,output wire EX_done_o
);
wire [31:0] reg_rd_data1_o;
wire [31:0] reg_rd_data2_o;

wire ALU_sel1_o;
wire ALU_sel2_o;

wire [2:0] cmp_op_o;
wire [11:0] csr_addr_o;
wire is_csr_o;
wire SYS_done;

// data
PipelineRegister #(.WIDTH( 1)) reg_is_impl   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(is_impl_i),   .data_o(is_impl_o));
PipelineRegister #(.WIDTH( 1)) reg_pc_valid  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_valid_i),   .data_o(pc_valid_o));
PipelineRegister #(.WIDTH(32)) reg_inst      (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(inst_i),     .data_o(inst_o));
PipelineRegister #(.WIDTH(32)) reg_pc        (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(pc_i),      .data_o(pc_o));
PipelineRegister #(.WIDTH(32)) reg_pc_p4     (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(pc_p4_i),   .data_o(pc_p4_o));

PipelineRegister #(.WIDTH(32)) reg_rd_data1  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(reg_rd_data1_i), .data_o(reg_rd_data1_o));
PipelineRegister #(.WIDTH(32)) reg_rd_data2  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(reg_rd_data2_i), .data_o(reg_rd_data2_o));

PipelineRegister #(.WIDTH(32)) reg_imm       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(imm_i),      .data_o(imm_o));
PipelineRegister #(.WIDTH(5))  reg_rd        (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(rd_i),       .data_o(rd_o));
PipelineRegister #(.WIDTH(5))  reg_rs1       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(rs1_i),      .data_o(rs1_o));
PipelineRegister #(.WIDTH(5))  reg_rs2       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(rs2_i),      .data_o(rs2_o));
PipelineRegister #(.WIDTH(5))  reg_rs3       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(rs3_i),      .data_o(rs3_o));

// control
PipelineRegister #(.WIDTH(1))  reg_reg_wr_en (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(reg_wr_en_i), .data_o(reg_wr_en_o));
PipelineRegister #(.WIDTH(3))  reg_reg_w_sel (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(reg_w_sel_i), .data_o(reg_w_sel_o));
// mem
PipelineRegister #(.WIDTH(1))  reg_mem_rd_en (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(mem_rd_en_i), .data_o(mem_rd_en_o));
PipelineRegister #(.WIDTH(1))  reg_mem_wr_en (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(mem_wr_en_i), .data_o(mem_wr_en_o));
PipelineRegister #(.WIDTH(4))  reg_mem_ctrl  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(mem_ctrl_i), .data_o(mem_ctrl_o));
// Br and Jump
PipelineRegister #(.WIDTH(1))  reg_is_j      (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(is_j_i), .data_o(is_j_o));
PipelineRegister #(.WIDTH(1))  reg_is_br     (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(is_br_i), .data_o(is_br_o));
PipelineRegister #(.WIDTH(1))  reg_ras_predicted    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(ras_predicted_i),    .data_o(ras_predicted_o));
PipelineRegister #(.WIDTH(32)) reg_ras_predicted_pc (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(ras_predicted_pc_i), .data_o(ras_predicted_pc_o));
PipelineRegister #(.WIDTH(1))  reg_jalr_target_valid (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(jalr_target_valid_i), .data_o(jalr_target_valid_o));
PipelineRegister #(.WIDTH(32)) reg_jalr_target       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(jalr_target_i),       .data_o(jalr_target_o));
// ALU
PipelineRegister #(.WIDTH(1))  reg_ALU_sel1  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(ALU_sel1_i), .data_o(ALU_sel1_o));
PipelineRegister #(.WIDTH(1))  reg_ALU_sel2  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(ALU_sel2_i), .data_o(ALU_sel2_o));
PipelineRegister #(.WIDTH(4))  reg_ALU_ctrl  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(ALU_ctrl_i), .data_o(ALU_ctrl_o));
// cmp
PipelineRegister #(.WIDTH(3))  reg_cmp_op    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(cmp_op_i), .data_o(cmp_op_o));
// MUL/DIV
PipelineRegister #(.WIDTH(1))  reg_is_MUL_DIV (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(is_MUL_DIV_i), .data_o(is_MUL_DIV_o));
PipelineRegister #(.WIDTH(3))  reg_MUL_DIV_ctrl (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(MUL_DIV_ctrl_i), .data_o(MUL_DIV_ctrl_o));
// csr
PipelineRegister #(.WIDTH(12)) reg_csr_addr  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(csr_addr_i), .data_o(csr_addr_o));
PipelineRegister #(.WIDTH(1))  reg_is_csr    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(is_csr_i), .data_o(is_csr_o));

// vpu
PipelineRegister #(.WIDTH(1))  reg_is_npu    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(is_npu_i), .data_o(is_npu_o));
// bypass
PipelineRegister #(.WIDTH(2))  reg_bypass_sel (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(bypass_sel_i), .data_o(bypass_sel_o));
// Fence
PipelineRegister #(.WIDTH(1))  reg_fetch_invalid (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en),  .data_i(fetch_invalid_i), .data_o(fetch_invalid_o));


// Forwarding
wire [1:0] EX_fwd1_sel;
wire [1:0] EX_fwd2_sel;
ForwardUnit m_Forward(
    .EX_rs1(rs1_o), .EX_rs2(rs2_o), .EX_rs3(rs3_o),
    .MEM_rd(MEM_rd_i), .MEM_reg_wr_en(MEM_reg_wr_en_i),
    .WB_rd(WB_rd_i),   .WB_reg_wr_en(WB_reg_wr_en_i),
    .EX_fwd_sel1(EX_fwd1_sel), .EX_fwd_sel2(EX_fwd2_sel)
);

wire [31:0] current_fwd_data1;
wire [31:0] current_fwd_data2;

// 0 = WB, 1 = register file, 2 = MEM (see ForwardUnit.v)
reg [31:0] fwd1_r, fwd2_r;
always @(*) begin
    case (EX_fwd1_sel)
        2'd0:    fwd1_r = wb_data_i;
        2'd2:    fwd1_r = MEM_fwd_data_i;
        default: fwd1_r = reg_rd_data1_o;
    endcase
    case (EX_fwd2_sel)
        2'd0:    fwd2_r = wb_data_i;
        2'd2:    fwd2_r = MEM_fwd_data_i;
        default: fwd2_r = reg_rd_data2_o;
    endcase
end
assign current_fwd_data1 = fwd1_r;
assign current_fwd_data2 = fwd2_r;

// EX start control
wire bypass_start;
wire ALU_start;
wire Br_start;
wire SYS_start;

// start logic
/*
set to 0 if
    - first cycle of execution
    - not executing
set to 1 if
    - not the first cycle of execution
*/
reg started;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) started <= 0;
    else begin
        if(en || !(pc_valid_o && is_impl_o)) started <= 0;
        else if((pc_valid_o && is_impl_o) && !started)
            started <= 1;
    end
end
assign EX_start_o = (!started) && (pc_valid_o && is_impl_o);

reg [31:0] held_fwd_data1;
reg [31:0] held_fwd_data2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        held_fwd_data1 <= 32'd0;
        held_fwd_data2 <= 32'd0;
    end else if (!started) begin
        held_fwd_data1 <= current_fwd_data1;
        held_fwd_data2 <= current_fwd_data2;
    end
end

assign reg_fwd_data1_o = started ? held_fwd_data1 : current_fwd_data1;
assign reg_fwd_data2_o = started ? held_fwd_data2 : current_fwd_data2;
// ====================================================================

// ALU src
wire [31:0] ALU_src1, ALU_src2;
Mux2to1 #(.size(32)) m_ALU_SRC1_MUX(
    .sel(ALU_sel1_o),
    .s0(pc_o),
    .s1(reg_fwd_data1_o),
    .out(ALU_src1)
);
Mux2to1 #(.size(32)) m_ALU_SRC2_MUX(
    .sel(ALU_sel2_o),
    .s0(reg_fwd_data2_o),
    .s1(imm_o),
    .out(ALU_src2)
);

assign bypass_start = EX_start_o && (|bypass_sel_o);
assign ALU_start = EX_start_o && (|ALU_ctrl_o);
assign Br_start  = EX_start_o && (is_br_o || is_j_o);
assign SYS_start = EX_start_o && is_csr_o;
assign MUL_DIV_start_o = EX_start_o && is_MUL_DIV_o;
assign NPU_start_o = EX_start_o && is_npu_o;
wire is_mem_op_w = mem_wr_en_o || mem_rd_en_o
                || (mem_ctrl_o[1:0] == 2'b11)      // Zicbom cbo.*
                || (mem_ctrl_o[2:1] == 2'b11);     // fence.i
assign mem_req_o = EX_start_o && is_mem_op_w;

// Load/store address + byte mask + rotated store-data =====
// decode mirrors lsu.v's former lb_inst/lh_inst/.../sw_inst (now computed here, one cycle earlier)
wire mem_is_lb_w = (mem_ctrl_o[2:0] == 3'b001) & mem_rd_en_o & mem_req_o;
wire mem_is_lh_w = (mem_ctrl_o[2:0] == 3'b010) & mem_rd_en_o & mem_req_o;
wire mem_is_lw_w = (mem_ctrl_o[2:0] == 3'b100) & mem_rd_en_o & mem_req_o;
wire mem_is_sb_w = (mem_ctrl_o[2:0] == 3'b001) & mem_wr_en_o & mem_req_o;
wire mem_is_sh_w = (mem_ctrl_o[2:0] == 3'b010) & mem_wr_en_o & mem_req_o;
wire mem_is_sw_w = (mem_ctrl_o[2:0] == 3'b100) & mem_wr_en_o & mem_req_o;

assign mem_addr_o = reg_fwd_data1_o + imm_o;

// Cacheable-address classification, moved here from MEM.v: same range check
// mmu.v's d_cachable uses (mmu.v:3-4,76), duplicated as a plain combinational
// function of mem_addr_o so MEM.v no longer has to re-derive it after the
// address arrives one stage later.
localparam [31:0] D_ADDR_MIN = 32'h6000_0000;
localparam [31:0] D_ADDR_MAX = 32'hFFFF_FFFF;
assign mem_cacheable_o = (mem_addr_o >= D_ADDR_MIN) && (mem_addr_o <= D_ADDR_MAX);

reg [31:0] mem_data_wr_r;
reg [ 3:0] mem_mask_r;
always @(*) begin
    mem_mask_r = 4'b0000; mem_data_wr_r = 32'b0;
    if (mem_is_sw_w) begin
        case (mem_addr_o[1:0])
        2'b11:   mem_data_wr_r = {reg_fwd_data2_o[7:0], 24'h0};
        2'b10:   mem_data_wr_r = {reg_fwd_data2_o[15:0], 16'h0};
        2'b01:   mem_data_wr_r = {reg_fwd_data2_o[23:0], 8'h0};
        2'b00:   mem_data_wr_r = reg_fwd_data2_o;
        endcase
    end else if (mem_is_sh_w) begin
        case (mem_addr_o[1:0])
        2'b11:   mem_data_wr_r = {reg_fwd_data2_o[7:0], 24'h0};
        2'b10:   mem_data_wr_r = {reg_fwd_data2_o[15:0], 16'h0};
        2'b01:   mem_data_wr_r = {8'h0, reg_fwd_data2_o[15:0], 8'h0};
        2'b00:   mem_data_wr_r = {16'h0, reg_fwd_data2_o[15:0]};
        endcase
    end else if (mem_is_sb_w) begin
        case (mem_addr_o[1:0])
        2'b11:   mem_data_wr_r = {reg_fwd_data2_o[7:0], 24'h0};
        2'b10:   mem_data_wr_r = {{8'h0, reg_fwd_data2_o[7:0]}, 16'h0};
        2'b01:   mem_data_wr_r = {{16'h0, reg_fwd_data2_o[7:0]}, 8'h0};
        2'b00:   mem_data_wr_r = {24'h0, reg_fwd_data2_o[7:0]};
        endcase
    end

    if (mem_is_sw_w || mem_is_lw_w) begin
        case (mem_addr_o[1:0])
        2'b11: mem_mask_r = 4'b1000; 2'b10: mem_mask_r = 4'b1100;
        2'b01: mem_mask_r = 4'b1110; 2'b00: mem_mask_r = 4'b1111;
        endcase
    end else if (mem_is_sh_w || mem_is_lh_w) begin
        case (mem_addr_o[1:0])
        2'b11: mem_mask_r = 4'b1000; 2'b10: mem_mask_r = 4'b1100;
        2'b01: mem_mask_r = 4'b0110; 2'b00: mem_mask_r = 4'b0011;
        endcase
    end else if (mem_is_sb_w || mem_is_lb_w) begin
        case (mem_addr_o[1:0])
        2'b11: mem_mask_r = 4'b1000; 2'b10: mem_mask_r = 4'b0100;
        2'b01: mem_mask_r = 4'b0010; 2'b00: mem_mask_r = 4'b0001;
        endcase
    end
end
assign mem_mask_o    = mem_mask_r;
assign mem_data_wr_o = mem_data_wr_r;

// ALU =========================
wire ALU_done;
ALU_top m_ALU(
    .ALU_ctrl(ALU_ctrl_o),
    .a(ALU_src1),
    .b(ALU_src2),
    .is_imm_i(ALU_sel2_o),
    
    .out(ALU_o)
);
assign ALU_done = ALU_start;

// BypassUnit ==================
wire bypass_done;
BypassUnit m_BypassUnit(
    .bypass_sel(bypass_sel_o),
    .imm(imm_o),
    .reg_data1(reg_fwd_data1_o),
    .result_o(bypass_o)
);
assign bypass_done = bypass_start;

// Branch Unit =================
wire Br_done;
BranchUnit m_Branch(
    .is_br(is_br_o),
    .is_j(is_j_o),
    .cmp_op(cmp_op_o),
    .reg_rd_data1(reg_fwd_data1_o),
    .reg_rd_data2(reg_fwd_data2_o),

    .br_taken(br_taken_o)
);
assign Br_done = Br_start;

// CSR =========================
CSR m_CSR(
    .clk(clk),
    .rst_n(rst_n),
    .csr_rd_addr_i(csr_addr_o),
    .csr_rd_data_o(csr_rd_data_o)
);

assign SYS_done = SYS_start;

// EX done logic
//
// Memory is dispatch-and-forget again: mem_req_o itself (the EX_start_o pulse
// for a load/store/CBO/fence.i, already qualified by is_mem_op_w) is what
// retires the instruction out of EX, not a completion strobe. EX no longer
// knows or cares when the access actually finishes -- MEM.v owns that, using
// the request register it already latches off this same mem_req_o pulse.
// This brings the load-use hazard back (a dependent instruction can enter EX
// before the load's data exists), so something downstream of EX -- MEM.v's
// own busy/admission tracking plus a stall into EX -- has to interlock it;
// EX itself has no completion signal left to interlock on.
//
// MUL/DIV are unaffected by this: both still hold EX until their own
// completion strobe, same as before.
//
// Each completion strobe is qualified by the instruction actually in EX. The
// units' done pulses are one cycle wide and are not otherwise tied to who owns
// them, so an unqualified strobe could retire an unrelated instruction that
// happened to be sitting in EX.
wire MUL_done_w = MUL_done_i && is_MUL_DIV_o && ~MUL_DIV_ctrl_o[2];
wire DIV_done_w = DIV_done_i && is_MUL_DIV_o &&  MUL_DIV_ctrl_o[2];

assign EX_done_o = (!pc_valid_o) | (!is_impl_o) |
    ALU_done | Br_done | mem_req_o | MUL_done_w |
    SYS_done | bypass_done | DIV_done_w |
    NPU_done_i;

endmodule
