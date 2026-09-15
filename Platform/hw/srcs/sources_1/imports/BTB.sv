`timescale 1ns / 1ps

// Direct-mapped Branch Target Buffer with per-entry direction prediction.
//
// lookup_pc_i is read combinationally.  When the indexed entry is valid and
// its tag matches, lookup_hit_o is asserted and lookup_target_o contains the
// previously recorded branch target. Conditional-branch entries also carry
// an independent 2-bit saturating counter. Direct jumps are always predicted
// taken after allocation and do not use the counter.
//
// The resolve stage should assert update_en_i for a branch or jump whose
// target is known. JALR must remain excluded because its target is dynamic.
module BTB #(
    // ENTRY_NUM must be a power of two and at least two.
    parameter integer ENTRY_NUM = 32
) (
    input  logic        clk,
    input  logic        rst_n,

    // Fetch/lookup interface
    input  logic [31:0] lookup_pc_i,
    output logic        lookup_hit_o,
    output logic        lookup_predict_taken_o,
    output logic        lookup_is_jump_o,
    output logic [31:0] lookup_target_o,

    // Branch resolution/update interface
    input  logic        update_en_i,
    input  logic [31:0] update_pc_i,
    input  logic [31:0] update_target_i,
    input  logic        update_is_jump_i,
    input  logic        update_taken_i
);

localparam integer INDEX_WIDTH = $clog2(ENTRY_NUM);
localparam integer TAG_WIDTH   = 32 - INDEX_WIDTH - 2;

localparam logic [1:0] STRONGLY_NOT_TAKEN = 2'b00;
localparam logic [1:0] WEAKLY_NOT_TAKEN   = 2'b01;
localparam logic [1:0] WEAKLY_TAKEN       = 2'b10;
localparam logic [1:0] STRONGLY_TAKEN     = 2'b11;

logic                 valid_array  [0:ENTRY_NUM-1];
logic                 is_jump_array[0:ENTRY_NUM-1];
logic [TAG_WIDTH-1:0] tag_array    [0:ENTRY_NUM-1];
logic [31:0]          target_array [0:ENTRY_NUM-1];
logic [1:0]           counter_array[0:ENTRY_NUM-1];
logic [1:0]           update_counter_d;

wire [INDEX_WIDTH-1:0] lookup_index =
    lookup_pc_i[INDEX_WIDTH+1:2];
wire [TAG_WIDTH-1:0] lookup_tag =
    lookup_pc_i[31:INDEX_WIDTH+2];

wire [INDEX_WIDTH-1:0] update_index =
    update_pc_i[INDEX_WIDTH+1:2];
wire [TAG_WIDTH-1:0] update_tag =
    update_pc_i[31:INDEX_WIDTH+2];
wire update_entry_matches = valid_array[update_index] &&
                            (tag_array[update_index] == update_tag) &&
                            !is_jump_array[update_index];

always_comb begin
    lookup_hit_o    = valid_array[lookup_index] &&
                      (tag_array[lookup_index] == lookup_tag) &&
                      (lookup_pc_i[1:0] == 2'b00);
    lookup_is_jump_o = lookup_hit_o && is_jump_array[lookup_index];
    lookup_predict_taken_o = lookup_hit_o &&
                             (is_jump_array[lookup_index] ||
                              counter_array[lookup_index][1]);
    lookup_target_o = lookup_hit_o ? target_array[lookup_index] : 32'b0;
end

always_comb begin
    // A newly allocated conditional branch starts as though a WNT counter
    // had just observed its first resolved outcome. Existing matching
    // conditional entries retain and update their local history.
    if (!update_entry_matches) begin
        update_counter_d = update_taken_i ? WEAKLY_TAKEN
                                          : STRONGLY_NOT_TAKEN;
    end else begin
        case (counter_array[update_index])
            STRONGLY_NOT_TAKEN:
                update_counter_d = update_taken_i ? WEAKLY_NOT_TAKEN
                                                  : STRONGLY_NOT_TAKEN;
            WEAKLY_NOT_TAKEN:
                update_counter_d = update_taken_i ? WEAKLY_TAKEN
                                                  : STRONGLY_NOT_TAKEN;
            WEAKLY_TAKEN:
                update_counter_d = update_taken_i ? STRONGLY_TAKEN
                                                  : WEAKLY_NOT_TAKEN;
            STRONGLY_TAKEN:
                update_counter_d = update_taken_i ? STRONGLY_TAKEN
                                                  : WEAKLY_TAKEN;
            default:
                update_counter_d = update_taken_i ? WEAKLY_TAKEN
                                                  : STRONGLY_NOT_TAKEN;
        endcase
    end
end

integer entry;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (entry = 0; entry < ENTRY_NUM; entry = entry + 1)
            valid_array[entry] <= 1'b0;
    end else if (update_en_i && (update_pc_i[1:0] == 2'b00)) begin
        valid_array[update_index]  <= 1'b1;
        is_jump_array[update_index] <= update_is_jump_i;
        tag_array[update_index]    <= update_tag;
        target_array[update_index] <= update_target_i;
        // The value is irrelevant for direct jumps, but initializing it keeps
        // the entry deterministic if its instruction type later changes.
        counter_array[update_index] <= update_is_jump_i
            ? WEAKLY_NOT_TAKEN : update_counter_d;
    end
end

endmodule
