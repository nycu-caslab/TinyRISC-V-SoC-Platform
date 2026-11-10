`timescale 1ns / 1ps
// Testbench for the NPU Logistic instruction (funct3 = 101) against the G3
// vectors exported by scratch/lab4/logistic_model (upstream reference output):
// 41 parameter sets (37 model + 4 test) x 256 int8 inputs.
module npu_logistic_tb;
    localparam integer NSETS = 41;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg [31:0] rs1_i = 0, rs2_i = 0, funct7_i = 0;
    reg [3:0] funct3_i = 0;
    reg NPU_start = 0;
    wire [31:0] NPU_out;
    wire NPU_done;

    NPU dut (
        .clk(clk), .rst_n(rst_n), .rs1_i(rs1_i), .rs2_i(rs2_i),
        .NPU_out(NPU_out), .NPU_start(NPU_start), .NPU_done(NPU_done),
        .funct3_i(funct3_i), .funct7_i(funct7_i),
        .M_AXI_AWREADY(1'b0), .M_AXI_WREADY(1'b0), .M_AXI_BRESP(2'b00),
        .M_AXI_BVALID(1'b0), .M_AXI_ARREADY(1'b0), .M_AXI_RID(4'd0),
        .M_AXI_RDATA(32'd0), .M_AXI_RRESP(2'b00), .M_AXI_RLAST(1'b0),
        .M_AXI_RVALID(1'b0)
    );

    reg [31:0] params [0:NSETS*4-1];
    reg [7:0]  expected [0:NSETS*256-1];
    integer mismatches = 0, checked = 0, s, i, cyc;
    reg [31:0] result;

    task npu_op(input [2:0] f3, input [31:0] f7, input [31:0] a, input [31:0] b);
        begin
            @(negedge clk);
            funct3_i = {1'b0, f3}; funct7_i = f7; rs1_i = a; rs2_i = b; NPU_start = 1;
            @(negedge clk);
            NPU_start = 0;
            cyc = 0;
            while (!NPU_done && cyc < 100000) begin @(negedge clk); cyc = cyc + 1; end
            if (!NPU_done) begin $display("TIMEOUT"); $finish; end
            result = NPU_out;
        end
    endtask

    reg [7:0] e0, e1, e2, e3;
    initial begin
        $readmemh("vectors/logistic_params.hex", params);
        $readmemh("vectors/logistic_expected.hex", expected);
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);
        for (s = 0; s < NSETS; s = s + 1) begin
            npu_op(3'b101, 0, params[s*4+0], params[s*4+1]);
            npu_op(3'b101, 1, params[s*4+2], params[s*4+3]);
            for (i = 0; i < 256; i = i + 4) begin
                npu_op(3'b101, 2, {i[7:0] ^ 8'h80, (i[7:0]+8'd1) ^ 8'h80,
                                   (i[7:0]+8'd2) ^ 8'h80, (i[7:0]+8'd3) ^ 8'h80}, 0);
                e0 = expected[s*256+i]; e1 = expected[s*256+i+1];
                e2 = expected[s*256+i+2]; e3 = expected[s*256+i+3];
                checked = checked + 4;
                if (result !== {e0, e1, e2, e3}) begin
                    mismatches = mismatches + 1;
                    if (mismatches < 10)
                        $display("MISMATCH set %0d idx %0d got %h exp %h", s, i, result, {e0,e1,e2,e3});
                end
            end
        end
        $display("checked %0d outputs, %0d mismatching words", checked, mismatches);
        $display("npu_logistic_tb: %0d mismatches", mismatches);
        $finish;
    end
endmodule
