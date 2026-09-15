//-----------------------------------------------------------------
// IB Queue
//-----------------------------------------------------------------

module IB_queue
#(
    parameter DATASIZE = 32,
    parameter DEPTH = 16,
    parameter CNT_WIDTH = $clog2(DEPTH+1)
)  
(
    input clk_i,
    input rst_n,
    input [DATASIZE-1:0] data_i,
    input push_i,
    input pop_i,
	input flush_i,
	
    output [CNT_WIDTH-1:0] count_o,
	output is_full,
	output is_empty,
    output [DATASIZE-1:0] data_o
);

localparam ADDRSIZE = 32;

reg [DATASIZE-1:0] ram_q[DEPTH-1:0];

localparam PTR_WIDTH = $clog2(DEPTH);
reg [PTR_WIDTH-1:0] wr_ptr;
reg [PTR_WIDTH-1:0] rd_ptr;
reg [CNT_WIDTH-1:0] count;

wire empty = (count == 0);
wire full  = (count == DEPTH);
wire accept = ~full | pop_i;
wire valid  = ~empty;

integer i;

assign data_o = ram_q[rd_ptr];
assign is_full = full;
assign is_empty = empty;
assign count_o = count;

always @(posedge clk_i or negedge rst_n) begin
    if (~rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count  <= 0;
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram_q[i] <= 0;
        end
    end else if (flush_i)begin // flush
		wr_ptr <= 0;
		rd_ptr <= 0;
		count  <= 0;
	end else begin
        // Push
        if (accept && push_i) begin
            ram_q[wr_ptr] <= data_i;
            wr_ptr <= (wr_ptr == DEPTH - 1) ? 0 : wr_ptr + 1;
        end

        // Pop
        if (valid && pop_i) begin
            rd_ptr <= (rd_ptr == DEPTH - 1) ? 0 : rd_ptr + 1;
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
