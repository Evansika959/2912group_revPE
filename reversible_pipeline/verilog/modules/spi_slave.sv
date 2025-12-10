//mode0 也就是说，数据要在第一个上升沿前就准备好，因为第一个上升沿就开始采样
//cmd为2是写，为1是读


module spi_slave #(
    parameter   DW  = 8,   // Data Width
    parameter   AW  = 16+2, // Address and Command Width
    parameter   CNT = 6     // SPI Counter
)(
    // Logic Domain
    input                   clk,
    input                   rst,
    input       [DW-1:0]    rdata,          // SPI <- TPU
    input                   rvalid,
    output                  ren,
    output  reg [DW-1:0]    wdata,          // SPI -> TPU
    output  reg             wen,
    output  reg [AW-3:0]    addr,           // SPI -> TPU
    // output  reg             avalid,

    // SPI Domain
    input                   spi_clk,
    input                   spi_csn,        // SPI Active Low
    input                   spi_mosi,       // Host -> SPI
    output                  spi_miso       // Host <- SPI
);

    localparam  SW = AW + DW + 1;
    localparam  TX_CNT = $clog2(DW);

// =============================================================================
// MOSI: FPGA Host -> SPI MOSI -> TPU

    // 1. Sample at the Positive Edge (First Edge)
    reg     [CNT-1:0]   rx_bit_cnt;

    always @(posedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            rx_bit_cnt <= 'd0;
        end
        else begin
            if (rx_bit_cnt == SW-1) begin
                rx_bit_cnt <= 'd0;
            end
            else begin
                rx_bit_cnt <= rx_bit_cnt + 1'b1;
            end
        end
    end

    // 2. MOSI Serial to Parallel
    reg     [SW-1:0]    rx_byte_buf;
    reg                 rx_addr_valid, rx_data_valid;

    always @(posedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            rx_byte_buf <= 'd0;
        end
        else begin
            rx_byte_buf <= {rx_byte_buf[SW-2:0], spi_mosi};
        end
    end

    always @(posedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            rx_addr_valid <= 1'b0;
        end
        else begin
            if (rx_bit_cnt == AW-1) begin
                rx_addr_valid <= 1'b1;
            end
            else begin
                rx_addr_valid <= 1'b0;
            end
        end
    end

    always @(posedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            rx_data_valid <= 1'b0;
        end
        else begin
            if (rx_bit_cnt == SW-1) begin
                rx_data_valid <= 1'b1;
            end
            else begin
                rx_data_valid <= 1'b0;
            end
        end
    end

    // 3. CDC: SPI Domain to Chip Domain
    reg     rx_addr_valid_d0, rx_addr_valid_d1, rx_addr_valid_d2;
    reg     rx_data_valid_d0, rx_data_valid_d1, rx_data_valid_d2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_addr_valid_d0 <= 1'b0;
            rx_addr_valid_d1 <= 1'b0;
            rx_addr_valid_d2 <= 1'b0;
        end
        else begin
            rx_addr_valid_d0 <= rx_addr_valid;
            rx_addr_valid_d1 <= rx_addr_valid_d0;
            rx_addr_valid_d2 <= rx_addr_valid_d1;
        end
    end 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data_valid_d0 <= 1'b0;
            rx_data_valid_d1 <= 1'b0;
            rx_data_valid_d2 <= 1'b0; 
        end
        else begin
            rx_data_valid_d0 <= rx_data_valid;
            rx_data_valid_d1 <= rx_data_valid_d0;
            rx_data_valid_d2 <= rx_data_valid_d1;
        end
    end

    reg     [1:0]   cmd;
    reg             avalid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr <= 'd0;
            cmd  <= 'd0;
        end
        else if (rx_addr_valid_d1 && ~rx_addr_valid_d2) begin
            {cmd, addr} <= rx_byte_buf[AW-1:0];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            avalid <= 1'b0;
        end
        else begin
            if (rx_addr_valid_d1 && ~rx_addr_valid_d2) begin
                avalid <= 1'b1;
            end
            else begin
                avalid <= 1'b0;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wdata <= 'd0;
        end
        else if (rx_data_valid_d1 && ~rx_data_valid_d2) begin
            wdata <= rx_byte_buf[DW-1:0];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wen <= 1'b0;
        end
        else begin
            if (rx_data_valid_d1 && ~rx_data_valid_d2) begin
                wen <= 1'b1 && cmd==2'b10;
            end
            else begin
                wen <= 1'b0;
            end
        end
    end

// =============================================================================
// MISO: FPGA Host <- SPI MOSI <- DLA

    assign  ren = cmd == 2'b01 && avalid;

    // 1. MISO Parrel to Serial
    reg     [DW-1:0]    tx_byte_buf;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_byte_buf <= 'd0;
        end
        else if (rvalid) begin
            tx_byte_buf <= rdata;
        end
    end

    // 2. CDC: Chip Domain to SPI Domain
    //         Transmit at the Falling Edge (Second Edge).
    reg     [CNT-1:0]   tx_bit_cnt;

    always @(negedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            tx_bit_cnt <= SW-1;
        end
        else begin
            if (tx_bit_cnt == 'd0) begin
                tx_bit_cnt <= SW-1;
            end
            else begin
                tx_bit_cnt <= tx_bit_cnt - 1'b1;
            end
        end
    end

    // 3. MISO Enable
    reg     spi_miso_enable;

    always @(negedge spi_clk or posedge spi_csn) begin
        if (spi_csn) begin
            spi_miso_enable <= 1'b0;
        end
        else begin
            if (tx_bit_cnt <= DW) begin
                spi_miso_enable <= 1'b1;
            end
            else begin
                spi_miso_enable <= 1'b0;
            end
        end
    end

    assign  spi_miso = spi_miso_enable && cmd == 2'b01 ? tx_byte_buf[tx_bit_cnt[TX_CNT-1:0]] : 1'b0;

endmodule
