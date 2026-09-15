module DSP_Multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] multiplicand,
    input  wire [31:0] multiplier,
    input  wire [ 2:0] MUL_DIV_ctrl,

    output      [31:0] MUL_out,
    output reg         MUL_done
);

    localparam MUL    = 3'b000;
    localparam MULH   = 3'b001;
    localparam MULHSU = 3'b010;
    localparam MULHU  = 3'b011;

    // One 33x33 signed multiply covers all four variants: the operand that is
    // unsigned for this opcode gets a zero top bit, the rest get their sign
    // bit. MULHSU is signed(rs1) x unsigned(rs2), so only the multiplier side
    // is zero-extended there.
    //
    // The previous version sign-extended both operands to 64 bits inside a
    // four-way case, i.e. four independent 64x64 multiplies for the synthesiser
    // to build and mux -- 10 DSP48 slices for what needs at most four.
    wire unsigned_a = (MUL_DIV_ctrl == MULHU);
    wire unsigned_b = (MUL_DIV_ctrl == MULHU) || (MUL_DIV_ctrl == MULHSU);

    wire signed [32:0] a = {unsigned_a ? 1'b0 : multiplicand[31], multiplicand};
    wire signed [32:0] b = {unsigned_b ? 1'b0 : multiplier[31],   multiplier};

    // dsp_p IS the EX/MEM pipeline register for multiplies.
    //
    // The multiply array now sits in the EX cycle, between the forwarding
    // muxes and this register, instead of after it. That is what lets Exec.v
    // report done at start: the product is guaranteed to be in dsp_p on the
    // next cycle, where Backend_top.v's MEM slot picks it up. Vivado absorbs
    // this into the DSP48's own P register, so it costs no fabric flops.
    (* use_dsp = "yes" *) reg signed [65:0] dsp_p;
    reg high;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dsp_p    <= 66'sd0;
            high     <= 1'b0;
            MUL_done <= 1'b0;
        end else if (start) begin
            dsp_p    <= a * b;
            high     <= (MUL_DIV_ctrl != MUL);
            MUL_done <= 1'b1;
        end else begin
            MUL_done <= 1'b0;
        end
    end

    // Stays readable until the next start, which Backend_top.v's admission
    // check cannot let happen while this result is still in the MEM slot.
    assign MUL_out = high ? dsp_p[63:32] : dsp_p[31:0];

endmodule
