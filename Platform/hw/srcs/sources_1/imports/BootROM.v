`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 03:12:07 AM
// Design Name: 
// Module Name: BootROM
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

module BootROM (
    input  wire            clk,
    input  wire [31:0]     addr, 
    output wire [31:0]     dout
);

    SPBROM #(
        .DATA_WIDTH(32),
        .DEPTH(1024),
        .INIT_FILE("../../../../boot/boot.hex") 
    ) u_spbrom ( 
        .clk  (clk),
        .addr (addr[11:2]), 
        .dout (dout)
    );
    
endmodule