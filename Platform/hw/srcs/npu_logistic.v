`timescale 1ns / 1ps
// int8 Logistic table engine (bit-exact with TFLM reference_integer_ops::Logistic).
// build_start computes all 256 table entries sequentially with one shared
// 32x32 multiplier (operand register -> product register -> srdhm), then
// lookup returns 4 table bytes (one per lane) in one cycle.
module npu_logistic (
    input             clk,
    input             rst_n,
    // configuration
    input             cfg_a_we,          // zero point, range radius
    input      [31:0] cfg_zero_point,
    input      [31:0] cfg_range_radius,
    input             build_start,       // multiplier, shift; starts the build
    input      [31:0] cfg_multiplier,
    input      [31:0] cfg_shift,
    output reg        busy,
    output reg        build_done,        // one-cycle pulse
    // lookup: lane i of lookup_in indexes table copy i; lut_out valid next cycle
    input      [31:0] lookup_in,
    output     [31:0] lut_out
);
    localparam signed [31:0] I32_MAX = 32'sh7fffffff;
    localparam signed [31:0] I32_MIN = 32'sh80000000;

    reg signed [31:0] zp_r, radius_r, mult_r, shift_r;

    // ---- table: 4 copies, one read port each ----
    reg [7:0] tab0 [0:255];
    reg [7:0] tab1 [0:255];
    reg [7:0] tab2 [0:255];
    reg [7:0] tab3 [0:255];
    reg [7:0] lq0, lq1, lq2, lq3;
    assign lut_out = {lq0, lq1, lq2, lq3};
    reg        tab_we;
    reg [7:0]  tab_waddr;
    reg [7:0]  tab_wdata;
    always @(posedge clk) begin
        if (tab_we) begin
            tab0[tab_waddr] <= tab_wdata;
            tab1[tab_waddr] <= tab_wdata;
            tab2[tab_waddr] <= tab_wdata;
            tab3[tab_waddr] <= tab_wdata;
        end
        lq0 <= tab0[lookup_in[31:24] ^ 8'h80];
        lq1 <= tab1[lookup_in[23:16] ^ 8'h80];
        lq2 <= tab2[lookup_in[15:8]  ^ 8'h80];
        lq3 <= tab3[lookup_in[7:0]   ^ 8'h80];
    end

    // ---- primitives ----
    function signed [31:0] rdivpot;
        input signed [31:0] x;
        input [5:0] e;
        reg [31:0] mask, rem, thr;
        begin
            mask = (32'd1 << e) - 32'd1;
            rem  = x & mask;
            thr  = (mask >> 1) + (x[31] ? 32'd1 : 32'd0);
            rdivpot = (x >>> e) + ((rem > thr) ? 32'sd1 : 32'sd0);
        end
    endfunction

    function signed [31:0] satshl2;
        input signed [31:0] a;
        begin
            if (a > (I32_MAX >>> 2)) satshl2 = I32_MAX;
            else if (a < (I32_MIN >>> 2)) satshl2 = I32_MIN;
            else satshl2 = a <<< 2;
        end
    endfunction
    function signed [31:0] satshl1;
        input signed [31:0] a;
        begin
            if (a > (I32_MAX >>> 1)) satshl1 = I32_MAX;
            else if (a < (I32_MIN >>> 1)) satshl1 = I32_MIN;
            else satshl1 = a <<< 1;
        end
    endfunction

    function signed [31:0] mult_k;
        input [2:0] k;
        begin
            case (k)
                3'd0: mult_k = 32'sd1672461947;
                3'd1: mult_k = 32'sd1302514674;
                3'd2: mult_k = 32'sd790015084;
                3'd3: mult_k = 32'sd290630308;
                3'd4: mult_k = 32'sd39332535;
                default: mult_k = 32'sd720401;
            endcase
        end
    endfunction

    // ---- datapath registers ----
    localparam [4:0] S_IDLE = 5'd0,  S_PREP = 5'd1,  S_MQ = 5'd2,   S_SIGN = 5'd3,
                     S_X2 = 5'd4,    S_X3 = 5'd5,    S_X4 = 5'd6,   S_T = 5'd7,
                     S_P = 5'd8,     S_MR = 5'd9,    S_LOOP = 5'd10, S_EXPEND = 5'd11,
                     S_HD = 5'd12,   S_H0 = 5'd13,   S_IA = 5'd14,  S_IB = 5'd15,
                     S_FIN = 5'd16,  S_OUT = 5'd17,  S_WR = 5'd18;
    reg [4:0] st;
    reg [1:0] ph;
    reg [7:0] idx;
    reg signed [31:0] vs_r, q4_r, x_r, x2_r, x3_r, x4_r, t_r, p_r, res_r, hd_r, xn_r, sig_r;
    reg signed [31:0] aneg_r, rem_r, omh_r;
    reg        pos_r;
    reg [2:0]  k_r;
    reg [1:0]  it_r;
    reg [7:0]  obyte_r;
    reg signed [31:0] opa_r, opb_r;
    reg signed [63:0] prod_r;
    reg        ovf_r;

    // in = idx - 128 (int8). v = in - zp.
    wire signed [31:0] in_w = $signed({24'd0, idx}) - 32'sd128;
    wire signed [31:0] vv_w = in_w - zp_r;

    wire [5:0] ls_w = (shift_r > 0) ? shift_r[5:0] : 6'd0;
    wire [5:0] rs_w = (shift_r > 0) ? 6'd0 : (-shift_r);

    // srdhm result from registered product
    wire signed [63:0] nudge_w = prod_r[63] ? (64'sd1 - 64'sd1073741824) : 64'sd1073741824;
    wire signed [63:0] sum_w   = prod_r + nudge_w;
    wire signed [63:0] div_w   = sum_w[63] ? ((sum_w + 64'sd2147483647) >>> 31) : (sum_w >>> 31);
    wire signed [31:0] res_w   = ovf_r ? I32_MAX : div_w[31:0];

    wire signed [31:0] x4q_w   = rdivpot(x4_r, 6'd2);
    wire signed [32:0] hs_w    = {res_r[31], res_r} + 33'sd2147483647;
    wire signed [32:0] hs1_w   = hs_w + (hs_w[32] ? -33'sd1 : 33'sd1);
    wire signed [32:0] hd_w    = hs1_w[32] ? ((hs1_w + 33'sd1) >>> 1) : (hs1_w >>> 1);

    wire signed [31:0] rdiv23_w = rdivpot(sig_r, 6'd23);
    wire signed [31:0] o_w      = rdiv23_w - 32'sd128;

    // Q4.27 operands
    wire signed [31:0] ab_w     = q4_r[31] ? -q4_r : q4_r;
    wire signed [31:0] aneg_w   = -ab_w;
    wire signed [31:0] amq_w    = (aneg_w & 32'sh01ffffff) - 32'sd33554432;
    wire signed [31:0] x_in_w   = (amq_w <<< 4) + 32'sd268435456;
    wire signed [31:0] rem_in_w = amq_w - aneg_w;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zp_r <= 0; radius_r <= 0; mult_r <= 0; shift_r <= 0;
            busy <= 1'b0; build_done <= 1'b0; st <= S_IDLE; ph <= 2'd0; idx <= 8'd0;
            tab_we <= 1'b0; tab_waddr <= 8'd0; tab_wdata <= 8'd0;
            vs_r <= 0; q4_r <= 0; x_r <= 0; x2_r <= 0; x3_r <= 0; x4_r <= 0; t_r <= 0;
            p_r <= 0; res_r <= 0; hd_r <= 0; xn_r <= 0; sig_r <= 0; aneg_r <= 0;
            rem_r <= 0; omh_r <= 0; pos_r <= 1'b0; k_r <= 0; it_r <= 0; obyte_r <= 0;
            opa_r <= 0; opb_r <= 0; prod_r <= 0; ovf_r <= 1'b0;
        end else begin
            build_done <= 1'b0;
            tab_we <= 1'b0;
            if (cfg_a_we && !busy) begin
                zp_r <= cfg_zero_point;
                radius_r <= cfg_range_radius;
            end
            if (build_start && !busy) begin
                mult_r <= cfg_multiplier;
                shift_r <= cfg_shift;
                busy <= 1'b1;
                idx <= 8'd0;
                st <= S_PREP;
                ph <= 2'd0;
            end else if (busy) begin
                case (ph)
                2'd0: begin
                    case (st)
                    S_PREP: begin
                        if (vv_w <= -radius_r) begin
                            obyte_r <= 8'h80; st <= S_WR;
                        end else if (vv_w >= radius_r) begin
                            obyte_r <= 8'h7f; st <= S_WR;
                        end else begin
                            vs_r <= vv_w <<< ls_w;
                            st <= S_MQ;
                        end
                    end
                    S_MQ: begin
                        opa_r <= vs_r; opb_r <= mult_r;
                        ovf_r <= (vs_r == I32_MIN) && (mult_r == I32_MIN);
                        ph <= 2'd1;
                    end
                    S_SIGN: begin
                        if (q4_r == 0) begin
                            sig_r <= 32'sd1073741824; st <= S_OUT;
                        end else begin
                            pos_r  <= !q4_r[31];
                            aneg_r <= aneg_w;
                            x_r    <= x_in_w;
                            rem_r  <= rem_in_w;
                            st <= S_X2;
                        end
                    end
                    S_X2: begin opa_r <= x_r;  opb_r <= x_r;  ovf_r <= (x_r == I32_MIN); ph <= 2'd1; end
                    S_X3: begin opa_r <= x2_r; opb_r <= x_r;  ovf_r <= (x2_r == I32_MIN) && (x_r == I32_MIN); ph <= 2'd1; end
                    S_X4: begin opa_r <= x2_r; opb_r <= x2_r; ovf_r <= (x2_r == I32_MIN); ph <= 2'd1; end
                    S_T: begin
                        opa_r <= x4q_w + x3_r; opb_r <= 32'sd715827883;
                        ovf_r <= 1'b0; ph <= 2'd1;
                    end
                    S_P: begin
                        p_r <= rdivpot(t_r + x2_r, 6'd1);
                        st <= S_MR;
                    end
                    S_MR: begin
                        opa_r <= 32'sd1895147668; opb_r <= x_r + p_r;
                        ovf_r <= 1'b0; ph <= 2'd1;
                    end
                    S_LOOP: begin
                        if (k_r == 3'd6) begin
                            st <= S_EXPEND;
                        end else if (rem_r[25 + k_r]) begin
                            opa_r <= res_r; opb_r <= mult_k(k_r);
                            ovf_r <= 1'b0; ph <= 2'd1;
                        end else begin
                            k_r <= k_r + 3'd1;
                        end
                    end
                    S_EXPEND: begin
                        if (aneg_r == 0) res_r <= I32_MAX;
                        st <= S_HD;
                    end
                    S_HD: begin
                        hd_r <= hd_w[31:0];
                        st <= S_H0;
                    end
                    S_H0: begin
                        opa_r <= hd_r; opb_r <= -32'sd1010580540;
                        ovf_r <= 1'b0; ph <= 2'd1;
                    end
                    S_IA: begin
                        opa_r <= hd_r; opb_r <= xn_r;
                        ovf_r <= (hd_r == I32_MIN) && (xn_r == I32_MIN); ph <= 2'd1;
                    end
                    S_IB: begin
                        opa_r <= xn_r; opb_r <= omh_r;
                        ovf_r <= (xn_r == I32_MIN) && (omh_r == I32_MIN); ph <= 2'd1;
                    end
                    S_FIN: begin
                        // r = satshl(x, 1); sig = pos ? r : MAX - r
                        sig_r <= pos_r ? satshl1(xn_r) : (I32_MAX - satshl1(xn_r));
                        st <= S_OUT;
                    end
                    S_OUT: begin
                        obyte_r <= (o_w < -32'sd128) ? 8'h80 : (o_w > 32'sd127) ? 8'h7f : o_w[7:0];
                        st <= S_WR;
                    end
                    S_WR: begin
                        tab_we <= 1'b1; tab_waddr <= idx; tab_wdata <= obyte_r;
                        if (idx == 8'd255) begin
                            busy <= 1'b0; build_done <= 1'b1; st <= S_IDLE;
                        end else begin
                            idx <= idx + 8'd1; st <= S_PREP;
                        end
                    end
                    default: st <= S_IDLE;
                    endcase
                end
                2'd1: begin
                    prod_r <= opa_r * opb_r;
                    ph <= 2'd2;
                end
                default: begin
                    ph <= 2'd0;
                    case (st)
                    S_MQ:  begin q4_r <= rdivpot(res_w, rs_w); st <= S_SIGN; end
                    S_X2:  begin x2_r <= res_w; st <= S_X3; end
                    S_X3:  begin x3_r <= res_w; st <= S_X4; end
                    S_X4:  begin x4_r <= res_w; st <= S_T; end
                    S_T:   begin t_r  <= res_w; st <= S_P; end
                    S_MR:  begin res_r <= 32'sd1895147668 + res_w; k_r <= 3'd0; st <= S_LOOP; end
                    S_LOOP: begin res_r <= res_w; k_r <= k_r + 3'd1; end
                    S_H0:  begin xn_r <= 32'sd1515870810 + res_w; it_r <= 2'd0; st <= S_IA; end
                    S_IA:  begin omh_r <= 32'sd536870912 - res_w; st <= S_IB; end
                    S_IB:  begin
                        xn_r <= xn_r + satshl2(res_w);
                        it_r <= it_r + 2'd1;
                        st <= (it_r == 2'd2) ? S_FIN : S_IA;
                    end
                    default: st <= S_IDLE;
                    endcase
                end
                endcase
            end
        end
    end
endmodule
