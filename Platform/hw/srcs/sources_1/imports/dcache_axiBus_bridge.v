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


module dcache_axiBus_bridge(
    input aclk,
    input aresetn,

    // D-Cache Native Memory Interface //
    input [31:0] mem_addr,
    
    output rm_rdy,
    input rm_vld,
    output [255:0] rm_data,
    output  rm_success,
    output  rm_complete,

    output wm_rdy,
    input wm_vld,
    input [255:0] wm_data,
    
    output wm_success,
    output wm_complete,

    // AXI4 Master Interface (M_AXI) //
    // AW Channel
    //output  [3:0] M_AXI_AWID,
    output reg [31:0] M_AXI_AWADDR,
    output  [7:0] M_AXI_AWLEN,
    output  [2:0] M_AXI_AWSIZE,
    output  [1:0] M_AXI_AWBURST,
    output  M_AXI_AWLOCK,
    output  [3:0] M_AXI_AWCACHE,
    output  [2:0] M_AXI_AWPROT,
    output  [3:0] M_AXI_AWQOS,
    output  [15:0] M_AXI_AWUSER,
    output reg M_AXI_AWVALID,
    input M_AXI_AWREADY,
    // W Channel
    output reg [255:0] M_AXI_WDATA,
    output  [31:0] M_AXI_WSTRB,
    output reg M_AXI_WLAST,
    output reg M_AXI_WVALID,
    input M_AXI_WREADY,
    
    // B Channel
    //input [3:0] M_AXI_BID,
    input [1:0] M_AXI_BRESP,
    //input [15:0] M_AXI_BUSER,
    input M_AXI_BVALID,
    output  M_AXI_BREADY,
    
    // AR Channel
    //output  [3:0] M_AXI_ARID,
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
    input [3:0] M_AXI_RID,
    input [255:0] M_AXI_RDATA,
    input [1:0] M_AXI_RRESP,
    input M_AXI_RLAST,
    input M_AXI_RVALID,
    output M_AXI_RREADY
);
    //parameter ID = 3'd1;
    parameter LEN = 8'd0; // beats
    parameter DATA_SIZE = 3'd5; //256 bits = 32B
    parameter BURST = 2'd1; // 0=> fixed , 1INCR
    parameter LOCK = 1'd0; //normal
    parameter CACHE = 4'd3; // official recommended
    parameter PROT = 3'd0; // mormal, no os, no secure
    parameter QOS = 4'd7; //priority
    //parameter REGION = 0; //use in multi logic function with single physical device
    parameter USER = 16'd0; // self-def
    parameter STRB = 32'hffff_ffff;
    
    // AW seeting
    // aw parameter
    parameter AW_IDLE = 0;
    parameter AW_COMP = 1;
    
    reg awcs,awns;
    
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)
            awcs <= 0;
        else
            awcs <= awns;
    end

    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            M_AXI_AWADDR <= 0;
            M_AXI_AWVALID <= 0;
        end
        else begin
            if(M_AXI_AWVALID & M_AXI_AWREADY)begin
                M_AXI_AWVALID <= 0;
            end
            else if(wm_vld & wm_rdy)begin
                M_AXI_AWVALID <= 1;
				M_AXI_AWADDR <= mem_addr;
            end  
        end
    end
    
    always@(*)begin
        case(awcs)
            AW_IDLE :   if(wm_vld)begin
                            awns = AW_COMP;
                        end 
                        else begin
                            awns = AW_IDLE;
                        end
            AW_COMP :   if(M_AXI_AWVALID & M_AXI_AWREADY)
                            awns = AW_IDLE;
                        else
                            awns = AW_COMP;
        endcase
    end
    
    //assign M_AXI_AWID = ID;
    assign M_AXI_AWLEN = LEN;
    assign M_AXI_AWSIZE = DATA_SIZE;
    assign M_AXI_AWBURST = BURST;
    assign M_AXI_AWLOCK = LOCK;
    assign M_AXI_AWCACHE = CACHE;
    assign M_AXI_AWPROT = PROT;
    assign M_AXI_AWQOS = QOS;
    assign M_AXI_AWUSER = USER;
    
    //W setting
    parameter W_IDLE = 0;
    parameter W_COMP = 1;
    
    reg wcs,wns;
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)
            wcs <= 0;
        else
            wcs <= wns;
    end

    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            M_AXI_WDATA <= 0;
            M_AXI_WVALID <= 0;
            M_AXI_WLAST <= 0;
        end
        else begin
            if(M_AXI_WVALID & M_AXI_WREADY)begin
                M_AXI_WVALID <= 0;
                M_AXI_WLAST <= 0;
            end
            else if(wm_vld)begin
                M_AXI_WVALID <= 1;
                M_AXI_WLAST <= 1;
				M_AXI_WDATA <= wm_data;
            end  
        end
    end
    
    always@(*)begin
        case(wcs)
            W_IDLE :   if(wm_vld)begin
                            wns = W_COMP;
                        end 
                        else begin
                            wns = W_IDLE;
                        end
            W_COMP :   if(M_AXI_WVALID & M_AXI_WREADY)
                            wns = W_IDLE;
                        else
                            wns = W_COMP;
        endcase
    end
    
    assign wm_rdy = (awcs == AW_IDLE) & (wcs == W_IDLE);
    
   
    assign M_AXI_WSTRB = STRB;
    assign M_AXI_WUSER = USER;

    //B channel
    assign M_AXI_BREADY = 1;
    assign wm_complete = M_AXI_BVALID;// & (M_AXI_BID == ID);
    assign wm_success = (M_AXI_BRESP == 0);
    
    
    //AR channel
    parameter AR_IDLE = 0;
    parameter AR_COMP = 1;
    
    reg arcs,arns;
    
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)
            arcs <= 0;
        else
            arcs <= arns;
    end

    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            M_AXI_ARADDR <= 0;
            M_AXI_ARVALID <= 0;
        end
        else begin
            if(M_AXI_ARVALID & M_AXI_ARREADY)begin
                M_AXI_ARVALID <= 0;
            end
            else if(rm_vld)begin
                M_AXI_ARVALID <= 1;
				M_AXI_ARADDR <= mem_addr;
            end  
        end
    end
    
    always@(*)begin
        case(arcs)
            AR_IDLE :   if(rm_vld)begin
                            arns = AR_COMP;
                        end 
                        else begin
                            arns = AR_IDLE;
                        end
            AR_COMP :   if(M_AXI_ARVALID & M_AXI_ARREADY)
                            arns = AR_IDLE;
                        else
                            arns = AR_COMP;
        endcase
    end

    //assign M_AXI_ARID = ID;
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
    assign rm_complete = M_AXI_RVALID;// & (M_AXI_RID == ID);
    assign rm_success = (M_AXI_RRESP == 0) & M_AXI_RLAST;
    assign rm_data = M_AXI_RDATA;
    
    assign rm_rdy = arcs == AR_IDLE;
endmodule
