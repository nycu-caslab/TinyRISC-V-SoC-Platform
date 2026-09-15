module Frontend_top(
    input         clk,
    input         rst_n,

    input         redirect_valid_i,
    input  [31:0] redirect_pc_i,

    // Resolved control-flow update from the backend
    input         resolve_valid_i,
    input         resolve_is_branch_i,
    input         resolve_is_jump_i,
    input         resolve_taken_i,
    input  [31:0] resolve_pc_i,
    input  [31:0] resolve_target_i,

    input         invalidate_i,
    output        invalid_complete,

    input         req_inst_i,
    output        inst_rdy_o,
    output [31:0] inst_pc_o,
    output [31:0] inst_o,
    output        inst_pred_taken_o,

    input         rm_rdy,
    input         rm_success,
    input         rm_complete,
    input [255:0] rm_data,
    output        req_rm,
    output [31:0] rm_addr
);

wire        ibuf_ready;
wire        ibuf_almost_full;
wire        ibuf_push;
wire        ibuf_flush;
wire        fetch_valid;
wire        ibus_ready;
wire        ibus_hit;
wire        inst_valid;
wire [31:0] fetch_addr;
wire [31:0] inst_data;
wire [31:0] inst_pc;
wire        ibus_flush;
wire        ibus_invld;
wire        flush_status;

wire        btb_lookup_hit;
wire        btb_lookup_predict_taken;
wire        btb_lookup_is_jump;
wire [31:0] btb_lookup_target;
wire        prediction_taken = btb_lookup_predict_taken;

BTB #(.ENTRY_NUM(32)) m_btb (
    .clk               (clk),
    .rst_n             (rst_n),
    .lookup_pc_i       (fetch_addr),
    .lookup_hit_o      (btb_lookup_hit),
    .lookup_predict_taken_o(btb_lookup_predict_taken),
    .lookup_is_jump_o  (btb_lookup_is_jump),
    .lookup_target_o   (btb_lookup_target),
    .update_en_i       (resolve_valid_i),
    .update_pc_i       (resolve_pc_i),
    .update_target_i   (resolve_target_i),
    .update_is_jump_i  (resolve_is_jump_i),
    .update_taken_i    (resolve_taken_i)
);

// I_bus registers the PC of an accepted request for the returned instruction.
// Register the prediction on the exact same handshake so metadata stays
// aligned with inst_pc/inst_data when the response is pushed into Inst_buf.
reg        issued_pred_taken;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        issued_pred_taken <= 1'b0;
    end else if (redirect_valid_i || invalidate_i) begin
        issued_pred_taken <= 1'b0;
    end else if (fetch_valid && ibus_ready) begin
        issued_pred_taken <= prediction_taken;
    end
end

    Fetch_ctrl m_fetch_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .redirect_valid_i   (redirect_valid_i),
        .redirect_pc_i      (redirect_pc_i),
        .prediction_taken_i (prediction_taken),
        .prediction_target_i(btb_lookup_target),
        .invalidate_i       (invalidate_i),
        .invalid_complete   (invalid_complete),
        .ibuf_ready_i       (ibuf_ready),
        .ibuf_almost_full_i (ibuf_almost_full), 
        .ibuf_push_o        (ibuf_push),
        .ibuf_flush_o       (ibuf_flush),
        .ibus_hit_i         (ibus_hit),
        .ibus_ready_i       (ibus_ready),
        .inst_valid_i       (inst_valid),
        .ibus_fetch_vld_o   (fetch_valid),
        .flush_status_i     (flush_status),
        .ibus_flush_o       (ibus_flush),
        .ibus_invld_o       (ibus_invld),
        .ibus_addr_o        (fetch_addr)
    );

    I_bus m_ibus (
        .clk            (clk),
        .rst_n          (rst_n),
        .fetch_vld      (fetch_valid),
        .fetch_addr     (fetch_addr),
        .ibus_ready     (ibus_ready),
        .inst_valid     (inst_valid),
        .ibus_hit       (ibus_hit),
        .inst_o         (inst_data),
        .pc_o           (inst_pc),
        .invalidate_i   (ibus_invld),
        .flush_i        (ibus_flush),
        .flush_status_o (flush_status),
        .rm_rdy         (rm_rdy),
        .rm_addr        (rm_addr),
        .rm_success     (rm_success),
        .rm_complete    (rm_complete),
        .req_rm         (req_rm),
        .rm_data        (rm_data)
    );

    Inst_buf m_inst_buf (
        .clk            (clk),   
        .rst_n          (rst_n),
        .push_valid_i   (ibuf_push),
        .push_pc_i      (inst_pc),
        .push_inst_i    (inst_data),
        .push_pred_taken_i (issued_pred_taken),
        .push_ready_o   (ibuf_ready),
        .almost_full_o  (ibuf_almost_full), 
        .flush          (ibuf_flush),
        .inst_rdy_o     (inst_rdy_o),
        .inst_pc_o      (inst_pc_o),
        .inst_o         (inst_o),
        .inst_pred_taken_o (inst_pred_taken_o),
        .req_inst_i     (req_inst_i)
    );

endmodule
