// -----------------------------------------------
// Dcache Signal Control (Decoupled / D-Cache Only)
// -----------------------------------------------

module mmu_cache_ctrl (
     input clk_i
    ,input rst_i

    // mmu internal (data)
    ,input mmu_dcache_rd_i
    ,input mmu_dcache_wr_i
    ,input [31:0] mmu_dcache_addr_i
    ,input [31:0] mmu_dcache_wr_data_i
    ,input [3:0] mmu_dcache_mask_i
    ,input mmu_cachable_i
    ,input mmu_d_oper_i
    ,output dcache_valid_o
    ,output reg [31:0] dcache_wb_data_o

    // dcache 
    ,input dcache_mmu_valid_i
    ,input [31:0] dcache_wb_data_i
    ,output mmu_dcache_rd_o
    ,output mmu_dcache_wr_o
    ,output reg [31:0] mmu_dcache_addr_o
    ,output reg [31:0] mmu_dcache_wr_data_o
    ,output reg [3:0] mmu_dcache_mask_o
    ,output mmu_dcachable_o

    // cdma
    ,output mmu_dma_rd_o
    ,output mmu_dma_wr_o
);

localparam FSM_W = 2;
localparam FSM_IDLE = 0;
localparam FSM_MEM = 1;
localparam FSM_WB = 2;

//=====================//
//      D-cache        //
//=====================//

reg [FSM_W-1:0] fsm_d_state_pre, fsm_d_state, fsm_d_state_next;
reg dcache_rd_r, dcache_wr_r;
reg cachable_r;
reg d_oper_r;

assign mmu_dcachable_o = cachable_r;

always @(posedge clk_i or negedge rst_i) begin
    if(~rst_i)begin
        fsm_d_state <= FSM_IDLE;
        fsm_d_state_pre <= FSM_IDLE;
    end else begin
        fsm_d_state <= fsm_d_state_next;
        fsm_d_state_pre <= fsm_d_state;
    end
end

always @(*) begin
    fsm_d_state_next = fsm_d_state;

    case(fsm_d_state_next)
    FSM_IDLE:
    begin
        if(mmu_dcache_rd_i || mmu_dcache_wr_i || mmu_d_oper_i)
            fsm_d_state_next = FSM_MEM;
        else
            fsm_d_state_next = FSM_IDLE;
    end
    FSM_MEM:
    begin
        if(dcache_mmu_valid_i)
            fsm_d_state_next = FSM_WB;
        else
            fsm_d_state_next = FSM_MEM;
    end
    FSM_WB:
    begin
        fsm_d_state_next = FSM_IDLE;
    end
    default: 
        fsm_d_state_next = FSM_IDLE;
    endcase
end

assign mmu_dcache_rd_o = (fsm_d_state == FSM_MEM) && (fsm_d_state_pre == FSM_IDLE) && dcache_rd_r && cachable_r;
assign mmu_dcache_wr_o = (fsm_d_state == FSM_MEM) && (fsm_d_state_pre == FSM_IDLE) && dcache_wr_r && cachable_r;
assign mmu_dma_rd_o = (fsm_d_state == FSM_MEM) && (fsm_d_state_pre == FSM_IDLE) && dcache_rd_r && ~cachable_r;
assign mmu_dma_wr_o = (fsm_d_state == FSM_MEM) && (fsm_d_state_pre == FSM_IDLE) && dcache_wr_r && ~cachable_r;
assign dcache_valid_o = (fsm_d_state == FSM_WB);

always @(posedge clk_i or negedge rst_i)begin
    if(~rst_i)begin
        dcache_rd_r <= 1'b0;
        dcache_wr_r <= 1'b0;
        dcache_wb_data_o <= 32'b0;
        mmu_dcache_addr_o <= 32'b0;
        mmu_dcache_wr_data_o <= 32'b0;
        mmu_dcache_mask_o <= 4'b0;
        cachable_r <= 1'b1;
        d_oper_r <= 1'b0;
    end else begin
        dcache_rd_r <= mmu_dcache_rd_i;
        dcache_wr_r <= mmu_dcache_wr_i;
        dcache_wb_data_o <= dcache_wb_data_i;
        mmu_dcache_addr_o <= mmu_dcache_addr_i;
        mmu_dcache_wr_data_o <= mmu_dcache_wr_data_i;
        mmu_dcache_mask_o <= mmu_dcache_mask_i;
        cachable_r <= mmu_cachable_i;
        d_oper_r <= mmu_d_oper_i;
    end
end

endmodule