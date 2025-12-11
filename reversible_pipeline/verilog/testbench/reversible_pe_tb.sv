`timescale 1ns/1ps
`include "sysdef.svh"

module reversible_pe_tb;
	logic clk;
	logic clk_b;
	logic rst_n;
    logic rst_master;

    logic fpga_clk;
	logic spi_clk;
	logic spi_csn;
	logic spi_mosi;
	logic spi_miso;

    logic spi_start;
    logic spi_complete;
    logic [`SPI_DATA_WIDTH + `SPI_ADDR_WIDTH + 2:0] spi_tx_data;
    logic [`SPI_DATA_WIDTH-1:0] spi_rx_data;
    logic spi_rx_valid;

    host_spi #(
        .DW(`SPI_DATA_WIDTH + `SPI_ADDR_WIDTH + 2 + 1),
        .RX(`SPI_DATA_WIDTH)
    )inst_host_spi (
        // Global Signals
        .clk(fpga_clk),
        .rst(rst_master),

        // Host Interface
        .spi_start(spi_start),
        .spi_complete(spi_complete),
        .spi_tx_data(spi_tx_data),
        .spi_rx_data(spi_rx_data),
        .spi_rx_valid(spi_rx_valid),

        // SPI Interface
        .spi_sck(spi_clk),
        .spi_csn(spi_csn),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

	// Device under test
	reversible_pe dut (
		.clk(clk),
		.clk_b(clk_b),
		.rst_n(rst_n),
		.spi_clk(spi_clk),
		.spi_csn(spi_csn),
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso)
	);

    task FPGA_SPI_WR(
    input logic [`SPI_ADDR_WIDTH-1:0] addr,
    input logic [`SPI_DATA_WIDTH-1:0] wdata
    );
        @(negedge fpga_clk);
        spi_start = 1;
        spi_tx_data = {2'b10, addr, 1'b0, wdata};
        @(negedge fpga_clk);
        spi_start = 0;
        while (1)begin
            @(negedge fpga_clk);
            if(spi_complete)begin
                // $display("One SPI write done.");
                break;
            end
        end
    endtask

    task FPGA_SPI_RD(
        input  logic [`SPI_ADDR_WIDTH-1:0] addr,
        output logic [`SPI_DATA_WIDTH-1:0] rdata
    );
        @(negedge fpga_clk);
        spi_start = 1;
        spi_tx_data = {2'b01, addr, 1'b0, 18'b0};
        @(negedge fpga_clk);
        spi_start = 0;
        while (1)begin
            @(negedge fpga_clk);
            if(spi_rx_valid)begin
                rdata = spi_rx_data;
                break;
            end
        end

    endtask

	// 20ns high / 30ns low primary clock
	initial begin
		clk = 1'b0;
		forever begin
			clk = 1'b1;
			#20;
			clk = 1'b0;
			#30;
		end
	end

	// Secondary clock delayed so high phases never overlap primary
	initial begin
		clk_b = 1'b0;
		#25; // ensure clk is low before clk_b begins its active phase
		forever begin
			clk_b = 1'b1;
			#20;
			clk_b = 1'b0;
			#30;
		end
	end

    initial fpga_clk = 0;
    always #100 fpga_clk = ~fpga_clk;

    logic [15:0] rd_val;

	// Basic stimulus: hold SPI idle and release reset after some time
	initial begin
        $dumpfile(`VCD_FILE);
        $dumpvars(0, reversible_pe_tb);

		rst_n = 1'b0;
        rst_master = 1'b1;
        spi_start = 0;
        spi_tx_data = '0;
		#200;
		rst_n = 1'b1;
        rst_master = 1'b0;

        #500;
        //write test data via SPI
        FPGA_SPI_WR(0, 18'h10101);

        #500;
        //write test data via SPI
        FPGA_SPI_WR(1, 18'h10102);
        #500;
        //write test data via SPI
        FPGA_SPI_WR(2, 18'h10103);
        #500;
        //write test data via SPI
        FPGA_SPI_WR(3, 18'h10104);

        #500;
        //write test data via SPI
        FPGA_SPI_WR(4, 18'h10105);
        #500;
        //write test data via SPI
        FPGA_SPI_WR(5, 18'h10106);
        #500;
        //write test data via SPI
        FPGA_SPI_WR(6, 18'h10107);
        #500;
        //write test data via SPI
        FPGA_SPI_WR(7, 18'h10108);

        #1000;
        FPGA_SPI_WR(0, 18'h20000);

        #10000;
        for (int i = 0; i < 8; i++) begin
            FPGA_SPI_RD(i, rd_val);
            $display("Read data from addr %0d: %h", i, rd_val);
        end;

        #10000;
		$finish;
	end


endmodule
