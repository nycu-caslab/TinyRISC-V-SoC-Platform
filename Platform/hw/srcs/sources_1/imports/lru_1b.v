`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:54:52 PM
// Design Name: 
// Module Name: lru_1b
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


module lru_1b(
    input clk,
    input hit,
    input [8:0]index,
    output lru
);
    wire lru_i = (lru ? 0: 1);
    
    DistributedRAM #(
        .DATA_WIDTH(1),
        .ADDR_WIDTH(9)
    ) lru_arr (
        .a(index),
        .d(lru_i),
        .clk(clk),
        .we(hit),
        .spo(lru)
    );
    
endmodule
