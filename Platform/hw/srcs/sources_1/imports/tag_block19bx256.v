`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:42:07 PM
// Design Name: 
// Module Name: tag_block19bx256
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


module tag_block19bx256(
    input clk,
    input write,
    input [7:0]index,
    input [18:0]tag_i,
    output [18:0]tag_o
);

    DistributedRAM #(
        .DATA_WIDTH(19),
        .ADDR_WIDTH(8)
    ) tag_arr (
        .a(index),
        .d(tag_i),
        .clk(clk),
        .we(write),
        .spo(tag_o)
    );

endmodule