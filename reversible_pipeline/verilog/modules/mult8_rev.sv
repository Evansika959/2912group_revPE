module mult8_rev (
`ifdef USE_POWER_PINS
    inout logic VDD,
    inout logic VSS,
`endif
    input  logic        dir,      // 0: forward  (A,B,C0_f,Z -> S,a_b,C0_b,C15)
                                 // 1: backward (S,a_b,C0_b,C15 -> A,B,C0_f,Z)

    // Forward Interface: Used when dir == 0
    input  logic [7:0] f_a,
    input  logic [7:0] f_b,
    input  logic [7:0] f_extra,

    output logic [15:0] f_p,
    output logic [7:0]  f_a_b,

    // Backward Interface: Used when dir == 1
    input  logic [15:0] r_p,
    input  logic [7:0]  r_a_b,
    
    output logic [7:0]  r_a,
    output logic [7:0]  r_b,
    output logic [7:0]  r_extra
);

    // Behavioural surrogate for the reversible multiplier core.
    logic [15:0] forward_prod;
    logic [7:0]  forward_passthru;

    logic [7:0]  backward_passthru;
    logic [7:0]  backward_recovered_b;
    logic [7:0]  backward_extra;

    assign forward_prod      = f_a * f_b;
    assign forward_passthru  = f_a;          // keep A as pass-through payload

    assign backward_passthru = r_a_b;        // supplied pass-through A during reverse mode
    assign backward_extra    = r_p[15:8];    // reuse upper product bits as auxiliary channel
    assign backward_recovered_b = (r_a_b != 0) ? (r_p / r_a_b) : 8'd0;

    // Forward direction output drive
    always_comb begin
        if (dir == 1'b0) begin
            f_p   = forward_prod;
            f_a_b = forward_passthru;
        end else begin
            f_p   = '0;
            f_a_b = '0;
        end
    end

    // Backward direction reconstruction
    always_comb begin
        if (dir == 1'b1) begin
            r_a     = backward_passthru;
            r_b     = backward_recovered_b;
            r_extra = backward_extra;
        end else begin
            r_a     = '0;
            r_b     = '0;
            r_extra = '0;
        end
    end

endmodule 