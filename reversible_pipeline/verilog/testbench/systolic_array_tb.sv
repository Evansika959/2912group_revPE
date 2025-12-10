`timescale 1ps/1ps

module systolic_array_testbench();
    parameter row = 8;
    parameter col = 8;

    reg clk;
    reg reset;
    reg [7:0] a_in [row-1:0];
    reg [7:0] b_in [col-1:0];
    wire [18:0] c_out [row-1:0][col-1:0];

    systolic_array #(
        .row(row),
        .col(col)
    ) my_systolic_array (
        .clk(clk),
        .reset(reset),
        .a_in(a_in),
        .b_in(b_in),
        .c_out(c_out)
    );

    parameter clk_period = 1000;
    integer A_file;
    integer B_file;
    integer write_file;
    integer A_idx = 0;
    integer B_idx = 0;
    integer tmp_val;

    // input/output for test

    reg [7:0] test_a_in [0:col-1][0:row+col-2];  // col, (row+col-1)
    reg [7:0] test_b_in [0:row-1][0:row+col-2];  // row, (row+col-1)
    wire [18:0] test_c_out [row-1:0][col-1:0];

    initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, systolic_array_testbench);

        clk = 1'b0;
        reset = 1'b1;

        // init full unpacked arrs to zero

        for (int i = 0; i < row; i++) begin
            a_in[i] = 8'd0;
        end

        for (int j = 0; j < col; j++) begin
            b_in[j] = 8'd0;
        end

        #clk_period reset = 1'b0;

        A_file = $fopen("./goldenbrick/At.txt", "r");

        if (A_file == 0) begin
            $display("Couldn't open At.txt");
            $finish;
        end else begin
            $display("At.txt opened successfully.");
        end

        B_file = $fopen("./goldenbrick/Bt.txt", "r");

        if (B_file == 0) begin
            $display("Couldn't open Bt.txt");
            $finish;
        end else begin
            $display("Bt.txt opened successfully.");
        end

        write_file = $fopen(`VSIM_OUT, "w");
        if (write_file == 0) begin
            $display("Can not open rtl_sim_output.txt");
            $finish;
        end

         // read in A

        for (int i = 0; i < row; i++) begin
            for (int j = 0; j < row+col-1; j++) begin
                if ($fscanf(A_file, "%d", tmp_val) != 1) begin
                    $display("Error reading At.txt at row=%0d, cycle=%0d", i, j);
                    $finish;
                end
                test_a_in[i][j] = tmp_val[7:0];
            end
        end

        $fclose(A_file);

        // read in B

        for (int i = 0; i < row; i++) begin
            for (int j = 0; j < row+col-1; j++) begin
                if ($fscanf(B_file, "%d", tmp_val) != 1) begin
                    $display("Error reading Bt.txt at row=%0d, cycle=%0d", i, j);
                    $finish;
                end
                test_b_in[i][j] = tmp_val[7:0];
            end
        end

        $fclose(B_file);

        for (int j = 0; j < row+col-1; j++) begin
            for (int i = 0; i < col; i++) begin
                a_in[i] = test_a_in[i][j];
            end
            for (int i = 0; i < col; i++) begin
                b_in[i] = test_b_in[i][j];
            end

            $write("Cycle %0d: a_in:", j);
            for (int i = 0; i < row; i++) $write(" %0d", a_in[i]);
            $write(", b_in:");
            for (int j = 0; j < col; j++) $write(" %0d", b_in[j]);
            $write("\n");

            #clk_period;

        end

        #((3*8) - 2); // not sure if this is correct

        $display("Writing outputs to file...");
        for (int i = 0; i < row; i++) begin
            for (int j = 0; j < col; j++) begin
                $fwrite(write_file, "%0d ", c_out[i][j]);
            end
            $fwrite(write_file, "\n");
        end

        $fclose(write_file);
        $display("Results written to %s", `VSIM_OUT);

        $finish;

    end

    always #(clk_period/2) clk = ~clk;

endmodule