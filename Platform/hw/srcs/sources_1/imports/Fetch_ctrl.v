module Fetch_ctrl(
    input clk, 
	input rst_n,
    input        redirect_valid_i, 
	input [31:0] redirect_pc_i,
    input        prediction_taken_i,
    input [31:0] prediction_target_i,
    input        invalidate_i, 
	output       invalid_complete,
    input        ibuf_ready_i, 
	input        ibuf_almost_full_i, 
    output       ibuf_push_o, 
	output       ibuf_flush_o,
    input        ibus_hit_i, 
	input        ibus_ready_i, 
	input        inst_valid_i, 
    output       ibus_fetch_vld_o, 
	input        flush_status_i,
    output       ibus_flush_o, 
	output       ibus_invld_o, 
	output [31:0] ibus_addr_o
);
    reg [31:0] pc_reg;

    wire normal_advance = ibus_hit_i && ibus_ready_i && !ibuf_almost_full_i;
    wire pc_en = redirect_valid_i || normal_advance;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_reg <= 32'h0000_0000;
        else if (pc_en) begin
            if (redirect_valid_i)
                pc_reg <= redirect_pc_i;
            else if (prediction_taken_i)
                pc_reg <= prediction_target_i;
            else
                pc_reg <= pc_reg + 32'd4;
        end
    end

    assign ibus_addr_o = pc_reg;
    assign ibus_fetch_vld_o = !ibuf_almost_full_i;
    assign ibuf_push_o = inst_valid_i;
    
    assign ibus_flush_o = redirect_valid_i;
    assign ibuf_flush_o = redirect_valid_i | invalidate_i;
    assign ibus_invld_o = invalidate_i;
    assign invalid_complete = invalidate_i && ibus_ready_i;
endmodule
