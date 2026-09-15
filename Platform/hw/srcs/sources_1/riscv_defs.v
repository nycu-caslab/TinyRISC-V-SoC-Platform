//-----------------------------------------------------------------
//                         RISC-V Core
//                            V1.0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------
//
// Copyright (c) 2014-2019, Ultra-Embedded.com
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions 
// are met:
//   - Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer 
//     in the documentation and/or other materials provided with the 
//     distribution.
//   - Neither the name of the author nor the names of its contributors 
//     may be used to endorse or promote products derived from this 
//     software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE 
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
// SUCH DAMAGE.
//-----------------------------------------------------------------

`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH
`endif // RISCV_DEFS_VH

//--------------------------------------------------------------------
// ALU Operations
//--------------------------------------------------------------------
`define ALU_NONE                                4'b0000
`define ALU_SHIFTL                              4'b0001
`define ALU_SHIFTR                              4'b0010
`define ALU_SHIFTR_ARITH                        4'b0011
`define ALU_ADD                                 4'b0100
`define ALU_SUB                                 4'b0110
`define ALU_AND                                 4'b0111
`define ALU_OR                                  4'b1000
`define ALU_XOR                                 4'b1001
`define ALU_LESS_THAN                           4'b1010
`define ALU_LESS_THAN_SIGNED                    4'b1011
`define ALU_MAX                                 4'b1100
`define ALU_MAX_SIGNED                          4'b1101

//--------------------------------------------------------------------
// Instructions Masks
//--------------------------------------------------------------------
// andi
`define INST_ANDI 32'h7013
`define INST_ANDI_MASK 32'h707f

// addi
`define INST_ADDI 32'h13
`define INST_ADDI_MASK 32'h707f

// slti
`define INST_SLTI 32'h2013
`define INST_SLTI_MASK 32'h707f

// sltiu
`define INST_SLTIU 32'h3013
`define INST_SLTIU_MASK 32'h707f

// ori
`define INST_ORI 32'h6013
`define INST_ORI_MASK 32'h707f

// xori
`define INST_XORI 32'h4013
`define INST_XORI_MASK 32'h707f

// slli
`define INST_SLLI 32'h1013
`define INST_SLLI_MASK 32'hfc00707f

// srli
`define INST_SRLI 32'h5013
`define INST_SRLI_MASK 32'hfc00707f

// srai
`define INST_SRAI 32'h40005013
`define INST_SRAI_MASK 32'hfc00707f

// lui
`define INST_LUI 32'h37
`define INST_LUI_MASK 32'h7f

// auipc
`define INST_AUIPC 32'h17
`define INST_AUIPC_MASK 32'h7f

// add
`define INST_ADD 32'h33
`define INST_ADD_MASK 32'hfe00707f

// sub
`define INST_SUB 32'h40000033
`define INST_SUB_MASK 32'hfe00707f

// slt
`define INST_SLT 32'h2033
`define INST_SLT_MASK 32'hfe00707f

// sltu
`define INST_SLTU 32'h3033
`define INST_SLTU_MASK 32'hfe00707f

// xor
`define INST_XOR 32'h4033
`define INST_XOR_MASK 32'hfe00707f

// or
`define INST_OR 32'h6033
`define INST_OR_MASK 32'hfe00707f

// and
`define INST_AND 32'h7033
`define INST_AND_MASK 32'hfe00707f

// sll
`define INST_SLL 32'h1033
`define INST_SLL_MASK 32'hfe00707f

// srl
`define INST_SRL 32'h5033
`define INST_SRL_MASK 32'hfe00707f

// sra
`define INST_SRA 32'h40005033
`define INST_SRA_MASK 32'hfe00707f

// jal
`define INST_JAL 32'h6f
`define INST_JAL_MASK 32'h7f

// jalr
`define INST_JALR 32'h67
`define INST_JALR_MASK 32'h707f

// beq
`define INST_BEQ 32'h63
`define INST_BEQ_MASK 32'h707f

// bne
`define INST_BNE 32'h1063
`define INST_BNE_MASK 32'h707f

// blt
`define INST_BLT 32'h4063
`define INST_BLT_MASK 32'h707f

// bge
`define INST_BGE 32'h5063
`define INST_BGE_MASK 32'h707f

// bltu
`define INST_BLTU 32'h6063
`define INST_BLTU_MASK 32'h707f

// bgeu
`define INST_BGEU 32'h7063
`define INST_BGEU_MASK 32'h707f

// lb
`define INST_LB 32'h3
`define INST_LB_MASK 32'h707f

// lh
`define INST_LH 32'h1003
`define INST_LH_MASK 32'h707f

// lw
`define INST_LW 32'h2003
`define INST_LW_MASK 32'h707f

// lbu
`define INST_LBU 32'h4003
`define INST_LBU_MASK 32'h707f

// lhu
`define INST_LHU 32'h5003
`define INST_LHU_MASK 32'h707f

// lwu
`define INST_LWU 32'h6003
`define INST_LWU_MASK 32'h707f

// sb
`define INST_SB 32'h23
`define INST_SB_MASK 32'h707f

// sh
`define INST_SH 32'h1023
`define INST_SH_MASK 32'h707f

// sw
`define INST_SW 32'h2023
`define INST_SW_MASK 32'h707f

// ecall
`define INST_ECALL 32'h73
`define INST_ECALL_MASK 32'hffffffff

// ebreak
`define INST_EBREAK 32'h100073
`define INST_EBREAK_MASK 32'hffffffff

// eret
`define INST_ERET 32'h200073
`define INST_ERET_MASK 32'hcfffffff

// csrrw
`define INST_CSRRW 32'h1073
`define INST_CSRRW_MASK 32'h707f

// csrrs
`define INST_CSRRS 32'h2073
`define INST_CSRRS_MASK 32'h707f

// csrrc
`define INST_CSRRC 32'h3073
`define INST_CSRRC_MASK 32'h707f

// csrrwi
`define INST_CSRRWI 32'h5073
`define INST_CSRRWI_MASK 32'h707f

// csrrsi
`define INST_CSRRSI 32'h6073
`define INST_CSRRSI_MASK 32'h707f

// csrrci
`define INST_CSRRCI 32'h7073
`define INST_CSRRCI_MASK 32'h707f

// mul
`define INST_MUL 32'h2000033
`define INST_MUL_MASK 32'hfe00707f

// mulh
`define INST_MULH 32'h2001033
`define INST_MULH_MASK 32'hfe00707f

// mulhsu
`define INST_MULHSU 32'h2002033
`define INST_MULHSU_MASK 32'hfe00707f

// mulhu
`define INST_MULHU 32'h2003033
`define INST_MULHU_MASK 32'hfe00707f

// div
`define INST_DIV 32'h2004033
`define INST_DIV_MASK 32'hfe00707f

// divu
`define INST_DIVU 32'h2005033
`define INST_DIVU_MASK 32'hfe00707f

// rem
`define INST_REM 32'h2006033
`define INST_REM_MASK 32'hfe00707f

// remu
`define INST_REMU 32'h2007033
`define INST_REMU_MASK 32'hfe00707f

// wfi
`define INST_WFI 32'h10500073
`define INST_WFI_MASK 32'hffff8fff

// fence
`define INST_FENCE 32'hf
`define INST_FENCE_MASK 32'h707f

// sfence
`define INST_SFENCE 32'h12000073
`define INST_SFENCE_MASK 32'hfe007fff

// fence.i
`define INST_IFENCE 32'h100f
`define INST_IFENCE_MASK 32'h707f

//--------------------------------------------------------------------
// FPU Instruction
//--------------------------------------------------------------------
// F Extension
// fmadd.s
`define INST_FMADD          32'b00000_00_00000_00000_000_00000_1000011 // R4 fs3 funtc2 fs2 fs1 funtc3 fd op
`define INST_FMADD_MASK     32'b00000_00_00000_00000_000_00000_1111111

// fmsub.s
`define INST_FMSUB          32'b00000_00_00000_00000_000_00000_1000111 // R4 fs3 funtc2 fs2 fs1 funtc3 fd op
`define INST_FMSUB_MASK     32'b00000_00_00000_00000_000_00000_1111111

// fnmsub.s
`define INST_FNMSUB         32'b00000_00_00000_00000_000_00000_1001011 // R4 fs3 funtc2 fs2 fs1 funtc3 fd op
`define INST_FNMSUB_MASK    32'b00000_00_00000_00000_000_00000_1111111

// fnmadd.s
`define INST_FNMADD         32'b00000_00_00000_00000_000_00000_1001111 // R4 fs3 funtc2 fs2 fs1 funtc3 fd op
`define INST_FNMADD_MASK    32'b00000_00_00000_00000_000_00000_1111111

// fadd.s
`define INST_FADD           32'b0000000_00000_00000_000_00000_1010011
`define INST_FADD_MASK      32'b1111111_00000_00000_000_00000_1111111

// fsub.s
`define INST_FSUB           32'b0000100_00000_00000_000_00000_1010011
`define INST_FSUB_MASK      32'b1111111_00000_00000_000_00000_1111111

// fmul.s
`define INST_FMUL           32'b0001000_00000_00000_000_00000_1010011
`define INST_FMUL_MASK      32'b1111111_00000_00000_000_00000_1111111

// fdiv.s
`define INST_FDIV           32'b0001100_00000_00000_000_00000_1010011
`define INST_FDIV_MASK      32'b1111111_00000_00000_000_00000_1111111

// fsqrt.s
`define INST_FSQRT          32'b0101100_00000_00000_000_00000_1010011
`define INST_FSQRT_MASK     32'b1111111_00000_00000_000_00000_1111111

// fsgnj.s
`define INST_FSGNJ          32'b0010000_00000_00000_000_00000_1010011
`define INST_FSGNJ_MASK     32'b1111111_00000_00000_111_00000_1111111

// fsgnjn.s
`define INST_FSGNJN         32'b0010000_00000_00000_001_00000_1010011
`define INST_FSGNJN_MASK    32'b1111111_00000_00000_111_00000_1111111

// fsgnjx.s
`define INST_FSGNJX         32'b0010000_00000_00000_010_00000_1010011
`define INST_FSGNJX_MASK    32'b1111111_00000_00000_111_00000_1111111

// fmin.s
`define INST_FMIN           32'b0010100_00000_00000_000_00000_1010011
`define INST_FMIN_MASK      32'b1111111_00000_00000_111_00000_1111111

// fmax.s
`define INST_FMAX           32'b0010100_00000_00000_001_00000_1010011
`define INST_FMAX_MASK      32'b1111111_00000_00000_111_00000_1111111

// feq.s
`define INST_FEQ            32'b1010000_00000_00000_010_00000_1010011
`define INST_FEQ_MASK       32'b1111111_00000_00000_111_00000_1111111

// flt.s
`define INST_FLT            32'b1010000_00000_00000_001_00000_1010011
`define INST_FLT_MASK       32'b1111111_00000_00000_111_00000_1111111

// fle.s
`define INST_FLE            32'b1010000_00000_00000_000_00000_1010011
`define INST_FLE_MASK       32'b1111111_00000_00000_111_00000_1111111

// fclass.s
`define INST_FCLASS         32'b1110000_00000_00000_001_00000_1010011
`define INST_FCLASS_MASK    32'b1111111_11111_00000_111_00000_1111111

// flw
`define INST_FLW            32'b0000000_00000_00000_010_00000_0000111
`define INST_FLW_MASK       32'b0000000_00000_00000_111_00000_1111111

// fsw
`define INST_FSW            32'b0000000_00000_00000_010_00000_0100111
`define INST_FSW_MASK       32'b0000000_00000_00000_111_00000_1111111

// fcvt.w.s
`define INST_FCVT_W_S       32'b1100000_00000_00000_000_00000_1010011
`define INST_FCVT_W_S_MASK  32'b1111111_11111_00000_000_00000_1111111

// fcvt.wu.s
`define INST_FCVT_WU_S      32'b1100000_00001_00000_000_00000_1010011
`define INST_FCVT_WU_S_MASK 32'b1111111_11111_00000_000_00000_1111111

// fcvt.s.w
`define INST_FCVT_S_W       32'b1101000_00000_00000_000_00000_1010011
`define INST_FCVT_S_W_MASK  32'b1111111_11111_00000_000_00000_1111111

// fcvt.s.wu
`define INST_FCVT_S_WU      32'b1101000_00001_00000_000_00000_1010011
`define INST_FCVT_S_WU_MASK 32'b1111111_11111_00000_000_00000_1111111

// fmv.x.w
`define INST_FMV_X_W        32'b1110000_00000_00000_000_00000_1010011
`define INST_FMV_X_W_MASK   32'b1111111_11111_00000_111_00000_1111111

// fmv.w.x
`define INST_FMV_W_X        32'b1111000_00000_00000_000_00000_1010011
`define INST_FMV_W_X_MASK   32'b1111111_11111_00000_111_00000_1111111

// D Extension
// fld
`define INST_FLD            32'b0000000_00000_00000_011_00000_0000111
`define INST_FLD_MASK       32'b0000000_00000_00000_111_00000_1111111

// fsd
`define INST_FSD            32'b0000000_00000_00000_011_00000_0100111
`define INST_FSD_MASK       32'b0000000_00000_00000_111_00000_1111111

// fcvt.w.d
`define INST_FCVT_W_D       32'b1100001_00000_00000_000_00000_1010011
`define INST_FCVT_W_D_MASK  32'b1111111_11111_00000_000_00000_1111111

// fcvt.wu.d
`define INST_FCVT_WU_D      32'b1100001_00001_00000_000_00000_1010011
`define INST_FCVT_WU_D_MASK 32'b1111111_11111_00000_000_00000_1111111

// fcvt.d.w
`define INST_FCVT_D_W       32'b1101001_00000_00000_000_00000_1010011
`define INST_FCVT_D_W_MASK  32'b1111111_11111_00000_000_00000_1111111

// fcvt.d.wu
`define INST_FCVT_D_WU      32'b1101001_00001_00000_000_00000_1010011
`define INST_FCVT_D_WU_MASK 32'b1111111_11111_00000_000_00000_1111111

// fcvt.s.d
`define INST_FCVT_S_D       32'b0100000_00001_00000_000_00000_1010011
`define INST_FCVT_S_D_MASK  32'b1111111_11111_00000_000_00000_1111111

// fcvt.d.s
`define INST_FCVT_D_S       32'b0100001_00000_00000_000_00000_1010011
`define INST_FCVT_D_S_MASK  32'b1111111_11111_00000_000_00000_1111111

// cbo.flush
`define INST_CBO_FLUSH      32'b000000000010_00000_010_00000_0001111
`define INST_CBO_FLUSH_MASK 32'b111111111111_00000_111_00000_1111111

// cbo.inval
`define INST_CBO_INVAL      32'b000000000000_00000_010_00000_0001111
`define INST_CBO_INVAL_MASK 32'b111111111111_00000_111_00000_1111111

// cbo.clean
`define INST_CBO_CLEAN      32'b000000000001_00000_010_00000_0001111
`define INST_CBO_CLEAN_MASK 32'b111111111111_00000_111_00000_1111111

// cbo.zero
`define INST_CBO_ZERO       32'b000000000100_00000_010_00000_0001111
`define INST_CBO_ZERO_MASK  32'b111111111111_00000_111_00000_1111111

//--------------------------------------------------------------------
// NPU Instruction
//--------------------------------------------------------------------
`define INST_NPU       32'b0000000_00000_00000_000_00000_0001011
`define INST_NPU_MASK  32'h0000007f

//--------------------------------------------------------------------
// Machine Level Instruction
//--------------------------------------------------------------------
`define INST_MRET       32'h30200073
`define INST_MRET_MASK  32'hffffffff

//--------------------------------------------------------------------
// Privilege levels
//--------------------------------------------------------------------
`define PRIV_USER         2'd0
`define PRIV_SUPER        2'd1
`define PRIV_MACHINE      2'd3

