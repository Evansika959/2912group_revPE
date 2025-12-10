`timescale 1ps/1ps

module pe_testbench();

    reg clk;
    reg reset;
    reg [7:0] a_in;
    reg [7:0] b_in;
    reg [18:0] sum_in;
    wire [18:0] sum_out;
    wire [7:0] a_out, b_out;

    pe my_pe(
    .clk(clk),
    .reset(reset),
    .a_in(a_in),
    .b_in(b_in),
    .sum_in(sum_in),
    .sum_out(sum_out),
    .a_out(a_out),
    .b_out(b_out)
);

    integer i;
    parameter clk_period = 1000;

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        a_in = 8'd0;
        b_in = 8'd0;

        #clk_period reset = 1'b0;

        // 10 random test points
        for (i = 0; i < 10; i = i + 1) begin
            a_in = $random % 256;
            b_in = $random % 256;
            sum_in = $random % 524288; // max value of 2^19
            #(clk_period);
            #10;

            $display("Test %0d: a=%0d, b=%0d, prev_sum=%0d, sum_out=%0d, a_out=%0d, b_out=%0d",
                      i, a_in, b_in, sum_in, sum_out, a_out, b_out);
        end

        $finish;
    end

    always #(clk_period/2) clk = ~clk;

endmodule
