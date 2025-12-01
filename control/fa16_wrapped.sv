// fa16_rev_wrapped.v
// This is the macro Defination
// Black Box: Pins are matched with those in the layout
// Synthesis / PnR should treate the module as a hard-coded macro, it's internal implementation comes from GDS

(* black_box, keep_hierarchy = "yes" *)
module fa16_rev_wrapped (
`ifdef USE_POWER_PINS
    inout wire vdd,
    inout wire vss,
`endif

    inout  wire [15:0] a,
    inout  wire [15:0] a_not,
    inout  wire [15:0] b,
    inout  wire [15:0] b_not,
    inout  wire        c0_f,
    inout  wire        c0_f_not,
    inout  wire        z,
    inout  wire        z_not,

    inout  wire [15:0] s,
    inout  wire [15:0] s_not,
    inout  wire [15:0] a_b,
    inout  wire [15:0] a_not_b,
    inout  wire        c0_b,
    inout  wire        c0_b_not,
    inout  wire        c15,
    inout  wire        c15_not
);
// Real RTL content comes for custom layout
endmodule
