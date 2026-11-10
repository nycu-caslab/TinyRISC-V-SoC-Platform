`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/21 19:38:15
// Design Name: 
// Module Name: dcache_axiBus_bridge
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module NPU (
    input clk,
    input rst_n,

    // CPU Interface //
    input      [31:0] rs1_i,
    input      [31:0] rs2_i,
    output reg [31:0] NPU_out,
    input             NPU_start,
    output reg        NPU_done,

    input [ 3:0] funct3_i,
    input [31:0] funct7_i,

    // AXI4 Master Interface (M_AXI) //
    // AW Channel
    //output  [3:0] M_AXI_AWID,
    output [31:0] M_AXI_AWADDR,
    output [7:0] M_AXI_AWLEN,
    output [2:0] M_AXI_AWSIZE,
    output [1:0] M_AXI_AWBURST,
    output M_AXI_AWLOCK,
    output [3:0] M_AXI_AWCACHE,
    output [2:0] M_AXI_AWPROT,
    output [3:0] M_AXI_AWQOS,
    output [15:0] M_AXI_AWUSER,
    output M_AXI_AWVALID,
    input M_AXI_AWREADY,
    // W Channel
    output [31:0] M_AXI_WDATA,
    output [3:0] M_AXI_WSTRB,
    output M_AXI_WLAST,
    output M_AXI_WVALID,
    input M_AXI_WREADY,

    // B Channel
    //input [3:0] M_AXI_BID,
    input [1:0] M_AXI_BRESP,
    //input [15:0] M_AXI_BUSER,
    input M_AXI_BVALID,
    output M_AXI_BREADY,

    // AR Channel
    //output  [3:0] M_AXI_ARID,
    output [31:0] M_AXI_ARADDR,
    output [7:0] M_AXI_ARLEN,
    output [2:0] M_AXI_ARSIZE,
    output [1:0] M_AXI_ARBURST,
    output M_AXI_ARLOCK,
    output [3:0] M_AXI_ARCACHE,
    output [2:0] M_AXI_ARPROT,
    output [3:0] M_AXI_ARQOS,
    output [15:0] M_AXI_ARUSER,
    output M_AXI_ARVALID,
    input M_AXI_ARREADY,

    // R Channel
    input [3:0] M_AXI_RID,
    input [31:0] M_AXI_RDATA,
    input [1:0] M_AXI_RRESP,
    input M_AXI_RLAST,
    input M_AXI_RVALID,
    output M_AXI_RREADY
);

    reg [31:0] axi_awaddr_r;
    reg        axi_awvalid_r;
    reg [31:0] axi_wdata_r;
    reg [3:0]  axi_wstrb_r;
    reg        axi_wlast_r;
    reg        axi_wvalid_r;
    assign M_AXI_AWSIZE  = 3'b010;
    assign M_AXI_AWBURST = 2'b01;
    assign M_AXI_AWLOCK  = 1'b0;
    assign M_AXI_AWCACHE = 4'b0011;
    assign M_AXI_AWPROT  = 3'b000;
    assign M_AXI_AWQOS   = 4'b0000;
    assign M_AXI_AWUSER  = 16'h0000;
    assign M_AXI_ARSIZE  = 3'b010;
    assign M_AXI_ARBURST = 2'b01;
    assign M_AXI_ARLOCK  = 1'b0;
    assign M_AXI_ARCACHE = 4'b0011;
    assign M_AXI_ARPROT  = 3'b000;
    assign M_AXI_ARQOS   = 4'b0000;
    assign M_AXI_ARUSER  = 16'h0000;

    localparam [3:0] STATE_IDLE              = 4'd0;
    localparam [3:0] STATE_COMP              = 4'd1;
    localparam [3:0] STATE_DONE              = 4'd2;
    localparam [3:0] STATE_AXI_READ_ADDR     = 4'd3;
    localparam [3:0] STATE_AXI_READ_DATA     = 4'd4;
    localparam [3:0] STATE_AXI_WRITE         = 4'd5;
    localparam [3:0] STATE_AXI_WRITE_RESP    = 4'd6;
    localparam [3:0] STATE_SIMD_MAC          = 4'd7;
    localparam [3:0] STATE_BURST_DOT_PRODUCT = 4'd8;
    localparam [3:0] STATE_LOGISTIC_BUILD    = 4'd9;
    localparam [3:0] STATE_LOGISTIC_LOOKUP   = 4'd10;
    localparam [3:0] STATE_TRANSPOSE         = 4'd11;
    localparam [3:0] STATE_TRANSPOSE_WAIT    = 4'd12;

    // Transpose (funct3 = 110), see npu_transpose.v:
    //   funct7 = 0: rs1 = input base, rs2 = output base.
    //   funct7 = 1: rs1 = element size in bytes.
    //   funct7 = 2: rs1 = hw dim (0..5, 5 innermost), rs2 = output extent.
    //   funct7 = 3: rs1 = hw dim, rs2 = signed input byte delta.
    //   funct7 = 4: run; NPU_done after the last output byte is written.
    localparam [2:0]  FUNCT3_TRANSPOSE = 3'b110;

    localparam [2:0]  FUNCT3_SIMD_MAC                 = 3'b011;
    localparam [31:0] FUNCT7_SIMD_MAC_RESET           = 32'd1;
    localparam [31:0] FUNCT7_SIMD_MAC_ACCUMULATE      = 32'd0;

    // Burst dot product (funct3 = 100):
    //   funct7 = 0: set the vector length in bytes (rs1); returns rs1.
    //   funct7 = 1: rd = sum int8(mem[rs1 + i]) * int8(mem[rs2 + i]) over
    //               the set length, streamed with AXI INCR read bursts.
    localparam [2:0]  FUNCT3_BURST_DOT_PRODUCT            = 3'b100;
    localparam [31:0] FUNCT7_BURST_DOT_PRODUCT_SET_LENGTH = 32'd0;
    localparam [31:0] FUNCT7_BURST_DOT_PRODUCT_COMPUTE    = 32'd1;

    // Logistic (funct3 = 101), int8 TFLM Logistic through a 256-entry table:
    //   funct7 = 0: rs1 = zero point, rs2 = input range radius; returns 0.
    //   funct7 = 1: rs1 = multiplier, rs2 = left shift (signed); builds the
    //               table; NPU_done only after the table is complete.
    //   funct7 = 2: rs1 = 4 packed int8 (lane 0 = bits [31:24]); rd = 4
    //               packed int8 logistic outputs.
    localparam [2:0]  FUNCT3_LOGISTIC            = 3'b101;
    localparam [31:0] FUNCT7_LOGISTIC_CONFIG     = 32'd0;
    localparam [31:0] FUNCT7_LOGISTIC_BUILD      = 32'd1;
    localparam [31:0] FUNCT7_LOGISTIC_COMPUTE    = 32'd2;

    reg [3:0] state_r;
    wire logistic_idle_start = (state_r == STATE_IDLE) && NPU_start &&
                               (funct3_i[2:0] == FUNCT3_LOGISTIC);
    wire logistic_busy;
    wire logistic_build_done;
    wire [31:0] logistic_lut_out;
    npu_logistic u_logistic (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_a_we         (logistic_idle_start && funct7_i == FUNCT7_LOGISTIC_CONFIG),
        .cfg_zero_point   (rs1_i),
        .cfg_range_radius (rs2_i),
        .build_start      (logistic_idle_start && funct7_i == FUNCT7_LOGISTIC_BUILD),
        .cfg_multiplier   (rs1_i),
        .cfg_shift        (rs2_i),
        .busy             (logistic_busy),
        .build_done       (logistic_build_done),
        .lookup_in        (rs1_i),
        .lut_out          (logistic_lut_out)
    );

    wire transpose_idle_cmd = (state_r == STATE_IDLE) && NPU_start &&
                              (funct3_i[2:0] == FUNCT3_TRANSPOSE);
    wire        t_done, t_arvalid, t_rready, t_awvalid, t_wvalid, t_bready;
    wire [31:0] t_araddr, t_awaddr, t_wdata;
    wire [3:0]  t_wstrb;
    reg         t_fast;
    wire        f_busy;
    wire        transpose_owns = (state_r == STATE_TRANSPOSE) || (t_fast && f_busy);
    // Fast (burst) transpose mode: selected by funct7=5, cleared by funct7=1.
    // funct7=4: start and wait; funct7=6: start, return immediately (fast mode
    // only); funct7=7: wait until the fast engine is idle.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) t_fast <= 1'b0;
        else if (transpose_idle_cmd) begin
            if (funct7_i == 32'd1) t_fast <= 1'b0;
            else if (funct7_i == 32'd5) t_fast <= 1'b1;
        end
    end
    wire        f_done, f_arvalid, f_rready, f_awvalid, f_wvalid, f_wlast, f_bready;
    wire [31:0] f_araddr, f_awaddr, f_wdata;
    wire [7:0]  f_arlen, f_awlen;
    npu_transpose_fast u_transpose_fast (
        .clk(clk), .rst_n(rst_n),
        .cfg_base_we (transpose_idle_cmd && funct7_i == 32'd0),
        .cfg_shape_we(transpose_idle_cmd && funct7_i == 32'd2),
        .cfg_adv_we  (transpose_idle_cmd && funct7_i == 32'd3),
        .cfg_fast_we (transpose_idle_cmd && funct7_i == 32'd5),
        .cfg_rs1(rs1_i), .cfg_rs2(rs2_i),
        .start(transpose_idle_cmd && (funct7_i == 32'd4 || funct7_i == 32'd6) && t_fast),
        .done(f_done), .busy(f_busy),
        .araddr(f_araddr), .arlen(f_arlen), .arvalid(f_arvalid), .arready(M_AXI_ARREADY),
        .rdata(M_AXI_RDATA), .rvalid(M_AXI_RVALID), .rready(f_rready),
        .awaddr(f_awaddr), .awlen(f_awlen), .awvalid(f_awvalid), .awready(M_AXI_AWREADY),
        .wdata(f_wdata), .wlast(f_wlast), .wvalid(f_wvalid), .wready(M_AXI_WREADY),
        .bvalid(M_AXI_BVALID), .bready(f_bready)
    );
    npu_transpose u_transpose (
        .clk(clk), .rst_n(rst_n),
        .cfg_base_we (transpose_idle_cmd && funct7_i == 32'd0),
        .cfg_esize_we(transpose_idle_cmd && funct7_i == 32'd1),
        .cfg_shape_we(transpose_idle_cmd && funct7_i == 32'd2),
        .cfg_adv_we  (transpose_idle_cmd && funct7_i == 32'd3),
        .cfg_rs1(rs1_i), .cfg_rs2(rs2_i),
        .start(transpose_idle_cmd && funct7_i == 32'd4 && !t_fast),
        .done(t_done),
        .araddr(t_araddr), .arvalid(t_arvalid), .arready(M_AXI_ARREADY),
        .rdata(M_AXI_RDATA), .rvalid(M_AXI_RVALID), .rready(t_rready),
        .awaddr(t_awaddr), .awvalid(t_awvalid), .awready(M_AXI_AWREADY),
        .wdata(t_wdata), .wstrb(t_wstrb), .wvalid(t_wvalid), .wready(M_AXI_WREADY),
        .bvalid(M_AXI_BVALID), .bready(t_bready)
    );
    assign M_AXI_AWADDR  = transpose_owns ? (t_fast ? f_awaddr : t_awaddr) : axi_awaddr_r;
    assign M_AXI_AWVALID = transpose_owns ? (t_fast ? f_awvalid : t_awvalid) : axi_awvalid_r;
    assign M_AXI_AWLEN   = (transpose_owns && t_fast) ? f_awlen : 8'h00;
    assign M_AXI_WDATA   = transpose_owns ? (t_fast ? f_wdata : t_wdata) : axi_wdata_r;
    assign M_AXI_WSTRB   = transpose_owns ? (t_fast ? 4'hF : t_wstrb) : axi_wstrb_r;
    assign M_AXI_WLAST   = transpose_owns ? (t_fast ? f_wlast : 1'b1) : axi_wlast_r;
    assign M_AXI_WVALID  = transpose_owns ? (t_fast ? f_wvalid : t_wvalid) : axi_wvalid_r;
    // Single-word AXI read (funct3 = 001) address channel registers.
    reg [31:0] axi_read_araddr_r;
    reg axi_read_arvalid_r;
    reg [31:0] burst_dot_product_length_r;

    wire burst_dot_product_start =
        (state_r == STATE_IDLE) && NPU_start &&
        (funct3_i[2:0] == FUNCT3_BURST_DOT_PRODUCT) &&
        (funct7_i == FUNCT7_BURST_DOT_PRODUCT_COMPUTE);
    wire burst_dot_product_owns_read = (state_r == STATE_BURST_DOT_PRODUCT);
    wire        burst_dot_product_done;
    wire [31:0] burst_dot_product_result;
    wire [31:0] burst_dot_product_araddr;
    wire [7:0]  burst_dot_product_arlen;
    wire        burst_dot_product_arvalid;
    wire        burst_dot_product_rready;

    npu_burst_dot_product u_burst_dot_product (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (burst_dot_product_start),
        .input_address  (rs1_i),
        .filter_address (rs2_i),
        .byte_length    (burst_dot_product_length_r),
        .done           (burst_dot_product_done),
        .result         (burst_dot_product_result),
        .m_axi_araddr   (burst_dot_product_araddr),
        .m_axi_arlen    (burst_dot_product_arlen),
        .m_axi_arvalid  (burst_dot_product_arvalid),
        .m_axi_arready  (M_AXI_ARREADY),
        .m_axi_rdata    (M_AXI_RDATA),
        .m_axi_rvalid   (M_AXI_RVALID),
        .m_axi_rready   (burst_dot_product_rready)
    );

    // The read channels belong to the burst engine while it runs and to the
    // single-word AXI read otherwise.
    assign M_AXI_ARADDR  = transpose_owns ? (t_fast ? f_araddr : t_araddr) :
                           burst_dot_product_owns_read ? burst_dot_product_araddr
                                                       : axi_read_araddr_r;
    assign M_AXI_ARLEN   = transpose_owns ? (t_fast ? f_arlen : 8'h00) : burst_dot_product_owns_read ? burst_dot_product_arlen
                                                       : 8'h00;
    assign M_AXI_ARVALID = transpose_owns ? (t_fast ? f_arvalid : t_arvalid) : burst_dot_product_owns_read ? burst_dot_product_arvalid
                                                       : axi_read_arvalid_r;
    assign M_AXI_RREADY  = transpose_owns ? (t_fast ? f_rready : t_rready) : burst_dot_product_owns_read ? burst_dot_product_rready
                                                       : (state_r == STATE_AXI_READ_DATA);
    assign M_AXI_BREADY  = (state_r == STATE_AXI_WRITE_RESP) || (transpose_owns && (t_fast ? f_bready : t_bready));
    reg [31:0] simd_mac_accumulator_r;
    reg [1:0] read_offset_r;
    reg [31:0] read_first_word_r;
    reg read_second_word_r;
    reg [31:0] write_second_data_r;
    reg [3:0] write_second_strb_r;
    reg write_second_pending_r;

    // Packed operands follow the Lab 1 convention: lane 0 is bits [31:24]
    // and lane 3 is bits [7:0]. Sign-extend each byte before multiplying.
    wire signed [15:0] input_lane0  = {{8{rs1_i[31]}}, rs1_i[31:24]};
    wire signed [15:0] input_lane1  = {{8{rs1_i[23]}}, rs1_i[23:16]};
    wire signed [15:0] input_lane2  = {{8{rs1_i[15]}}, rs1_i[15:8]};
    wire signed [15:0] input_lane3  = {{8{rs1_i[7]}},  rs1_i[7:0]};
    wire signed [15:0] filter_lane0 = {{8{rs2_i[31]}}, rs2_i[31:24]};
    wire signed [15:0] filter_lane1 = {{8{rs2_i[23]}}, rs2_i[23:16]};
    wire signed [15:0] filter_lane2 = {{8{rs2_i[15]}}, rs2_i[15:8]};
    wire signed [15:0] filter_lane3 = {{8{rs2_i[7]}},  rs2_i[7:0]};

    wire signed [31:0] simd_product0 = input_lane0 * filter_lane0;
    wire signed [31:0] simd_product1 = input_lane1 * filter_lane1;
    wire signed [31:0] simd_product2 = input_lane2 * filter_lane2;
    wire signed [31:0] simd_product3 = input_lane3 * filter_lane3;
    wire signed [31:0] simd_dot_product = simd_product0 + simd_product1 +
                                              simd_product2 + simd_product3;
    wire [63:0] read_word_pair = {M_AXI_RDATA, read_first_word_r};
    wire [31:0] reconstructed_read_data =
        read_word_pair >> {read_offset_r, 3'b000};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r                <= STATE_IDLE;
            NPU_out                <= 32'd0;
            NPU_done               <= 1'b0;
            simd_mac_accumulator_r <= 32'd0;
            read_offset_r          <= 2'b00;
            read_first_word_r      <= 32'd0;
            read_second_word_r    <= 1'b0;
            axi_read_araddr_r  <= 32'd0;
            axi_read_arvalid_r <= 1'b0;
            axi_awaddr_r  <= 32'd0;
            axi_awvalid_r <= 1'b0;
            axi_wdata_r   <= 32'd0;
            axi_wstrb_r   <= 4'b1111;
            axi_wlast_r   <= 1'b0;
            axi_wvalid_r  <= 1'b0;
            write_second_data_r    <= 32'd0;
            write_second_strb_r    <= 4'd0;
            write_second_pending_r <= 1'b0;
            burst_dot_product_length_r <= 32'd0;
        end else begin
            NPU_done <= 1'b0;
            case (state_r)
                STATE_IDLE: begin
                    NPU_done <= 1'b0;
                    if (NPU_start) begin
                        if (funct3_i[2:0] == 3'b000) begin
                            state_r <= STATE_COMP;
                        end else if (funct3_i[2:0] == 3'b001) begin
                            axi_read_araddr_r  <= {rs1_i[31:2], 2'b00};
                            axi_read_arvalid_r <= 1'b1;
                            read_offset_r      <= rs1_i[1:0];
                            read_second_word_r <= 1'b0;
                            state_r            <= STATE_AXI_READ_ADDR;
                        end else if (funct3_i[2:0] == 3'b010) begin
                            axi_awaddr_r  <= {rs1_i[31:2], 2'b00};
                            axi_awvalid_r <= 1'b1;
                            axi_wdata_r   <= rs2_i << {rs1_i[1:0], 3'b000};
                            axi_wstrb_r   <= 4'b1111 << rs1_i[1:0];
                            axi_wlast_r   <= 1'b1;
                            axi_wvalid_r  <= 1'b1;
                            write_second_data_r <= rs2_i >>
                                (6'd32 - {1'b0, rs1_i[1:0], 3'b000});
                            write_second_strb_r <=
                                (4'b0001 << rs1_i[1:0]) - 4'b0001;
                            write_second_pending_r <= (rs1_i[1:0] != 2'b00);
                            state_r       <= STATE_AXI_WRITE;
                        end else if (funct3_i[2:0] == FUNCT3_SIMD_MAC) begin
                            state_r <= STATE_SIMD_MAC;
                        end else if (funct3_i[2:0] == FUNCT3_BURST_DOT_PRODUCT) begin
                            if (funct7_i == FUNCT7_BURST_DOT_PRODUCT_SET_LENGTH) begin
                                burst_dot_product_length_r <= rs1_i;
                                NPU_out <= rs1_i;
                                state_r <= STATE_DONE;
                            end else if (funct7_i == FUNCT7_BURST_DOT_PRODUCT_COMPUTE) begin
                                state_r <= STATE_BURST_DOT_PRODUCT;
                            end else begin
                                state_r <= STATE_DONE;
                            end
                        end else if (funct3_i[2:0] == FUNCT3_TRANSPOSE) begin
                            NPU_out <= 32'd0;
                            state_r <= (funct7_i == 32'd4) ? STATE_TRANSPOSE :
                                       (funct7_i == 32'd7) ? STATE_TRANSPOSE_WAIT
                                                           : STATE_DONE;
                        end else if (funct3_i[2:0] == FUNCT3_LOGISTIC) begin
                            if (funct7_i == FUNCT7_LOGISTIC_BUILD) begin
                                state_r <= STATE_LOGISTIC_BUILD;
                            end else if (funct7_i == FUNCT7_LOGISTIC_COMPUTE) begin
                                state_r <= STATE_LOGISTIC_LOOKUP;
                            end else begin
                                NPU_out <= 32'd0;
                                state_r <= STATE_DONE;
                            end
                        end else begin
                            state_r <= STATE_DONE;
                        end
                    end
                end

                STATE_TRANSPOSE: begin
                    if (t_fast ? f_done : t_done) state_r <= STATE_DONE;
                end

                STATE_TRANSPOSE_WAIT: begin
                    if (!f_busy) state_r <= STATE_DONE;
                end

                STATE_LOGISTIC_BUILD: begin
                    if (logistic_build_done) begin
                        NPU_out <= 32'd0;
                        state_r <= STATE_DONE;
                    end
                end

                STATE_LOGISTIC_LOOKUP: begin
                    NPU_out <= logistic_lut_out;
                    state_r <= STATE_DONE;
                end

                STATE_COMP: begin
                    NPU_out <= rs1_i + rs2_i + funct7_i;
                    state_r <= STATE_DONE;
                end

                STATE_SIMD_MAC: begin
                    if (funct7_i == FUNCT7_SIMD_MAC_RESET) begin
                        simd_mac_accumulator_r <= simd_dot_product;
                        NPU_out                <= simd_dot_product;
                    end else if (funct7_i == FUNCT7_SIMD_MAC_ACCUMULATE) begin
                        simd_mac_accumulator_r <= simd_mac_accumulator_r +
                                                  simd_dot_product;
                        NPU_out <= simd_mac_accumulator_r + simd_dot_product;
                    end
                    state_r <= STATE_DONE;
                end

                STATE_BURST_DOT_PRODUCT: begin
                    if (burst_dot_product_done) begin
                        NPU_out <= burst_dot_product_result;
                        state_r <= STATE_DONE;
                    end
                end

                STATE_AXI_READ_ADDR: begin
                    if (axi_read_arvalid_r && M_AXI_ARREADY) begin
                        axi_read_arvalid_r <= 1'b0;
                        state_r       <= STATE_AXI_READ_DATA;
                    end else begin
                        state_r <= STATE_AXI_READ_ADDR;
                    end
                end

                STATE_AXI_READ_DATA: begin
                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        if ((read_offset_r != 2'b00) && !read_second_word_r) begin
                            read_first_word_r  <= M_AXI_RDATA;
                            axi_read_araddr_r  <= axi_read_araddr_r + 32'd4;
                            axi_read_arvalid_r <= 1'b1;
                            read_second_word_r <= 1'b1;
                            state_r            <= STATE_AXI_READ_ADDR;
                        end else begin
                            if (read_second_word_r) begin
                                NPU_out <= reconstructed_read_data;
                            end else begin
                                NPU_out <= M_AXI_RDATA;
                            end
                            read_second_word_r <= 1'b0;
                            state_r            <= STATE_DONE;
                        end
                    end else begin
                        state_r <= STATE_AXI_READ_DATA;
                    end
                end

                STATE_AXI_WRITE: begin
                    if (axi_awvalid_r && M_AXI_AWREADY) begin
                        axi_awvalid_r <= 1'b0;
                    end
                    if (axi_wvalid_r && M_AXI_WREADY) begin
                        axi_wvalid_r <= 1'b0;
                        axi_wlast_r  <= 1'b0;
                    end
                    if ((!axi_awvalid_r || M_AXI_AWREADY) &&
                        (!axi_wvalid_r || M_AXI_WREADY)) begin
                        state_r <= STATE_AXI_WRITE_RESP;
                    end
                end

                STATE_AXI_WRITE_RESP: begin
                    if (M_AXI_BVALID && M_AXI_BREADY) begin
                        if (write_second_pending_r) begin
                            axi_awaddr_r  <= axi_awaddr_r + 32'd4;
                            axi_awvalid_r <= 1'b1;
                            axi_wdata_r   <= write_second_data_r;
                            axi_wstrb_r   <= write_second_strb_r;
                            axi_wlast_r   <= 1'b1;
                            axi_wvalid_r  <= 1'b1;
                            write_second_pending_r <= 1'b0;
                            state_r <= STATE_AXI_WRITE;
                        end else begin
                            state_r <= STATE_DONE;
                        end
                    end
                end

                STATE_DONE: begin
                    NPU_done <= 1'b1;
                    state_r  <= STATE_IDLE;
                end

                default: state_r <= STATE_IDLE;
            endcase
        end
    end
endmodule
