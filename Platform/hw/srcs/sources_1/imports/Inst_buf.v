module Inst_buf(
    input clk,
    input rst_n,
    
    input         push_valid_i,
    input [31:0]  push_pc_i,
    input [31:0]  push_inst_i,
    input         push_pred_taken_i,
    output        push_ready_o,
    output        almost_full_o, 
    
    input         flush,
    
    output        inst_rdy_o,
    output [31:0] inst_pc_o,
    output [31:0] inst_o,
    output        inst_pred_taken_o,
    input         req_inst_i
);
	localparam FIFO_DEPTH = 16;
    wire pc_is_full;
    wire pc_is_empty;
    wire inst_is_full;
    wire inst_is_empty;
    wire pred_is_full;
    wire pred_is_empty;
    wire [4:0] pc_count;

    assign almost_full_o = (pc_count >= FIFO_DEPTH - 2); 

    assign inst_rdy_o = ~pc_is_empty && ~inst_is_empty && ~pred_is_empty;
    assign push_ready_o = ~pc_is_full && ~inst_is_full && ~pred_is_full;
    
    IB_queue #(
        .DATASIZE(32),
        .DEPTH(FIFO_DEPTH)
    ) m_pc_queue (
        .clk_i    (clk),         
        .rst_n    (rst_n),         
        .data_i   (push_pc_i),  
        .push_i   (push_valid_i),    
        .pop_i    (req_inst_i),     
        .flush_i  (flush),   
        .count_o  (),
        .is_full  (pc_is_full), 
        .is_empty (pc_is_empty),
        .data_o   (inst_pc_o)   
    );

    IB_queue #(
        .DATASIZE(32),
        .DEPTH(FIFO_DEPTH)
    ) m_inst_queue (
        .clk_i    (clk),         
        .rst_n    (rst_n),         
        .data_i   (push_inst_i),  
        .push_i   (push_valid_i),    
        .pop_i    (req_inst_i),     
        .flush_i  (flush), 
        .count_o  (pc_count),
        .is_full  (inst_is_full), 
        .is_empty (inst_is_empty),
        .data_o   (inst_o)   
    );

    IB_queue #(
        .DATASIZE(1),
        .DEPTH(FIFO_DEPTH)
    ) m_prediction_queue (
        .clk_i    (clk),
        .rst_n    (rst_n),
        .data_i   (push_pred_taken_i),
        .push_i   (push_valid_i),
        .pop_i    (req_inst_i),
        .flush_i  (flush),
        .count_o  (),
        .is_full  (pred_is_full),
        .is_empty (pred_is_empty),
        .data_o   (inst_pred_taken_o)
    );

endmodule
