`timescale 1ns / 1ps

module CPU(
    input         clk,
(* mark_debug = "true" *)    input         rst_n,

    //---------------------------------------------------
    // I-Cache Bus (256-bit)
    //---------------------------------------------------
    input         ibus_rm_rdy,
    input         ibus_rm_success,
    input         ibus_rm_complete,
    input [255:0] ibus_rm_data,
    output        ibus_req_rm,
    output [31:0] ibus_rm_addr,

    //---------------------------------------------------
    // D-Cache Bus (256-bit)
    //---------------------------------------------------
    output [31:0]  dbus_rm_addr,
    input          dbus_rm_rdy,
    input  [255:0] dbus_rm_data,
    input          dbus_rm_success,
    input          dbus_rm_complete,
    output         dbus_rm_vld,
    
    input          dbus_wm_rdy,
    output [255:0] dbus_wm_data,
    output         dbus_wm_vld,
    input          dbus_wm_success,
    input          dbus_wm_complete,

    //---------------------------------------------------
    // MMIO AXI4-Lite Interface
    //---------------------------------------------------
    output        m_axi_lite_awvalid,
    input         m_axi_lite_awready,
    output [31:0] m_axi_lite_awaddr,
    output        m_axi_lite_wvalid,
    input         m_axi_lite_wready,
    output [31:0] m_axi_lite_wdata,
    output [ 3:0] m_axi_lite_wstrb,
    input         m_axi_lite_bvalid,
    output        m_axi_lite_bready,
    input  [ 1:0] m_axi_lite_bresp,
    output        m_axi_lite_arvalid,
    input         m_axi_lite_arready,
    output [31:0] m_axi_lite_araddr,
    input         m_axi_lite_rvalid,
    output        m_axi_lite_rready,
    input  [31:0] m_axi_lite_rdata,
    input  [ 1:0] m_axi_lite_rresp,

    //---------------------------------------------------
    // NPU Interface
    //---------------------------------------------------
    output [31:0] npu_rs1,
    output [31:0] npu_rs2,
    input  [31:0] npu_out,
    output        npu_start,
    input         npu_done,
    output [3:0]  npu_funct3,
    output [31:0] npu_funct7
);

    wire        cpu_req_inst;
    wire        cpu_inst_rdy;
    wire [31:0] cpu_inst_pc;
    wire [31:0] cpu_inst_data;
    wire        cpu_inst_pred_taken;

    wire        cpu_redirect_valid;
    wire [31:0] cpu_redirect_pc;

    wire        cpu_invalidate;
    wire        cpu_invalid_complete;

    wire        cpu_resolve_valid;
    wire        cpu_resolve_is_branch;
    wire        cpu_resolve_is_jump;
    wire        cpu_resolve_taken;
    wire [31:0] cpu_resolve_pc;
    wire [31:0] cpu_resolve_target;

    Frontend_top u_Frontend (
        .clk              (clk),
        .rst_n            (rst_n),

        .redirect_valid_i (cpu_redirect_valid),
        .redirect_pc_i    (cpu_redirect_pc),
        .resolve_valid_i  (cpu_resolve_valid),
        .resolve_is_branch_i(cpu_resolve_is_branch),
        .resolve_is_jump_i(cpu_resolve_is_jump),
        .resolve_taken_i  (cpu_resolve_taken),
        .resolve_pc_i     (cpu_resolve_pc),
        .resolve_target_i (cpu_resolve_target),
        .invalidate_i     (cpu_invalidate),
        .invalid_complete (cpu_invalid_complete),
        
        .req_inst_i       (cpu_req_inst),
        .inst_rdy_o       (cpu_inst_rdy),
        .inst_pc_o        (cpu_inst_pc),
        .inst_o           (cpu_inst_data),
        .inst_pred_taken_o(cpu_inst_pred_taken),

        .rm_rdy           (ibus_rm_rdy),
        .rm_success       (ibus_rm_success),
        .rm_complete      (ibus_rm_complete),
        .rm_data          (ibus_rm_data),
        .req_rm           (ibus_req_rm),
        .rm_addr          (ibus_rm_addr)
    );

    Backend_top u_Backend (
        .clk              (clk),
        .rst_n            (rst_n),

        .inst_rdy_i       (cpu_inst_rdy),
        .inst_pc_i        (cpu_inst_pc),
        .inst_i           (cpu_inst_data),
        .inst_pred_taken_i(cpu_inst_pred_taken),
        .req_inst_o       (cpu_req_inst),
        
        .redirect_valid_o (cpu_redirect_valid),
        .redirect_pc_o    (cpu_redirect_pc),
        .invalidate_o     (cpu_invalidate),
        .invalid_complete_i(cpu_invalid_complete),
        .resolve_valid_o  (cpu_resolve_valid),
        .resolve_is_branch_o(cpu_resolve_is_branch),
        .resolve_is_jump_o(cpu_resolve_is_jump),
        .resolve_taken_o  (cpu_resolve_taken),
        .resolve_pc_o     (cpu_resolve_pc),
        .resolve_target_o (cpu_resolve_target),

        .dbus_rm_addr       (dbus_rm_addr),
        .dbus_rm_rdy        (dbus_rm_rdy),
        .dbus_rm_data       (dbus_rm_data),
        .dbus_rm_success    (dbus_rm_success),
        .dbus_rm_complete   (dbus_rm_complete),
        .dbus_rm_vld        (dbus_rm_vld),
        
        .dbus_wm_rdy        (dbus_wm_rdy),
        .dbus_wm_data       (dbus_wm_data),
        .dbus_wm_vld        (dbus_wm_vld),
        .dbus_wm_success    (dbus_wm_success),
        .dbus_wm_complete   (dbus_wm_complete),
        
        .m_axi_lite_awvalid (m_axi_lite_awvalid),
        .m_axi_lite_awready (m_axi_lite_awready),
        .m_axi_lite_awaddr  (m_axi_lite_awaddr),
        .m_axi_lite_wvalid  (m_axi_lite_wvalid),
        .m_axi_lite_wready  (m_axi_lite_wready),
        .m_axi_lite_wdata   (m_axi_lite_wdata),
        .m_axi_lite_wstrb   (m_axi_lite_wstrb),
        .m_axi_lite_bvalid  (m_axi_lite_bvalid),
        .m_axi_lite_bready  (m_axi_lite_bready),
        .m_axi_lite_bresp   (m_axi_lite_bresp),
        .m_axi_lite_arvalid (m_axi_lite_arvalid),
        .m_axi_lite_arready (m_axi_lite_arready),
        .m_axi_lite_araddr  (m_axi_lite_araddr),
        .m_axi_lite_rvalid  (m_axi_lite_rvalid),
        .m_axi_lite_rready  (m_axi_lite_rready),
        .m_axi_lite_rdata   (m_axi_lite_rdata),
        .m_axi_lite_rresp   (m_axi_lite_rresp),

        .rs1_o            (npu_rs1),
        .rs2_o            (npu_rs2),
        .NPU_out          (npu_out),
        .NPU_start        (npu_start),
        .NPU_done         (npu_done),
        .funct3_o         (npu_funct3),
        .funct7_o         (npu_funct7)
    );

endmodule
