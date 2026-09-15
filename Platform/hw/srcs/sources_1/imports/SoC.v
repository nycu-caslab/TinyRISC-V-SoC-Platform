`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 11:31:35 PM
// Design Name: 
// Module Name: SoC
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


module SoC(
    input         CLK100MHZ,
    input         CPU_RESETN,
    
    // DDR3 Interface
    output [13:0] DDR3_addr,   
    output [2:0]  DDR3_ba,
    output        DDR3_cas_n,
    output [0:0]  DDR3_ck_n,
    output [0:0]  DDR3_ck_p,
    output [0:0]  DDR3_cke,
    output [0:0]  DDR3_cs_n,
    output [1:0]  DDR3_dm,
    inout  [15:0] DDR3_dq,
    inout  [1:0]  DDR3_dqs_n,
    inout  [1:0]  DDR3_dqs_p,
    output [0:0]  DDR3_odt,
    output        DDR3_ras_n,
    output        DDR3_we_n,
    output        DDR3_reset_n,
    
    // 其它 IO
    input         UART_rxd,
    output        UART_txd,
    output        mb_reset,
    output        diag_led_blink, 
    output        diag_led_rst   
);

    wire sys_clk;
    
    reg [26:0] cnt;
    always @(posedge sys_clk) cnt <= cnt + 1;
    assign diag_led_blink = cnt[26];   
    assign diag_led_rst   = ~CPU_RESETN; 
    
    MMIO MMIO_i
       (.DDR3_0_addr(DDR3_addr),
        .DDR3_0_ba(DDR3_ba),
        .DDR3_0_cas_n(DDR3_cas_n),
        .DDR3_0_ck_n(DDR3_ck_n),
        .DDR3_0_ck_p(DDR3_ck_p),
        .DDR3_0_cke(DDR3_cke),
        .DDR3_0_cs_n(DDR3_cs_n),
        .DDR3_0_dm(DDR3_dm),
        .DDR3_0_dq(DDR3_dq),
        .DDR3_0_dqs_n(DDR3_dqs_n),
        .DDR3_0_dqs_p(DDR3_dqs_p),
        .DDR3_0_odt(DDR3_odt),
        .DDR3_0_ras_n(DDR3_ras_n),
        .DDR3_0_reset_n(DDR3_reset_n), 
        .DDR3_0_we_n(DDR3_we_n),
        .UART_0_rxd(UART_rxd),
        .UART_0_txd(UART_txd),
        .button_resetn(CPU_RESETN),
        .clk_in(CLK100MHZ),
        .mem_retn(),
        .sys_clk(sys_clk));
endmodule