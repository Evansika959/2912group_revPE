`timescale 1ns/1ps

module fa16_rev_tb;
    // DUT interface signals
    logic        dir;
    logic [15:0] f_a;
    logic [15:0] f_b;
    logic        f_c0_f;
    logic        f_z;
    logic [15:0] f_s;
    logic [15:0] f_a_b;
    logic        f_c0_b;
    logic        f_c15;

    logic [15:0] r_s;
    logic [15:0] r_a_b;
    logic        r_c0_b;
    logic        r_c15;
    logic [15:0] r_a;
    logic [15:0] r_b;
    logic        r_c0_f;
    logic        r_z;

    // Device under test
    fa16_rev dut (
        .dir    (dir),
        .f_a    (f_a),
        .f_b    (f_b),
        .f_c0_f (f_c0_f),
        .f_z    (f_z),
        .f_s    (f_s),
        .f_a_b  (f_a_b),
        .f_c0_b (f_c0_b),
        .f_c15  (f_c15),
        .r_s    (r_s),
        .r_a_b  (r_a_b),
        .r_c0_b (r_c0_b),
        .r_c15  (r_c15),
        .r_a    (r_a),
        .r_b    (r_b),
        .r_c0_f (r_c0_f),
        .r_z    (r_z)
    );

    initial begin
        // Forward mode exercise
        dir      = 1'b0;
        f_a      = 16'h0001;
        f_b      = 16'h0002;
        f_c0_f   = 1'b0;
        f_z      = 1'b0;
        r_s      = '0;
        r_a_b    = '0;
        r_c0_b   = 1'b0;
        r_c15    = 1'b0;

        #1;
        $display("Forward: f_s=%h f_a_b=%h f_c0_b=%b f_c15=%b", f_s, f_a_b, f_c0_b, f_c15);

        // Change forward operands
        f_a    = 16'h0003;
        f_b    = 16'h0004;
        f_c0_f = 1'b0;
        f_z    = 1'b1;
        #1;
        $display("Forward updated: f_s=%h f_a_b=%h f_c0_b=%b f_c15=%b", f_s, f_a_b, f_c0_b, f_c15);

        // Switch to backward mode
        dir      = 1'b1;
        r_s      = 16'h0003;
        r_a_b    = 16'h0001;
        r_c0_b   = 1'b0;
        r_c15    = 1'b0;
        #1;
        $display("Backward: r_a=%h r_b=%h r_c0_f=%b r_z=%b", r_a, r_b, r_c0_f, r_z);

        r_s    = 16'h0004;
        r_a_b  = 16'h0001;
        r_c0_b = 1'b0;
        r_c15  = 1'b1;
        #1;
        $display("Backward updated: r_a=%h r_b=%h r_c0_f=%b r_z=%b", r_a, r_b, r_c0_f, r_z);

        #5;
        $finish;
    end
endmodule
