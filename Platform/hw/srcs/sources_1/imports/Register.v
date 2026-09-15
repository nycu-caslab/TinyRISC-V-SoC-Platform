module Register #(parameter sp_init = 65536) (
    input clk,
    input rst_n,

    input [4:0] rs1,
    input [4:0] rs2,
    
    input wr_en,
    input [4:0] rd,
    input [31:0] data_i,
    
    output [31:0] rd_data1_o,
    output [31:0] rd_data2_o
);
    reg [31:0] regs [0:31];
    
    assign rd_data1_o = regs[rs1];
    assign rd_data2_o = regs[rs2];

    always @(negedge clk, negedge rst_n) begin
        if(~rst_n) begin
            regs[0] <= 0; regs[1] <= 0; regs[2] <= sp_init; regs[3] <= 0;
            regs[4] <= 0; regs[5] <= 0; regs[6] <= 0; regs[7] <= 0;
            regs[8] <= 0; regs[9] <= 0; regs[10] <= 0; regs[11] <= 0;
            regs[12] <= 0; regs[13] <= 0; regs[14] <= 0; regs[15] <= 0;
            regs[16] <= 0; regs[17] <= 0; regs[18] <= 0; regs[19] <= 0;
            regs[20] <= 0; regs[21] <= 0; regs[22] <= 0; regs[23] <= 0;
            regs[24] <= 0; regs[25] <= 0; regs[26] <= 0; regs[27] <= 0;
            regs[28] <= 0; regs[29] <= 0; regs[30] <= 0; regs[31] <= 0;
        end
        else if(wr_en)
            regs[rd] <= (rd == 0) ? 0 : data_i;
    end

endmodule
