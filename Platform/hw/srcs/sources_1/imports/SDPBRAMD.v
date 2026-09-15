`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/01/06 15:15:13
// Design Name: 
// Module Name: SDPBRAMD
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


module SDPBRAMD #(
    parameter ADDR_WIDTH = 9
)(
    input wire clk,
    input wire [3:0] we,
    input wire [ADDR_WIDTH-1:0] waddr,
    input wire [31:0] din,
    input wire [ADDR_WIDTH-1:0] raddr,
    output reg [31:0] dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    (* ram_style = "block" *)
    reg [31:0] ram [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 0;
        end
    end

    reg [31:0] ram_dout;
    always @(posedge clk) begin
        if (we[0]) ram[waddr][7:0]   <= din[7:0];
        if (we[1]) ram[waddr][15:8]  <= din[15:8];
        if (we[2]) ram[waddr][23:16] <= din[23:16];
        if (we[3]) ram[waddr][31:24] <= din[31:24];
        
        ram_dout <= ram[raddr]; 
    end

    reg [3:0] bypass_we;
    reg [31:0] bypass_din;
    
    always @(posedge clk) begin
        if (waddr == raddr) begin
            bypass_we <= we;
            bypass_din <= din;
        end else begin
            bypass_we <= 4'b0000;
        end
    end

    always @(*) begin
        dout[7:0]   = bypass_we[0] ? bypass_din[7:0]   : ram_dout[7:0];
        dout[15:8]  = bypass_we[1] ? bypass_din[15:8]  : ram_dout[15:8];
        dout[23:16] = bypass_we[2] ? bypass_din[23:16] : ram_dout[23:16];
        dout[31:24] = bypass_we[3] ? bypass_din[31:24] : ram_dout[31:24];
    end

endmodule