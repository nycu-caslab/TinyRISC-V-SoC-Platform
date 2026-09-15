`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:41:09 PM
// Design Name: 
// Module Name: vld_block1bx256
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
//////////////////////////////////////////////////////////////////////////////////

module vld_block1bx256(
    input clk,
    input rst_n,       
    input invalidate, 
    input write,
    input vld_i,
    input [7:0] index,
    output vld_o
);
    
    reg [255:0] valid_array;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_array <= 256'b0;      
        end else if (invalidate) begin
            valid_array <= 256'b0;
        end else if (write) begin
            valid_array[index] <= vld_i; 
        end
    end

    assign vld_o = valid_array[index];

endmodule