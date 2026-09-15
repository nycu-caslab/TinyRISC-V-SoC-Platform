//-----------------------------------------------------------------
// LSU Queue
//-----------------------------------------------------------------

module lsu_queue
#(
    parameter DATASIZE = 32, 
    parameter LENGTH = 32,  // Memory number of queue.
    parameter DEPTH = 8     // Maximal element of queue.
)  
(
    input clk_i,
    input rst_i,
    input [DATASIZE-1:0] data_i,
    input push_i,
    input pop_i,
    
    output [DATASIZE-1:0] data_o,
    output accept_o,                // Push success
    output valid_o                  // Pop success
);

localparam ADDRSIZE = 32;

reg [DATASIZE-1:0] ram_q[LENGTH-1:0];
reg [ADDRSIZE-1:0] wr_ptr;
reg [ADDRSIZE-1:0] rd_ptr;
reg [ADDRSIZE-1:0] count;

wire empty = (count == 0);
wire full  = (count == DEPTH);
wire accept = ~full;
wire valid  = ~empty;

integer i;

assign data_o = ram_q[rd_ptr];
assign accept_o = accept;
assign valid_o = valid;

always @(posedge clk_i or negedge rst_i) begin
    if (~rst_i) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count  <= 0;
        for (i = 0; i < LENGTH; i = i + 1) begin
            ram_q[i] <= 0;
        end
    end else begin
        // Push
        if (accept && push_i) begin
            ram_q[wr_ptr] <= data_i;
            wr_ptr <= (wr_ptr == LENGTH - 1) ? 0 : wr_ptr + 1;
        end

        // Pop
        if (valid && pop_i) begin
            rd_ptr <= (rd_ptr == LENGTH - 1) ? 0 : rd_ptr + 1;
        end

        // Count Element
        case ({accept && push_i, valid && pop_i})
            2'b10: count <= count + 1;
            2'b01: count <= count - 1;
            default: count <= count;
        endcase

    end
end

endmodule
