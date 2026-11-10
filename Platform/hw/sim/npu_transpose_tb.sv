`timescale 1ns / 1ps
// Randomized testbench for the NPU transpose instruction (CUSTOM-0 funct3=110).
// 500 random cases: rank 1..6, element size 1/2/3/4/8 bytes, random permutation,
// unaligned input/output base addresses, random AXI stalls (AR/AW/W ready,
// R/B latency). The DUT is the full NPU top, driven exactly like the CPU does:
// the configuration sequence below mirrors transpose.h (output-extent and
// byte-delta computation). The golden output is computed independently by
// coordinate decoding.  Guard bytes around the output and the input region are
// checked for stray writes.
module npu_transpose_tb;
    localparam integer NCASES = 500;
    localparam integer MEMSZ  = 1 << 17;
    localparam [31:0]  MEMBASE = 32'h6000_0000;
    localparam integer IN_REGION  = 32'h0000_1000;
    localparam integer OUT_REGION = 32'h0001_0000;
    localparam integer GUARD = 16;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg [31:0] rs1_i = 0, rs2_i = 0, funct7_i = 0;
    reg [3:0] funct3_i = 0;
    reg NPU_start = 0;
    wire [31:0] NPU_out;
    wire NPU_done;

    wire [31:0] awaddr, wdata, araddr;
    wire [7:0] awlen, arlen;
    wire [3:0] wstrb;
    wire awvalid, wvalid, wlast, bready, arvalid, rready;
    reg awready, wready_ok, bvalid, arready, rvalid;
    wire wready;
    reg [31:0] rdata_r;

    NPU dut (
        .clk(clk), .rst_n(rst_n), .rs1_i(rs1_i), .rs2_i(rs2_i),
        .NPU_out(NPU_out), .NPU_start(NPU_start), .NPU_done(NPU_done),
        .funct3_i(funct3_i), .funct7_i(funct7_i),
        .M_AXI_AWADDR(awaddr), .M_AXI_AWLEN(awlen),
        .M_AXI_AWVALID(awvalid), .M_AXI_AWREADY(awready),
        .M_AXI_WDATA(wdata), .M_AXI_WSTRB(wstrb), .M_AXI_WLAST(wlast),
        .M_AXI_WVALID(wvalid), .M_AXI_WREADY(wready),
        .M_AXI_BRESP(2'b00), .M_AXI_BVALID(bvalid), .M_AXI_BREADY(bready),
        .M_AXI_ARADDR(araddr), .M_AXI_ARLEN(arlen), .M_AXI_ARVALID(arvalid),
        .M_AXI_ARREADY(arready), .M_AXI_RID(4'd0), .M_AXI_RDATA(rdata_r),
        .M_AXI_RRESP(2'b00), .M_AXI_RLAST(1'b1), .M_AXI_RVALID(rvalid),
        .M_AXI_RREADY(rready)
    );

    reg [7:0] mem [0:MEMSZ-1];
    integer stall_pct;       // probability (0..100) of stalling per decision
    integer protocol_errors = 0;

    // ---------------- AXI slave model with random stalls ----------------
    // Supports INCR bursts on AR and AW/W (up to 256 beats). In single-beat
    // mode (fast_mode == 0) any burst longer than one beat is a protocol error.
    reg        fast_mode;
    reg        w_active;
    assign wready = w_active && wready_ok;
    reg [31:0] arq_addr [0:7];
    reg [8:0]  arq_len  [0:7];
    integer    arq_wr, arq_rd, arq_cnt;
    reg        r_active;
    reg [31:0] r_addr;
    integer    r_left;
    reg [31:0] awq_addr [0:7];
    reg [8:0]  awq_len  [0:7];
    integer    awq_wr, awq_rd, awq_cnt;
    reg [31:0] w_addr;
    integer    w_left;
    integer    b_pend;
    integer    arq_pre, awq_pre;
    integer    b_delay;
    integer    ci;
    integer    r_beats_total = 0, w_beats_total = 0;

    function stall;
        input integer dummy;
        begin stall = ($urandom_range(99, 0) < stall_pct); end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 0; wready_ok <= 0; bvalid <= 0; arready <= 0; rvalid <= 0;
            rdata_r <= 0; arq_wr <= 0; arq_rd <= 0; arq_cnt <= 0; r_active <= 0;
            awq_wr <= 0; awq_rd <= 0; awq_cnt <= 0; w_active <= 0; b_pend <= 0; b_delay <= 0;
            r_left <= 0; w_left <= 0;
        end else begin
            arq_pre = arq_cnt; awq_pre = awq_cnt;
            // ---- read address ----
            arready <= (arq_cnt < 6) && !stall(0);
            if (arvalid && arready && arq_cnt < 8) begin
                arq_addr[arq_wr] <= araddr;
                arq_len[arq_wr]  <= arlen + 9'd1;
                arq_wr  <= (arq_wr + 1) % 8;
                arq_cnt = arq_cnt + 1;
                if (araddr[1:0] != 0) begin protocol_errors = protocol_errors + 1; $display("unaligned AR"); end
                if (!fast_mode && arlen !== 8'd0) begin protocol_errors = protocol_errors + 1; $display("ARLEN != 0"); end
                if (({20'd0, araddr[11:0]} + (arlen + 1) * 4) > 4096) begin protocol_errors = protocol_errors + 1; $display("AR crosses 4KB"); end
            end
            // ---- read data ----
            if (rvalid && rready) begin
                rvalid <= 0;
            end
            if ((!rvalid || rready) && !(rvalid && rready && 0)) begin
                if (!r_active && arq_pre > 0 && !(rvalid && !rready)) begin
                    r_active <= 1; r_addr <= arq_addr[arq_rd]; r_left <= arq_len[arq_rd];
                    arq_rd <= (arq_rd + 1) % 8; arq_cnt = arq_cnt - 1;
                end else if (r_active && r_left > 0 && !stall(0)) begin
                    rvalid  <= 1;
                    rdata_r <= {mem[r_addr[16:0]+3], mem[r_addr[16:0]+2],
                                mem[r_addr[16:0]+1], mem[r_addr[16:0]]};
                    r_addr <= r_addr + 4;
                    r_left <= r_left - 1;
                    r_beats_total = r_beats_total + 1;
                    if (r_left == 1) r_active <= 0;
                end
            end
            // ---- write address ----
            awready <= (awq_cnt < 6) && !stall(0);
            if (awvalid && awready && awq_cnt < 8) begin
                awq_addr[awq_wr] <= awaddr;
                awq_len[awq_wr]  <= awlen + 9'd1;
                awq_wr  <= (awq_wr + 1) % 8;
                awq_cnt = awq_cnt + 1;
                if (awaddr[1:0] != 0) begin protocol_errors = protocol_errors + 1; $display("unaligned AW"); end
                if (!fast_mode && awlen !== 8'd0) begin protocol_errors = protocol_errors + 1; $display("AWLEN != 0"); end
                if (({20'd0, awaddr[11:0]} + (awlen + 1) * 4) > 4096) begin protocol_errors = protocol_errors + 1; $display("AW crosses 4KB"); end
            end
            // ---- write data ----
            wready_ok <= !stall(0);
            if (!w_active && awq_pre > 0) begin
                w_active <= 1; w_addr <= awq_addr[awq_rd]; w_left <= awq_len[awq_rd];
                awq_rd <= (awq_rd + 1) % 8; awq_cnt = awq_cnt - 1;
            end else if (w_active && wvalid && wready) begin
                for (ci = 0; ci < 4; ci = ci + 1)
                    if (wstrb[ci]) mem[w_addr[16:0] + ci] <= wdata[8*ci +: 8];
                if (wstrb == 0) begin protocol_errors = protocol_errors + 1; $display("zero strobe write"); end
                if (fast_mode && wstrb != 4'hF) begin protocol_errors = protocol_errors + 1; $display("partial strobe in fast mode"); end
                if ((w_left == 1) != (wlast === 1'b1)) begin protocol_errors = protocol_errors + 1; $display("WLAST mismatch"); end
                w_addr <= w_addr + 4;
                w_left <= w_left - 1;
                w_beats_total = w_beats_total + 1;
                if (w_left == 1) begin
                    w_active <= 0; b_pend = b_pend + 1;
                    b_delay <= stall(0) ? $urandom_range(6, 1) : 0;
                end
            end
            // ---- write response ----
            if (bvalid && bready) begin bvalid <= 0; b_pend = b_pend - 1; end
            else if (b_pend > 0 && !bvalid) begin
                if (b_delay > 0) b_delay <= b_delay - 1;
                else bvalid <= 1;
            end
        end
    end

    // ---------------- instruction driver ----------------
    integer cyc;
    task npu_op(input [2:0] f3, input [31:0] f7, input [31:0] a, input [31:0] b);
        begin
            @(negedge clk);
            funct3_i = {1'b0, f3}; funct7_i = f7; rs1_i = a; rs2_i = b; NPU_start = 1;
            @(negedge clk);
            NPU_start = 0;
            cyc = 0;
            while (!NPU_done && cyc < 300000) begin @(negedge clk); cyc = cyc + 1; end
            if (!NPU_done) begin $display("TIMEOUT case %0d rank %0d esize %0d total %0d fast %0d k %0d R %0d", n, rank, esize, total, use_fast, fast_k, fast_R); $finish; end
        end
    endtask

    // ---------------- random case ----------------
    integer rank, esize, total, n, d, e, t, tmp, in_off, out_off, h;
    integer in_shape [0:5];
    integer perm [0:5];
    integer out_shape [0:5];
    integer in_stride [0:5];     // elements
    integer out_stride [0:5];
    integer coord [0:5];
    integer stride_b [0:5];      // bytes, per output dim
    integer adv_b;
    integer cases_done = 0, mismatches = 0, errors_total = 0;
    integer lin, rem, in_lin, bb, a;
    integer rank_hist [1:6];
    integer cycles_total = 0;
    reg [7:0] golden [0:MEMSZ-1];
    reg [7:0] in_copy [0:16399];
    integer fast_cases = 0, fast_k, fast_R, hh, use_fast, fast_cand;
    integer in_bytes, out_bytes, bad;
    integer maxel;

    initial begin
        for (n = 1; n <= 6; n = n + 1) rank_hist[n] = 0;
        stall_pct = 0; fast_mode = 0;
        for (n = 0; n < MEMSZ; n = n + 1) mem[n] = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        for (n = 0; n < NCASES; n = n + 1) begin
            rank = (n < 12) ? (n % 6) + 1 : $urandom_range(6, 1);
            rank_hist[rank] = rank_hist[rank] + 1;
            case ($urandom_range(7, 0))
                0, 1, 2: esize = 1;
                3: esize = 2;
                4: esize = 4;
                5: esize = 8;
                6: esize = 3;
                default: esize = 1;
            endcase
            stall_pct = (n % 4 == 0) ? 0 : (n % 4 == 1) ? 30 : (n % 4 == 2) ? 60 : 85;
            maxel = 400;
            // odd cases: int8 tensors with model-like extents (burst engine candidates)
            fast_cand = (n % 2 == 1);
            if (fast_cand) begin esize = 1; maxel = 3000; end
            total = 1;
            for (d = 0; d < rank; d = d + 1) begin
                if (fast_cand) begin
                    case ($urandom_range(9, 0))
                        0: in_shape[d] = 1;
                        1: in_shape[d] = 2;
                        2: in_shape[d] = 3;
                        3, 4: in_shape[d] = 4;
                        5: in_shape[d] = 5;
                        6, 7: in_shape[d] = 8;
                        8: in_shape[d] = 16;
                        default: in_shape[d] = 7;
                    endcase
                end else
                    in_shape[d] = $urandom_range((rank > 4) ? 3 : 7, 1);
                if (total * in_shape[d] > maxel) in_shape[d] = 1;
                total = total * in_shape[d];
            end
            if (n == 7) begin   // real model shape: 1x16x16x64 -> 1x64x16x16 style (NHWC -> NCHW)
                rank = 4; esize = 1; fast_cand = 1;
                in_shape[0] = 1; in_shape[1] = 16; in_shape[2] = 16; in_shape[3] = 64; total = 16384;
            end
            if (n == 9) begin
                rank = 6; esize = 1; fast_cand = 1;
                in_shape[0] = 1; in_shape[1] = 64; in_shape[2] = 8; in_shape[3] = 2; in_shape[4] = 8; in_shape[5] = 2; total = 16384;
            end
            // random permutation (Fisher-Yates)
            for (d = 0; d < rank; d = d + 1) perm[d] = d;
            if (n == 7) begin perm[0]=0; perm[1]=3; perm[2]=1; perm[3]=2; end
            else if (n == 9) begin perm[0]=0; perm[1]=3; perm[2]=5; perm[3]=2; perm[4]=4; perm[5]=1; end
            else if (n % 17 != 5) // a few identity permutations
                for (d = rank - 1; d > 0; d = d - 1) begin
                    e = $urandom_range(d, 0);
                    tmp = perm[d]; perm[d] = perm[e]; perm[e] = tmp;
                end
            for (d = 0; d < rank; d = d + 1) out_shape[d] = in_shape[perm[d]];
            in_stride[rank-1] = 1;
            for (d = rank - 2; d >= 0; d = d - 1) in_stride[d] = in_stride[d+1] * in_shape[d+1];

            in_bytes  = total * esize;
            in_off  = $urandom_range(3, 0);
            out_off = fast_cand ? 0 : $urandom_range(3, 0);
            if (n == 7 || n == 9) in_off = 0;
            // fill: whole memory neighbourhood
            for (a = 0; a < in_bytes + 2*GUARD; a = a + 1)
                mem[IN_REGION + in_off - GUARD + a] = $urandom;
            for (a = 0; a < in_bytes + 2*GUARD; a = a + 1)
                mem[OUT_REGION + out_off - GUARD + a] = 8'hA5 ^ a[7:0];
            // snapshot expected memory of the whole output neighbourhood
            for (a = 0; a < in_bytes + 2*GUARD; a = a + 1)
                golden[a] = mem[OUT_REGION + out_off - GUARD + a];
            for (a = 0; a < in_bytes; a = a + 1) in_copy[a] = mem[IN_REGION + in_off + a];
            // independent golden: decode output linear index into coordinates
            for (lin = 0; lin < total; lin = lin + 1) begin
                rem = lin; in_lin = 0;
                for (d = rank - 1; d >= 0; d = d - 1) begin
                    coord[d] = rem % out_shape[d];
                    rem = rem / out_shape[d];
                end
                for (d = 0; d < rank; d = d + 1) in_lin = in_lin + coord[d] * in_stride[perm[d]];
                for (bb = 0; bb < esize; bb = bb + 1)
                    golden[GUARD + lin*esize + bb] = in_copy[in_lin*esize + bb];
            end

            // ---- configure exactly like transpose.h ----
            // fast-mode eligibility (mirrors transpose.h)
            use_fast = (esize == 1) && (total % 4 == 0) && (out_off % 4 == 0) &&
                       (((MEMBASE + IN_REGION + in_off) % 4) + total <= 16384);
            fast_R = 1; fast_k = 0;
            if (use_fast) begin
                use_fast = 0;
                for (hh = 5; hh >= 0 && fast_k >= 0; hh = hh - 1) begin
                    d = hh - (6 - rank);
                    fast_R = fast_R * ((d < 0) ? 1 : out_shape[d]);
                    fast_k = fast_k + 1;
                    if (fast_R % 4 == 0) begin
                        use_fast = (fast_R <= 4096);
                        hh = -1;   // stop
                    end
                end
            end
            fast_mode = use_fast;
            npu_op(3'b110, 0, MEMBASE + IN_REGION + in_off, MEMBASE + OUT_REGION + out_off);
            npu_op(3'b110, 1, esize, 0);
            for (d = 0; d < rank; d = d + 1) stride_b[d] = in_stride[perm[d]] * esize;
            for (h = 0; h < 6; h = h + 1) begin
                d = h - (6 - rank);
                if (d < 0) begin
                    npu_op(3'b110, 2, h, 1);
                    npu_op(3'b110, 3, h, 0);
                end else begin
                    adv_b = stride_b[d];
                    for (e = d + 1; e < rank; e = e + 1)
                        adv_b = adv_b - (out_shape[e] - 1) * stride_b[e];
                    npu_op(3'b110, 2, h, out_shape[d]);
                    npu_op(3'b110, 3, h, adv_b);
                end
            end
            if (use_fast) begin
                npu_op(3'b110, 5, total, (fast_k << 16) | fast_R);
                fast_cases = fast_cases + 1;
            end
            t = $time;
            if (use_fast && (n % 4 == 1)) begin
                // asynchronous start, then wait (CPU would do cache maintenance in between)
                npu_op(3'b110, 6, 0, 0);
                repeat ($urandom_range(400, 0)) @(negedge clk);
                npu_op(3'b110, 7, 0, 0);
            end else
                npu_op(3'b110, 4, 0, 0);
            cycles_total = cycles_total + ($time - t) / 10;

            // ---- compare ----
            bad = 0;
            for (a = 0; a < in_bytes + 2*GUARD; a = a + 1)
                if (mem[OUT_REGION + out_off - GUARD + a] !== golden[a]) begin
                    if (bad < 3) $display("case %0d MISMATCH rank=%0d esize=%0d total=%0d off=%0d: byte %0d got %h exp %h",
                        n, rank, esize, total, a - GUARD, a, mem[OUT_REGION + out_off - GUARD + a], golden[a]);
                    bad = bad + 1;
                end
            for (a = 0; a < in_bytes; a = a + 1)
                if (mem[IN_REGION + in_off + a] !== in_copy[a]) bad = bad + 1;
            if (bad != 0) mismatches = mismatches + 1;
            cases_done = cases_done + 1;
        end
        $display("rank histogram: 1:%0d 2:%0d 3:%0d 4:%0d 5:%0d 6:%0d",
                 rank_hist[1], rank_hist[2], rank_hist[3], rank_hist[4], rank_hist[5], rank_hist[6]);
        $display("cases run: %0d, failing cases: %0d, protocol errors: %0d, engine cycles: %0d, burst-engine cases: %0d",
                 cases_done, mismatches, protocol_errors, cycles_total, fast_cases);
        if (mismatches == 0 && protocol_errors == 0 && cases_done == NCASES && fast_cases >= 100)
            $display("npu_transpose_tb: PASS (%0d/%0d)", cases_done, NCASES);
        else
            $display("npu_transpose_tb: FAIL");
        $finish;
    end
endmodule
