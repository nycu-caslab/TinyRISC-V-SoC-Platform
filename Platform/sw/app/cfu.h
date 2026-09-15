#ifndef PLATFORM_SW_APP_CFU_H_
#define PLATFORM_SW_APP_CFU_H_

#include <stdint.h>

typedef uintptr_t CfuWord;

// Instruction fields used by the current example accelerator. Raw helpers
// below accept the same CUSTOM-0 funct3/funct7 fields that the hardware sees.
#define CFU_FUNCT3_COMPUTE 0
#define CFU_FUNCT3_AXI_READ 1
#define CFU_FUNCT3_AXI_WRITE 2

#define CFU_FUNCT7_AXI 0
#define CFU_FUNCT7_SCALAR_COMPUTE 5

enum CfuFunction {
  kCfuScalarCompute = 0,
  kCfuAxiRead = 1,
  kCfuAxiWrite = 2,
};

uint32_t software_cfu_raw(uint32_t funct3, uint32_t funct7, CfuWord rs1,
                          CfuWord rs2);

#define CFU_STRINGIFY_INNER(value) #value
#define CFU_STRINGIFY(value) CFU_STRINGIFY_INNER(value)

#if defined(__riscv)
#define cfu_raw_op_hw(funct3, funct7, rs1, rs2)                           \
  ({                                                                       \
    uint32_t cfu_result;                                                   \
    __asm__ volatile(".insn r 0x0B, " CFU_STRINGIFY(funct3) ", "          \
                     CFU_STRINGIFY(funct7) ", %0, %1, %2"                 \
                     : "=r"(cfu_result)                                   \
                     : "r"((CfuWord)(rs1)), "r"((CfuWord)(rs2))           \
                     : "memory");                                         \
    cfu_result;                                                            \
  })
#else
#define cfu_raw_op_hw(funct3, funct7, rs1, rs2) \
  software_cfu_raw((uint32_t)(funct3), (uint32_t)(funct7), (CfuWord)(rs1), \
                   (CfuWord)(rs2))
#endif

#define cfu_raw_op_sw(funct3, funct7, rs1, rs2) \
  software_cfu_raw((uint32_t)(funct3), (uint32_t)(funct7), (CfuWord)(rs1), \
                   (CfuWord)(rs2))

#ifdef CFU_SOFTWARE_DEFINED
#define cfu_raw_op(funct3, funct7, rs1, rs2) \
  cfu_raw_op_sw(funct3, funct7, rs1, rs2)
#else
#define cfu_raw_op(funct3, funct7, rs1, rs2) \
  cfu_raw_op_hw(funct3, funct7, rs1, rs2)
#endif

#define cfu_op0_hw(funct7, rs1, rs2) \
  cfu_raw_op_hw(CFU_FUNCT3_COMPUTE, funct7, rs1, rs2)
#define cfu_op1_hw(funct7, rs1, rs2) \
  cfu_raw_op_hw(CFU_FUNCT3_AXI_READ, funct7, rs1, rs2)
#define cfu_op2_hw(funct7, rs1, rs2) \
  cfu_raw_op_hw(CFU_FUNCT3_AXI_WRITE, funct7, rs1, rs2)
#define cfu_op3_hw(funct7, rs1, rs2) cfu_raw_op_hw(3, funct7, rs1, rs2)
#define cfu_op4_hw(funct7, rs1, rs2) cfu_raw_op_hw(4, funct7, rs1, rs2)
#define cfu_op5_hw(funct7, rs1, rs2) cfu_raw_op_hw(5, funct7, rs1, rs2)
#define cfu_op6_hw(funct7, rs1, rs2) cfu_raw_op_hw(6, funct7, rs1, rs2)
#define cfu_op7_hw(funct7, rs1, rs2) cfu_raw_op_hw(7, funct7, rs1, rs2)

#define cfu_op0_sw(funct7, rs1, rs2) \
  cfu_raw_op_sw(CFU_FUNCT3_COMPUTE, funct7, rs1, rs2)
#define cfu_op1_sw(funct7, rs1, rs2) \
  cfu_raw_op_sw(CFU_FUNCT3_AXI_READ, funct7, rs1, rs2)
#define cfu_op2_sw(funct7, rs1, rs2) \
  cfu_raw_op_sw(CFU_FUNCT3_AXI_WRITE, funct7, rs1, rs2)
#define cfu_op3_sw(funct7, rs1, rs2) cfu_raw_op_sw(3, funct7, rs1, rs2)
#define cfu_op4_sw(funct7, rs1, rs2) cfu_raw_op_sw(4, funct7, rs1, rs2)
#define cfu_op5_sw(funct7, rs1, rs2) cfu_raw_op_sw(5, funct7, rs1, rs2)
#define cfu_op6_sw(funct7, rs1, rs2) cfu_raw_op_sw(6, funct7, rs1, rs2)
#define cfu_op7_sw(funct7, rs1, rs2) cfu_raw_op_sw(7, funct7, rs1, rs2)

#define cfu_op0(funct7, rs1, rs2) \
  cfu_raw_op(CFU_FUNCT3_COMPUTE, funct7, rs1, rs2)
#define cfu_op1(funct7, rs1, rs2) \
  cfu_raw_op(CFU_FUNCT3_AXI_READ, funct7, rs1, rs2)
#define cfu_op2(funct7, rs1, rs2) \
  cfu_raw_op(CFU_FUNCT3_AXI_WRITE, funct7, rs1, rs2)
#define cfu_op3(funct7, rs1, rs2) cfu_raw_op(3, funct7, rs1, rs2)
#define cfu_op4(funct7, rs1, rs2) cfu_raw_op(4, funct7, rs1, rs2)
#define cfu_op5(funct7, rs1, rs2) cfu_raw_op(5, funct7, rs1, rs2)
#define cfu_op6(funct7, rs1, rs2) cfu_raw_op(6, funct7, rs1, rs2)
#define cfu_op7(funct7, rs1, rs2) cfu_raw_op(7, funct7, rs1, rs2)

uint32_t cfu_op(CfuWord rs1, CfuWord rs2, uint32_t func);
uint32_t cfu_op_hw(CfuWord rs1, CfuWord rs2, uint32_t func);

#endif  // PLATFORM_SW_APP_CFU_H_
