`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:37:30 PM
// Design Name: 
// Module Name: way_32Bx256
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


module way_32Bx256(
    input clk,
	input rst_n,
	input invalidate,
    input write,
    input wr_vld,
    input [18:0]tag_i,
    input [7:0]index,
    input [2:0]word_offset, // equal to the first three of 5 bits offset.
    input [255:0]mem_data,
    input vld_i,
    output [18:0]tag_o,
    output [31:0]cpu_inst_o,
    output vld_o
);
    // parameter definition //
    
    // instance struction //
    vld_block1bx256 v_arr(.clk(clk), .rst_n(rst_n), .invalidate(invalidate), .write(wr_vld), .vld_i(vld_i), .index(index), .vld_o(vld_o));
    tag_block19bx256 t_arr (.clk(clk), .write(write), .index(index), .tag_i(tag_i), .tag_o(tag_o));
    data_block32Bx256 d_arr (.clk(clk), .mem_wr(write), .index(index), .word_ofs(word_offset), .mem_data(mem_data), .cpu_inst_o(cpu_inst_o));
    
    // input logic //
    
    
    // output logic //
    
endmodule