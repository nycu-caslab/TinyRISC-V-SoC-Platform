#include "software_cfu.h"

uint32_t software_cfu_raw(uint32_t funct3, uint32_t funct7, CfuWord rs1,
                          CfuWord rs2) {
  switch (funct3) {
    case CFU_FUNCT3_COMPUTE:
      return (uint32_t)rs1 + (uint32_t)rs2 + funct7;
    case CFU_FUNCT3_AXI_READ:
      if (funct7 != CFU_FUNCT7_AXI) {
        return 0;
      }
      return *reinterpret_cast<volatile uint32_t*>(rs1);
    case CFU_FUNCT3_AXI_WRITE:
      if (funct7 != CFU_FUNCT7_AXI) {
        return 0;
      }
      *reinterpret_cast<volatile uint32_t*>(rs1) = (uint32_t)rs2;
      return 0;
    default:
      return 0;
  }
}

uint32_t software_cfu(CfuWord rs1, CfuWord rs2, uint32_t func) {
  switch (func) {
    case kCfuScalarCompute:
      return software_cfu_raw(CFU_FUNCT3_COMPUTE, CFU_FUNCT7_SCALAR_COMPUTE,
                              rs1, rs2);
    case kCfuAxiRead:
      return software_cfu_raw(CFU_FUNCT3_AXI_READ, CFU_FUNCT7_AXI, rs1, rs2);
    case kCfuAxiWrite:
      return software_cfu_raw(CFU_FUNCT3_AXI_WRITE, CFU_FUNCT7_AXI, rs1, rs2);
    default:
      return 0;
  }
}
