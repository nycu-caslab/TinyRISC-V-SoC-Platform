`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:56:36 PM
// Design Name: 
// Module Name: tag_block18b
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


module tag_block18b(
    input clk,
    input write,
    input [8:0]index,
    input [17:0]tag_i,
    output [17:0]tag_o
);
    
    DistributedRAM #(
        .DATA_WIDTH(18),
        .ADDR_WIDTH(9)
    ) tag_arr (
        .a(index),
        .d(tag_i),
        .clk(clk),
        .we(write),
        .spo(tag_o)
    );
    
endmodule
