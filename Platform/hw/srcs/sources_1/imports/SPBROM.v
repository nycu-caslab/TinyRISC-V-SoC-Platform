`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 03:16:25 AM
// Design Name: 
// Module Name: SPBROM
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


module SPBROM #(
    parameter DATA_WIDTH = 32,           
    parameter DEPTH      = 1024,         
    parameter INIT_FILE  = ""    
)(
    input  wire                        clk,
    input  wire [$clog2(DEPTH)-1:0]    addr, 
    output reg  [DATA_WIDTH-1:0]       dout
);

    (* rom_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            for (i = 0; i < DEPTH; i = i + 1) mem[i] = 0;
        end
    end

    always @(posedge clk) begin
            dout <= mem[addr];
    end

endmodule
