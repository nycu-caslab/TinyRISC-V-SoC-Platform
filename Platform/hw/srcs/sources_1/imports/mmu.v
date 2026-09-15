module mmu
#(
     parameter  D_ADDR_MIN = 32'h60000000
    ,parameter  D_ADDR_MAX = 32'hFFFFFFFF
    ,parameter  SUPPORT_CDMA = 1
    ,parameter  SUPPORT_ROM = 0 
)
(
     input          clk_i
    ,input          rst_i
    ,input  [1:0]   priv_i

    // LSU Interface 
    ,input  [31:0]  lsu_in_addr_i
    ,input  [31:0]  lsu_in_data_i
    ,input          lsu_in_rd_i
    ,input          lsu_in_wr_i
    ,input  [ 3:0]  lsu_in_mask_i
    ,input          lsu_in_flush_i
    ,input          lsu_in_invalidate_i
    ,input          lsu_in_writeback_i
    ,input          lsu_in_zero_i
    ,input          lsu_in_i_invalidate_i

    ,output [31:0]  lsu_out_value_o
    ,output         lsu_out_valid_o

    // Dcache Interface
    ,input  [31:0]  dcache_in_value_i
    ,input          dcache_in_valid_i

    ,output [31:0]  dcache_addr_o
    ,output [31:0]  dcache_value_o
    ,output         dcache_rd_o        
    ,output         dcache_wr_o        
    ,output [ 3:0]  dcache_mask_o      
    ,output reg     dcache_flush_o     
    ,output reg     dcache_invalidate_o
    ,output reg     dcache_writeback_o 
    ,output reg     dcache_zero_o
 
    // CDMA
    ,input [31:0]   cdma_data_i
    ,input          cdma_valid_i
    ,output         cdma_wr_o
    ,output         cdma_rd_o

    // Icache Interface 
    ,output reg     icache_invalidate_o
);

reg [31:0] dcache_addr_r;
reg [ 3:0] dcache_mask_r;

wire req_d_rd = lsu_in_rd_i;
wire req_d_wr = lsu_in_wr_i;

wire dcache_rd_c = req_d_rd;
wire dcache_wr_c = req_d_wr;

wire d_flush     = lsu_in_flush_i;
wire d_invalid   = lsu_in_invalidate_i;
wire d_writeback = lsu_in_writeback_i;
wire d_zero      = lsu_in_zero_i;

wire dcache_valid;

wire d_cachable_w;
wire d_cachable;
reg d_cacheable_pre;    // select current input is cdma or dcache
reg d_valid;
reg [31:0] data_i;

generate 
if(SUPPORT_CDMA) begin : gen_cdma_support
    assign d_cachable = (dcache_addr_r >= D_ADDR_MIN) && (dcache_addr_r <= D_ADDR_MAX); 
    always @(posedge clk_i or negedge rst_i)begin
        if(~rst_i)begin
            d_cacheable_pre <= 1;
        end else begin
            d_cacheable_pre <= d_cachable_w;
        end
    end
end else begin : gen_only_dcache
    assign d_cachable = 1;
    always @(posedge clk_i or negedge rst_i)begin
        if(~rst_i)begin
            d_cacheable_pre <= 1'b1;
        end else begin
            d_cacheable_pre <= 1'b1;    
        end
    end
end
endgenerate

always @(*)begin
    if(d_cacheable_pre)begin
        d_valid = dcache_in_valid_i;
        data_i = dcache_in_value_i;
    end else begin
        d_valid = cdma_valid_i;
        data_i = cdma_data_i;
    end
end

wire [31:0] dcache_wb_data_value;

mmu_cache_ctrl u_mmu_cache_ctrl(
    .clk_i           (clk_i),
    .rst_i           (rst_i),

    .mmu_dcache_rd_i (dcache_rd_c),
    .mmu_dcache_wr_i (dcache_wr_c),
    .mmu_dcache_addr_i(dcache_addr_r),
    .mmu_dcache_wr_data_i(lsu_in_data_i),
    .mmu_dcache_mask_i(dcache_mask_r),
    .mmu_cachable_i  (d_cachable),
    .mmu_d_oper_i    (d_invalid || d_writeback  || d_flush),
    .dcache_valid_o  (dcache_valid),
    .dcache_wb_data_o(dcache_wb_data_value),

    .mmu_dcache_rd_o (dcache_rd_o),
    .mmu_dcache_wr_o (dcache_wr_o),
    .mmu_dcache_addr_o(dcache_addr_o),
    .mmu_dcache_wr_data_o(dcache_value_o),
    .mmu_dcache_mask_o(dcache_mask_o),
    .mmu_dcachable_o  (d_cachable_w),
    .dcache_mmu_valid_i(d_valid),
    .dcache_wb_data_i(data_i),

    .mmu_dma_rd_o (cdma_rd_o),
    .mmu_dma_wr_o (cdma_wr_o)
);

assign lsu_out_value_o      = dcache_wb_data_value;
assign lsu_out_valid_o      = (dcache_valid);

always @(*)begin
    dcache_mask_r = 0;
    dcache_addr_r = lsu_in_addr_i;

    if(dcache_rd_c)
        dcache_mask_r = 4'hf;
    else if(dcache_wr_c)
        dcache_mask_r = lsu_in_mask_i;
    else
        dcache_mask_r = 4'h0;
end

always @(posedge clk_i or negedge rst_i) begin
    if(~rst_i)begin
        dcache_invalidate_o <= 1'b0;
        dcache_flush_o <= 1'b0;
        dcache_writeback_o <= 1'b0;
        dcache_zero_o <= 1'b0;
        icache_invalidate_o <= 1'b0;
    end else begin
        dcache_invalidate_o <= d_invalid;
        dcache_flush_o <= d_flush;
        dcache_writeback_o <= d_writeback;
        dcache_zero_o <= d_zero;
        
        icache_invalidate_o <= lsu_in_i_invalidate_i;
    end
end

endmodule