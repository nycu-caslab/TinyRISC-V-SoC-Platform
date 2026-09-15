`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/07 00:36:46
// Design Name: 
// Module Name: dcache_pro
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dcache_pro(
    input clk,
    input rst_n,
    
	// cpu interface //
	input [31:0] cpu_daddr_i,
    input [31:0]cpu_data_i,
    input [3:0]mask_i,
    input cpu_req_wr,
    input cpu_req_rd,
	output reg [31:0]cpu_data_o,
    output dcache_rdy_o,
	output reg dcache_data_vld_o,
	output reg [1:0]d_exception,
	output hit_o, // combinational hit/miss for this cycle's request -- for the future MEM stage's hit=no-stall/miss=stall logic
	
	// MMU interface
	input invalidate_i,
	input flush_i,
	input writeback_i,
	
	// mem interface //
	output reg [31:0] mem_addr,
	// AR, R
    input rm_rdy,
	input [255:0]rm_data,
	input rm_success,
	input rm_complete,
	output reg rm_vld,
	
	// AW, W
	input wm_rdy,
    output reg [255:0]wm_data,
    output reg wm_vld,
    
    //B
    input wm_success,
    input wm_complete 
);  
    
    // cpu valid
	reg data_vld;
	
	// way parameter //
	wire [17:0] tag_0,tag_1;
    reg [1:0]cpu_wr;
    reg [1:0]mem_wr;  
	reg [1:0]wr_vld;
	reg [1:0]wr_dty;
	reg vld_i;
	reg dty_i;
	wire dty_0,dty_1;
    reg [17:0]cache_tag_i;
    reg [8:0]cache_idx_i;
    reg [2:0]cache_ofs_i; 
	reg [3:0]cache_mask;
    reg [31:0]cache_cpu_data_i;
    reg [255:0]cache_mem_data_i;
    wire [17:0]tag_i;
    wire [8:0]idx_i;
    wire [2:0]word_ofs_i;
    reg exception_laf;
    reg exception_saf;
    
    
    wire [31:0]cpu_data_o1,cpu_data_o0;
    wire [255:0]mem_data_o1,mem_data_o0;
	
	// hold signal //
	reg hold_cpu_wr;
    reg [17:0]hold_tag_i;
    reg [8:0]hold_idx_i;
    reg [2:0]hold_word_ofs;
    reg [31:0]hold_data_i;
    reg [3:0]hold_mask;
    reg hold_match0;
    reg hold_match1;
    reg hold_wb;
	reg hold_flush;
	reg [17:0]hold_tag0;
	reg [17:0]hold_tag1;
	
	// decode address
	assign {tag_i, idx_i, word_ofs_i} = cpu_daddr_i[31:2];
	
    // replacement related parameter  //
    wire lru;
	reg do_lru;
    wire is_dty = lru ? dty_1 : dty_0;

    // hit_miss & replacement policy //
    reg data_o_sel;
	wire vld_0,vld_1;
    wire match1 = vld_1 & (tag_i == tag_1);
    wire match0 = vld_0 & (tag_i == tag_0);
	wire match = match0 | match1;
	wire comp_mode = cpu_req_rd | cpu_req_wr;
    wire hit =  comp_mode & match;
    assign hit_o = hit;
	
    
    // FSM parameter //
    parameter IDLE = 0;//000   
	parameter WM = 1;  //001    // 
	parameter WMEND = 2;//010
	parameter RM = 3;   //011
	parameter RMEND = 4;//100
	parameter EXC = 5;  //101
	parameter RECOMP = 6;//110  // Recompare when miss

    reg [2:0]cs, ns;
    //reg skip_wb;
	
	// signal hold //
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			hold_tag0        <= 0;
			hold_tag1        <= 0;
			hold_cpu_wr      <= 0;
			hold_tag_i       <= 0;
			hold_idx_i       <= 0;
			hold_word_ofs	 <= 0;
			hold_data_i      <= 0;
			hold_flush       <= 0;
			hold_wb          <= 0;
			hold_mask        <= 0;
			hold_match0      <= 0;
            hold_match1      <= 0;end
		else if(cs == IDLE)begin 
			hold_tag0        <= tag_0;
			hold_tag1        <= tag_1;
			hold_cpu_wr      <=  cpu_req_wr;
            hold_tag_i       <=  tag_i;
            hold_idx_i       <=  idx_i;
            hold_word_ofs    <=  word_ofs_i;
            hold_data_i      <=  cpu_data_i;
			hold_flush       <=  flush_i;
            hold_wb          <=  writeback_i;
            hold_mask        <=  mask_i; 
            hold_match0      <= match0;
            hold_match1      <= match1;end
    end
    
    // state control //
    always@(posedge clk or negedge rst_n)begin //state update
        if(!rst_n)
            cs <= IDLE;
        else
            cs <= ns;
    end
    
	// state transfer //
    always@(*)begin
        ns = IDLE;
		case(cs)
			IDLE :  if(flush_i | writeback_i)begin
						ns = (match1 & dty_1 | match0 & dty_0) ? WM : IDLE;
					end
					else if(invalidate_i | hit | !comp_mode ) begin
						ns = IDLE;
					end
					else if(is_dty)
						ns = WM;
					else
						ns = RM;
			WM : 	if(wm_rdy)
						ns = WMEND;
					else
						ns = WM;
			WMEND: 	if(wm_complete & wm_success)begin //update cache block&status
						ns = (hold_wb | hold_flush) ? IDLE : RM;
					end
				    else if(wm_complete & ~wm_success)
				        ns = IDLE;
					else
						ns = WMEND;
			RM : 	if(rm_rdy)
						ns = RMEND;
					else
						ns = RM;
			RMEND : if(rm_complete)begin
						ns = rm_success ? RECOMP : IDLE;
					end
					else 
						ns = RMEND;
			RECOMP: begin
			            ns = IDLE;
			        end               
			default:ns = IDLE;
		endcase
	end

    always@(*)begin
		data_vld = 0;
        do_lru = 0;
        vld_i = 0;
        wr_vld = 2'b00;
        cpu_wr = 2'b00;
        dty_i = 0;
        wr_dty = 2'b00;
        mem_wr = 2'b00;
        {exception_saf,exception_laf} = 0;
		case(cs)
			IDLE :  if(flush_i | writeback_i)begin
						wr_vld = flush_i ? {match1& ~dty_1,match0& ~dty_0} : 2'b00;
						data_vld = ns == IDLE;
					end
					else if(invalidate_i) begin
                        wr_vld = {match1,match0};
						wr_dty = {match1,match0};
						data_vld = 1;
					end
					// else if(writeback_i) begin
						// ns = (match1 & dty_1 | match0 & dty_0) ? WM : IDLE;
					// end
					else if(hit)begin
						do_lru = 1;
						cpu_wr = {cpu_req_wr & match1,cpu_req_wr & match0};
						dty_i = cpu_req_wr;
						wr_dty = cpu_wr;
						data_vld = 1;
					end
			WMEND: 	if(wm_complete & wm_success)begin //update cache block&status
						wr_dty = (hold_wb | hold_flush) ? {hold_match1, hold_match0} : {lru, ~lru};//lru ? 2'b10 : 2'b01;
						wr_vld = {hold_match1 & hold_flush, hold_match0 & hold_flush};
						//dty_i = 0;
						data_vld = ns == IDLE;
					end
				    else if(wm_complete & ~wm_success)
				        {exception_saf,exception_laf} = {hold_cpu_wr,~hold_cpu_wr};
			RMEND : if(rm_complete & rm_success)begin
					    mem_wr = {lru, ~lru};//lru ? 2'b10 : 2'b01;
						wr_dty = mem_wr;
						wr_vld = mem_wr;
						vld_i = 1;
					end
				    else if(rm_complete & ~rm_success)
				        {exception_saf,exception_laf} = {hold_cpu_wr,~hold_cpu_wr};
			RECOMP: begin
                        //cpu_wr = {(hold_tag_i == tag_1) & hold_cpu_wr, (hold_tag_i == tag_0) & hold_cpu_wr};
                        cpu_wr = {lru & hold_cpu_wr, ~lru & hold_cpu_wr};
                        do_lru = 1;
                        dty_i  = hold_cpu_wr;
                        wr_dty = cpu_wr;
						data_vld = 1;
			        end            
		endcase
	end
	
	always@(posedge clk or negedge rst_n)begin
	   if(!rst_n)begin
            d_exception <= 0;
	   end
	   else begin
	       d_exception <= {exception_saf,exception_laf};
	   end
	end

    
	// Define cache input
	always@(*)begin
		if(cs == IDLE)begin
			cache_tag_i = tag_i;
			cache_idx_i = idx_i;
			cache_ofs_i = word_ofs_i;
			cache_mask = mask_i;
			cache_mem_data_i = rm_data;
			cache_cpu_data_i = cpu_data_i;end
		else if(cs == WM)begin //RO cache, tag & data
			cache_tag_i = hold_tag_i;
			cache_idx_i = hold_idx_i;
			cache_ofs_i = 0;
			cache_mask = 0;
			cache_mem_data_i = rm_data;
			cache_cpu_data_i = 0;end
		else if(cs == WMEND)begin
			cache_tag_i = hold_tag_i;
			cache_idx_i = hold_idx_i;
			cache_ofs_i = 0;
			cache_mem_data_i = rm_data;
			cache_mask = 0;
			cache_cpu_data_i = 0;end
		else if(cs == RM)begin
			cache_tag_i = hold_tag_i;
			cache_idx_i = hold_idx_i;
			cache_ofs_i = 0;
			cache_mem_data_i = rm_data;
			cache_mask = 0;
			cache_cpu_data_i = 0;end
		else if(cs == RMEND)begin
			cache_tag_i = hold_tag_i;
			cache_idx_i = hold_idx_i;
			cache_ofs_i = 0;
			cache_mask = 0;
			cache_mem_data_i = rm_data;
			cache_cpu_data_i = 0;end	
		else if(cs == RECOMP)begin
			cache_tag_i = hold_tag_i;
			cache_idx_i = hold_idx_i;
			cache_ofs_i = hold_word_ofs;
			cache_mask = hold_mask;
			cache_mem_data_i = rm_data;
			cache_cpu_data_i = hold_data_i;end
		else begin
			cache_tag_i = 0;
			cache_idx_i = 0;
			cache_ofs_i = 0;
			cache_mask = 0;
			cache_mem_data_i = rm_data;
			cache_cpu_data_i = 0;end	
	end
	
	
	// WM/RM setting
	always@(*)begin
       rm_vld = 0;
       wm_vld = 0;
       wm_data = 0;
       mem_addr = 0;
	   if(cs == WM)begin
	       wm_vld = 1;
			if(hold_flush | hold_wb)begin
			   wm_data = hold_match1 ? mem_data_o1 : mem_data_o0;
			   //mem_addr = {hold_match1 ? tag_1 : tag_0, hold_idx_i,5'd0};
			   mem_addr = {hold_match1 ? hold_tag1 : hold_tag0, hold_idx_i,5'd0};
			end
			else begin
			   wm_data = lru ? mem_data_o1 : mem_data_o0;
			   //mem_addr = {lru? tag_1 : tag_0, hold_idx_i,5'd0};
			   mem_addr = {lru? hold_tag1 : hold_tag0, hold_idx_i,5'd0};
			end
	   end
	   else if(cs == RM)begin
	       rm_vld = 1;
	       mem_addr = {hold_tag_i,hold_idx_i,5'd0};
	   end
    end

	// output logic
    assign dcache_rdy_o = (cs == IDLE);
    
    // always@(posedge clk or negedge rst_n)begin
        // if(!rst_n)
            // data_o_sel <= 0;
        // else 
			// data_o_sel <= match1;
    // end
    
    always@(*)begin
            cpu_data_o = match1 ? cpu_data_o1 : cpu_data_o0;
    end
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)
			dcache_data_vld_o <= 0;
		else
			dcache_data_vld_o <= data_vld; 
	end
    

    
    // instance construction //
    lru_1b lru_arr(clk, do_lru, cache_idx_i, lru);
	
    way_32Bx512 way0(
        .clk(clk),
        .cpu_wr(cpu_wr[0]),
        .mem_wr(mem_wr[0]),
		.wr_vld(wr_vld[0]),
		.wr_dty(wr_dty[0]),
		.vld_i(vld_i),
		.dty_i(dty_i),
        .mask(cache_mask),
        .tag_i(cache_tag_i),
        .index(cache_idx_i),
        .word_offset(cache_ofs_i),
        .cpu_data_i(cache_cpu_data_i),
        .mem_data_i(cache_mem_data_i),
        .cpu_data_o(cpu_data_o0),
        .mem_data_o(mem_data_o0),
        .vld_o(vld_0),
        .dty_o(dty_0),
        .tag_o(tag_0)
    );
    
    way_32Bx512 way1(
        .clk(clk),
        .cpu_wr(cpu_wr[1]),
        .mem_wr(mem_wr[1]),
		.wr_vld(wr_vld[1]),
		.wr_dty(wr_dty[1]),
		.vld_i(vld_i),
		.dty_i(dty_i),
        .mask(cache_mask),
        .tag_i(cache_tag_i),
        .index(cache_idx_i),
        .word_offset(cache_ofs_i),
        .cpu_data_i(cache_cpu_data_i),
        .mem_data_i(cache_mem_data_i),
        .cpu_data_o(cpu_data_o1),
        .mem_data_o(mem_data_o1),
        .vld_o(vld_1),
        .dty_o(dty_1),
        .tag_o(tag_1)
    );
endmodule
