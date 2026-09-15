module Decode (
    input clk,
    input rst_n,
    input en,
    input clear,

    input inst_valid_i,
	
    input [31:0] pc_i,
    input [31:0] pc_p4_i,
    input [31:0] inst_i,
   
    output pc_valid_o,
    output [31:0] pc_o,
    output [31:0] pc_p4_o,
    output [31:0] inst_o,
   
    output [4:0] rs1_o,
    output [4:0] rs2_o,
    output [4:0] rs3_o,
    output [4:0] rd_o,
    output [11:0] csr_addr_o,

    output reg [31:0] imm_o,

    // WB stage
    output reg_wr_en_o,
    output [2:0] reg_w_sel_o, // 0: pc_p4, 1: ALU, 2: mem, 3:csr, 4: FPU, 5: bypass, 6: MUL_DIV_top
    
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
	
    // NPU
    output is_npu_o,

    // Bypass
    output [1:0] bypass_sel_o,

    // Fence
    output fetch_invalid_o,

    output is_impl_o
);
wire        ID_pc_valid_out;
wire [31:0] ID_pc_out;
wire [31:0] ID_pc_p4_out;
wire [31:0] ID_inst_out;
wire [6:0] opcode = ID_inst_out[6:0];

// Immediate Generation
always @(*)begin
    case(opcode)
        7'b0010011, // I ADDI SLLI SLTI SLTIU XORI SRLI SRAI ORI ANDI
        7'b0000011, // I LB LH LW LBU LHU
        7'b0000111, // I FLW FLD
        7'b1100111: // JALR
            // {imm[31:20]}
            imm_o = {{20{ID_inst_out[31]}}, ID_inst_out[31:20]}; 
        7'b1110011: // CSR
            // {zero imm[24:20]}
            imm_o = {27'b0, ID_inst_out[19:15]}; 
        7'b0100011, // S SB SH SW
        7'b0100111: // S FSW FSD
            // {imm[11:5], imm[4:0]}
            imm_o = {{20{ID_inst_out[31]}}, ID_inst_out[31:25], ID_inst_out[11:7]};

        7'b1100011: // B BEQ BNE BLT BGE BLTU BGEU
            // {imm[12], imm[10:5], imm[4:1], 0}
            imm_o = {{19{ID_inst_out[31]}}, ID_inst_out[31], ID_inst_out[7], ID_inst_out[30:25], ID_inst_out[11:8], 1'b0};

        7'b1101111: // J JAL
            // {imm[20], imm[10:1], imm[11], imm[19:12], 0}
            imm_o = {{11{ID_inst_out[31]}}, ID_inst_out[31], ID_inst_out[19:12], ID_inst_out[20], ID_inst_out[30:21], 1'b0};

        7'b0110111, // U LUI
        7'b0010111: // U AUIPC
            // {imm[31:12]}
            imm_o={ID_inst_out[31:12], 12'b0};
        default:
            imm_o = 32'b0;
    endcase
end


// Decode ========================
wire        is_impl;
wire        reg_wr_en;
wire [2:0]  reg_w_sel;
wire        mem_wr_en;
wire        mem_rd_en;
wire [3:0]  mem_ctrl;
wire        is_j;
wire        is_br;
wire [2:0]  cmp_op;
wire        ALU_sel1;
wire        ALU_sel2;
wire [3:0]  ALU_ctrl;
wire        is_MUL_DIV;
wire [2:0]  MUL_DIV_ctrl;
wire        is_csr;
wire [11:0] csr_addr;
wire [1:0]  bypass_sel;
wire        fetch_invalid;

ID_Reg m_ID_Reg(
    .clk(clk),
    .rst_n(rst_n),

    .en(en),
    .clear(clear),

    .pc_valid_i(inst_valid_i),
    .pc_p4_i(pc_p4_i),
    .inst_i(inst_i),
    .pc_i(pc_i),

    .pc_valid_o(ID_pc_valid_out),
    .pc_o(ID_pc_out),
    .pc_p4_o(ID_pc_p4_out),
    .inst_o(ID_inst_out)
);


Control m_Control(
    .inst(ID_inst_out),
    .is_impl_o(is_impl),
    
    .reg_wr_en_o(reg_wr_en),
    .reg_w_sel_o(reg_w_sel),
    
    .mem_wr_en_o(mem_wr_en),
    .mem_rd_en_o(mem_rd_en),
    .mem_ctrl_o(mem_ctrl),
    
    .is_j_o(is_j),
    .is_br_o(is_br),
    .cmp_op_o(cmp_op),
    
    .ALU_sel1_o(ALU_sel1),
    .ALU_sel2_o(ALU_sel2),
    .ALU_ctrl_o(ALU_ctrl),

    .is_MUL_DIV_o(is_MUL_DIV),
    .MUL_DIV_ctrl_o(MUL_DIV_ctrl),
    
    .is_csr_o(is_csr),
    .csr_addr_o(csr_addr),

    .is_npu_o(is_npu_o),

    .bypass_sel_o(bypass_sel),

    .fetch_invalid_o(fetch_invalid)
);
assign is_impl_o = is_impl;
assign reg_wr_en_o = reg_wr_en;
assign reg_w_sel_o = reg_w_sel;
assign mem_wr_en_o = mem_wr_en;
assign mem_rd_en_o = mem_rd_en;
assign mem_ctrl_o = mem_ctrl;
assign is_j_o = is_j;
assign is_br_o = is_br;
assign cmp_op_o = cmp_op;
assign ALU_sel1_o = ALU_sel1;
assign ALU_sel2_o = ALU_sel2;
assign ALU_ctrl_o = ALU_ctrl;
assign is_MUL_DIV_o = is_MUL_DIV;
assign MUL_DIV_ctrl_o = MUL_DIV_ctrl;
assign is_csr_o = is_csr;
assign csr_addr_o = csr_addr;
assign bypass_sel_o = bypass_sel;
assign fetch_invalid_o = fetch_invalid;
assign pc_valid_o = ID_pc_valid_out;
assign pc_o = ID_pc_out;
assign pc_p4_o = ID_pc_p4_out;
assign inst_o = ID_inst_out;
assign rs1_o = ID_inst_out[19:15];
assign rs2_o = ID_inst_out[24:20];
assign rs3_o = ID_inst_out[31:27];
assign rd_o  = ID_inst_out[11:07];

endmodule