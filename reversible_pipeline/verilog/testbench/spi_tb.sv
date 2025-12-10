`timescale 1ps/1ps

`define CHANNEL_ADDR_WIDTH 4
`define CHANNEL_DATA_WIDTH 8


module spi_tb();

logic clk;
logic rst_slave;
logic fpga_clk;
logic rst_master;

// SPI wires
logic [`CHANNEL_DATA_WIDTH-1:0] spi_rdata;
logic spi_rvalid;
logic spi_ren;
logic [`CHANNEL_DATA_WIDTH-1:0] spi_wdata;
logic [`CHANNEL_ADDR_WIDTH-1:0] spi_addr;
logic spi_wen;
logic spi_clk;
logic spi_csn;
logic spi_mosi;
logic spi_miso;

logic spi_start;
logic spi_complete;
logic [`CHANNEL_DATA_WIDTH + `CHANNEL_ADDR_WIDTH + 2:0] spi_tx_data;
logic [`CHANNEL_DATA_WIDTH-1:0] spi_rx_data;
logic spi_rx_valid;

logic [0:(1<<`CHANNEL_ADDR_WIDTH)-1][`CHANNEL_DATA_WIDTH-1:0] data_base ;


spi_slave #(
    .DW(`CHANNEL_DATA_WIDTH),   // Data Width
    .AW(`CHANNEL_ADDR_WIDTH+2), // Address and Command Width
    .CNT(6)    // SPI Counter
)spi_slave(
    // Logic Domain
    .clk(clk),
    .rst(rst_slave),
    .rdata(spi_rdata),          // SPI <- TPU
    .rvalid(spi_rvalid),
    .ren(spi_ren),
    .wdata(spi_wdata),          // SPI -> TPU
    .wen(spi_wen),
    .addr(spi_addr),           // SPI -> TPU
    // output  reg             avalid,

    // SPI Domain
    .spi_clk(spi_clk),
    .spi_csn(spi_csn),        // SPI Active Low
    .spi_mosi(spi_mosi),       // Host -> SPI
    .spi_miso(spi_miso)       // Host <- SPI
);

host_spi #(
    .DW(`CHANNEL_DATA_WIDTH + `CHANNEL_ADDR_WIDTH + 2 + 1),
    .RX(`CHANNEL_DATA_WIDTH)
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

// logic [`CHANNEL_ADDR_WIDTH - 1:0]  taddr; 
// logic [`CHANNEL_DATA_WIDTH - 1:0] trdata;
// logic [`CHANNEL_DATA_WIDTH - 1:0] twdata;

task FPGA_SPI_WR(
    input logic [`CHANNEL_ADDR_WIDTH-1:0] addr,
    input logic [`CHANNEL_DATA_WIDTH-1:0] wdata
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
    input  logic [`CHANNEL_ADDR_WIDTH-1:0] addr,
    output logic [`CHANNEL_DATA_WIDTH-1:0] rdata
);
    @(negedge fpga_clk);
    spi_start = 1;
    spi_tx_data = {2'b01, addr, 1'b0, 8'b0};
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


initial clk = 0;
always #5 clk = ~clk;

initial fpga_clk = 0;
always #20 fpga_clk = ~fpga_clk;

// always_comb spi_rdata = data_base[spi_addr];
always @(posedge clk or posedge rst_slave) begin
    if (rst_slave) begin
        data_base <= '0;
        spi_rvalid <= 1'b0;
    end
    else begin
        spi_rvalid <= 1'b0;
        if (spi_wen) begin
            data_base[spi_addr] <= spi_wdata;
        end 
        else if (spi_ren) begin
            spi_rdata <= data_base[spi_addr];
            spi_rvalid <= 1'b1;
        end
        end
    end

logic [`CHANNEL_DATA_WIDTH-1:0] rd_val;

initial begin
    $dumpfile(`VCD_FILE);
    $dumpvars(0, spi_tb);

    rst_slave = 1;
    rst_master = 1;
    spi_start = 0;
    spi_tx_data = '0;
    #50
    rst_slave = 0;
    rst_master = 0;

    #50;

    FPGA_SPI_WR(0, 8'hA5);
    #20;

    FPGA_SPI_RD(0, rd_val);
    $display("Read data: %h", rd_val);

    #1000;
    $finish;

end
endmodule
