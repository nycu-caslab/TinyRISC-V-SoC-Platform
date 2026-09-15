`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/21 19:38:15
// Design Name: 
// Module Name: dcache_axiBus_bridge
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


module icache_axiBus_bridge(
    input aclk,
    input aresetn,

    // I-Cache Native Memory Interface //
    input [31:0] mem_addr,
    output rm_rdy,
    input req_rm,
    output [255:0] rm_data,
    output  rm_success,
    output  rm_complete,

    // AXI4 Master Interface (M_AXI) //
    
    // AR Channel
    output reg [31:0] M_AXI_ARADDR,
    output  [7:0] M_AXI_ARLEN,
    output  [2:0] M_AXI_ARSIZE,
    output  [1:0] M_AXI_ARBURST,
    output  M_AXI_ARLOCK,
    output  [3:0] M_AXI_ARCACHE,
    output  [2:0] M_AXI_ARPROT,
    output  [3:0] M_AXI_ARQOS,
    output  [15:0] M_AXI_ARUSER,
    output reg M_AXI_ARVALID,
    input M_AXI_ARREADY,
    
    // R Channel
    input [255:0] M_AXI_RDATA,
    input [1:0] M_AXI_RRESP,
    input M_AXI_RLAST,
    input M_AXI_RVALID,
    output M_AXI_RREADY
);
    parameter LEN = 8'd0; // beats
    parameter DATA_SIZE = 3'd5; //256 bits = 32B
    parameter BURST = 2'd1; // 0=> fixed , 1INCR
    parameter LOCK = 1'd0; //normal
    parameter CACHE = 4'd3; // official recommended
    parameter PROT = 3'd0; // mormal, no os, no secure
    parameter QOS = 4'd15; //priority
    //parameter REGION = 0; //use in multi logic function with single physical device
    parameter USER = 16'd0; // self-def

    // FSM
    parameter IDLE = 0, RM = 1;//, WB = 2;
    reg cs;
    
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            cs <= 0;
            M_AXI_ARVALID <= 0;
            M_AXI_ARADDR <= 0;
        end
        else begin
            case(cs)
                IDLE : begin
                    if(req_rm)begin
                        cs <= RM;
                        M_AXI_ARVALID <= 1;
                        M_AXI_ARADDR <= {mem_addr[31:5],5'd0};
                    end
                    else begin
                        cs <= IDLE;
                        M_AXI_ARVALID <= 0;
                    end
                end
                RM :    begin
                    if(M_AXI_ARVALID & M_AXI_ARREADY)begin
                        cs <= IDLE;
                        M_AXI_ARVALID <= 0;
                    end
                    else
                        cs <= RM;
                end
				// WB : begin
					// if(M_AXI_RVALID)
						// cs <= IDLE;
				// end
            endcase
        end    
    end
    

    assign M_AXI_ARLEN = LEN;
    assign M_AXI_ARSIZE = DATA_SIZE;
    assign M_AXI_ARBURST = BURST;
    assign M_AXI_ARLOCK = LOCK;
    assign M_AXI_ARCACHE = CACHE;
    assign M_AXI_ARPROT = PROT;
    assign M_AXI_ARQOS = QOS;
    assign M_AXI_ARUSER = USER;    

    // R channel
    assign M_AXI_RREADY = 1;
    assign rm_complete = M_AXI_RVALID;
    assign rm_success = (M_AXI_RRESP == 0) & M_AXI_RLAST;
    assign rm_data = M_AXI_RDATA;
    
    assign rm_rdy = cs == IDLE;
endmodule
