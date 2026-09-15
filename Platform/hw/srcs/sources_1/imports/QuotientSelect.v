module QuotientSelect (
    input [65:0] r_1_i, //sign + 65 bits
    input [65:0] r_2_i, //sign + 65 bits
    input [33:0] d, //sign + 33 bits
    input [33:0] neg_d,

    input [31:0] pos_q,
    input [31:0] neg_q,

    output [65:0] r_1_o,
    output [65:0] r_2_o,
    output reg [31:0] pos_q_o,
    output reg [31:0] neg_q_o
);

    //Input: remainder in carry-save format
    //       divisor
    //       quotient
    //Output: above data in the next iteration
    
    wire [65:0] r_1, r_2;
    wire [5:0] r; 

    wire [7:0] pre_add_r;

    assign pre_add_r = r_1_i[65:58] + r_2_i[65:58];
    assign r = {pre_add_r[7], pre_add_r[4:0]};

    assign r_1 = {r,    r_1_i[57:0], 2'b0};
    assign r_2 = {6'b0, r_2_i[57:0], 2'b0};
    
    wire [5:0] d_p;
    wire [5:0] d_p_0_5;
    wire [5:0] d_p_1_5;
    wire [5:0] d_n;
    wire [5:0] d_n_0_5;
    wire [5:0] d_n_1_5;

    assign d_p = d[33:28];
    assign d_n = neg_d[33:28];

    assign d_p_0_5 = d_p >>> 1;
    assign d_n_0_5 = {d_n[5], d_n[5:1]};

    assign d_p_1_5 = d_p + d_p_0_5;
    assign d_n_1_5 = d_n + d_n_0_5;

    wire [2:0] q;

    assign q = r[5] ? ((r >= d_n_0_5) ? 3'b000 : (r >= d_n_1_5) ? 3'b111 : 3'b110):
                      ((r > d_p_1_5) ? 3'b010 : (r > d_p_0_5) ? 3'b001 : 3'b000);

    reg [65:0] sub;

    Compressor32 #(.WIDTH(66)) m_Compressor32(
        .in1(r_1),
        .in2(r_2),
        .in3(sub),
        .out1(r_1_o),
        .out2(r_2_o)
    );

    always @(*) begin
        case(q)
            3'b000: begin
                sub = 0;
                pos_q_o = {pos_q[29:0], 2'b00};
                neg_q_o = {neg_q[29:0], 2'b00};
            end
            3'b001: begin
                sub = {neg_d, 32'b0};
                pos_q_o = {pos_q[29:0], 2'b01};
                neg_q_o = {neg_q[29:0], 2'b00};
            end
            3'b010: begin
                sub = {(neg_d << 1), 32'b0};
                pos_q_o = {pos_q[29:0], 2'b10};
                neg_q_o = {neg_q[29:0], 2'b00};
            end
            3'b111: begin
                sub = {d, 32'b0};
                pos_q_o = {pos_q[29:0], 2'b00};
                neg_q_o = {neg_q[29:0], 2'b01};
            end
            3'b110: begin
                sub = {(d << 1), 32'b0};
                pos_q_o = {pos_q[29:0], 2'b00};
                neg_q_o = {neg_q[29:0], 2'b10};
            end
            default: begin
                sub = 0;
                pos_q_o = {pos_q[29:0], 2'b00};
                neg_q_o = {neg_q[29:0], 2'b10};
            end
        endcase
    end

endmodule
