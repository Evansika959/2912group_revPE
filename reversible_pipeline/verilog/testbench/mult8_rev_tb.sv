`timescale 1ns/1ps

module mult8_rev_tb;
    // DUT interface
    logic        dir;
    logic [7:0]  f_a;
    logic [7:0]  f_b;
    logic [7:0]  f_extra;
    logic [15:0] f_p;
    logic [7:0]  f_a_b;

    logic [15:0] r_p;
    logic [15:0] r_a_b;
    logic [7:0]  r_a;
    logic [7:0]  r_b;
    logic [7:0]  r_extra;

    mult8_rev dut (
        .dir    (dir),
        .f_a    (f_a),
        .f_b    (f_b),
        .f_extra(f_extra),
        .f_p    (f_p),
        .f_a_b  (f_a_b),
        .r_p    (r_p),
        .r_a_b  (r_a_b),
        .r_a    (r_a),
        .r_b    (r_b),
        .r_extra(r_extra)
    );

    task automatic check_forward(string tag, logic [7:0] exp_a, logic [7:0] exp_b, logic [7:0] exp_extra);
        logic [15:0] exp_prod;
        exp_prod = exp_a * exp_b;
        if (f_p !== exp_prod) begin
            $error("%s: expected f_p=%h, got %h", tag, exp_prod, f_p);
        end else begin
            $display("%s: f_p OK (%h)", tag, f_p);
        end

        if (f_a_b !== exp_a) begin
            $error("%s: expected f_a_b(pass-through A)=%h, got %h", tag, exp_a, f_a_b);
        end else begin
            $display("%s: f_a_b OK (%h)", tag, f_a_b);
        end
    endtask

    task automatic check_backward(string tag, logic [15:0] exp_r_p, logic [15:0] exp_r_a_b);
        logic [7:0] exp_a;
        logic [7:0] exp_b;
        logic [7:0] exp_extra;

        exp_a     = exp_r_a_b;
        exp_b     = (exp_r_a_b != 0) ? (exp_r_p / exp_r_a_b) : 8'h00;
        exp_extra = exp_r_p[15:8];

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

        if (r_extra !== exp_extra) begin
            $error("%s: expected r_extra=%h, got %h", tag, exp_extra, r_extra);
        end else begin
            $display("%s: r_extra OK (%h)", tag, r_extra);
        end
    endtask

    initial begin
        // Forward mode
        dir     = 1'b0;
        f_a     = 8'h12;
        f_b     = 8'h04;
        f_extra = 8'hAA;
        r_p     = '0;
        r_a_b   = '0;
        #1;
        check_forward("Forward #1", f_a, f_b, f_extra);

    f_a     = 8'h08;
    f_b     = 8'h11;
    f_extra = 8'h55;
        #1;
        check_forward("Forward #2", f_a, f_b, f_extra);

        // Switch to backward mode
        dir   = 1'b1;
    r_p   = 16'h8C40; // upper byte carries extra information
    r_a_b = 8'h12;    // pass-through A
        #1;
        check_backward("Backward #1", r_p, r_a_b);

    r_p   = 16'h7740;
    r_a_b = 8'h08;
        #1;
        check_backward("Backward #2", r_p, r_a_b);

        #5;
        $finish;
    end
endmodule
