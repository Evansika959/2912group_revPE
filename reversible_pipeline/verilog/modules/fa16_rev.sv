module fa16_rev (
`ifdef USE_POWER_PINS
    inout logic VDD,
    inout logic VSS,
`endif
    input  logic        dir,      // 0: forward  (A,B,C0_f,Z -> S,a_b,C0_b,C15)
                                 // 1: backward (S,a_b,C0_b,C15 -> A,B,C0_f,Z)

    // Forward Interface: Used when dir == 0
    // Input: A, B, C0_f, z
    input  logic [15:0] f_a,
    input  logic [15:0] f_b,
    input  logic        f_c0_f,
    input  logic        f_z,

    // Output: S, A_B, C0_b, C15
    output logic [15:0] f_s,
    output logic [15:0] f_a_b,
    output logic        f_c0_b,
    output logic        f_c15,

    // Backward Interface: Used when dir == 1
    // Output: S, A_B, C0_b, C15
    input  logic [15:0] r_s,
    input  logic [15:0] r_a_b,
    input  logic        r_c0_b,
    input  logic        r_c15,

    // Output: A, B, C0_f, z (Original input recovered)
    output logic [15:0] r_a,
    output logic [15:0] r_b,
    output logic        r_c0_f,
    output logic        r_z
);

    // Simple behavioural approximation of the reversible adder
    logic [16:0] forward_accum;
    logic [16:0] backward_accum;
    logic [15:0] forward_sum;
    logic        forward_carry;
    logic [15:0] backward_sum;

    assign forward_sum   = forward_accum[15:0];
    assign forward_carry = forward_accum[16];
    assign backward_sum  = backward_accum[15:0];
    // Forward direction: produce sum, carry, and simple pass-through signals
    always_comb begin
        forward_accum = {1'b0, f_a} + {1'b0, f_b} + {16'b0, f_c0_f};

        if (dir == 1'b0) begin
            f_s    = forward_sum;
            f_a_b  = f_a;         // simple mirror of input A
            f_c0_b = f_z;         // reuse external z as buffered output
            f_c15  = forward_carry;
        end else begin
            f_s    = '0;
            f_a_b  = '0;
            f_c0_b = 1'b0;
            f_c15  = 1'b0;
        end
    end

    // Backward direction: reconstruct input-side view from the reverse interface
    always_comb begin
        backward_accum = {1'b0, r_s} - {1'b0, r_a_b} - {16'b0, r_c15};

        if (dir == 1'b1) begin
            r_b    = backward_sum;
            r_a    = r_a_b;
            r_c0_f = r_c0_b;
            r_z    = r_c15;
        end else begin
            r_b    = '0;
            r_a    = '0;
            r_c0_f = 1'b0;
            r_z    = 1'b0;
        end
    end


endmodule