//--------------------------------------------------------------------
// IRQ Numbers
//--------------------------------------------------------------------
`define IRQ_S_SOFT   1
`define IRQ_M_SOFT   3
`define IRQ_S_TIMER  5
`define IRQ_M_TIMER  7
`define IRQ_S_EXT    9
`define IRQ_M_EXT    11
`define IRQ_MIN      (`IRQ_S_SOFT)
`define IRQ_MAX      (`IRQ_M_EXT + 1)
`define IRQ_MASK     ((1 << `IRQ_M_EXT)   | (1 << `IRQ_S_EXT)   |                       (1 << `IRQ_M_TIMER) | (1 << `IRQ_S_TIMER) |                       (1 << `IRQ_M_SOFT)  | (1 << `IRQ_S_SOFT))

`define SR_IP_MSIP_R      `IRQ_M_SOFT
`define SR_IP_MTIP_R      `IRQ_M_TIMER
`define SR_IP_MEIP_R      `IRQ_M_EXT
`define SR_IP_SSIP_R      `IRQ_S_SOFT
`define SR_IP_STIP_R      `IRQ_S_TIMER
`define SR_IP_SEIP_R      `IRQ_S_EXT

//--------------------------------------------------------------------
// CSR Registers - Simulation control
//--------------------------------------------------------------------
`define CSR_DSCRATCH       12'h7b2
`define CSR_SIM_CTRL       12'h8b2
`define CSR_SIM_CTRL_MASK  32'hFFFFFFFF
    `define CSR_SIM_CTRL_EXIT (0 << 24)
    `define CSR_SIM_CTRL_PUTC (1 << 24)

//--------------------------------------------------------------------
// CSR Registers
//--------------------------------------------------------------------
`define CSR_MSTATUS       12'h300
`define CSR_MSTATUS_MASK  32'hFFFFFFFF
`define CSR_MISA          12'h301
`define CSR_MISA_MASK     32'hFFFFFFFF
    `define MISA_RV32     32'h40000000
    `define MISA_RVI      32'h00000100
    `define MISA_RVE      32'h00000010
    `define MISA_RVM      32'h00001000
    `define MISA_RVA      32'h00000001
    `define MISA_RVF      32'h00000020
    `define MISA_RVD      32'h00000008
    `define MISA_RVC      32'h00000004
    `define MISA_RVS      32'h00040000
    `define MISA_RVU      32'h00100000
`define CSR_MEDELEG       12'h302
`define CSR_MEDELEG_MASK  32'h0000FFFF
`define CSR_MIDELEG       12'h303
`define CSR_MIDELEG_MASK  32'h0000FFFF
`define CSR_MIE           12'h304
`define CSR_MIE_MASK      `IRQ_MASK
`define CSR_MTVEC         12'h305
`define CSR_MTVEC_MASK    32'hFFFFFFFC // alway direct mode
`define CSR_MSCRATCH      12'h340
`define CSR_MSCRATCH_MASK 32'hFFFFFFFF
`define CSR_MEPC          12'h341
`define CSR_MEPC_MASK     32'hFFFFFFFF
`define CSR_MCAUSE        12'h342
`define CSR_MCAUSE_MASK   32'h8000000F
`define CSR_MTVAL         12'h343
`define CSR_MTVAL_MASK    32'hFFFFFFFF
`define CSR_MIP           12'h344
`define CSR_MIP_MASK      `IRQ_MASK
`define CSR_MCYCLE        12'hb00
`define CSR_MCYCLE_MASK   32'hFFFFFFFF
`define CSR_MCYCLEH       12'hb80
`define CSR_MCYCLEH_MASK  32'hFFFFFFFF
`define CSR_MTIME         12'hb01
`define CSR_MTIME_MASK    32'hFFFFFFFF
`define CSR_MTIMEH        12'hc81
`define CSR_MTIMEH_MASK   32'hFFFFFFFF
`define CSR_MHARTID       12'hF14
`define CSR_MHARTID_MASK  32'hFFFFFFFF
`define CSR_PMPCFG        12'h3a?
`define CSR_PMPCFG_MASK   32'h9F9F9F9F
`define CSR_PMPADDR       12'h3b?, 12'h3c?, 12'h3d?, 12'h3e?

// Non-std
`define CSR_MTIMECMP        12'h7c0
`define CSR_MTIMECMP_MASK   32'hFFFFFFFF

//-----------------------------------------------------------------
// CSR Registers - Supervisor
//-----------------------------------------------------------------
`define CSR_SSTATUS       12'h100
`define CSR_SSTATUS_MASK  `SR_SMODE_MASK
`define CSR_SIE           12'h104
`define CSR_SIE_MASK      ((1 << `IRQ_S_EXT) | (1 << `IRQ_S_TIMER) | (1 << `IRQ_S_SOFT))
`define CSR_STVEC         12'h105
`define CSR_STVEC_MASK    32'hFFFFFFFF
`define CSR_SSCRATCH      12'h140
`define CSR_SSCRATCH_MASK 32'hFFFFFFFF
`define CSR_SEPC          12'h141
`define CSR_SEPC_MASK     32'hFFFFFFFF
`define CSR_SCAUSE        12'h142
`define CSR_SCAUSE_MASK   32'h8000000F
`define CSR_STVAL         12'h143
`define CSR_STVAL_MASK    32'hFFFFFFFF
`define CSR_SIP           12'h144
`define CSR_SIP_MASK      ((1 << `IRQ_S_EXT) | (1 << `IRQ_S_TIMER) | (1 << `IRQ_S_SOFT))
`define CSR_SATP          12'h180
`define CSR_SATP_MASK     32'hFFFFFFFF

//-----------------------------------------------------------------
// CSR Registers - User
//-----------------------------------------------------------------
`define CSR_FFLAGS        12'h001
`define CSR_FFLAGS_MASK   32'b11111
`define CSR_FRM           12'h002
`define CSR_FRM_MASK      32'b111
`define CSR_FCSR          12'h003
`define CSR_FCSR_MASK     32'hFF

`define VCSR_VSTART         12'h008
`define VCSR_VSTART_MASK    32'hFFFFFFFF
`define VCSR_VXSAT          12'h009
`define VCSR_VXSAT_MASK     32'h00000001
`define VCSR_VXRM           12'h00A
`define VCSR_VXRM_MASK      32'h00000003
`define VCSR_VCSR           12'h00F
`define VCSR_VCSR_MASK      32'h00000007
`define VCSR_VL             12'hC20
`define VCSR_VL_MASK        32'hFFFFFFFF
`define VCSR_VTYPE          12'hC21
`define VCSR_VTYPE_MASK     32'h800000FF
`define VCSR_VLENB          12'hC22
`define VCSR_VLENB_MASK     32'hFFFFFFFF

//--------------------------------------------------------------------
// CSR Registers - DCACHE control
//--------------------------------------------------------------------
`define CSR_DFLUSH            12'h3a0 // pmpcfg0
`define CSR_DFLUSH_MASK       32'hFFFFFFFF
`define CSR_DWRITEBACK        12'h3a1 // pmpcfg1
`define CSR_DWRITEBACK_MASK   32'hFFFFFFFF
`define CSR_DINVALIDATE       12'h3a2 // pmpcfg2
`define CSR_DINVALIDATE_MASK  32'hFFFFFFFF

//--------------------------------------------------------------------
// Status Register
//--------------------------------------------------------------------
`define SR_UIE         (1 << 0)
`define SR_UIE_R       0
`define SR_SIE         (1 << 1)
`define SR_SIE_R       1
`define SR_MIE         (1 << 3)
`define SR_MIE_R       3
`define SR_UPIE        (1 << 4)
`define SR_UPIE_R      4
`define SR_SPIE        (1 << 5)
`define SR_SPIE_R      5
`define SR_MPIE        (1 << 7)
`define SR_MPIE_R      7
`define SR_SPP         (1 << 8)
`define SR_SPP_R       8
`define SR_SD_R        31
`define SR_SD          (1 << 31)

`define SR_MPP_SHIFT   11
`define SR_MPP_MASK    2'h3
`define SR_MPP_R       12:11
`define SR_MPP_U       `PRIV_USER
`define SR_MPP_S       `PRIV_SUPER
`define SR_MPP_M       `PRIV_MACHINE

`define SR_SUM_R        18
`define SR_SUM          (1 << `SR_SUM_R)

