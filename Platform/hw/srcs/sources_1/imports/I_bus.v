module I_bus(
    input clk,
    input rst_n,
    
    output       ibus_ready,
    output       inst_valid,
    output       ibus_hit,
    
    input        fetch_vld,
    input [31:0] fetch_addr,
    
    output [31:0] inst_o,
    output [31:0] pc_o,
    
    input invalidate_i,
    input flush_i,
    output flush_status_o,
    
    // Memory bus interface
    input rm_rdy,
    output [31:0] rm_addr,
    input rm_success,
    input rm_complete,
    output req_rm,
    input [255:0] rm_data
);
    
    localparam IROM_BASE = 32'h0000_0000;
    localparam IROM_END  = 32'h0000_0FFF;
    localparam ICache_BASE = 32'h6000_0000;
    localparam ICache_END  = 32'h67FF_FFFF;    
    
    wire is_rom_addr   = (fetch_addr <= IROM_END);
    wire is_cache_addr = (fetch_addr <= ICache_END) && (fetch_addr >= ICache_BASE);

    reg [31:0] inst_pc_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            inst_pc_reg <= 32'd0;
        else if (fetch_vld && ibus_ready) 
            inst_pc_reg <= fetch_addr;
    end
    assign pc_o = inst_pc_reg;

    // BootROM
    reg rom_vld;
    wire [31:0] rom_inst;
    wire rom_hit = is_rom_addr;
    
    BootROM m_bootrom (
        .clk  (clk),             
        .addr (fetch_addr),   
        .dout (rom_inst)    
    );
    
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rom_vld <= 0;
        end else begin
            rom_vld <= (invalidate_i || flush_i) ? 0 : (is_rom_addr && fetch_vld && ibus_ready);
        end
    end
    
    // I-Cache
    wire        icache_rdy;
    wire [31:0] cache_inst;
    wire        icache_excp;
    wire        icache_vld;
    wire        cache_hit;
    wire        icache_hit = cache_hit && is_cache_addr;

    icache_plus m_icache (
        .clk            (clk),            
        .rst_n          (rst_n),   
        .fetch_vld      (is_cache_addr && fetch_vld),
        .fetch_addr     (fetch_addr),           
        .invalidate_i   (invalidate_i),
        .flush_i        (flush_i),
        .flush_status_o (flush_status_o),
        .icache_rdy_o   (icache_rdy),     
        .cpu_inst_o     (cache_inst),       
        .i_exception    (icache_excp),     
        .icache_vld_o   (icache_vld),     
        .hit_o          (cache_hit),
        
        .rm_rdy         (rm_rdy),    
        .mem_addr       (rm_addr),   
        .rm_success     (rm_success),   
        .rm_complete    (rm_complete),
        .req_rm         (req_rm),     
        .rm_data        (rm_data)    
    );
    
    // output
    assign ibus_hit   = icache_hit | rom_hit;
    assign ibus_ready = is_cache_addr ? icache_rdy : 1'b1;
    
    assign inst_valid = icache_vld | rom_vld; 
    assign inst_o     = icache_vld ? cache_inst : rom_inst;

endmodule