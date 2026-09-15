module MUL_DIV_top (
    input clk,
    input rst_n,

    input [31:0] data1,
    input [31:0] data2,

    input MUL_DIV_start,
    input [2:0] MUL_DIV_ctrl,

    output [31:0] MUL_DIV_out,
    output        MUL_done_o,
    output        DIV_done_o
);

    wire is_MUL = ~MUL_DIV_ctrl[2];
    wire is_DIV =  MUL_DIV_ctrl[2];
    wire MUL_done, DIV_done;
    wire [31:0] MUL_out, DIV_out;

    // Which unit the in-flight operation belongs to.
    //
    // The old output mux was
    //     MUL_done ? MUL_out : DIV_done ? DIV_out : 0
    // which collapsed to zero the moment *_done deasserted. That is why
    // Backend_top.v needed EX_hold_MUL_DIV to snapshot the value. Latching the
    // selector at dispatch instead keeps MUL_out -- the DSP's own output
    // register -- readable for as long as the MEM slot holds the multiply.
    //
    // DIV_out still has to be snapshotted: SRTDivider's stages are clocked
    // unconditionally (DIV_Reg.v wires every en to 1'b1), so its result is
    // valid only on the cycle DIV_done is high.
    reg sel_div;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)             sel_div <= 1'b0;
        else if (MUL_DIV_start) sel_div <= is_DIV;
    end

    assign MUL_DIV_out = sel_div ? DIV_out : MUL_out;
    assign MUL_done_o  = MUL_done;
    assign DIV_done_o  = DIV_done;

    DSP_Multiplier m_DSP_Multiplier(
        .clk(clk),
        .rst_n(rst_n),
        .start(MUL_DIV_start & is_MUL),
        .multiplicand(data1),
        .multiplier(data2),

        .MUL_DIV_ctrl(MUL_DIV_ctrl),

        .MUL_out(MUL_out),
        .MUL_done(MUL_done)
    );

    SRTDivider m_SRTDivider(
        .clk(clk),
        .rst_n(rst_n),
        .start(MUL_DIV_start & is_DIV),
        .remainder(data1),
        .divisor(data2),

        .MUL_DIV_ctrl(MUL_DIV_ctrl),

        .DIV_out(DIV_out),
        .DIV_done(DIV_done)
    );

endmodule
