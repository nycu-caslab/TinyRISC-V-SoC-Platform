`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 08:43:02 PM
// Design Name: 
// Module Name: data_block32Bx256
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


//8KB 
//ofs = 5 bits, idx = 8 bits, tag = 32 - 8 - 5 =19
module data_block32Bx256(
    input clk,
    input mem_wr,
    input [255:0]mem_data,
    input [7:0]index,
    input [2:0]word_ofs,
    output [31:0]cpu_inst_o
);
    reg [31:0]data_i[0:7];
    wire [31:0]data_o[0:7];
    
    integer i;
    always@(*)begin
        for(i = 0; i < 8 ; i = i + 1)begin
                data_i[i] = mem_data[i*32 + 31 -: 32];
        end
    end  
    
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : ram_bank
            SDPBRAM #(
                .DATA_WIDTH(32), 
                .ADDR_WIDTH(8)
            ) b (
                .clk(clk), 
                .we(mem_wr), 
                .waddr(index), 
                .din(data_i[j]), 
                .raddr(index), 
                .dout(data_o[j])
            );
        end
    endgenerate
    
    assign cpu_inst_o = data_o[word_ofs];
endmodule