//-----------------------------------------------------------------
// LSU
//-----------------------------------------------------------------

`include"../riscv_defs.v"

module lsu
#(
     parameter QUEUE_LEN   = 2
)
(   
     input           clk_i, 
	 input           rst_i

    // data Interface
    ,input   [31:0]  opcode_inst_i,
	input   [31:0]  opcode_rb_data_i,
	input           opcode_valid_i,
	input           ex_mem_rd_i,
	input           ex_mem_wr_i,
	input   [ 3:0]  ex_mem_ctrl_i
    // effective address + mask + rotated store-data, computed in EX (Phase 1 roadmap)
    ,input   [31:0]  ex_mem_addr_i
    ,input   [31:0]  ex_mem_data_wr_i
    ,input   [ 3:0]  ex_mem_mask_i

    // Dcache
    ,input   [31:0]  mmu_value_i, 
	input           mmu_valid_i
    ,output  [31:0]  mmu_addr_o, 
	output  [31:0]  mmu_data_o, 
	output          mmu_rd_o, 
	output          mmu_wr_o, 
	output  [ 3:0]  mmu_mask_o
    ,output  reg     mmu_dflush_o, 
	output  reg     mmu_dinvalidate_o, 
	output  reg     mmu_dwriteback_o, 
	output  reg     mmu_dzero_o, 
	output  reg     mmu_iinvalidate_o,
        
    // writeback interface
    output  [31:0]  writeback_value_o, 
	output          writeback_valid_o
);

localparam DATASIZE = 78;

wire [31:0] rb_data = opcode_rb_data_i;

wire [31:0] mem_addr_w, mem_addr_w_4;
reg [31:0] mem_data_wr_r, mem_data_wr_u;
reg mem_rd_r, mem_wr_r;
reg [ 3:0] mem_mask_r, mem_mask_u;

wire [31:0] final_mem_addr_r, final_data_wr_r;    
wire [ 3:0] final_mask_r;
reg [ DATASIZE-1:0] data_q_i;

wire [DATASIZE-1:0] resp_data_o;
wire resp_accept_o, resp_valid_o, resp_lb, resp_lh, resp_lw, resp_signed, resp_rd, resp_wr, resp_addr_unaligned;
wire [31:0] resp_addr, resp_data;
wire [ 3:0] resp_mask;
wire [ 2:0] resp_u_type;

wire lb_inst = (ex_mem_ctrl_i[2:0] == 3'b001) & ex_mem_rd_i & opcode_valid_i;
wire lh_inst = (ex_mem_ctrl_i[2:0] == 3'b010) & ex_mem_rd_i & opcode_valid_i;
wire lw_inst = (ex_mem_ctrl_i[2:0] == 3'b100) & ex_mem_rd_i & opcode_valid_i;
wire sh_inst = (ex_mem_ctrl_i[2:0] == 3'b010) & ex_mem_wr_i & opcode_valid_i;
wire sw_inst = (ex_mem_ctrl_i[2:0] == 3'b100) & ex_mem_wr_i & opcode_valid_i;
wire sign_inst = ex_mem_ctrl_i[3] & (ex_mem_ctrl_i[1:0] != 2'b11) & ex_mem_rd_i;
wire ld_inst = ex_mem_rd_i & opcode_valid_i;
wire st_inst = ex_mem_wr_i & opcode_valid_i;
wire csrrw_inst = ((opcode_inst_i & `INST_CSRRW_MASK) == `INST_CSRRW) & opcode_valid_i;

wire dflush       = ((opcode_inst_i[31:20] == `CSR_DFLUSH) && csrrw_inst)      || ((ex_mem_ctrl_i == 4'b0011) & opcode_valid_i);
wire dwriteback   = ((opcode_inst_i[31:20] == `CSR_DWRITEBACK) && csrrw_inst)  || ((ex_mem_ctrl_i == 4'b1011) & opcode_valid_i);
wire dinvalidate  = ((opcode_inst_i[31:20] == `CSR_DINVALIDATE) && csrrw_inst) || ((ex_mem_ctrl_i == 4'b0111) & opcode_valid_i);
wire dzero        = ((ex_mem_ctrl_i == 4'b1111) & opcode_valid_i);
wire iinvalidate  = (ex_mem_ctrl_i == 4'b0110) && opcode_valid_i; // fence.i, already decoded in ID (Control.v) -- don't re-decode the raw instruction here

assign mem_addr_w = ex_mem_addr_i;
assign mem_addr_w_4 = ex_mem_addr_i + 32'd4;

reg lb_inst_p, lh_inst_p, lw_inst_p, sh_inst_p, sw_inst_p, sign_inst_p, ld_inst_p, st_inst_p;
reg dflush_p, dwriteback_p, dinvalidate_p, dzero_p, iinvalidate_p;
reg [31:0] mem_addr_p, mem_addr_4_p, mem_data_wr_p;
reg [31:0] mem_data_wr_rot_p; // registered rotated store-data from EX (replaces local case-statement)
reg [ 3:0] mem_mask_reg_p;    // registered byte mask from EX (replaces local case-statement)
reg opcode_valid_p;

always @(posedge clk_i or negedge rst_i) begin
    if(~rst_i)begin
        lb_inst_p <= 1'b0; lh_inst_p <= 1'b0; lw_inst_p <= 1'b0; sh_inst_p <= 1'b0;
        sw_inst_p <= 1'b0; sign_inst_p <= 1'b0; ld_inst_p <= 1'b0; st_inst_p <= 1'b0;
        dflush_p <= 1'b0; dwriteback_p <= 1'b0; dinvalidate_p <= 1'b0; dzero_p <= 1'b0; iinvalidate_p <= 1'b0;
        mem_addr_p <= 32'b0; mem_addr_4_p <= 32'b0; mem_data_wr_p <= 32'b0; opcode_valid_p <= 1'b0;
        mem_data_wr_rot_p <= 32'b0; mem_mask_reg_p <= 4'b0;
    end else begin
        lb_inst_p <= lb_inst; lh_inst_p <= lh_inst; lw_inst_p <= lw_inst;
        sh_inst_p <= sh_inst; sw_inst_p <= sw_inst; sign_inst_p <= sign_inst; ld_inst_p <= ld_inst; st_inst_p <= st_inst;

        mem_addr_p <= mem_addr_w; mem_addr_4_p <= mem_addr_w_4;
        mem_data_wr_p <= rb_data; opcode_valid_p <= opcode_valid_i;
        mem_data_wr_rot_p <= ex_mem_data_wr_i; mem_mask_reg_p <= ex_mem_mask_i;

        if (mmu_valid_i) begin
            dflush_p <= 1'b0;
            dwriteback_p <= 1'b0;
            dinvalidate_p <= 1'b0;
            dzero_p <= 1'b0;
        end else begin
            dflush_p <= dflush_p | dflush;
            dwriteback_p <= dwriteback_p | dwriteback;
            dinvalidate_p <= dinvalidate_p | dinvalidate;
            dzero_p <= dzero_p | dzero;
        end

        iinvalidate_p <= iinvalidate;
    end
end

always @(*)begin
    mmu_dflush_o      = dflush_p;
    mmu_dwriteback_o  = dwriteback_p;
    mmu_dinvalidate_o = dinvalidate_p;
    mmu_dzero_o       = dzero_p;
    mmu_iinvalidate_o = iinvalidate_p;
end

wire unaligned_1_r = (mem_addr_p[1:0] == 2'b11) & (lh_inst_p | sh_inst_p);
wire unaligned_2_r = (mem_addr_p[1:0] != 2'b00) & (lw_inst_p | sw_inst_p);
wire addr_unaligned = unaligned_1_r || unaligned_2_r;

reg u_state, u_rd, u_wr, u_sign, u_lh;
reg [31:0] u_addr, u_data; reg [2:0] u_type;

always @(posedge clk_i or negedge rst_i)begin
    if(~rst_i) begin
        u_state <= 0; u_rd <= 0; u_wr <= 0; u_type <= 3'h0;
        u_sign <= 0; u_lh <= 0; u_addr <= 32'b0; u_data <= 32'b0;
    end else begin
        if(unaligned_1_r) begin
            u_state <= 1; u_rd <= ld_inst_p; u_wr <= st_inst_p; u_type <= 3'h1;
            u_data <= mem_data_wr_p; u_addr <= mem_addr_4_p; u_sign <= sign_inst_p; u_lh <= 1'b1;
        end else if(unaligned_2_r) begin
            u_state <= 1'b1; u_rd <= ld_inst_p; u_wr <= st_inst_p;
            u_data <= mem_data_wr_p; u_addr <= mem_addr_4_p; u_sign <= 0; u_lh <= 0;
            case(mem_addr_p[1:0])
                2'b01:  u_type <= 3'h2;
                2'b10:  u_type <= 3'h3;
                2'b11:  u_type <= 3'h4;
                default:u_type <= 3'h0;
            endcase
        end else begin
            u_state <= 0; u_rd <= 0; u_wr <= 0; u_type <= 3'h0; u_sign <= 0; u_lh <= 0;
        end
    end
end

assign mmu_addr_o   = (ex_mem_ctrl_i[1:0] == 2'b11)? mem_addr_p : {resp_addr[31:2],2'b00};
assign mmu_data_o   = resp_data;
assign mmu_rd_o     = resp_valid_o && resp_rd;
assign mmu_wr_o     = resp_valid_o && resp_wr;
assign mmu_mask_o   = (mmu_wr_o)?resp_mask: (mmu_rd_o)?4'hf: 4'h0;

always @(*)begin
    mem_rd_r = ld_inst_p | u_rd;
    mem_wr_r = st_inst_p | u_wr;
    // byte mask + rotated store-data are now computed in EX (Exec.v) and just registered here
    mem_mask_r    = mem_mask_reg_p;
    mem_data_wr_r = mem_data_wr_rot_p;
end

always @(*)begin
    mem_data_wr_u = u_data; mem_mask_u = 4'b0000;
    if(u_type == 3'h1) begin mem_data_wr_u = {24'h000000,u_data[15:8]}; mem_mask_u = 4'b0001; end
    else if(u_type == 3'h2) begin mem_data_wr_u = {24'h000000,u_data[31:24]}; mem_mask_u = 4'b0001; end
    else if(u_type == 3'h3) begin mem_data_wr_u = {16'h0000,u_data[31:16]}; mem_mask_u = 4'b0011; end
    else if(u_type == 3'h4) begin mem_data_wr_u = {8'h00,u_data[31:8]}; mem_mask_u = 4'b0111; end
end

wire push_q = ((mem_rd_r || mem_wr_r ) && resp_accept_o) || u_state;
wire is_dcache_cmi = dflush_p | dwriteback_p | dinvalidate_p | dzero_p;
wire pop_q = mmu_valid_i && resp_valid_o && !is_dcache_cmi;
wire mem_sign = sign_inst_p || u_sign;
wire mem_lb = lb_inst_p || u_lh;

assign final_mem_addr_r = (u_type==3'b000) ? mem_addr_p : u_addr;
assign final_data_wr_r = (u_type==3'b000) ? mem_data_wr_r : mem_data_wr_u;
assign final_mask_r = (u_type==3'b000) ? mem_mask_r : mem_mask_u; 
assign {resp_addr, resp_data, resp_lb, resp_lh, resp_lw, resp_signed, resp_rd, resp_wr, resp_mask, resp_u_type, resp_addr_unaligned} = resp_data_o; 

always @(*)begin
    data_q_i = {(DATASIZE){1'b0}};
    if (ld_inst_p || u_rd)
        data_q_i = {final_mem_addr_r, 32'b0, mem_lb, lh_inst_p, lw_inst_p, mem_sign, mem_rd_r, 1'b0, final_mask_r, u_type, addr_unaligned};
    else if (st_inst_p || u_wr)
        data_q_i = {final_mem_addr_r, final_data_wr_r, mem_lb, lh_inst_p, lw_inst_p, mem_sign, 1'b0, mem_wr_r, final_mask_r, u_type, addr_unaligned};
end

lsu_queue #(.DATASIZE(DATASIZE), .LENGTH(QUEUE_LEN), .DEPTH(QUEUE_LEN)) LDQ (
    .clk_i(clk_i), .rst_i(rst_i), .data_i(data_q_i), .push_i(push_q),
    .accept_o(resp_accept_o), .pop_i(pop_q), .data_o(resp_data_o), .valid_o(resp_valid_o)      
);

reg [31:0] writeback_value_r, writeback_value_pre, writeback_value_ma;
reg resp_valid_pre;
wire is_ma = !(resp_u_type == 3'b0);

assign writeback_valid_o = (mmu_valid_i && (is_dcache_cmi || !resp_valid_o || !resp_addr_unaligned || is_ma)) || iinvalidate_p;
assign writeback_value_o = (is_ma)? writeback_value_ma : writeback_value_r;

always @(posedge clk_i or negedge rst_i) begin
    if(~rst_i) begin writeback_value_pre <= 32'h0; resp_valid_pre <= 0; end
    else begin
        resp_valid_pre <= resp_valid_o;
        if(mmu_valid_i) writeback_value_pre <= writeback_value_r;
    end
end

always @(*)begin
    writeback_value_r = 32'b0; writeback_value_ma = 32'h0;
    case(resp_mask)
        4'b0001: writeback_value_r = {24'b0, mmu_value_i[7:0]};
        4'b0010: writeback_value_r = {24'b0, mmu_value_i[15:8]};
        4'b0100: writeback_value_r = {24'b0, mmu_value_i[23:16]};
        4'b1000: writeback_value_r = {24'b0, mmu_value_i[31:24]};
        4'b0011: writeback_value_r = {16'b0, mmu_value_i[15:0]};
        4'b0110: writeback_value_r = {16'b0, mmu_value_i[23:8]};
        4'b1100: writeback_value_r = {16'b0, mmu_value_i[31:16]};
        4'b0111: writeback_value_r = {8'b0, mmu_value_i[23:0]};
        4'b1110: writeback_value_r = {8'b0, mmu_value_i[31:8]};
        4'b1111: writeback_value_r = mmu_value_i;
    endcase
    if(resp_signed && resp_lh && writeback_value_r[15]) writeback_value_r = {16'hFFFF, writeback_value_r[15:0]};
    else if(resp_signed && resp_lb && writeback_value_r[7]) writeback_value_r = {24'hFFFFFF, writeback_value_r[7:0]};
    case(resp_u_type)
        3'h1: writeback_value_ma = {writeback_value_r[23:0], writeback_value_pre[ 7:0]};
        3'h2: writeback_value_ma = {writeback_value_r[ 7:0], writeback_value_pre[23:0]};
        3'h3: writeback_value_ma = {writeback_value_r[15:0], writeback_value_pre[15:0]};
        3'h4: writeback_value_ma = {writeback_value_r[23:0], writeback_value_pre[ 7:0]};
        default: writeback_value_ma = writeback_value_r; 
    endcase
end
endmodule