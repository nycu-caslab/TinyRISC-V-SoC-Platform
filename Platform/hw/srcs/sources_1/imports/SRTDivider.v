module SRTDivider (
    input clk,
    input rst_n,
    input start,
    input wire [31:0] remainder,
    input wire [31:0] divisor,

    input wire [2:0] MUL_DIV_ctrl,

    output wire [31:0] DIV_out,
    output wire DIV_done
);

    // start
    wire unsign;
    wire rem;
    assign unsign = MUL_DIV_ctrl[0];
    assign rem = MUL_DIV_ctrl[1];

    wire remainder_sign;
    wire divisor_sign;
    assign remainder_sign = remainder[31];
    assign divisor_sign = divisor[31];

    wire [31:0] abs_remainder;
    wire [31:0] abs_divisor;
    assign abs_remainder = remainder_sign & (~unsign) ? -remainder : remainder;
    assign abs_divisor = divisor_sign & (~unsign) ? -divisor : divisor;

    // for normalize
    wire [65:0] r_o [3:0];
    wire [33:0] d_o [3:0];
    wire [4:0] shift_o [3:0];

    // processing
    wire [65:0] r_1 [15:0]; // sign + 65 bits 
    wire [65:0] r_2 [15:0];

    wire [31:0] pos_q [15:0];
    wire [31:0] neg_q [15:0];

    // end
    wire [31:0] quotient;
    wire [31:0] remain;

    wire [31:0] q;
    wire [65:0] r;

    // Pipeline-register outputs are declared before the restoration logic
    // that reads their final stages.  Some tools reject implicit forward nets.
    wire r_start_o[20:0];
    wire [31:0] r_r_o [20:0];
    wire [33:0] r_d_o [20:0];
    wire [33:0] r_neg_d_o [20:0];
    wire [65:0] r_r_1_o [20:0];
    wire [65:0] r_r_2_o [20:0];
    wire [31:0] r_pos_q_o [20:0];
    wire [31:0] r_neg_q_o [20:0];
    wire [4:0] r_shift_o [20:0];
    wire r_r_sign_o [20:0];
    wire r_d_sign_o [20:0];
    wire r_unsign_o [20:0];
    wire r_rem_o [20:0];

    assign q = r_pos_q_o[19] - r_neg_q_o[19]; // for restoration (18)
    assign r = r_r_1_o[19] + r_r_2_o[19]; // for restoration (18)

    wire [31:0] q_out; // final process (19)
    wire [33:0] r_out; // final process (19)
    wire d_zero;

    assign q_out = r_pos_q_o[20] - r_neg_q_o[20];
    assign r_out = (r_r_1_o[20][65:32] + r_r_2_o[20][65:32]) >>> r_shift_o[20];
    assign d_zero = ~(|r_d_o[20]);

    assign quotient = d_zero ? -1 : (r_r_sign_o[20] ^ r_d_sign_o[20]) & (~r_unsign_o[20]) ? -q_out : q_out; // divide by 0: q = -1
    assign remain = d_zero ? r_r_o[20] : r_r_sign_o[20] & (~r_unsign_o[20]) ? -r_out[31:0] : r_out[31:0]; // divide by 0: r = r_input

    assign DIV_out = r_rem_o[20] ? remain : quotient;
    assign DIV_done = r_start_o[20];

    // stage EX0
    DivideLeftShift m_DivideLeftShift(
        .r_i({{34'b0}, abs_remainder}),
        .d_i({{ 2'b0}, abs_divisor}),
        .shift_i(5'b0),
        .r_o(r_o[0]),
        .d_o(d_o[0]),
        .shift_o(shift_o[0])
    );

    DIV_Reg m_DIV_0_Reg(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start),
        .r_i(remainder),
        .d_i(d_o[0]),
        .neg_d_i(-d_o[0]),
        .r_1_i(r_o[0]),
        .r_2_i(66'b0),
        .pos_q_i(32'b0),
        .neg_q_i(32'b0),
        .shift_i(shift_o[0]),
        .r_sign_i(remainder_sign),
        .d_sign_i(divisor_sign),
        .unsign_i(unsign),
        .rem_i(rem),

        .start_o(r_start_o[0]),
        .r_o(r_r_o[0]),
        .d_o(r_d_o[0]),
        .neg_d_o(r_neg_d_o[0]),
        .r_1_o(r_r_1_o[0]),
        .r_2_o(r_r_2_o[0]),
        .pos_q_o(r_pos_q_o[0]),
        .neg_q_o(r_neg_q_o[0]),
        .shift_o(r_shift_o[0]),
        .r_sign_o(r_r_sign_o[0]),
        .d_sign_o(r_d_sign_o[0]),
        .unsign_o(r_unsign_o[0]),
        .rem_o(r_rem_o[0])
    );

    genvar g_i;
    generate
        for (g_i = 0; g_i < 3; g_i = g_i + 1) begin: m_DIV_Shifters
            DivideLeftShift m_DivideLeftShift(
                .r_i(r_r_1_o[g_i]),
                .d_i(r_d_o[g_i]),
                .shift_i(r_shift_o[g_i]),
                .r_o(r_o[g_i + 1]),
                .d_o(d_o[g_i + 1]),
                .shift_o(shift_o[g_i + 1])
            );
        end

        for (g_i = 0; g_i < 3; g_i = g_i + 1) begin: m_DIV_Shifting_Regs
            DIV_Reg m_DIV_Reg(
                .clk(clk),
                .rst_n(rst_n),
                .start_i(r_start_o[g_i]),
                .r_i(r_r_o[g_i]),
                .d_i(d_o[g_i + 1]),
                .neg_d_i(-d_o[g_i + 1]),
                .r_1_i(r_o[g_i + 1]),
                .r_2_i(66'b0),
                .pos_q_i(32'b0),
                .neg_q_i(32'b0),
                .shift_i(shift_o[g_i + 1]),
                .r_sign_i(r_r_sign_o[g_i]),
                .d_sign_i(r_d_sign_o[g_i]),
                .unsign_i(r_unsign_o[g_i]),
                .rem_i(r_rem_o[g_i]),

                .start_o(r_start_o[g_i + 1]),
                .r_o(r_r_o[g_i + 1]),
                .d_o(r_d_o[g_i + 1]),
                .neg_d_o(r_neg_d_o[g_i + 1]),
                .r_1_o(r_r_1_o[g_i + 1]),
                .r_2_o(r_r_2_o[g_i + 1]),
                .pos_q_o(r_pos_q_o[g_i + 1]),
                .neg_q_o(r_neg_q_o[g_i + 1]),
                .shift_o(r_shift_o[g_i + 1]),
                .r_sign_o(r_r_sign_o[g_i + 1]),
                .d_sign_o(r_d_sign_o[g_i + 1]),
                .unsign_o(r_unsign_o[g_i + 1]),
                .rem_o(r_rem_o[g_i + 1])
            );
        end
    endgenerate

    generate
        for (g_i = 3; g_i < 19; g_i = g_i + 1) begin: m_QuotientSelects
            QuotientSelect m_QuotientSelect(
                .r_1_i(r_r_1_o[g_i]), // cur reg
                .r_2_i(r_r_2_o[g_i]),
                .d(r_d_o[g_i]),
                .neg_d(r_neg_d_o[g_i]),
                .pos_q(r_pos_q_o[g_i]),
                .neg_q(r_neg_q_o[g_i]),
                .r_1_o(r_1[g_i - 3]), // cur QS
                .r_2_o(r_2[g_i - 3]),
                .pos_q_o(pos_q[g_i - 3]),
                .neg_q_o(neg_q[g_i - 3])
            );
        end

        for (g_i = 3; g_i < 19; g_i = g_i + 1) begin: m_DIV_Processing_Regs // last iteration output: r_*[19]
            DIV_Reg m_DIV_Reg(
                .clk(clk),
                .rst_n(rst_n),
                .start_i(r_start_o[g_i]),
                .r_i(r_r_o[g_i]),
                .d_i(r_d_o[g_i]),
                .neg_d_i(r_neg_d_o[g_i]),
                .r_1_i(r_1[g_i - 3]), // last QS
                .r_2_i(r_2[g_i - 3]), // last QS
                .pos_q_i(pos_q[g_i - 3]), // last QS
                .neg_q_i(neg_q[g_i - 3]), // last QS
                .shift_i(r_shift_o[g_i]),
                .r_sign_i(r_r_sign_o[g_i]),
                .d_sign_i(r_d_sign_o[g_i]),
                .unsign_i(r_unsign_o[g_i]),
                .rem_i(r_rem_o[g_i]),

                .start_o(r_start_o[g_i + 1]),
                .r_o(r_r_o[g_i + 1]),
                .d_o(r_d_o[g_i + 1]),
                .neg_d_o(r_neg_d_o[g_i + 1]),
                .r_1_o(r_r_1_o[g_i + 1]),
                .r_2_o(r_r_2_o[g_i + 1]),
                .pos_q_o(r_pos_q_o[g_i + 1]),
                .neg_q_o(r_neg_q_o[g_i + 1]),
                .shift_o(r_shift_o[g_i + 1]),
                .r_sign_o(r_r_sign_o[g_i + 1]),
                .d_sign_o(r_d_sign_o[g_i + 1]),
                .unsign_o(r_unsign_o[g_i + 1]),
                .rem_o(r_rem_o[g_i + 1])
            );
        end
    endgenerate

    DIV_Reg m_DIV_20_Reg(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(r_start_o[19]),
        .r_i(r_r_o[19]),
        .d_i(r_d_o[19]),
        .neg_d_i(r_neg_d_o[19]),
        .r_1_i(r), // remainder 1&2 is added to know if the r is pos or neg 
        .r_2_i(r[65] ? {r_d_o[19], 32'b0} : 0), // if r is neg, restore 1 divisor
        .pos_q_i(r_pos_q_o[19]),
        .neg_q_i(r[65] ? {r_neg_q_o[19][31:2], |(r_neg_q_o[19][1:0]), ~r_neg_q_o[19][0]} : r_neg_q_o[19]), // if r is neg, restore quotient by adding -1
        .shift_i(r_shift_o[19]),
        .r_sign_i(r_r_sign_o[19]),
        .d_sign_i(r_d_sign_o[19]),
        .unsign_i(r_unsign_o[19]),
        .rem_i(r_rem_o[19]),

        .start_o(r_start_o[20]),
        .r_o(r_r_o[20]),
        .d_o(r_d_o[20]),
        .neg_d_o(r_neg_d_o[20]),
        .r_1_o(r_r_1_o[20]),
        .r_2_o(r_r_2_o[20]),
        .pos_q_o(r_pos_q_o[20]),
        .neg_q_o(r_neg_q_o[20]),
        .shift_o(r_shift_o[20]),
        .r_sign_o(r_r_sign_o[20]),
        .d_sign_o(r_d_sign_o[20]),
        .unsign_o(r_unsign_o[20]),
        .rem_o(r_rem_o[20])
    );

endmodule
