`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 02:46:04
// Design Name: 
// Module Name: SDPBRAM
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

module SDPBRAM #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
)(
    input  wire                    clk,
    input  wire                    we,
    input  wire [ADDR_WIDTH-1:0]   waddr,
    input  wire [DATA_WIDTH-1:0]   din,
    input  wire [ADDR_WIDTH-1:0]   raddr,
    output reg  [DATA_WIDTH-1:0]   dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            ram[waddr] <= din;
        end
    end

    always @(posedge clk) begin
            dout <= ram[raddr]; 
    end

endmodule
