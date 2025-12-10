`include "sysdef.svh"

module reversible_pe (
    input  logic                          clk,
    input  logic                          clk_b,
    input  logic                          rst_n,
    
    // spi interface
    input  logic                          spi_clk,
    input  logic                          spi_csn,
    input  logic                          spi_mosi,
    output logic                          spi_miso

    // err flag
    // output logic                          err1,
    // output logic                          err2
);

localparam IDLE = 2'b01;
localparam WORK = 2'b10;
localparam READOUT = 2'b11;

localparam START_CMD = 2'b10;
localparam WRITE_CMD  = 2'b00;

// State register
logic [1:0] current_state, next_state;
logic [$clog2(`DATA_NUM)-1:0] counter, nxt_counter;

// SPI signals
logic [`DATA_WIDTH+`CMD_WIDTH-1:0]        spi_rdata;
logic                          spi_rvalid;
logic                          spi_ren;
logic [`DATA_WIDTH+`CMD_WIDTH-1:0]        spi_wdata;
logic                          spi_wen;
logic [$clog2(`DATA_NUM*2)-1:0] spi_addr;

// Buffer signals
logic [`DATA_WIDTH-1:0]         buffer_data_in;
logic                          buffer_wen;
logic [$clog2(`DATA_NUM*2)-1:0] buffer_waddr;
logic                          buffer_ren;
logic [$clog2(`DATA_NUM*2)-1:0] buffer_raddr;
logic [`DATA_WIDTH-1:0]         buffer_data_out;

logic [`CMD_WIDTH-1:0]         cmd, nxt_cmd;


// pipeline registers
// reg0 and reg2 are triggered by clk_0
// reg1 is triggered by clk_b
logic [15:0] output_reg, nxt_output_reg;
logic [`DATA_WIDTH-1:0]        pe_reg0, nxt_pe_reg0;
logic [23:0]        pe_reg1, nxt_pe_reg1;
logic [31:0]        pe_reg2, nxt_pe_reg2;

logic [15:0] mult_rev_ab;

logic [31:0] add_rev_ab;

logic        unused_f_c0_b;
logic        unused_f_c15;
logic        unused_r_c0_f;
logic        unused_r_z;
logic [7:0]  unused_mult_r_extra;



assign nxt_cmd = spi_wdata[`DATA_WIDTH +: `CMD_WIDTH];
assign buffer_data_in = spi_wdata[`DATA_WIDTH-1:0];
assign buffer_waddr = spi_addr;
assign buffer_wen = spi_wen & (nxt_cmd == WRITE_CMD); // decode command with current payload

assign buffer_ren = (spi_ren & (current_state == IDLE)) | (current_state == WORK); // read command
assign buffer_raddr = (current_state == IDLE) ? spi_addr : counter;
assign spi_rdata = { {`CMD_WIDTH{1'b0}}, buffer_data_out };

assign nxt_pe_reg0 = buffer_data_out;

always_comb begin
    // Default assignments
    next_state = current_state;
    nxt_counter = counter;
 
    case (current_state)
        IDLE: begin
            if (cmd == START_CMD) begin
                next_state = WORK;
                nxt_counter = '0;
            end
        end

        WORK: begin
            if (counter == `DATA_NUM - 1) begin
                next_state = IDLE;
                nxt_counter = '0;
            end else begin
                nxt_counter = counter + 1;
            end
        end

        default: begin
            next_state = IDLE;
        end
    endcase

end

// always_comb begin
//     // Default assignments
//     nxt_pe_reg0 = pe_reg0;
//     nxt_pe_reg1 = pe_reg1;
//     nxt_pe_reg2 = pe_reg2;

//     if (current_state == WORK) begin
//         // Simple example operation: increment each register by 1
//         nxt_pe_reg0 = buffer_data_out;
//         nxt_pe_reg1 = mult_f_out;
//         nxt_pe_reg2 = pe_reg2 + 1;
//     end
// end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pe_reg0 <= '0;
        pe_reg2 <= '0;
    end else begin
        pe_reg0 <= (current_state == WORK) ? nxt_pe_reg0 : pe_reg0;
        pe_reg2 <= (current_state == WORK) ? nxt_pe_reg2 : pe_reg2;
    end
end

always_ff @(posedge clk_b or negedge rst_n) begin
    if (!rst_n) begin
        pe_reg1 <= '0;
        output_reg <= '0;
    end else begin
        pe_reg1 <= (current_state == WORK) ? nxt_pe_reg1 : pe_reg1;
        output_reg <= nxt_output_reg;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        cmd <= '0;
        counter <= '0;
        spi_rvalid <= 1'b0;
    end else begin
        current_state <= next_state;
        cmd <= nxt_cmd;
        counter <= nxt_counter;
        spi_rvalid <= spi_ren & (current_state == IDLE);
    end
end

assign nxt_output_reg = nxt_pe_reg2[15:0];

fa16_rev u_fa16_rev (
    .dir     (~clk), // forward on clk, backward on clk_b
    .f_a     (pe_reg1[15:0]),
    .f_b     (output_reg),
    .f_c0_f  (1'b0),
    .f_z     (1'b0),
    .f_s     (nxt_pe_reg2[15:0]),
    .f_a_b   (nxt_pe_reg2[31:16]),
    .f_c0_b  (unused_f_c0_b),
    .f_c15   (unused_f_c15),
    .r_s     (pe_reg2[15:0]),
    .r_a_b   (pe_reg2[31:16]),
    .r_c0_b  (1'b0),
    .r_c15   (1'b0),
    .r_a     (add_rev_ab[15:0]),
    .r_b     (add_rev_ab[31:16]),
    .r_c0_f  (unused_r_c0_f),
    .r_z     (unused_r_z)
);    

mult8_rev u_mult8_rev (
    .dir     (~clk_b), // forward on clk, backward on clk_b
    .f_a     (pe_reg0[7:0]),
    .f_b     (pe_reg0[15:8]),
    .f_extra (8'b0),
    .f_p     (nxt_pe_reg1[15:0]),
    .f_a_b   (nxt_pe_reg1[23:16]),
    .r_p     (pe_reg1[15:0]),
    .r_a_b   (pe_reg1[23:16]),
    .r_a     (mult_rev_ab[7:0]),
    .r_b     (mult_rev_ab[15:8]),
    .r_extra (unused_mult_r_extra)
);

spi_slave #(
    .DW (`SPI_DATA_WIDTH),
    .AW (6),
    .CNT (6)
) u_spi_slave (
    .clk(clk),
    .rst(~rst_n),
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

pe_buffer #(
    .DATA_NUM(`DATA_NUM),
    .DATA_WIDTH(`DATA_WIDTH),
    .DEPTH(`DATA_NUM*2),
    .ADDR_WIDTH($clog2(`DATA_NUM*2))
) u_pe_buffer (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(buffer_data_in),
    .write_en(buffer_wen),
    .write_addr(buffer_waddr),

    .read_en(buffer_ren),
    .read_addr(buffer_raddr),
    .data_out(buffer_data_out) // connect to PE inputs
);

endmodule