// This takes in mult8b_rev_wrapped, and achieves bidirectional control under signal 'dir'
/*
Wrapping Structure:
Outter Logic <-> f_/r_ Port <-> mult8b_rev_ctrl <-> pin_* bus <-> mult8b_rev_wrapped
- mult8b_rev_wrapped: the macro defined
- pin_*: physical wire connected to the macro pin, tristate bus
- mult8b_rev_ctrl: control logic actually defined in the module
- f_/r_ Port: What the upper level(testbench) actually see
- Outter Logic: Testbench Written


*/

module mult8b_rev (
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input  wire        dir,      // 0: forward  (A,B -> P,b_r_b,X_c0_b)
                                 // 1: backward (P,b_r_b,X_c0_b -> A,B)

    // Forward Interface: Used when dir == 0
    // Input: A, B
    input  wire [7:0] f_a,
    input  wire [7:0] f_b,

    // Output: P, b_r_b (reversible carries), X_c0_b
    output wire [15:0] f_p,
    output wire [7:0] f_b0_r_b,
    output wire [7:0] f_b2_r_b,
    output wire [7:0] f_b3_r_b,
    output wire [7:0] f_b4_r_b,
    output wire [7:0] f_b5_r_b,
    output wire [7:0] f_b6_r_b,
    output wire [7:0] f_b7_r_b,
    output wire [6:0] f_x_c0_b,

    // Backward Interface: Used when dir == 1
    // Input: P, b_r_b, X_c0_b
    input  wire [15:0] r_p,
    input  wire [7:0] r_b0_r_b,
    input  wire [7:0] r_b2_r_b,
    input  wire [7:0] r_b3_r_b,
    input  wire [7:0] r_b4_r_b,
    input  wire [7:0] r_b5_r_b,
    input  wire [7:0] r_b6_r_b,
    input  wire [7:0] r_b7_r_b,
    input  wire [6:0] r_x_c0_b,

    // Output: A, B (Original inputs recovered)
    output wire [7:0] r_a,
    output wire [7:0] r_b
);

    // ============================================================
    // 1) Define the physical pin (bus) connected to the macro 
    //    Allowing multiple tri-state driver
    // ============================================================
    tri [7:0] pin_a;
    tri [7:0] pin_a_not;
    tri [7:0] pin_b;
    tri [7:0] pin_b_not;
    tri [6:0] pin_x_c0_b;
    tri [6:0] pin_x_c0_b_not;

    tri [15:0] pin_p;
    tri [15:0] pin_p_not;
    tri [7:0] pin_b0_r_b;
    tri [7:0] pin_b0_r_b_not;
    tri [7:0] pin_b2_r_b;
    tri [7:0] pin_b2_r_b_not;
    tri [7:0] pin_b3_r_b;
    tri [7:0] pin_b3_r_b_not;
    tri [7:0] pin_b4_r_b;
    tri [7:0] pin_b4_r_b_not;
    tri [7:0] pin_b5_r_b;
    tri [7:0] pin_b5_r_b_not;
    tri [7:0] pin_b6_r_b;
    tri [7:0] pin_b6_r_b_not;
    tri [7:0] pin_b7_r_b;
    tri [7:0] pin_b7_r_b_not;

    // ============================================================
    // 2) Instantiating the reversible multiplier core
    // ============================================================
    mult8b_rev_wrapped u_rev (
    `ifdef USE_POWER_PINS
        .VDD     (VDD),
        .VSS     (VSS),
    `endif
        .a        (pin_a),
        .a_not    (pin_a_not),
        .b        (pin_b),
        .b_not    (pin_b_not),
        .x_c0_b   (pin_x_c0_b),
        .x_c0_b_not (pin_x_c0_b_not),

        .p        (pin_p),
        .p_not    (pin_p_not),
        .b0_r_b   (pin_b0_r_b),
        .b0_r_b_not (pin_b0_r_b_not),
        .b2_r_b   (pin_b2_r_b),
        .b2_r_b_not (pin_b2_r_b_not),
        .b3_r_b   (pin_b3_r_b),
        .b3_r_b_not (pin_b3_r_b_not),
        .b4_r_b   (pin_b4_r_b),
        .b4_r_b_not (pin_b4_r_b_not),
        .b5_r_b   (pin_b5_r_b),
        .b5_r_b_not (pin_b5_r_b_not),
        .b6_r_b   (pin_b6_r_b),
        .b6_r_b_not (pin_b6_r_b_not),
        .b7_r_b   (pin_b7_r_b),
        .b7_r_b_not (pin_b7_r_b_not)
    );

    // ============================================================
    // 3) Forward-Backward control drive
    //    This is implemented using pure combinational logic
    //
    //   - dir = 0: Forward
    //       Outside -> Macro
    //         A, B Drive pin_a/pin_b (And it's corresponding _not)
    //       Macro -> Outside
    //         pin_p, pin_b_r_b, pin_x_c0_b for outside read
    //
    //   - dir = 1: Backward
    //       Outside -> Macro
    //         P, b_r_b, X_c0_b Drives pin_p/pin_b_r_b/pin_x_c0_b (And it's corresponding _not)
    //       Macro -> Outside
    //         pin_a, pin_b for outside read
    //
    //   The tri-state bus and a one-bit dir is to ensure that each pin has only one driver at any time
    // ============================================================

    // 3.1 Forward Drive, when Dir == 0
    // Input: A, B
    assign pin_a        = (dir == 1'b0) ? f_a       : 8'hzz;
    assign pin_a_not    = (dir == 1'b0) ? ~f_a      : 8'hzz;

    assign pin_b        = (dir == 1'b0) ? f_b       : 8'hzz;
    assign pin_b_not    = (dir == 1'b0) ? ~f_b      : 8'hzz;

    // Output side P, b_r_b, x_c0_b are driven by the macro, read-only
    assign f_p       = pin_p;
    assign f_b0_r_b  = pin_b0_r_b;
    assign f_b2_r_b  = pin_b2_r_b;
    assign f_b3_r_b  = pin_b3_r_b;
    assign f_b4_r_b  = pin_b4_r_b;
    assign f_b5_r_b  = pin_b5_r_b;
    assign f_b6_r_b  = pin_b6_r_b;
    assign f_b7_r_b  = pin_b7_r_b;
    assign f_x_c0_b  = pin_x_c0_b;

    // Backward Drive, when Dir == 1
    // Input: P, b_r_b, X_c0_b
    assign pin_p        = (dir == 1'b1) ? r_p       : 16'hzzzz;
    assign pin_p_not    = (dir == 1'b1) ? ~r_p      : 16'hzzzz;

    assign pin_b0_r_b     = (dir == 1'b1) ? r_b0_r_b     : 8'hz;
    assign pin_b0_r_b_not = (dir == 1'b1) ? ~r_b0_r_b    : 8'hz;

    assign pin_b2_r_b     = (dir == 1'b1) ? r_b2_r_b     : 8'hz;
    assign pin_b2_r_b_not = (dir == 1'b1) ? ~r_b2_r_b    : 8'hz;

    assign pin_b3_r_b     = (dir == 1'b1) ? r_b3_r_b     : 8'hz;
    assign pin_b3_r_b_not = (dir == 1'b1) ? ~r_b3_r_b    : 8'hz;

    assign pin_b4_r_b     = (dir == 1'b1) ? r_b4_r_b     : 8'hz;
    assign pin_b4_r_b_not = (dir == 1'b1) ? ~r_b4_r_b    : 8'hz;

    assign pin_b5_r_b     = (dir == 1'b1) ? r_b5_r_b     : 8'hz;
    assign pin_b5_r_b_not = (dir == 1'b1) ? ~r_b5_r_b    : 8'hz;

    assign pin_b6_r_b     = (dir == 1'b1) ? r_b6_r_b     : 8'hz;
    assign pin_b6_r_b_not = (dir == 1'b1) ? ~r_b6_r_b    : 8'hz;

    assign pin_b7_r_b     = (dir == 1'b1) ? r_b7_r_b     : 8'hz;
    assign pin_b7_r_b_not = (dir == 1'b1) ? ~r_b7_r_b    : 8'hz;

    assign pin_x_c0_b     = (dir == 1'b1) ? r_x_c0_b     : 7'hz;
    assign pin_x_c0_b_not = (dir == 1'b1) ? ~r_x_c0_b    : 7'hz;

    assign r_a     = pin_a;
    assign r_b     = pin_b;

endmodule
