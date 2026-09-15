`include "riscv_defs.v"
module Control (
    input [31:0] inst,
    // WB stage
    output reg_wr_en_o,
    output [2:0] reg_w_sel_o, // 0: pc_p4, 1: ALU, 2: mem, 3:csr, 4: FPU, 5: bypass, 6: MUL_DIV_top, 7: NPU
    
    // LSU
    output mem_wr_en_o,
    output mem_rd_en_o,
    output [3:0] mem_ctrl_o,
    
    // Branch
    output is_j_o,
    output is_br_o,
    output [2:0] cmp_op_o,
    
    // ALU
    output [3:0] ALU_ctrl_o,
    output ALU_sel1_o, // 0: PC, 1: rs1
    output ALU_sel2_o, // 0: rs2, 1: imm

    // MUL/DIV
    output is_MUL_DIV_o,
    output [2:0] MUL_DIV_ctrl_o,

    // CSR
    output is_csr_o,
    output [11:0] csr_addr_o,

    // NPU
    output is_npu_o,

    // Bypass
    output [1:0] bypass_sel_o,

    // Fence
    output fetch_invalid_o,

    output is_impl_o
);

parameter CSR_FRM = 12'h002;

// declare
wire [2:0] funct3 = inst[14:12];
reg  [3:0] alu_ctrl_r;
reg  [3:0] mem_ctrl_r;
reg  [2:0] cmp_op_r;
reg  [2:0] reg_w_sel_r;
reg  [1:0] bypass_sel_r;

// 0: PC, 1: rs1
wire alu_sel1_w = ((inst&`INST_ADDI_MASK) == `INST_ADDI)   ||
                  ((inst&`INST_SLTI_MASK) == `INST_SLTI)   ||
                  ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) ||
                  ((inst&`INST_ANDI_MASK) == `INST_ANDI)   ||
                  ((inst&`INST_ORI_MASK) == `INST_ORI)     ||
                  ((inst&`INST_XORI_MASK) == `INST_XORI)   ||
                  ((inst&`INST_SLLI_MASK) == `INST_SLLI)   ||
                  ((inst&`INST_SRLI_MASK) == `INST_SRLI)   ||
                  ((inst&`INST_SRAI_MASK) == `INST_SRAI)   ||
                  ((inst&`INST_ADD_MASK) == `INST_ADD)     ||
                  ((inst&`INST_SLT_MASK) == `INST_SLT)     ||
                  ((inst&`INST_SLTU_MASK) == `INST_SLTU)   ||
                  ((inst&`INST_AND_MASK) == `INST_AND)     ||
                  ((inst&`INST_OR_MASK) == `INST_OR)       ||
                  ((inst&`INST_XOR_MASK) == `INST_XOR)     ||
                  ((inst&`INST_SLL_MASK) == `INST_SLL)     ||
                  ((inst&`INST_SRL_MASK) == `INST_SRL)     ||
                  ((inst&`INST_SUB_MASK) == `INST_SUB)     ||
                  ((inst&`INST_SRA_MASK) == `INST_SRA)     ||
                  ((inst&`INST_JALR_MASK) == `INST_JALR)   ||
                  ((inst&`INST_NPU_MASK) == `INST_NPU) ;
// 0: rs2, 1: imm
wire alu_sel2_w = ((inst&`INST_ADDI_MASK) == `INST_ADDI)   ||
                  ((inst&`INST_SLTI_MASK) == `INST_SLTI)   ||
                  ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) ||
                  ((inst&`INST_ANDI_MASK) == `INST_ANDI)   ||
                  ((inst&`INST_ORI_MASK) == `INST_ORI)     ||
                  ((inst&`INST_XORI_MASK) == `INST_XORI)   ||
                  ((inst&`INST_SLLI_MASK) == `INST_SLLI)   ||
                  ((inst&`INST_SRLI_MASK) == `INST_SRLI)   ||
                  ((inst&`INST_SRAI_MASK) == `INST_SRAI)   ||
                  ((inst&`INST_LUI_MASK) == `INST_LUI)     ||
                  ((inst&`INST_AUIPC_MASK) == `INST_AUIPC) ||
                  ((inst&`INST_JAL_MASK) == `INST_JAL)     ||
                  ((inst&`INST_JALR_MASK) == `INST_JALR)   ||
                  ((inst&`INST_BEQ_MASK) == `INST_BEQ)     ||
                  ((inst&`INST_BNE_MASK) == `INST_BNE)     ||
                  ((inst&`INST_BLT_MASK) == `INST_BLT)     ||
                  ((inst&`INST_BGE_MASK) == `INST_BGE)     ||
                  ((inst&`INST_BLTU_MASK) == `INST_BLTU)   ||
                  ((inst&`INST_BGEU_MASK) == `INST_BGEU)   ;

wire is_impl_w =((inst&`INST_ADDI_MASK) == `INST_ADDI)   ||
                ((inst&`INST_SLTI_MASK) == `INST_SLTI)   ||
                ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) ||
                ((inst&`INST_ANDI_MASK) == `INST_ANDI)   ||
                ((inst&`INST_ORI_MASK) == `INST_ORI)     ||
                ((inst&`INST_XORI_MASK) == `INST_XORI)   ||
                ((inst&`INST_SLLI_MASK) == `INST_SLLI)   ||
                ((inst&`INST_SRLI_MASK) == `INST_SRLI)   ||
                ((inst&`INST_SRAI_MASK) == `INST_SRAI)   ||
                ((inst&`INST_LUI_MASK) == `INST_LUI)     ||
                ((inst&`INST_AUIPC_MASK) == `INST_AUIPC) ||
                ((inst&`INST_ADD_MASK) == `INST_ADD)     ||
                ((inst&`INST_SLT_MASK) == `INST_SLT)     ||
                ((inst&`INST_SLTU_MASK) == `INST_SLTU)   ||
                ((inst&`INST_AND_MASK) == `INST_AND)     ||
                ((inst&`INST_OR_MASK) == `INST_OR)       ||
                ((inst&`INST_XOR_MASK) == `INST_XOR)     ||
                ((inst&`INST_SLL_MASK) == `INST_SLL)     ||
                ((inst&`INST_SRL_MASK) == `INST_SRL)     ||
                ((inst&`INST_SUB_MASK) == `INST_SUB)     ||
                ((inst&`INST_SRA_MASK) == `INST_SRA)     ||
                // J-Type
                ((inst&`INST_JAL_MASK) == `INST_JAL)   ||
                ((inst&`INST_JALR_MASK) == `INST_JALR) ||
                ((inst&`INST_BEQ_MASK) == `INST_BEQ)   ||
                ((inst&`INST_BNE_MASK) == `INST_BNE)   ||
                ((inst&`INST_BLT_MASK) == `INST_BLT)   ||
                ((inst&`INST_BGE_MASK) == `INST_BGE)   ||
                ((inst&`INST_BLTU_MASK) == `INST_BLTU) ||
                ((inst&`INST_BGEU_MASK) == `INST_BGEU) ||
                ((inst&`INST_LB_MASK) == `INST_LB)     ||
                ((inst&`INST_LBU_MASK) == `INST_LBU)   ||
                ((inst&`INST_LH_MASK) == `INST_LH)     ||
                ((inst&`INST_LHU_MASK) == `INST_LHU)   ||
                ((inst&`INST_LW_MASK) == `INST_LW)     ||
                ((inst&`INST_SB_MASK) == `INST_SB)     ||
                ((inst&`INST_SH_MASK) == `INST_SH)     ||
                ((inst&`INST_SW_MASK) == `INST_SW)     ||
                // M-Ext
                ((inst&`INST_MUL_MASK) == `INST_MUL)        ||
                ((inst&`INST_MULH_MASK) == `INST_MULH)      ||
                ((inst&`INST_MULHSU_MASK) == `INST_MULHSU)  ||
                ((inst&`INST_MULHU_MASK) == `INST_MULHU)    ||
                ((inst&`INST_DIV_MASK) == `INST_DIV)        ||
                ((inst&`INST_DIVU_MASK) == `INST_DIVU)      ||
                ((inst&`INST_REM_MASK) == `INST_REM)        ||
                ((inst&`INST_REMU_MASK) == `INST_REMU)      ||
                // Zicsr
                ((inst&`INST_CSRRS_MASK) == `INST_CSRRS)   ||
                // Zifencei
                ((inst&`INST_IFENCE_MASK) == `INST_IFENCE) ||
                // fence
                ((inst&`INST_FENCE_MASK) == `INST_FENCE) ||
                // NPU
                ((inst&`INST_NPU_MASK) == `INST_NPU) ||
                // zicbom
                ((inst&`INST_CBO_FLUSH_MASK) == `INST_CBO_FLUSH) ||
                ((inst&`INST_CBO_INVAL_MASK) == `INST_CBO_INVAL) || 
                ((inst&`INST_CBO_CLEAN_MASK) == `INST_CBO_CLEAN) || 
                ((inst&`INST_CBO_ZERO_MASK) == `INST_CBO_ZERO) ;

wire reg_wr_en_w = ((inst&`INST_ADDI_MASK) == `INST_ADDI)    ||
                    ((inst&`INST_SLTI_MASK) == `INST_SLTI)   ||
                    ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) ||
                    ((inst&`INST_ANDI_MASK) == `INST_ANDI)   ||
                    ((inst&`INST_ORI_MASK) == `INST_ORI)     ||
                    ((inst&`INST_XORI_MASK) == `INST_XORI)   ||
                    ((inst&`INST_SLLI_MASK) == `INST_SLLI)   ||
                    ((inst&`INST_SRLI_MASK) == `INST_SRLI)   ||
                    ((inst&`INST_SRAI_MASK) == `INST_SRAI)   ||
                    ((inst&`INST_LUI_MASK) == `INST_LUI)     ||
                    ((inst&`INST_AUIPC_MASK) == `INST_AUIPC) ||
                    ((inst&`INST_ADD_MASK) == `INST_ADD)     ||
                    ((inst&`INST_SLT_MASK) == `INST_SLT)     ||
                    ((inst&`INST_SLTU_MASK) == `INST_SLTU)   ||
                    ((inst&`INST_AND_MASK) == `INST_AND)     ||
                    ((inst&`INST_OR_MASK) == `INST_OR)       ||
                    ((inst&`INST_XOR_MASK) == `INST_XOR)     ||
                    ((inst&`INST_SLL_MASK) == `INST_SLL)     ||
                    ((inst&`INST_SRL_MASK) == `INST_SRL)     ||
                    ((inst&`INST_SUB_MASK) == `INST_SUB)     ||
                    ((inst&`INST_SRA_MASK) == `INST_SRA)     ||
                    // Jump
                    ((inst&`INST_JAL_MASK) == `INST_JAL)   ||
                    ((inst&`INST_JALR_MASK) == `INST_JALR) ||
                    // load
                    ((inst&`INST_LB_MASK) == `INST_LB)   ||
                    ((inst&`INST_LBU_MASK) == `INST_LBU) ||
                    ((inst&`INST_LH_MASK) == `INST_LH)   ||
                    ((inst&`INST_LHU_MASK) == `INST_LHU) ||
                    ((inst&`INST_LW_MASK) == `INST_LW)   ||
                    // M-Ext
                    ((inst&`INST_MUL_MASK) == `INST_MUL)        ||
                    ((inst&`INST_MULH_MASK) == `INST_MULH)      ||
                    ((inst&`INST_MULHSU_MASK) == `INST_MULHSU)  ||
                    ((inst&`INST_MULHU_MASK) == `INST_MULHU)    ||
                    ((inst&`INST_DIV_MASK) == `INST_DIV)        ||
                    ((inst&`INST_DIVU_MASK) == `INST_DIVU)      ||
                    ((inst&`INST_REM_MASK) == `INST_REM)        ||
                    ((inst&`INST_REMU_MASK) == `INST_REMU)      ||
                    // CSR
                    ((inst&`INST_CSRRS_MASK) == `INST_CSRRS)   ||
                    // NPU
                    ((inst&`INST_NPU_MASK) == `INST_NPU) ;

wire mem_rd_en_w = ((inst&`INST_LB_MASK) == `INST_LB)    ||
                    ((inst&`INST_LBU_MASK) == `INST_LBU) ||
                    ((inst&`INST_LH_MASK) == `INST_LH)   ||
                    ((inst&`INST_LHU_MASK) == `INST_LHU) ||
                    ((inst&`INST_LW_MASK) == `INST_LW);
                    
wire mem_wr_en_w = ((inst&`INST_SB_MASK) == `INST_SB)   ||
                   ((inst&`INST_SH_MASK) == `INST_SH)   ||
                   ((inst&`INST_SW_MASK) == `INST_SW);
				   
wire is_j_w = ((inst&`INST_JAL_MASK) == `INST_JAL)  ||
              ((inst&`INST_JALR_MASK) == `INST_JALR);

wire is_br_w = ((inst&`INST_BEQ_MASK) == `INST_BEQ)   ||
               ((inst&`INST_BNE_MASK) == `INST_BNE)   ||
               ((inst&`INST_BLT_MASK) == `INST_BLT)   ||
               ((inst&`INST_BGE_MASK) == `INST_BGE)   ||
               ((inst&`INST_BLTU_MASK) == `INST_BLTU) ||
               ((inst&`INST_BGEU_MASK) == `INST_BGEU) ;

wire is_MUL_DIV_w = ((inst&`INST_MUL_MASK) == `INST_MUL)        ||
                    ((inst&`INST_MULH_MASK) == `INST_MULH)      ||
                    ((inst&`INST_MULHSU_MASK) == `INST_MULHSU)  ||
                    ((inst&`INST_MULHU_MASK) == `INST_MULHU)    ||
                    ((inst&`INST_DIV_MASK) == `INST_DIV)        ||
                    ((inst&`INST_DIVU_MASK) == `INST_DIVU)      ||
                    ((inst&`INST_REM_MASK) == `INST_REM)        ||
                    ((inst&`INST_REMU_MASK) == `INST_REMU)      ;

wire is_csr_w =     ((inst&`INST_CSRRS_MASK) == `INST_CSRRS)    ;

wire is_alu_w = ((inst&`INST_ADDI_MASK) == `INST_ADDI)   ||
                ((inst&`INST_SLTI_MASK) == `INST_SLTI)   ||
                ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) ||
                ((inst&`INST_ANDI_MASK) == `INST_ANDI)   ||
                ((inst&`INST_ORI_MASK) == `INST_ORI)     ||
                ((inst&`INST_XORI_MASK) == `INST_XORI)   ||
                ((inst&`INST_SLLI_MASK) == `INST_SLLI)   ||
                ((inst&`INST_SRLI_MASK) == `INST_SRLI)   ||
                ((inst&`INST_SRAI_MASK) == `INST_SRAI)   ||
                ((inst&`INST_AUIPC_MASK) == `INST_AUIPC) ||
                ((inst&`INST_ADD_MASK) == `INST_ADD)     ||
                ((inst&`INST_SLT_MASK) == `INST_SLT)     ||
                ((inst&`INST_SLTU_MASK) == `INST_SLTU)   ||
                ((inst&`INST_AND_MASK) == `INST_AND)     ||
                ((inst&`INST_OR_MASK) == `INST_OR)       ||
                ((inst&`INST_XOR_MASK) == `INST_XOR)     ||
                ((inst&`INST_SLL_MASK) == `INST_SLL)     ||
                ((inst&`INST_SRL_MASK) == `INST_SRL)     ||
                ((inst&`INST_SUB_MASK) == `INST_SUB)     ||
                ((inst&`INST_SRA_MASK) == `INST_SRA)     ||
                // Jump
                ((inst&`INST_JAL_MASK) == `INST_JAL)     ||
                ((inst&`INST_JALR_MASK) == `INST_JALR)   ;

wire is_lsu_w = ((inst&`INST_LB_MASK) == `INST_LB)   ||
                ((inst&`INST_LBU_MASK) == `INST_LBU) ||
                ((inst&`INST_LH_MASK) == `INST_LH)   ||
                ((inst&`INST_LHU_MASK) == `INST_LHU) ||
                ((inst&`INST_LW_MASK) == `INST_LW)   ||
                ((inst&`INST_SB_MASK) == `INST_SB)   ||
                ((inst&`INST_SH_MASK) == `INST_SH)   ||
                ((inst&`INST_SW_MASK) == `INST_SW)   ||
                // zicbom
                ((inst&`INST_CBO_FLUSH_MASK) == `INST_CBO_FLUSH) ||
                ((inst&`INST_CBO_INVAL_MASK) == `INST_CBO_INVAL) || 
                ((inst&`INST_CBO_CLEAN_MASK) == `INST_CBO_CLEAN) || 
                ((inst&`INST_CBO_ZERO_MASK) == `INST_CBO_ZERO) ||
                // fence.i
                ((inst&`INST_IFENCE_MASK) == `INST_IFENCE);

wire is_npu_inst_w = ((inst&`INST_NPU_MASK) == `INST_NPU)             ;

wire fetch_invalid_w = ((inst&`INST_FENCE_MASK) == `INST_FENCE)   ||
                       ((inst&`INST_IFENCE_MASK) == `INST_IFENCE) ||
                       ((inst&`INST_SFENCE_MASK) == `INST_SFENCE) ;

wire is_npu_w = is_npu_inst_w;

wire [2:0] MUL_DIV_ctrl_w = {3{is_MUL_DIV_w}} & funct3;

assign is_impl_o = is_impl_w;
assign reg_wr_en_o = reg_wr_en_w;
assign mem_wr_en_o = mem_wr_en_w;
assign mem_rd_en_o = mem_rd_en_w;
assign mem_ctrl_o = mem_ctrl_r;
assign is_j_o = is_j_w;
assign is_br_o = is_br_w;
assign ALU_ctrl_o = alu_ctrl_r;
assign is_MUL_DIV_o = is_MUL_DIV_w;
assign MUL_DIV_ctrl_o = MUL_DIV_ctrl_w;
assign cmp_op_o = cmp_op_r;
assign is_csr_o = is_csr_w;
assign csr_addr_o = inst[31:20];
assign ALU_sel1_o = alu_sel1_w;
assign ALU_sel2_o = alu_sel2_w;
assign reg_w_sel_o = reg_w_sel_r;
assign is_npu_o = is_npu_w;
assign bypass_sel_o = bypass_sel_r;
assign fetch_invalid_o = fetch_invalid_w;


always @(*) begin
    alu_ctrl_r   = 4'b0000;
    mem_ctrl_r   = 4'b0000;
    cmp_op_r     = 3'b000;
    bypass_sel_r = 2'b00;
    // alu_ctrl
    if (is_alu_w | is_j_w | is_br_w) begin
        if      ((inst&`INST_ADD_MASK) == `INST_ADD)     alu_ctrl_r = `ALU_ADD;              // ADD
        else if ((inst&`INST_SUB_MASK) == `INST_SUB)     alu_ctrl_r = `ALU_SUB;              // SUB
        else if ((inst&`INST_AND_MASK) == `INST_AND)     alu_ctrl_r = `ALU_AND;              // AND
        else if ((inst&`INST_OR_MASK) == `INST_OR)       alu_ctrl_r = `ALU_OR;               // OR
        else if ((inst&`INST_XOR_MASK) == `INST_XOR)     alu_ctrl_r = `ALU_XOR;              // XOR
        else if ((inst&`INST_SLL_MASK) == `INST_SLL)     alu_ctrl_r = `ALU_SHIFTL;           // SLL
        else if ((inst&`INST_SRL_MASK) == `INST_SRL)     alu_ctrl_r = `ALU_SHIFTR;           // SRL
        else if ((inst&`INST_SRA_MASK) == `INST_SRA)     alu_ctrl_r = `ALU_SHIFTR_ARITH;     // SRA
        else if ((inst&`INST_SLT_MASK) == `INST_SLT)     alu_ctrl_r = `ALU_LESS_THAN_SIGNED; // SLT
        else if ((inst&`INST_SLTU_MASK) == `INST_SLTU)   alu_ctrl_r = `ALU_LESS_THAN;        // SLTU
        else if ((inst&`INST_SLTI_MASK) == `INST_SLTI)   alu_ctrl_r = `ALU_LESS_THAN_SIGNED; // SLTI
        else if ((inst&`INST_SLTIU_MASK) == `INST_SLTIU) alu_ctrl_r = `ALU_LESS_THAN;        // SLTIU
        else if ((inst&`INST_SLLI_MASK) == `INST_SLLI)   alu_ctrl_r = `ALU_SHIFTL;           // SLLI
        else if ((inst&`INST_SRLI_MASK) == `INST_SRLI)   alu_ctrl_r = `ALU_SHIFTR;           // SRLI
        else if ((inst&`INST_SRAI_MASK) == `INST_SRAI)   alu_ctrl_r = `ALU_SHIFTR_ARITH;     // SRAI
        else if ((inst&`INST_ANDI_MASK) == `INST_ANDI)   alu_ctrl_r = `ALU_AND;              // ANDI
        else if ((inst&`INST_ORI_MASK) == `INST_ORI)     alu_ctrl_r = `ALU_OR;               // ORI
        else if ((inst&`INST_XORI_MASK) == `INST_XORI)   alu_ctrl_r = `ALU_XOR;              // XORI
        else if ((inst&`INST_ADDI_MASK) == `INST_ADDI)   alu_ctrl_r = `ALU_ADD;              // ADDI
        else if ((inst&`INST_AUIPC_MASK) == `INST_AUIPC) alu_ctrl_r = `ALU_ADD;              // AUIPC
        else if ((inst&`INST_LUI_MASK) == `INST_LUI)     alu_ctrl_r = `ALU_NONE;             // NOP
        else if(is_j_w | is_br_w)                        alu_ctrl_r = `ALU_ADD;              // B+J
        else                                             alu_ctrl_r = `ALU_NONE;             // NOP
    end

    // mem_ctrl
    if (is_lsu_w) begin
        if      ((inst&`INST_LB_MASK) == `INST_LB)   mem_ctrl_r = 4'b1001; // LB
        else if ((inst&`INST_LBU_MASK) == `INST_LBU) mem_ctrl_r = 4'b0001; // LBU

        else if ((inst&`INST_LH_MASK) == `INST_LH)   mem_ctrl_r = 4'b1010; // LH
        else if ((inst&`INST_LHU_MASK) == `INST_LHU) mem_ctrl_r = 4'b0010; // LHU

        else if ((inst&`INST_LW_MASK) == `INST_LW)   mem_ctrl_r = 4'b0100; // LW
        
        else if ((inst&`INST_SB_MASK) == `INST_SB)   mem_ctrl_r = 4'b0001; // SB
        else if ((inst&`INST_SH_MASK) == `INST_SH)   mem_ctrl_r = 4'b0010; // SH
        else if ((inst&`INST_SW_MASK) == `INST_SW)   mem_ctrl_r = 4'b0100; // SW

        else if ((inst&`INST_FLW_MASK) == `INST_FLW) mem_ctrl_r = 4'b0100; // FLW
        else if ((inst&`INST_FSW_MASK) == `INST_FSW) mem_ctrl_r = 4'b1100; // FSW

        else if ((inst&`INST_CBO_FLUSH_MASK) == `INST_CBO_FLUSH) mem_ctrl_r = 4'b0011; // cbo.flush
        else if ((inst&`INST_CBO_INVAL_MASK) == `INST_CBO_INVAL) mem_ctrl_r = 4'b0111; // cbo.inval
        else if ((inst&`INST_CBO_CLEAN_MASK) == `INST_CBO_CLEAN) mem_ctrl_r = 4'b1011; // cbo.clean
        else if ((inst&`INST_CBO_ZERO_MASK) == `INST_CBO_ZERO)   mem_ctrl_r = 4'b1111; // cbo.zero
        else if ((inst&`INST_IFENCE_MASK) == `INST_IFENCE)       mem_ctrl_r = 4'b0110; // fence.i
        else mem_ctrl_r = 4'b0000;                                         // undefined
    end

    // cmp_op
    if (is_br_w) begin
        if      ((inst&`INST_BEQ_MASK) == `INST_BEQ)   cmp_op_r = 3'b000; // BEQ
        else if ((inst&`INST_BNE_MASK) == `INST_BNE)   cmp_op_r = 3'b001; // BNE
        else if ((inst&`INST_BLT_MASK) == `INST_BLT)   cmp_op_r = 3'b010; // BLT
        else if ((inst&`INST_BGE_MASK) == `INST_BGE)   cmp_op_r = 3'b011; // BGE
        else if ((inst&`INST_BLTU_MASK) == `INST_BLTU) cmp_op_r = 3'b100; // BLTU
        else if ((inst&`INST_BGEU_MASK) == `INST_BGEU) cmp_op_r = 3'b101; // BGEU
        else                                           cmp_op_r = 3'b111; // NONE
    end

    // bypass_sel
    if      ((inst&`INST_LUI_MASK) == `INST_LUI)         bypass_sel_r = 1;
    // impl as nop, but still need something to start
    else if ((inst&`INST_FENCE_MASK) == `INST_FENCE)     bypass_sel_r = 1;
    else                                                 bypass_sel_r = 0;

    // 0: pc_p4, 1: ALU, 2: mem, 3:csr, 4: FPU, 5: bypass
    // reg_w_sel
    if      (is_j_w)                                 reg_w_sel_r = 0;
    else if (|bypass_sel_r)                          reg_w_sel_r = 5; // bypass
    else if (is_npu_w)                               reg_w_sel_r = 7; // VPU higher priority
    else if (is_alu_w)                               reg_w_sel_r = 1; // ALUout
    else if (is_lsu_w)                               reg_w_sel_r = 2; // memory
    else if (is_csr_w)                               reg_w_sel_r = 3; // CSR read data path
    else if (is_MUL_DIV_w)                           reg_w_sel_r = 6; // MUL / DIV
    else                                             reg_w_sel_r = 0; // default PC+4
end

endmodule