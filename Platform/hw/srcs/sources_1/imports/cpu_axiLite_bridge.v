`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
//
// Create Date: 2025/09/19 00:45:38
// Design Name: 
// Module Name: cpu_axiCdma_bridge
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: AXI4-Lite Master interface to control a slave device.
//
// Dependencies: 
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// This module provides the interface for an AXI4-Lite Master.
// Control logic must be implemented elsewhere.
//////////////////////////////////////////////////////////////////////////////////

module cpu_axiLite_bridge (   

    ///////////////////////////////////////////
    //                                       //
    //           CPU interface             //
    //                                       //
    ///////////////////////////////////////////
    input aclk,
    input aresetn,
    
    input req_rd_mm,
    input req_wr_mm,
    input [31:0] mm_addr_i,
    input [31:0] mm_data_i,
    
    output reg [31:0]mm_data_out,
    output [1:0]mm_exception,
    output mm_rdy,
	output mm_vld,
    //

    
    ///////////////////////////////////////////
    //                                       //
    //           AXI interface             //
    //                                       //
    ///////////////////////////////////////////
    
    // AXI4-Lite Master AW Channel
    output  reg        m_axi_lite_awvalid,
    input           m_axi_lite_awready,
    output reg[31:0]  m_axi_lite_awaddr,
    
    // AXI4-Lite Master W Channel
    output  reg     m_axi_lite_wvalid,
    input           m_axi_lite_wready,
    output reg [31:0]  m_axi_lite_wdata,
    output [3:0] m_axi_lite_wstrb,
    
    // AXI4-Lite Master B Channel
    input           m_axi_lite_bvalid,
    output   reg    m_axi_lite_bready,
    input   [1:0]   m_axi_lite_bresp,

    // AXI4-Lite Master AR Channel
    output   reg     m_axi_lite_arvalid,
    input           m_axi_lite_arready,
    output  reg [31:0]  m_axi_lite_araddr,
    
    // AXI4-Lite Master R Channel
    input           m_axi_lite_rvalid,
    output   reg    m_axi_lite_rready,
    input   [31:0]  m_axi_lite_rdata,
    input   [1:0]   m_axi_lite_rresp
);  
	//CPU interface
	reg mm_rvld,mm_wvld;
	assign mm_vld = mm_rvld | mm_wvld;
	

    reg b_exception,r_exception;
    assign m_axi_lite_wstrb = 4'hf;
    assign mm_exception = {b_exception,r_exception};
    
    wire wdone;
    wire rdone;
    // AW 
    parameter AW_IDLE = 0, AW_WAIT = 1;
    reg aw_cs;
   
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            aw_cs <= AW_IDLE;
            m_axi_lite_awvalid <= 0;
            m_axi_lite_awaddr <= 0;
        end
        else begin
            case(aw_cs)
                AW_IDLE : begin
                    if(req_wr_mm)begin
                        aw_cs <= AW_WAIT;
                        m_axi_lite_awvalid <= 1;
                        m_axi_lite_awaddr <= mm_addr_i;
                    end
                    else begin
                        aw_cs <= AW_IDLE;
                        m_axi_lite_awvalid <= 0;
                    end
                end
                AW_WAIT : begin
                    if(m_axi_lite_awready & m_axi_lite_awvalid)
                        m_axi_lite_awvalid <= 0;
                    aw_cs <= wdone ? AW_IDLE : AW_WAIT;
                end
           endcase
        end
    end
    
    // W 
    parameter W_IDLE = 0, W_WAIT = 1;
    reg w_cs;
   
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            w_cs <= W_IDLE;
            m_axi_lite_wvalid <= 0;
            m_axi_lite_wdata <= 0;
        end
        else begin
            case(w_cs)
                W_IDLE : begin
                    if(req_wr_mm)begin
                        w_cs <= W_WAIT;
                        m_axi_lite_wvalid <= 1;
                        m_axi_lite_wdata <= mm_data_i;
                    end
                    else begin
                        w_cs <= W_IDLE;
                        m_axi_lite_wvalid <= 0;
                    end
                end
                W_WAIT : begin
                    w_cs <= wdone ? W_IDLE : W_WAIT;
                    if(m_axi_lite_wready & m_axi_lite_wvalid)
                        m_axi_lite_wvalid <= 0;
                end
           endcase
        end
    end
    
    // B 
    parameter B_IDLE = 0, B_WAIT = 1;
    reg b_cs;
    assign wdone = (b_cs == B_IDLE);
   
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            b_cs <= B_IDLE;
            m_axi_lite_bready <= 0;
            b_exception <= 0;
			mm_wvld <= 0;
        end
        else begin
            case(b_cs)
                B_IDLE : begin
					mm_wvld <= 0;
                    if(req_wr_mm)begin
                        b_cs <= B_WAIT;
                        m_axi_lite_bready <= 1;
                        b_exception <= 0;
                    end
                    else begin
                        b_cs <= B_IDLE;
                        m_axi_lite_bready <= 0;
                        b_exception <= 0;
                    end
                end
                B_WAIT : begin
                    if(m_axi_lite_bready & m_axi_lite_bvalid)begin
                        m_axi_lite_bready <= 0;
						mm_wvld <= 1;
                        if(m_axi_lite_bresp == 0)
                            b_cs <= B_IDLE;
                        else begin
                            b_cs <= B_IDLE;
                            b_exception <= 1;
                        end
                    end
                end
           endcase
        end
    end
    
    //AR
    parameter AR_IDLE = 0, AR_WAIT = 1;
    reg ar_cs;
   
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            ar_cs <= AR_IDLE;
            m_axi_lite_arvalid <= 0;
            m_axi_lite_araddr <= 0;
        end
        else begin
            case(ar_cs)
                AR_IDLE : begin
                    if(req_rd_mm)begin
                        ar_cs <= AR_WAIT;
                        m_axi_lite_arvalid <= 1;
                        m_axi_lite_araddr <= mm_addr_i;
                    end
                    else begin
                        ar_cs <= AR_IDLE;
                        m_axi_lite_arvalid <= 0;
                    end
                end
                AR_WAIT : begin
                    if(m_axi_lite_arready & m_axi_lite_arvalid)
                        m_axi_lite_arvalid <= 0;
                    ar_cs <= rdone ? AR_IDLE : AR_WAIT;
                end
           endcase
        end
    end


    // R 
    parameter R_IDLE = 0, R_WAIT = 1;
    reg r_cs;
    assign rdone = (r_cs == R_IDLE);
   
    always@(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            r_cs <= R_IDLE;
            m_axi_lite_rready <= 0;
            r_exception <= 0;
            mm_data_out <= 0;
			mm_rvld <= 0;
        end
        else begin
            case(r_cs)
                R_IDLE : begin
					mm_rvld <= 0;
                    if(req_rd_mm)begin
                        r_cs <= R_WAIT;
                        m_axi_lite_rready <= 1;
                        r_exception <= 0;
                    end
                    else begin
                        r_cs <= R_IDLE;
                        m_axi_lite_rready <= 0;
                        r_exception <= 0;
                    end
                end
                R_WAIT : begin
                    if(m_axi_lite_rready & m_axi_lite_rvalid)begin
                        m_axi_lite_rready <= 0;
                        mm_data_out <= m_axi_lite_rdata;
						mm_rvld <= 1;
                        if(m_axi_lite_rresp == 0)
                            r_cs <= R_IDLE;
                        else begin
                            r_cs <= R_IDLE;
                            r_exception <= 1;
                        end
                    end
                end
           endcase
        end
    end
    
    assign mm_rdy = wdone & rdone;
endmodule