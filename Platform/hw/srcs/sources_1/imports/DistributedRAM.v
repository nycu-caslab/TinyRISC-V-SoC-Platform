`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 02:35:23
// Design Name: 
// Module Name: DistributedRAM
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

module DistributedRAM #(
    parameter DATA_WIDTH = 1,
    parameter ADDR_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    we,
    input  wire [ADDR_WIDTH-1:0]   a,
    input  wire [DATA_WIDTH-1:0]   d,
    output wire [DATA_WIDTH-1:0]   spo
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = "distributed" *)
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            ram[a] <= d;
        end
    end

    assign spo = ram[a];

endmodule
