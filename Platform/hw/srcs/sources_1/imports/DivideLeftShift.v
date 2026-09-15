module DivideLeftShift (
    input [65:0] r_i,
    input [33:0] d_i,
    input [ 4:0] shift_i,
    output reg [65:0] r_o, //66
    output reg [33:0] d_o, //34
    output reg [ 4:0] shift_o
);
    integer i;

    wire [33:0] mask;
    assign mask = 34'h080000000;

    always @(*) begin

        r_o = r_i;
        d_o = d_i;
        shift_o = shift_i;

        for (i = 0; i < 8; i = i + 1) begin
            if (~|(mask & d_o)) begin
                r_o = r_o << 1;
                d_o = d_o << 1;
                shift_o = shift_o + 1;
            end
        end
        
    end

endmodule