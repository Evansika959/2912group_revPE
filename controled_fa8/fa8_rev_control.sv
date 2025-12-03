// This takes in fa8_rev_wrapped, and achieves bidirectional control under signal 'dir'
/*
Wrapping Structure:
Outter Logic <-> f_/r_ Port <-> fa8_rev_ctrl <-> pin_* bus <-> fa8_rev_wrapped
- fa8_rev_wrapped: the macro defined
- pin_*: physical wire connected to the macro pin, tristate bus
- fa8_rev_ctrl: control logic actually defined in the module
- f_/r_ Port: What the upper level(testbench) actually see
- Outter Logic: Testbench Written


*/

module fa8_rev_ctrl (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        dir,      // 0: forward  (A,B,C0_f,Z -> S,a_b,C0_b,C7)
                                 // 1: backward (S,a_b,C0_b,C7 -> A,B,C0_f,Z)

    // Forward Interface: Used when dir == 0
    // Input: A, B, C0_f, z
    input  wire [7:0]  f_a,
    input  wire [7:0]  f_b,
    input  wire        f_c0_f,
    input  wire        f_z,

    // Output: S, A_B, C0_b, C7
    output wire [7:0]  f_s,
    output wire [7:0]  f_a_b,
    output wire        f_c0_b,
    output wire        f_c7,

    // Backward Interface: Used when dir == 1
    // Output: S, A_B, C0_b, C7
    input  wire [7:0]  r_s,
    input  wire [7:0]  r_a_b,
    input  wire        r_c0_b,
    input  wire        r_c7,

    // Output: A, B, C0_f, z (Original input recovered)
    output wire [7:0]  r_a,
    output wire [7:0]  r_b,
    output wire        r_c0_f,
    output wire        r_z
);

    // ============================================================
    // 1) Define the physical pin (bus) connected to the macro 
    //    Allowing multiple tri-state driver
    // ============================================================
    tri [7:0]  pin_a;
    tri [7:0]  pin_a_not;
    tri [7:0]  pin_b;
    tri [7:0]  pin_b_not;
    tri        pin_c0_f;
    tri        pin_c0_f_not;
    tri        pin_z;
    tri        pin_z_not;

    tri [7:0]  pin_s;
    tri [7:0]  pin_s_not;
    tri [7:0]  pin_a_b;
    tri [7:0]  pin_a_not_b;
    tri        pin_c0_b;
    tri        pin_c0_b_not;
    tri        pin_c7;
    tri        pin_c7_not;

    // ============================================================
    // 2) Instantiating the reversible adder core
    // ============================================================
    fa8_rev_wrapped u_rev (
    `ifdef USE_POWER_PINS
        .VDD     (VDD),
        .VSS     (VSS),
    `endif
        .a        (pin_a),
        .a_not    (pin_a_not),
        .b        (pin_b),
        .b_not    (pin_b_not),
        .c0_f     (pin_c0_f),
        .c0_f_not (pin_c0_f_not),
        .z        (pin_z),
        .z_not    (pin_z_not),

        .s        (pin_s),
        .s_not    (pin_s_not),
        .a_b      (pin_a_b),
        .a_not_b  (pin_a_not_b),
        .c0_b     (pin_c0_b),
        .c0_not_b (pin_c0_b_not),
        .c7       (pin_c7),
        .c7_not   (pin_c7_not)
    );

    // ============================================================
    // 3) Forward-Backward control drive
    //    This is implemented using pure combinational logic
    //
    //   - dir = 0: Forward
    //       Outside -> Macro
    //         A, B, C0_f, Z  Drive pin_a/pin_b/pin_c0_f/pin_z(And it's corresponding _not)
    //       Macro -> Ourside
    //         pin_s, pin_a_b, pin_c0_b, pin_c7 for outside read
    //
    //   - dir = 1: Backward
    //       Outside -> Macro
    //         S, A_B, C0_b, C7 Drives pin_s/pin_a_b/pin_c0_b/pin_c7 (and its corresponding _not)
    //       Macro -> Ourside
    //         pin_a, pin_b, pin_c0_f, pin_z for outside read
    //
    //   The tri-state bus and a one-bit dir is to ensure that each pin has only one driver at any time
    // ============================================================

    // 3.1 Forward Drive, when Dir == 0
    // Input: A, B, C0_f, z
    assign pin_a        = (dir == 1'b0) ? f_a       : 8'hzz;
    assign pin_a_not    = (dir == 1'b0) ? ~f_a      : 8'hzz;

    assign pin_b        = (dir == 1'b0) ? f_b       : 8'hzz;
    assign pin_b_not    = (dir == 1'b0) ? ~f_b      : 8'hzz;

    assign pin_c0_f     = (dir == 1'b0) ? f_c0_f    : 1'bz;
    assign pin_c0_f_not = (dir == 1'b0) ? ~f_c0_f   : 1'bz;

    assign pin_z        = (dir == 1'b0) ? f_z       : 1'bz;
    assign pin_z_not    = (dir == 1'b0) ? ~f_z      : 1'bz;

    // Output side S, A_B, C0_b, C15 is drived by the macro, it is read-only
    assign f_s    = pin_s;
    assign f_a_b  = pin_a_b;
    assign f_c0_b = pin_c0_b;
    assign f_c7   = pin_c7;

    // Backward Drive, when Dir == 1
    // Input: S, A_B, C0_b, C15
    assign pin_s        = (dir == 1'b1) ? r_s       : 8'hzz;
    assign pin_s_not    = (dir == 1'b1) ? ~r_s      : 8'hzz;

    assign pin_a_b      = (dir == 1'b1) ? r_a_b     : 8'hzz;
    assign pin_a_not_b  = (dir == 1'b1) ? ~r_a_b    : 8'hzz;

    assign pin_c0_b     = (dir == 1'b1) ? r_c0_b    : 1'bz;
    assign pin_c0_b_not = (dir == 1'b1) ? ~r_c0_b   : 1'bz;

    assign pin_c7       = (dir == 1'b1) ? r_c7      : 1'bz;
    assign pin_c7_not   = (dir == 1'b1) ? ~r_c7     : 1'bz;

    assign r_a     = pin_a;
    assign r_b     = pin_b;
    assign r_c0_f  = pin_c0_f;
    assign r_z     = pin_z;

    // ============================================================
    // 4) Optional Sanity Check (generated by ChatGPT)
    //    To check whether the 'dir' is clean (cannot be both 0 and 1, or being contaminated by X)
    // ============================================================
// `ifndef SYNTHESIS
//     // Throw error if this happens
//     always @(*) begin
//         if (dir !== 1'b0 && dir !== 1'b1) begin
//             $error("fa8_rev_ctrl: dir is X or Z, this will break reversibility.");
//         end
//     end
// `endif

endmodule

