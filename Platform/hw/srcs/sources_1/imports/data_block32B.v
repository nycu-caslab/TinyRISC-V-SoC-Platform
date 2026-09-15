`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:57:22 PM
// Design Name: 
// Module Name: data_block32B
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


module data_block32B(
    input clk,
    input cpu_wr,
    input mem_wr,
    input [3:0]mask,
    input [8:0]index,
    input [2:0]word_offset, 
    input [31:0]cpu_data_i,
    input [255:0]mem_data_i,
    output [31:0]cpu_data_o,
    output [255:0]mem_data_o
    );
    
    // parameter definition //
    wire [7:0] word_ena = (1 << word_offset);
    wire [31:0] word_o [0:7];
    reg  [3:0] wea [0:7];
    reg [31:0] data_i[0:7];
    
    // write policy //
    integer i;
    always@(*)begin
        for(i = 0; i < 8 ; i = i + 1)begin
            if(cpu_wr)begin
                wea[i] = word_ena[i] ? mask : 0;
                data_i[i] = word_ena[i] ? cpu_data_i : 0; end
            else if(mem_wr)begin
                wea[i] = 4'hf;
                data_i[i] = mem_data_i[i*32 + 31 -: 32]; end
            else begin
            wea[i] = 4'b0000;
            data_i[i] = 32'h00000000; end
        end 
    end    

    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : ram_bank
            SDPBRAMD #(
                .ADDR_WIDTH(9)
            ) b (
                .clk(clk), 
                .we(wea[j]), 
                .waddr(index), 
                .din(data_i[j]), 
                .raddr(index), 
                .dout(word_o[j])
            );
        end
    endgenerate
    
    // read policy //
    assign cpu_data_o = word_o[word_offset];
    assign mem_data_o = {word_o[7],word_o[6],word_o[5],word_o[4],word_o[3],word_o[2],word_o[1],word_o[0]};
    
    
endmodule