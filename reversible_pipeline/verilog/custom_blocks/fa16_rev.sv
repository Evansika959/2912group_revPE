// `include "fa_16b.vh"

// This takes in fa16_rev_wrapped, and achieves bidirectional control under signal 'dir'
/*
Wrapping Structure:
Outter Logic <-> f_/r_ Port <-> fa16_rev_ctrl <-> pin_* bus <-> fa16_rev_wrapped
- fa16_rev_wrapped: the macro defined
- pin_*: physical wire connected to the macro pin, tristate bus
- fa16_rev_ctrl: control logic actually defined in the module
- f_/r_ Port: What the upper level(testbench) actually see
- Outter Logic: Testbench Written


*/

module fa16_rev (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        dir,      // 0: forward  (A,B,C0_f,Z -> S,a_b,C0_b,C15)
                                 // 1: backward (S,a_b,C0_b,C15 -> A,B,C0_f,Z)

    // Forward Interface: Used when dir == 0
    // Input: A, B, C0_f, z
    input  wire [15:0] f_a,
    input  wire [15:0] f_b,
    input  wire        f_c0_f,
    input  wire        f_z,

    // Output: S, A_B, C0_b, C15
    output wire [15:0] f_s,
    output wire [15:0] f_a_b,
    output wire        f_c0_b,
    output wire        f_c15,

    // Backward Interface: Used when dir == 1
    // Output: S, A_B, C0_b, C15
    input  wire [15:0] r_s,
    input  wire [15:0] r_a_b,
    input  wire        r_c0_b,
    input  wire        r_c15,

    // Output: A, B, C0_f, z (Original input recovered)
    output wire [15:0] r_a,
    output wire [15:0] r_b,
    output wire        r_c0_f,
    output wire        r_z
);

    // ============================================================
    // 1) Define the physical pin (bus) connected to the macro 
    //    Allowing multiple tri-state driver
    // ============================================================
    tri [15:0] pin_a;
    tri [15:0] pin_a_not;
    tri [15:0] pin_b;
    tri [15:0] pin_b_not;
    tri        pin_c0_f;
    tri        pin_c0_f_not;
    tri        pin_z;
    tri        pin_z_not;

    tri [15:0] pin_s;
    tri [15:0] pin_s_not;
    tri [15:0] pin_a_b;
    tri [15:0] pin_a_not_b;
    tri        pin_c0_b;
    tri        pin_c0_b_not;
    tri        pin_c15;
    tri        pin_c15_not;

    // ============================================================
    // 2) Instantiating the reversible adder core
    // ============================================================
    fa16_rev_wrapped u_rev (
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
        .c15      (pin_c15),
        .c15_not  (pin_c15_not)
    );

    // ============================================================
    // 3) Forward-Backward control drive
    //    This is implemented using pure combinational logic
    //
    //   - dir = 0: Forward
    //       Outside -> Macro
    //         A, B, C0_f, Z  Drive pin_a/pin_b/pin_c0_f/pin_z(And it's corresponding _not)
    //       Macro -> Ourside
    //         pin_s, pin_a_b, pin_c0_b, pin_c15 for outside read
    //
    //   - dir = 1: Backward
    //       Outside -> Macro
    //         S, A_B, C0_b, C15 Drives pin_s/pin_a_b/pin_c0_b/pin_c15(And it's corresponding _not)
    //       Macro -> Ourside
    //         pin_a, pin_b, pin_c0_f, pin_z for outside read
    //
    //   The tri-state bus and a one-bit dir is to ensure that each pin has only one driver at any time
    // ============================================================

    // 3.1 Forward Drive, when Dir == 0
    // Input: A, B, C0_f, z
    assign pin_a        = (dir == 1'b0) ? f_a       : 16'hzzzz;
    assign pin_a_not    = (dir == 1'b0) ? ~f_a      : 16'hzzzz;

    assign pin_b        = (dir == 1'b0) ? f_b       : 16'hzzzz;
    assign pin_b_not    = (dir == 1'b0) ? ~f_b      : 16'hzzzz;

    assign pin_c0_f     = (dir == 1'b0) ? f_c0_f    : 1'bz;
    assign pin_c0_f_not = (dir == 1'b0) ? ~f_c0_f   : 1'bz;

    assign pin_z        = (dir == 1'b0) ? f_z       : 1'bz;
    assign pin_z_not    = (dir == 1'b0) ? ~f_z      : 1'bz;

    // Output side S, A_B, C0_b, C15 is drived by the macro, it is read-only
    assign f_s    = pin_s;      
    assign f_a_b  = pin_a_b;
    assign f_c0_b = pin_c0_b;
    assign f_c15  = pin_c15;

    // Backward Drive, when Dir == 1
    // Input: S, A_B, C0_b, C15
    assign pin_s        = (dir == 1'b1) ? r_s       : 16'hzzzz;
    assign pin_s_not    = (dir == 1'b1) ? ~r_s      : 16'hzzzz;

    assign pin_a_b      = (dir == 1'b1) ? r_a_b     : 16'hzzzz;
    assign pin_a_not_b  = (dir == 1'b1) ? ~r_a_b    : 16'hzzzz;

    assign pin_c0_b     = (dir == 1'b1) ? r_c0_b    : 1'bz;
    assign pin_c0_b_not = (dir == 1'b1) ? ~r_c0_b   : 1'bz;

    assign pin_c15      = (dir == 1'b1) ? r_c15     : 1'bz;
    assign pin_c15_not  = (dir == 1'b1) ? ~r_c15    : 1'bz;

    assign r_a     = pin_a;       
    assign r_b     = pin_b;
    assign r_c0_f  = pin_c0_f;
    assign r_z     = pin_z;


endmodule

// (* keep_hierarchy = "yes" *)
module fa16_rev_wrapped (
    `ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
    `endif

    // Input ports
    inout  wire [15:0] a,
    inout  wire [15:0] a_not,
    inout  wire [15:0] b,
    inout  wire [15:0] b_not,
    inout  wire        c0_f,
    inout  wire        c0_f_not,
    inout  wire        c15,
    inout  wire        c15_not,

    // Output ports
    inout wire [15:0] s,
    inout wire [15:0] s_not,
    inout wire [15:0] a_b,
    inout wire [15:0] a_not_b,
    inout wire        z,
    inout wire        z_not,
    inout wire        c0_b,
    inout wire        c0_not_b
);

    (* keep *)
    fa_16b  u_fa16b_rev (
        `ifdef USE_POWER_PINS
        .VSS         (VSS),
        .VDD         (VDD),
        `endif
        .z           (z),
        .z_not       (z_not),
        .c0_b        (c0_b),
        .c0_not_b    (c0_not_b),
        .c15_not     (c15_not),
        .c15         (c15),
        .s5_not      (s_not[5]),
        .s5          (s[5]),
        .s0_not      (s_not[0]),
        .s0          (s[0]),
        .s6_not      (s_not[6]),
        .s6          (s[6]),
        .s1_not      (s_not[1]),
        .s1          (s[1]),
        .s7_not      (s_not[7]),
        .s7          (s[7]),
        .s2_not      (s_not[2]),
        .s2          (s[2]),
        .s8_not      (s_not[8]),
        .s8          (s[8]),
        .s3_not      (s_not[3]),
        .s3          (s[3]),
        .s9_not      (s_not[9]),
        .s9          (s[9]),
        .s4_not      (s_not[4]),
        .s4          (s[4]),
        .s10_not     (s_not[10]),
        .s10         (s[10]),
        .s11_not     (s_not[11]),
        .s11         (s[11]),
        .s12_not     (s_not[12]),
        .s12         (s[12]),
        .s13_not     (s_not[13]),
        .s13         (s[13]),
        .s14_not     (s_not[14]),
        .s14         (s[14]),
        .s15_not     (s_not[15]),
        .s15         (s[15]),
        .c0_f        (c0_f),
        .c0_f_not    (c0_f_not),
        .a0_f        (a[0]),
        .a0_not_f    (a_not[0]),
        .b0          (b[0]),
        .b0_not      (b_not[0]),
        .a1_f        (a[1]),
        .a1_not_f    (a_not[1]),
        .b1          (b[1]),
        .b1_not      (b_not[1]),
        .a2_f        (a[2]),
        .a2_not_f    (a_not[2]),
        .b2          (b[2]),
        .b2_not      (b_not[2]),
        .a3_f        (a[3]),
        .a3_not_f    (a_not[3]),
        .b3          (b[3]),
        .b3_not      (b_not[3]),
        .a4_f        (a[4]),
        .a4_not_f    (a_not[4]),
        .b4          (b[4]),
        .b4_not      (b_not[4]),
        .a5_f        (a[5]),
        .a5_not_f    (a_not[5]),
        .b5          (b[5]),
        .b5_not      (b_not[5]),
        .a6_f        (a[6]),
        .a6_not_f    (a_not[6]),
        .b6          (b[6]),
        .b6_not      (b_not[6]),
        .a7_f        (a[7]),
        .a7_not_f    (a_not[7]),
        .b7          (b[7]),
        .b7_not      (b_not[7]),
        .a8_f        (a[8]),
        .a8_not_f    (a_not[8]),
        .b8          (b[8]),
        .b8_not      (b_not[8]),
        .a9_f        (a[9]),
        .a9_not_f    (a_not[9]),
        .b9          (b[9]),
        .b9_not      (b_not[9]),
        .a10_f       (a[10]),
        .a10_not_f   (a_not[10]),
        .b10         (b[10]),
        .b10_not     (b_not[10]),
        .a11_f       (a[11]),
        .a11_not_f   (a_not[11]),
        .b11         (b[11]),
        .b11_not     (b_not[11]),
        .a12_f       (a[12]),
        .a12_not_f   (a_not[12]),
        .b12         (b[12]),
        .b12_not     (b_not[12]),
        .a13_f       (a[13]),
        .a13_not_f   (a_not[13]),
        .b13         (b[13]),
        .b13_not     (b_not[13]),
        .a14_f       (a[14]),
        .a14_not_f   (a_not[14]),
        .b14         (b[14]),
        .b14_not     (b_not[14]),
        .a15_f       (a[15]),
        .a15_not_f   (a_not[15]),
        .b15         (b[15]),
        .b15_not     (b_not[15]),
        .a0_b        (a_b[0]),
        .a0_not_b    (a_not_b[0]),
        .a1_b        (a_b[1]),
        .a1_not_b    (a_not_b[1]),
        .a2_b        (a_b[2]),
        .a2_not_b    (a_not_b[2]),
        .a3_b        (a_b[3]),
        .a3_not_b    (a_not_b[3]),
        .a4_b        (a_b[4]),
        .a4_not_b    (a_not_b[4]),
        .a5_b        (a_b[5]),
        .a5_not_b    (a_not_b[5]),
        .a6_b        (a_b[6]),
        .a6_not_b    (a_not_b[6]),
        .a7_b        (a_b[7]),
        .a7_not_b    (a_not_b[7]),
        .a8_b        (a_b[8]),
        .a8_not_b    (a_not_b[8]),
        .a9_b        (a_b[9]),
        .a9_not_b    (a_not_b[9]),
        .a10_b       (a_b[10]),
        .a10_not_b   (a_not_b[10]),
        .a11_b       (a_b[11]),
        .a11_not_b   (a_not_b[11]),
        .a12_b       (a_b[12]),
        .a12_not_b   (a_not_b[12]),
        .a13_b       (a_b[13]),
        .a13_not_b   (a_not_b[13]),
        .a14_b       (a_b[14]),
        .a14_not_b   (a_not_b[14]),
        .a15_b       (a_b[15]),
        .a15_not_b   (a_not_b[15])
    );

endmodule