`timescale 1ns / 1ps
module icache_plus(
    input clk, 
	input rst_n, 
	input fetch_vld, 
	input [31:0] fetch_addr,
    input invalidate_i, 
	input flush_i, 
	output flush_status_o,
    output icache_rdy_o, 
	output reg [31:0] cpu_inst_o,
    output reg i_exception, 
	output hit_o, 
	output reg icache_vld_o,
    input rm_rdy, 
	output reg [31:0] mem_addr, 
	input rm_success,
    input rm_complete, 
	output reg req_rm, 
	input [255:0] rm_data
);
    reg fifo_en; wire fifo; reg wr0, wr1; reg [255:0] mem_data;
    wire [31:0] cpu_inst_0, cpu_inst_1;
    wire [18:0] cache_tag; wire [7:0] cache_idx; wire [4:0] cache_ofs;
    wire [18:0] tag_i; wire [7:0] idx_i; wire [4:0] ofs_i;
    assign {tag_i, idx_i, ofs_i} = fetch_addr;
    
    reg [8:0] sram_working_idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sram_working_idx <= 9'h1FF;
        else sram_working_idx <= cache_idx;
    end
    wire sram_ready = (idx_i == sram_working_idx);

    reg [1:0] vld_out_inst; wire [18:0] tag_0, tag_1; wire vld_0, vld_1;
    wire match1 = vld_1 & (tag_i == tag_1);
    wire match0 = vld_0 & (tag_i == tag_0);
    wire hit = (match1 | match0) & sram_ready;
    assign hit_o = hit;
    
    reg invld_s, flush_s;
    assign flush_status_o = flush_s;
    
    parameter IDLE = 0, RM = 1, UPDATE = 2, RECOMP = 3;
    reg [1:0] cs;
    
    assign icache_rdy_o = (cs == IDLE) && (!fetch_vld || hit || invalidate_i || flush_i);
    
    assign cache_tag = (cs == IDLE) ? tag_i : mem_addr[31:13]; 
    assign cache_idx = (cs == IDLE) ? idx_i : mem_addr[12:5];
    assign cache_ofs = (cs == IDLE) ? ofs_i : mem_addr[4:0];
    
    reg wr_vld0, wr_vld1, vld_i;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cs <= IDLE; vld_out_inst <= 0; req_rm <= 0; fifo_en <= 0;
            {wr_vld1, wr_vld0} <= 2'b00; vld_i <= 0; i_exception <= 0;
            mem_addr <= 0; icache_vld_o <= 0; invld_s <= 0; flush_s <= 0;
            cpu_inst_o <= 32'h00000013; // NOP
        end else begin
            case(cs)
                IDLE : begin
                    vld_i <= 0; i_exception <= 0; fifo_en <= 0;
                    invld_s <= 0; flush_s <= 0; mem_addr <= {tag_i, idx_i, ofs_i};
                    if(invalidate_i | flush_i) begin
                        cs <= IDLE; vld_out_inst <= 0; {wr_vld1, wr_vld0} <= 2'b00; icache_vld_o <= 0;
                    end else if (!sram_ready && fetch_vld) begin 
                        {wr_vld1, wr_vld0} <= 2'b00; icache_vld_o <= 0;
                    end else if(hit && fetch_vld) begin
                        cs <= IDLE; {wr_vld1, wr_vld0} <= 2'b00; vld_out_inst <= {match1, match0}; icache_vld_o <= 1;
                        cpu_inst_o <= match1 ? cpu_inst_1 : cpu_inst_0;
                    end else if(fetch_vld) begin
                        cs <= RM; {wr_vld1, wr_vld0} <= 2'b00; vld_out_inst <= 0; req_rm <= 1; icache_vld_o <= 0;
                    end else begin
                        {wr_vld1, wr_vld0} <= 2'b00; icache_vld_o <= 0;
                    end
                end
                RM : begin
                    invld_s <= invld_s | invalidate_i; flush_s <= flush_s | flush_i;
                    if(rm_rdy) begin cs <= UPDATE; req_rm <= 0; end
                end
                UPDATE : begin
                    invld_s <= invld_s | invalidate_i; flush_s <= flush_s | flush_i;
                    if(rm_complete & rm_success) begin
                        cs <= RECOMP; fifo_en <= 1;
                        vld_i <= (!invld_s) & (!invalidate_i);
                        {wr_vld1, wr_vld0} <= fifo ? 2'b10 : 2'b01;
                    end else if(rm_complete & ~rm_success) begin
                        cs <= IDLE; i_exception <= 1;
                    end
                end
                RECOMP : begin 
                    fifo_en <= 0; cs <= IDLE; {wr_vld1, wr_vld0} <= 2'b00;
                    icache_vld_o <= 0; 
                    vld_out_inst <= 2'b00;
                end
            endcase
        end
    end
    
    always @(*) begin
        {wr1, wr0} = 0; mem_data = 0;
        if(cs == UPDATE && rm_complete && rm_success) begin
            {wr1, wr0} = fifo ? 2'b10 : 2'b01; mem_data = rm_data;
        end
    end
    
    fifo_block1bx256 f0(.clk(clk), .en(fifo_en), .index(cache_idx), .fifo(fifo));    
    way_32Bx256 w0(.clk(clk), .rst_n(rst_n), .invalidate(invalidate_i), .write(wr0), .wr_vld(wr_vld0), .tag_i(cache_tag), .index(cache_idx), .word_offset(cache_ofs[4:2]), .mem_data(mem_data), .vld_i(vld_i), .tag_o(tag_0), .cpu_inst_o(cpu_inst_0), .vld_o(vld_0));
    way_32Bx256 w1(.clk(clk), .rst_n(rst_n), .invalidate(invalidate_i), .write(wr1), .wr_vld(wr_vld1), .tag_i(cache_tag), .index(cache_idx), .word_offset(cache_ofs[4:2]), .mem_data(mem_data), .vld_i(vld_i), .tag_o(tag_1), .cpu_inst_o(cpu_inst_1), .vld_o(vld_1));
endmodule