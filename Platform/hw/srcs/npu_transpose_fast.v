`timescale 1ns / 1ps
// funct7 = 4 starts and waits for completion; funct7 = 6 starts and returns at
// once (the CPU may then work on cache maintenance), funct7 = 7 waits until the
// engine is idle.
// Burst tensor-transpose engine for int8 tensors (esize = 1), selected by the
// CPU with CUSTOM-0 funct3=110 funct7=5 (fast mode); everything else goes
// through the single-beat engine npu_transpose.v.
//
// Data flow (all on the NPU, the CPU never touches an element):
//   fill   : the input tensor (<= 16 KiB) is fetched with AXI INCR read bursts
//            into two word-wide block-RAM replicas (4 read ports in total);
//   build  : concurrently, a table INNER[b] of input byte offsets for the R
//            innermost output elements (R = product of the k innermost output
//            extents, R % 4 == 0) is built, 4 offsets per 64-bit word;
//   gather : one output word (4 consecutive output bytes) per cycle:
//            offset(n) = rowbase + INNER[n mod R]; rowbase follows an odometer
//            over the remaining (outer) dimensions; the 4 bytes are read
//            through the 4 BRAM ports and packed;
//   drain  : the packed words go into an output buffer and are written back
//            with AXI INCR write bursts while the gather is still running.
//
// Preconditions (checked by software, see transpose.h): esize = 1, output base
// word aligned, (input base mod 4) + total <= 16384, total % 4 == 0,
// R % 4 == 0, R <= 4096.
module npu_transpose_fast #(
    parameter integer WBURST = 16            // output words per write burst
) (
    input             clk,
    input             rst_n,

    input             cfg_base_we,    // rs1 = input base, rs2 = output base
    input             cfg_shape_we,   // rs1 = hw dim (0..5), rs2 = extent
    input             cfg_adv_we,     // rs1 = hw dim (0..5), rs2 = byte delta
    input             cfg_fast_we,    // rs1 = total bytes, rs2 = {k[3:0] @ 16, R[15:0]}
    input      [31:0] cfg_rs1,
    input      [31:0] cfg_rs2,
    input             start,
    output reg        done,
    output            busy,

    output reg [31:0] araddr,
    output reg [7:0]  arlen,
    output reg        arvalid,
    input             arready,
    input      [31:0] rdata,
    input             rvalid,
    output            rready,
    output reg [31:0] awaddr,
    output reg [7:0]  awlen,
    output reg        awvalid,
    input             awready,
    output reg [31:0] wdata,
    output reg        wlast,
    output reg        wvalid,
    input             wready,
    input             bvalid,
    output            bready
);
    // ---------------- configuration ----------------
    reg [31:0] in_base, out_base;
    reg [15:0] shape [0:5];
    reg [15:0] adv   [0:5];
    reg [15:0] tot_bytes;     // up to 16384
    reg [15:0] r_cnt;         // R
    reg [3:0]  k_cnt;
    integer i;

    // ---------------- run state ----------------
    reg        run;
    reg        fill_done, build_done, gather_go;
    reg [1:0]  a_in;
    reg [12:0] W;             // output words
    reg [11:0] Rw;            // R / 4

    // fill
    reg [31:0] ar_addr;       // next AR address (word aligned)
    reg [12:0] ar_left;       // words still to request
    reg [12:0] wr_ptr;        // words received
    reg [12:0] n_in_words;
    wire [12:0] to4k_ar2 = 13'd1024 - {3'd0, ar_addr[11:2]};
    wire [12:0] ar_len_a = (ar_left < 13'd256) ? ar_left : 13'd256;
    wire [12:0] ar_len   = (ar_len_a < to4k_ar2) ? ar_len_a : to4k_ar2;
    assign rready = run && !fill_done;
    wire fill_we = rvalid && rready;

    // INNER table build
    reg        building;
    reg [15:0] brem [0:5];
    reg [15:0] boff;
    reg [15:0] bq0, bq1, bq2;
    reg [13:0] bcnt;
    reg [15:0] inner_last;
    reg        b_any;
    reg [2:0]  b_d;
    integer jb, jo;
    always @* begin
        b_any = 1'b0; b_d = 3'd0;
        for (jb = 5; jb >= 0; jb = jb - 1)
            if (!b_any && (jb >= 6 - k_cnt) && (brem[jb] != 16'd0)) begin
                b_any = 1'b1; b_d = jb[2:0];
            end
    end
    reg [63:0] inner_mem [0:1023];
    reg [63:0] inner_q;
    reg [9:0]  inner_ra;

    // outer odometer + issue stage
    reg [15:0] orem [0:5];
    reg [15:0] rbase;
    reg [11:0] wcol;
    reg [12:0] ic;
    reg        o_any;
    reg [2:0]  o_d;
    always @* begin
        o_any = 1'b0; o_d = 3'd0;
        for (jo = 5; jo >= 0; jo = jo - 1)
            if (!o_any && (jo < 6 - k_cnt) && (orem[jo] != 16'd0)) begin
                o_any = 1'b1; o_d = jo[2:0];
            end
    end
    wire issue = run && gather_go && (ic != W);

    reg        v0, v1, v2, v3, v4;
    reg [15:0] base0, base1;
    reg [15:0] idx2_0, idx2_1, idx2_2, idx2_3;
    reg [1:0]  sel3_0, sel3_1, sel3_2, sel3_3;
    wire [31:0] qa0, qb0, qa1, qb1;
    reg [31:0] gw;            // gathered word (stage 4 register)
    reg [12:0] gptr;          // output word index being written
    reg [12:0] pcnt;          // output words visible to the drain

    wire [11:0] ram_addr_a0 = fill_we ? wr_ptr[11:0] : idx2_0[13:2];
    wire [11:0] ram_addr_a1 = fill_we ? wr_ptr[11:0] : idx2_2[13:2];
    npu_tp_ram u_rep0 (.clk(clk), .we(fill_we), .addr_a(ram_addr_a0), .din(rdata),
                       .qa(qa0), .addr_b(idx2_1[13:2]), .qb(qb0));
    npu_tp_ram u_rep1 (.clk(clk), .we(fill_we), .addr_a(ram_addr_a1), .din(rdata),
                       .qa(qa1), .addr_b(idx2_3[13:2]), .qb(qb1));

    function [7:0] pick;
        input [31:0] w;
        input [1:0]  s;
        begin pick = w >> {s, 3'b000}; end
    endfunction

    // output buffer
    reg [31:0] out_mem [0:4095];
    reg [31:0] out_q;
    reg [12:0] rptr;

    // drain / AW
    reg [31:0] aw_addr_n;
    reg [12:0] aw_words;
    reg [12:0] aw_acc;        // AW bursts accepted (count)
    reg [12:0] b_cnt;
    reg [4:0]  lenq [0:3];
    reg [1:0]  lq_wr, lq_rd;
    reg [2:0]  lq_cnt;
    reg [5:0]  pf_left;
    reg        qv, qlast;
    wire [12:0] aw_rem   = W - aw_words;
    wire [12:0] aw_to4k  = 13'd1024 - {3'd0, aw_addr_n[11:2]};
    wire [12:0] aw_l1    = (aw_rem < WBURST) ? aw_rem : WBURST;
    wire [12:0] aw_len   = (aw_l1 < aw_to4k) ? aw_l1 : aw_to4k;
    wire aw_ready_to_issue = run && !awvalid && (aw_words != W) &&
                             (pcnt >= aw_words + aw_len) && (lq_cnt <= 3'd2);
    wire aw_hs = awvalid && awready;
    wire [5:0] cur_left = (pf_left != 6'd0) ? pf_left : (lq_cnt != 0 ? {1'b0, lenq[lq_rd]} : 6'd0);
    wire move  = qv && (!wvalid || wready);
    wire ren   = !qv || move;
    wire can_issue = ren && (cur_left != 6'd0);
    assign bready = run;
    assign busy   = run;

    wire all_done = run && (aw_words == W) && !awvalid && (b_cnt == aw_acc) && (W != 0);

    always @(posedge clk) begin
        // memories (no reset needed)
        inner_q <= inner_mem[inner_ra];
        if (building && bcnt[1:0] == 2'd3)
            inner_mem[bcnt[13:2]] <= {boff, bq2, bq1, bq0};
        if (v4) out_mem[gptr[11:0]] <= gw;
        if (ren) out_q <= out_mem[rptr[11:0]];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_base <= 32'd0; out_base <= 32'd0; tot_bytes <= 16'd0;
            r_cnt <= 16'd4; k_cnt <= 4'd1;
            run <= 1'b0; done <= 1'b0;
            fill_done <= 1'b0; build_done <= 1'b0; gather_go <= 1'b0;
            araddr <= 32'd0; arlen <= 8'd0; arvalid <= 1'b0;
            awaddr <= 32'd0; awlen <= 8'd0; awvalid <= 1'b0;
            wdata <= 32'd0; wlast <= 1'b0; wvalid <= 1'b0;
            building <= 1'b0;
            v0 <= 1'b0; v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0; v4 <= 1'b0;
            qv <= 1'b0; qlast <= 1'b0; pf_left <= 6'd0;
            lq_wr <= 2'd0; lq_rd <= 2'd0; lq_cnt <= 3'd0;
            aw_acc <= 13'd0; b_cnt <= 13'd0; aw_words <= 13'd0;
            pcnt <= 13'd0; gptr <= 13'd0; rptr <= 13'd0;
            ic <= 13'd0; wcol <= 12'd0; rbase <= 16'd0;
            wr_ptr <= 13'd0; ar_left <= 13'd0; ar_addr <= 32'd0;
            for (i = 0; i < 6; i = i + 1) begin
                shape[i] <= 16'd1; adv[i] <= 16'd0;
                brem[i] <= 16'd0; orem[i] <= 16'd0;
            end
        end else begin
            done <= 1'b0;
            if (cfg_base_we) begin in_base <= cfg_rs1; out_base <= cfg_rs2; end
            if (cfg_shape_we && cfg_rs1 < 6) shape[cfg_rs1[2:0]] <= cfg_rs2[15:0];
            if (cfg_adv_we && cfg_rs1 < 6)   adv[cfg_rs1[2:0]]   <= cfg_rs2[15:0];
            if (cfg_fast_we) begin
                tot_bytes <= cfg_rs1[15:0];
                r_cnt     <= cfg_rs2[15:0];
                k_cnt     <= cfg_rs2[19:16];
            end

            if (!run) begin
                if (start) begin
                    run <= 1'b1;
                    a_in <= in_base[1:0];
                    W  <= tot_bytes[15:2];
                    Rw <= r_cnt[13:2];
                    n_in_words <= (tot_bytes + {14'd0, in_base[1:0]} + 16'd3) >> 2;
                    ar_addr <= {in_base[31:2], 2'b00};
                    ar_left <= (tot_bytes + {14'd0, in_base[1:0]} + 16'd3) >> 2;
                    wr_ptr <= 13'd0;
                    fill_done <= 1'b0; build_done <= 1'b0; gather_go <= 1'b0;
                    building <= 1'b1; bcnt <= 14'd0; boff <= 16'd0;
                    for (i = 0; i < 6; i = i + 1) begin
                        brem[i] <= shape[i] - 16'd1;
                        orem[i] <= shape[i] - 16'd1;
                    end
                    rbase <= {14'd0, in_base[1:0]};
                    wcol <= 12'd0; ic <= 13'd0;
                    v0 <= 1'b0; v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0; v4 <= 1'b0;
                    gptr <= 13'd0; pcnt <= 13'd0; rptr <= 13'd0;
                    aw_addr_n <= out_base; aw_words <= 13'd0; aw_acc <= 13'd0; b_cnt <= 13'd0;
                    lq_wr <= 2'd0; lq_rd <= 2'd0; lq_cnt <= 3'd0; pf_left <= 6'd0;
                    qv <= 1'b0; wvalid <= 1'b0;
                end
            end else begin
                // ---------------- fill: AR issue ----------------
                if (arvalid) begin
                    if (arready) arvalid <= 1'b0;
                end else if (ar_left != 13'd0) begin
                    araddr  <= ar_addr;
                    arlen   <= ar_len[7:0] - 8'd1;
                    arvalid <= 1'b1;
                    ar_addr <= ar_addr + {17'd0, ar_len, 2'b00};
                    ar_left <= ar_left - ar_len;
                end
                if (fill_we) begin
                    wr_ptr <= wr_ptr + 13'd1;
                    if (wr_ptr + 13'd1 == n_in_words) fill_done <= 1'b1;
                end

                // ---------------- INNER table build ----------------
                if (building) begin
                    case (bcnt[1:0])
                        2'd0: bq0 <= boff;
                        2'd1: bq1 <= boff;
                        2'd2: bq2 <= boff;
                        default: ;
                    endcase
                    bcnt <= bcnt + 14'd1;
                    if (b_any) begin
                        boff <= boff + adv[b_d];
                        for (i = 0; i < 6; i = i + 1) begin
                            if (i == b_d) brem[i] <= brem[i] - 16'd1;
                            else if (i > b_d && i >= 6 - k_cnt) brem[i] <= shape[i] - 16'd1;
                        end
                    end else begin
                        inner_last <= boff;
                        building   <= 1'b0;
                        build_done <= 1'b1;
                    end
                end
                if (build_done && fill_done && !gather_go) gather_go <= 1'b1;

                // ---------------- gather pipeline ----------------
                // stage 0: issue (INNER read + row base)
                v0 <= issue;
                if (issue) begin
                    inner_ra <= wcol[9:0];
                    base0    <= rbase;
                    ic       <= ic + 13'd1;
                    if (wcol == Rw - 12'd1) begin
                        wcol <= 12'd0;
                        rbase <= rbase + inner_last + adv[o_d];
                        for (i = 0; i < 6; i = i + 1) begin
                            if (i == o_d) orem[i] <= orem[i] - 16'd1;
                            else if (i > o_d && i < 6 - k_cnt) orem[i] <= shape[i] - 16'd1;
                        end
                    end else begin
                        wcol <= wcol + 12'd1;
                    end
                end
                // stage 1: INNER word available (inner_q) next cycle
                v1 <= v0; base1 <= base0;
                // stage 2: byte offsets
                v2 <= v1;
                idx2_0 <= base1 + inner_q[15:0];
                idx2_1 <= base1 + inner_q[31:16];
                idx2_2 <= base1 + inner_q[47:32];
                idx2_3 <= base1 + inner_q[63:48];
                // stage 3: BRAM read issued with idx2 (data valid next cycle)
                v3 <= v2;
                sel3_0 <= idx2_0[1:0]; sel3_1 <= idx2_1[1:0];
                sel3_2 <= idx2_2[1:0]; sel3_3 <= idx2_3[1:0];
                // stage 4: byte select and pack
                v4 <= v3;
                gw <= {pick(qb1, sel3_3), pick(qa1, sel3_2),
                       pick(qb0, sel3_1), pick(qa0, sel3_0)};
                // stage 5: write to the output buffer (v4 at the memory block)
                if (v4) begin
                    gptr <= gptr + 13'd1;
                    pcnt <= pcnt + 13'd1;
                end

                // ---------------- drain: AW issue ----------------
                if (aw_hs) begin
                    awvalid <= 1'b0;
                    aw_acc <= aw_acc + 13'd1;
                    lenq[lq_wr] <= awlen[4:0] + 5'd1;
                    lq_wr <= lq_wr + 2'd1;
                end else if (aw_ready_to_issue) begin
                    awaddr  <= aw_addr_n;
                    awlen   <= aw_len[7:0] - 8'd1;
                    awvalid <= 1'b1;
                    aw_addr_n <= aw_addr_n + {17'd0, aw_len, 2'b00};
                    aw_words  <= aw_words + aw_len;
                end

                // ---------------- drain: W stream ----------------
                if (wvalid && wready) wvalid <= 1'b0;
                if (move) begin
                    wdata  <= out_q;
                    wlast  <= qlast;
                    wvalid <= 1'b1;
                end
                if (ren) begin
                    qv <= can_issue;
                    if (can_issue) begin
                        qlast <= (cur_left == 6'd1);
                        rptr  <= rptr + 13'd1;
                        pf_left <= cur_left - 6'd1;
                    end
                end
                // length-queue bookkeeping (pop when a new burst is entered)
                if (can_issue && pf_left == 6'd0) lq_rd <= lq_rd + 2'd1;
                lq_cnt <= lq_cnt + (aw_hs ? 3'd1 : 3'd0) -
                          ((can_issue && pf_left == 6'd0) ? 3'd1 : 3'd0);

                if (bvalid) b_cnt <= b_cnt + 13'd1;

                if (all_done) begin
                    run  <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end
endmodule

// 4096 x 32 true-dual-port block RAM: port A writes (and reads), port B reads.
module npu_tp_ram (
    input             clk,
    input             we,
    input      [11:0] addr_a,
    input      [31:0] din,
    output reg [31:0] qa,
    input      [11:0] addr_b,
    output reg [31:0] qb
);
    (* ram_style = "block" *) reg [31:0] mem [0:4095];
    always @(posedge clk) begin
        if (we) mem[addr_a] <= din;
        qa <= mem[addr_a];
    end
    always @(posedge clk) begin
        qb <= mem[addr_b];
    end
endmodule