`define SR_MPRV_R       17
`define SR_MPRV         (1 << `SR_MPRV_R)

`define SR_MXR_R        19
`define SR_MXR          (1 << `SR_MXR_R)

`define SR_FS_R         14:13
`define SR_XS_R         16:15

`define SR_XS_OFF      0
`define SR_XS_INIT     1
`define SR_XS_CLEAN    2
`define SR_XS_DIRTY    3

`define SR_FS_OFF      `SR_XS_OFF
`define SR_FS_INIT     `SR_XS_INIT
`define SR_FS_CLEAN    `SR_XS_CLEAN
`define SR_FS_DIRTY    `SR_XS_DIRTY

`define SR_SMODE_MASK   (`SR_UIE | `SR_SIE | `SR_UPIE | `SR_SPIE | `SR_SPP | `SR_SUM)


//--------------------------------------------------------------------
// SATP definitions
//--------------------------------------------------------------------
`define SATP_PPN_R        19:0 // TODO: Should be 21??
`define SATP_ASID_R       30:22
`define SATP_MODE_R       31

//--------------------------------------------------------------------
// MMU Defs (SV32)
//--------------------------------------------------------------------
`define MMU_LEVELS        2
`define MMU_PTIDXBITS     10
`define MMU_PTESIZE       4
`define MMU_PGSHIFT       (`MMU_PTIDXBITS + 2)
`define MMU_PGSIZE        (1 << `MMU_PGSHIFT)
`define MMU_VPN_BITS      (`MMU_PTIDXBITS * `MMU_LEVELS)
`define MMU_PPN_BITS      (32 - `MMU_PGSHIFT)
`define MMU_VA_BITS       (`MMU_VPN_BITS + `MMU_PGSHIFT)

`define PAGE_PRESENT      0
`define PAGE_READ         1
`define PAGE_WRITE        2
`define PAGE_EXEC         3
`define PAGE_USER         4
`define PAGE_GLOBAL       5
`define PAGE_ACCESSED     6
`define PAGE_DIRTY        7
`define PAGE_SOFT         9:8

`define PAGE_FLAGS       10'h3FF

`define PAGE_PFN_SHIFT   10
`define PAGE_SIZE        4096

//--------------------------------------------------------------------
// Exception Causes
//--------------------------------------------------------------------
`define EXCEPTION_W                        6
`define EXCEPTION_MISALIGNED_FETCH         6'h10
`define EXCEPTION_FAULT_FETCH              6'h11
`define EXCEPTION_ILLEGAL_INSTRUCTION      6'h12
`define EXCEPTION_BREAKPOINT               6'h13
`define EXCEPTION_MISALIGNED_LOAD          6'h14
`define EXCEPTION_FAULT_LOAD               6'h15
`define EXCEPTION_MISALIGNED_STORE         6'h16
`define EXCEPTION_FAULT_STORE              6'h17
`define EXCEPTION_ECALL                    6'h18
`define EXCEPTION_ECALL_U                  6'h18
`define EXCEPTION_ECALL_S                  6'h19
`define EXCEPTION_ECALL_H                  6'h1a
`define EXCEPTION_ECALL_M                  6'h1b
`define EXCEPTION_PAGE_FAULT_INST          6'h1c
`define EXCEPTION_PAGE_FAULT_LOAD          6'h1d
`define EXCEPTION_PAGE_FAULT_STORE         6'h1f
`define EXCEPTION_EXCEPTION                6'h10
`define EXCEPTION_INTERRUPT                6'h20
`define EXCEPTION_ERET_U                   6'h30
`define EXCEPTION_ERET_S                   6'h31
`define EXCEPTION_ERET_H                   6'h32
`define EXCEPTION_ERET_M                   6'h33
`define EXCEPTION_FENCE                    6'h34
`define EXCEPTION_FPU                      6'h35
`define EXCEPTION_CONFIG                   6'h36
`define EXCEPTION_TYPE_MASK                6'h30
`define EXCEPTION_SUBTYPE_R                3:0

`define MCAUSE_INT                      31
`define MCAUSE_MISALIGNED_FETCH         ((0 << `MCAUSE_INT) | 0)
`define MCAUSE_FAULT_FETCH              ((0 << `MCAUSE_INT) | 1)
`define MCAUSE_ILLEGAL_INSTRUCTION      ((0 << `MCAUSE_INT) | 2)
`define MCAUSE_BREAKPOINT               ((0 << `MCAUSE_INT) | 3)
`define MCAUSE_MISALIGNED_LOAD          ((0 << `MCAUSE_INT) | 4)
`define MCAUSE_FAULT_LOAD               ((0 << `MCAUSE_INT) | 5)
`define MCAUSE_MISALIGNED_STORE         ((0 << `MCAUSE_INT) | 6)
`define MCAUSE_FAULT_STORE              ((0 << `MCAUSE_INT) | 7)
`define MCAUSE_ECALL_U                  ((0 << `MCAUSE_INT) | 8)
`define MCAUSE_ECALL_S                  ((0 << `MCAUSE_INT) | 9)
`define MCAUSE_ECALL_H                  ((0 << `MCAUSE_INT) | 10)
`define MCAUSE_ECALL_M                  ((0 << `MCAUSE_INT) | 11)
`define MCAUSE_PAGE_FAULT_INST          ((0 << `MCAUSE_INT) | 12)
`define MCAUSE_PAGE_FAULT_LOAD          ((0 << `MCAUSE_INT) | 13)
`define MCAUSE_PAGE_FAULT_STORE         ((0 << `MCAUSE_INT) | 15)
`define MCAUSE_INTERRUPT                (1 << `MCAUSE_INT)

//--------------------------------------------------------------------
// Debug
//--------------------------------------------------------------------
`define RISCV_REGNO_FIRST   13'd0
`define RISCV_REGNO_GPR0    13'd0
`define RISCV_REGNO_GPR31   13'd31
`define RISCV_REGNO_PC      13'd32
`define RISCV_REGNO_CSR0    13'd65
`define RISCV_REGNO_CSR4095 (`RISCV_REGNO_CSR0 +  13'd4095)
`define RISCV_REGNO_PRIV    13'd4161
