`timescale 1ns/1ps

module mult8_rev_tb;
    // DUT interface
    logic        dir;
    logic [7:0]  f_a;
    logic [7:0]  f_b;
    logic [15:0] f_p;
    logic [7:0]  f_b0_r_b;
    logic [7:0]  f_b2_r_b;
    logic [7:0]  f_b3_r_b;
    logic [7:0]  f_b4_r_b;
    logic [7:0]  f_b5_r_b;
    logic [7:0]  f_b6_r_b;
    logic [7:0]  f_b7_r_b;
    logic [6:0]  f_x_c0_b;

    logic [15:0] r_p;
    logic [7:0]  r_b0_r_b;
    logic [7:0]  r_b2_r_b;
    logic [7:0]  r_b3_r_b;
    logic [7:0]  r_b4_r_b;
    logic [7:0]  r_b5_r_b;
    logic [7:0]  r_b6_r_b;
    logic [7:0]  r_b7_r_b;
    logic [6:0]  r_x_c0_b;
    logic [7:0]  r_a;
    logic [7:0]  r_b;

    mult8_rev dut (
        .dir      (dir),
        .f_a      (f_a),
        .f_b      (f_b),
        .f_p      (f_p),
        .f_b0_r_b (f_b0_r_b),
        .f_b2_r_b (f_b2_r_b),
        .f_b3_r_b (f_b3_r_b),
        .f_b4_r_b (f_b4_r_b),
        .f_b5_r_b (f_b5_r_b),
        .f_b6_r_b (f_b6_r_b),
        .f_b7_r_b (f_b7_r_b),
        .f_x_c0_b (f_x_c0_b),
        .r_p      (r_p),
        .r_b0_r_b (r_b0_r_b),
        .r_b2_r_b (r_b2_r_b),
        .r_b3_r_b (r_b3_r_b),
        .r_b4_r_b (r_b4_r_b),
        .r_b5_r_b (r_b5_r_b),
        .r_b6_r_b (r_b6_r_b),
        .r_b7_r_b (r_b7_r_b),
        .r_x_c0_b (r_x_c0_b),
        .r_a      (r_a),
        .r_b      (r_b)
    );

    task automatic check_forward(string tag, logic [7:0] exp_a, logic [7:0] exp_b);
        logic [15:0] exp_prod;
        exp_prod = exp_a * exp_b;
        if (f_p !== exp_prod) begin
            $error("%s: expected f_p=%h, got %h", tag, exp_prod, f_p);
        end else begin
            $display("%s: f_p OK (%h)", tag, f_p);
        end

        if (f_b0_r_b !== exp_a) begin
            $error("%s: expected f_b0_r_b(pass-through A)=%h, got %h", tag, exp_a, f_b0_r_b);
        end else begin
            $display("%s: f_b0_r_b OK (%h)", tag, f_b0_r_b);
        end

        if (|f_b2_r_b || |f_b3_r_b || |f_b4_r_b || |f_b5_r_b || |f_b6_r_b || |f_b7_r_b || |f_x_c0_b) begin
            $error("%s: expected higher reversible outputs to be zero, got %h%h%h%h%h%h and %h", tag,
                   f_b7_r_b, f_b6_r_b, f_b5_r_b, f_b4_r_b, f_b3_r_b, f_b2_r_b, f_x_c0_b);
        end else begin
            $display("%s: higher-order reversible outputs OK (all zero)", tag);
        end
    endtask

    task automatic check_backward(string tag, logic [15:0] exp_r_p, logic [7:0] exp_r_b0_r_b);
        logic [7:0] exp_a;
        logic [7:0] exp_b;

        exp_a = exp_r_b0_r_b;
        exp_b = (exp_r_b0_r_b != 0) ? (exp_r_p / exp_r_b0_r_b) : 8'h00;

        if (r_a !== exp_a) begin
            $error("%s: expected r_a=%h, got %h", tag, exp_a, r_a);
        end else begin
            $display("%s: r_a OK (%h)", tag, r_a);
        end

        if (r_b !== exp_b) begin
            $error("%s: expected r_b(recovered)=%h, got %h", tag, exp_b, r_b);
        end else begin
            $display("%s: r_b OK (%h)", tag, r_b);
        end

        if (|r_b2_r_b || |r_b3_r_b || |r_b4_r_b || |r_b5_r_b || |r_b6_r_b || |r_b7_r_b || |r_x_c0_b) begin
            $error("%s: expected unused reverse inputs to remain zero, got %h%h%h%h%h%h and %h",
                   tag, r_b7_r_b, r_b6_r_b, r_b5_r_b, r_b4_r_b, r_b3_r_b, r_b2_r_b, r_x_c0_b);
        end else begin
            $display("%s: unused reverse inputs OK (all zero)", tag);
        end
    endtask

    initial begin
        // Forward mode
        dir     = 1'b0;
        f_a     = 8'h12;
        f_b     = 8'h04;
        r_p     = '0;
        r_b0_r_b   = '0;
        r_b2_r_b   = '0;
        r_b3_r_b   = '0;
        r_b4_r_b   = '0;
        r_b5_r_b   = '0;
        r_b6_r_b   = '0;
        r_b7_r_b   = '0;
        r_x_c0_b   = '0;
        #1;
        check_forward("Forward #1", f_a, f_b);

        f_a     = 8'h08;
        f_b     = 8'h11;
        #1;
        check_forward("Forward #2", f_a, f_b);

        // Switch to backward mode
        dir   = 1'b1;
        r_p   = 16'h8C40;
        r_b0_r_b = 8'h12;    // pass-through A
        r_b2_r_b = '0;
        r_b3_r_b = '0;
        r_b4_r_b = '0;
        r_b5_r_b = '0;
        r_b6_r_b = '0;
        r_b7_r_b = '0;
        r_x_c0_b = '0;
        #1;
        check_backward("Backward #1", r_p, r_b0_r_b);

        r_p   = 16'h7740;
        r_b0_r_b = 8'h08;
        #1;
        check_backward("Backward #2", r_p, r_b0_r_b);

        #5;
        $finish;
    end
endmodule
