`timescale 1ns / 1ps
// Tensor transpose engine (CUSTOM-0 funct3 = 110), up to 6 dimensions, any
// element size 1..255 bytes. The engine walks the OUTPUT tensor in row-major
// order; the CPU supplies, per output dimension, the extent and the signed
// input byte delta applied when that dimension is the one that increments
// (i.e. stride[d] - sum_{e>d} (extent[e]-1)*stride[e], in bytes). The engine
// fetches input bytes with single-beat AXI reads (one-word read cache) and
// writes the output as packed words with byte strobes. No multiplier.
module npu_transpose (
    input             clk,
    input             rst_n,

    // configuration (one-cycle strobes from NPU.v)
    input             cfg_base_we,    // rs1 = input base, rs2 = output base
    input             cfg_esize_we,   // rs1 = element size in bytes
    input             cfg_shape_we,   // rs1 = hw dim (0..5), rs2 = extent
    input             cfg_adv_we,     // rs1 = hw dim (0..5), rs2 = signed byte delta
    input      [31:0] cfg_rs1,
    input      [31:0] cfg_rs2,
    input             start,
    output reg        done,

    // AXI master (single beat)
    output reg [31:0] araddr,
    output reg        arvalid,
    input             arready,
    input      [31:0] rdata,
    input             rvalid,
    output            rready,
    output reg [31:0] awaddr,
    output reg        awvalid,
    input             awready,
    output reg [31:0] wdata,
    output reg [3:0]  wstrb,
    output reg        wvalid,
    input             wready,
    input             bvalid,
    output            bready
);
    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_FETCH = 3'd1;
    localparam [2:0] S_AR    = 3'd2;
    localparam [2:0] S_R     = 3'd3;
    localparam [2:0] S_PUT   = 3'd4;
    localparam [2:0] S_WR    = 3'd5;
    localparam [2:0] S_B     = 3'd6;

    reg [2:0]  state;
    reg [31:0] in_base, out_base_r;
    reg [7:0]  esize;
    reg [31:0] shape [0:5];
    reg [31:0] adv   [0:5];
    reg [31:0] coord [0:5];
    reg [31:0] in_off;
    reg [31:0] out_addr;
    reg [7:0]  bcnt;
    reg        rd_valid;
    reg [29:0] rd_tag;
    reg [31:0] rd_data;
    reg        last_pending;   // final byte of final element already placed

    wire [31:0] byte_addr = in_base + in_off + {24'd0, bcnt};
    wire [7:0]  cur_byte  = rd_data >> {byte_addr[1:0], 3'b000};
    wire        hit       = rd_valid && (rd_tag == byte_addr[31:2]);
    wire        elem_end  = (bcnt == esize - 8'd1);
    wire [1:0]  lane      = out_addr[1:0];

    // Innermost (highest-index) hardware dimension that can still increment.
    reg        any_inc_r;
    reg [2:0]  inc_d_r;
    integer j;
    always @* begin
        any_inc_r = 1'b0;
        inc_d_r   = 3'd0;
        for (j = 5; j >= 0; j = j - 1) begin
            if (!any_inc_r && (coord[j] + 32'd1 < shape[j])) begin
                any_inc_r = 1'b1;
                inc_d_r   = j[2:0];
            end
        end
    end

    assign rready = (state == S_R);
    assign bready = (state == S_B);

    wire put_flush = (lane == 2'd3) || (elem_end && !any_inc_r);

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; done <= 1'b0;
            in_base <= 32'd0; out_base_r <= 32'd0; esize <= 8'd1;
            in_off <= 32'd0; out_addr <= 32'd0; bcnt <= 8'd0;
            rd_valid <= 1'b0; rd_tag <= 30'd0; rd_data <= 32'd0;
            araddr <= 32'd0; arvalid <= 1'b0;
            awaddr <= 32'd0; awvalid <= 1'b0;
            wdata <= 32'd0; wstrb <= 4'd0; wvalid <= 1'b0;
            last_pending <= 1'b0;
            for (i = 0; i < 6; i = i + 1) begin
                shape[i] <= 32'd1; adv[i] <= 32'd0; coord[i] <= 32'd0;
            end
        end else begin
            done <= 1'b0;
            if (cfg_base_we) begin in_base <= cfg_rs1; out_base_r <= cfg_rs2; end
            if (cfg_esize_we) esize <= cfg_rs1[7:0];
            if (cfg_shape_we && cfg_rs1 < 6) shape[cfg_rs1[2:0]] <= cfg_rs2;
            if (cfg_adv_we && cfg_rs1 < 6)   adv[cfg_rs1[2:0]]   <= cfg_rs2;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        for (i = 0; i < 6; i = i + 1) coord[i] <= 32'd0;
                        in_off <= 32'd0;
                        out_addr <= out_base_r;
                        bcnt <= 8'd0;
                        rd_valid <= 1'b0;
                        wstrb <= 4'd0;
                        last_pending <= 1'b0;
                        state <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    if (hit) begin
                        state <= S_PUT;
                    end else begin
                        araddr  <= {byte_addr[31:2], 2'b00};
                        arvalid <= 1'b1;
                        state   <= S_AR;
                    end
                end

                S_AR: begin
                    if (arvalid && arready) begin
                        arvalid <= 1'b0;
                        state   <= S_R;
                    end
                end

                S_R: begin
                    if (rvalid) begin
                        rd_data  <= rdata;
                        rd_tag   <= araddr[31:2];
                        rd_valid <= 1'b1;
                        state    <= S_PUT;
                    end
                end

                S_PUT: begin
                    wdata[{lane, 3'b000} +: 8] <= cur_byte;
                    wstrb[lane] <= 1'b1;
                    awaddr <= {out_addr[31:2], 2'b00};
                    out_addr <= out_addr + 32'd1;
                    if (elem_end) begin
                        bcnt <= 8'd0;
                        if (any_inc_r) begin
                            for (i = 0; i < 6; i = i + 1) begin
                                if (i > inc_d_r) coord[i] <= 32'd0;
                                else if (i == inc_d_r) coord[i] <= coord[i] + 32'd1;
                            end
                            in_off <= in_off + adv[inc_d_r];
                        end
                    end else begin
                        bcnt <= bcnt + 8'd1;
                    end
                    last_pending <= elem_end && !any_inc_r;
                    if (put_flush) begin
                        awvalid <= 1'b1;
                        wvalid  <= 1'b1;
                        state   <= S_WR;
                    end else begin
                        state <= S_FETCH;
                    end
                end

                S_WR: begin
                    if (awvalid && awready) awvalid <= 1'b0;
                    if (wvalid && wready)   wvalid  <= 1'b0;
                    if ((!awvalid || awready) && (!wvalid || wready))
                        state <= S_B;
                end

                S_B: begin
                    if (bvalid) begin
                        wstrb <= 4'd0;
                        if (last_pending) begin
                            done  <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            state <= S_FETCH;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
