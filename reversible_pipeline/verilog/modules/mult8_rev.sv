// module mult8_rev (
// `ifdef USE_POWER_PINS
//     inout logic VDD,
//     inout logic VSS,
// `endif
//     input  logic        dir,      // 0: forward  (A,B,C0_f,Z -> S,a_b,C0_b,C15)
//                                  // 1: backward (S,a_b,C0_b,C15 -> A,B,C0_f,Z)

//     // Forward Interface: Used when dir == 0
//     input  logic [7:0] f_a,
//     input  logic [7:0] f_b,
//     input  logic [7:0] f_extra,

//     output logic [15:0] f_p,
//     output logic [7:0]  f_a_b,

//     // Backward Interface: Used when dir == 1
//     input  logic [15:0] r_p,
//     input  logic [7:0]  r_a_b,
    
//     output logic [7:0]  r_a,
//     output logic [7:0]  r_b,
//     output logic [7:0]  r_extra
// );

//     // Behavioural surrogate for the reversible multiplier core.
//     logic [15:0] forward_prod;
//     logic [7:0]  forward_passthru;

//     logic [7:0]  backward_passthru;
//     logic [7:0]  backward_recovered_b;
//     logic [7:0]  backward_extra;

//     assign forward_prod      = f_a * f_b;
//     assign forward_passthru  = f_a;          // keep A as pass-through payload

//     assign backward_passthru = r_a_b;        // supplied pass-through A during reverse mode
//     assign backward_extra    = r_p[15:8];    // reuse upper product bits as auxiliary channel
//     assign backward_recovered_b = (r_a_b != 0) ? (r_p / r_a_b) : 8'd0;

//     // Forward direction output drive
//     always_comb begin
//         if (dir == 1'b0) begin
//             f_p   = forward_prod;
//             f_a_b = forward_passthru;
//         end else begin
//             f_p   = '0;
//             f_a_b = '0;
//         end
//     end

//     // Backward direction reconstruction
//     always_comb begin
//         if (dir == 1'b1) begin
//             r_a     = backward_passthru;
//             r_b     = backward_recovered_b;
//             r_extra = backward_extra;
//         end else begin
//             r_a     = '0;
//             r_b     = '0;
//             r_extra = '0;
//         end
//     end

// endmodule 

module mult8_rev (
`ifdef USE_POWER_PINS
    inout logic VDD,
    inout logic VSS,
`endif
    input  logic        dir,      // 0: forward  (A,B -> P,b_r_b,X_c0_b)
                                 // 1: backward (P,b_r_b,X_c0_b -> A,B)

    // Forward Interface: Used when dir == 0
    // Input: A, B
    input  logic [7:0] f_a,
    input  logic [7:0] f_b,

    // Output: P, b_r_b (reversible carries), X_c0_b
    output logic [15:0] f_p,
    output logic [7:0] f_b0_r_b,
    output logic [7:0] f_b2_r_b,
    output logic [7:0] f_b3_r_b,
    output logic [7:0] f_b4_r_b,
    output logic [7:0] f_b5_r_b,
    output logic [7:0] f_b6_r_b,
    output logic [7:0] f_b7_r_b,
    output logic [6:0] f_x_c0_b,

    // Backward Interface: Used when dir == 1
    // Input: P, b_r_b, X_c0_b
    input  logic [15:0] r_p,
    input  logic [7:0] r_b0_r_b,
    input  logic [7:0] r_b2_r_b,
    input  logic [7:0] r_b3_r_b,
    input  logic [7:0] r_b4_r_b,
    input  logic [7:0] r_b5_r_b,
    input  logic [7:0] r_b6_r_b,
    input  logic [7:0] r_b7_r_b,
    input  logic [6:0] r_x_c0_b,

    // Output: A, B (Original inputs recovered)
    output logic [7:0] r_a,
    output logic [7:0] r_b
);

    // Behavioural surrogate for the reversible multiplier core.
    logic [15:0] forward_prod;
    logic [7:0]  forward_passthru;

    logic [7:0]  backward_passthru;
    logic [7:0]  backward_recovered_b;

    assign forward_prod      = f_a * f_b;
    assign forward_passthru  = f_a;          // keep A as pass-through payload

    assign backward_passthru = r_b0_r_b;        // supplied pass-through A during reverse mode
    assign backward_recovered_b = (r_b0_r_b != 0) ? (r_p / r_b0_r_b) : 8'd0;

    // Forward direction output drive
    always_comb begin
        if (dir == 1'b0) begin
            f_p   = forward_prod;
            f_b0_r_b = forward_passthru;
        end else begin
            f_p   = '0;
            f_b0_r_b = '0;
        end
    end

    // Backward direction reconstruction
    always_comb begin
        if (dir == 1'b1) begin
            r_a     = backward_passthru;
            r_b     = backward_recovered_b;
        end else begin
            r_a     = '0;
            r_b     = '0;
        end
    end

    assign f_b2_r_b = 8'd0;
    assign f_b3_r_b = 8'd0;
    assign f_b4_r_b = 8'd0;
    assign f_b5_r_b = 8'd0;
    assign f_b6_r_b = 8'd0;
    assign f_b7_r_b = 8'd0;
    assign f_x_c0_b = 7'd0;



endmodule