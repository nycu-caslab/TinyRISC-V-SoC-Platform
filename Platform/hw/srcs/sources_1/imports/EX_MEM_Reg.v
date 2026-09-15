//-----------------------------------------------------------------
// EX/MEM pipeline register
//
// A plain stage register in the same style as ID_Reg.v and WB_Reg.v: en holds,
// clear inserts a bubble, and every instruction flows through it -- mem ops
// included, address/mask/store-data and all. This is the single EX/MEM
// boundary register: MEM.v owns no request register of its own any more, it
// just reads this register's held output.
//
// For a non-mem instruction, en/clear behave exactly as in a plain flow-
// through pipeline register: captures every cycle EX hands off a real result,
// bubbles otherwise.
//
// For a mem instruction, Backend_top.v/PipelineCtrl.v additionally freeze en
// (mem_busy_reg_i) for as long as the access is still in flight, so this
// register HOLDS the mem op's address/mask/store-data/rd/pc/is_impl steady
// across the whole multi-cycle access -- matching how a textbook 5-stage
// pipeline's EX/MEM register freezes during a MEM-stage stall, instead of
// being overwritten by a bubble the very next cycle. reg_wr_en_i/result_i are
// still forced to 0 by Backend_top.v for a mem op (the ALU-side result path
// has nothing valid for a load/store) -- holding a steady "no write" is
// harmless, unlike holding a steady real write would be, which is why this
// register can safely freeze without a double-commit risk at WB.
//-----------------------------------------------------------------

module EX_MEM_Reg (
     input         clk
    ,input         rst_n
    ,input         en
    ,input         clear

    ,input         pc_valid_i
    ,input         is_impl_i
    ,input  [31:0] pc_p4_i
    ,input  [ 4:0] rd_i
    ,input         reg_wr_en_i
    ,input  [31:0] result_i

    // mem request payload -- held steady across the whole in-flight access
    ,input         mem_rd_en_i
    ,input         mem_wr_en_i
    ,input  [ 3:0] mem_ctrl_i
    ,input  [31:0] mem_addr_i
    ,input  [ 3:0] mem_mask_i
    ,input  [31:0] mem_data_wr_i
    ,input  [31:0] inst_i        // lsu.v's CSR-alias decode reads this
    ,input  [31:0] rb_data_i     // store data, pre-rotation
    ,input         mem_cacheable_i

    ,output        pc_valid_o
    ,output        is_impl_o
    ,output [31:0] pc_p4_o
    ,output [ 4:0] rd_o
    ,output        reg_wr_en_o
    ,output [31:0] result_o

    ,output        mem_rd_en_o
    ,output        mem_wr_en_o
    ,output [ 3:0] mem_ctrl_o
    ,output [31:0] mem_addr_o
    ,output [ 3:0] mem_mask_o
    ,output [31:0] mem_data_wr_o
    ,output [31:0] inst_o
    ,output [31:0] rb_data_o
    ,output        mem_cacheable_o
);

PipelineRegister #(.WIDTH( 1)) r_pc_valid   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_valid_i),    .data_o(pc_valid_o));
PipelineRegister #(.WIDTH( 1)) r_is_impl    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(is_impl_i),     .data_o(is_impl_o));
PipelineRegister #(.WIDTH(32)) r_pc_p4      (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(pc_p4_i),       .data_o(pc_p4_o));
PipelineRegister #(.WIDTH( 5)) r_rd         (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(rd_i),          .data_o(rd_o));
PipelineRegister #(.WIDTH( 1)) r_reg_wr_en  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(reg_wr_en_i),   .data_o(reg_wr_en_o));
PipelineRegister #(.WIDTH(32)) r_result     (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(result_i),     .data_o(result_o));

PipelineRegister #(.WIDTH( 1)) r_mem_rd_en  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_rd_en_i),   .data_o(mem_rd_en_o));
PipelineRegister #(.WIDTH( 1)) r_mem_wr_en  (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_wr_en_i),   .data_o(mem_wr_en_o));
PipelineRegister #(.WIDTH( 4)) r_mem_ctrl   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_ctrl_i),    .data_o(mem_ctrl_o));
PipelineRegister #(.WIDTH(32)) r_mem_addr   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_addr_i),    .data_o(mem_addr_o));
PipelineRegister #(.WIDTH( 4)) r_mem_mask   (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_mask_i),    .data_o(mem_mask_o));
PipelineRegister #(.WIDTH(32)) r_mem_dwr    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_data_wr_i), .data_o(mem_data_wr_o));
PipelineRegister #(.WIDTH(32)) r_inst       (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(inst_i),        .data_o(inst_o));
PipelineRegister #(.WIDTH(32)) r_rb_data    (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(rb_data_i),     .data_o(rb_data_o));
PipelineRegister #(.WIDTH( 1)) r_mem_cacheable (.clk(clk), .rst_n(rst_n), .clear(clear), .en(en), .data_i(mem_cacheable_i), .data_o(mem_cacheable_o));

endmodule
