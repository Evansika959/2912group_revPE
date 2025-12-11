`include "sysdef.svh"

module reversible_pe (
    `ifdef USE_POWER_PINS
        inout logic VDD,
        inout logic VSS,
    `endif

    // global signals
    input  logic                          clk,
    input  logic                          clk_b,
    input  logic                          rst_n,
    
    // spi interface
    input  logic                          spi_clk,
    input  logic                          spi_csn,
    input  logic                          spi_mosi,
    output logic                          spi_miso,

    // err flag
    output logic                          err1,
    output logic                          err2
);

localparam IDLE = 2'b01;
localparam WORK = 2'b10;
// localparam READOUT = 2'b11;

localparam START_CMD = 2'b10;
localparam WRITE_CMD  = 2'b01;
localparam NO_CMD  = 2'b00;


// State register
logic [1:0] current_state, nxt_state;
logic [$clog2(`DATA_NUM)-1:0] counter, nxt_counter;
logic [$clog2(`DATA_NUM)-1:0] wr_counter;


// SPI signals
logic [`DATA_WIDTH+`CMD_WIDTH-1:0]        spi_rdata;
logic                          spi_rvalid;
logic                          spi_ren;
logic [`DATA_WIDTH+`CMD_WIDTH-1:0]        spi_wdata;
logic                          spi_wen;
logic [`SPI_ADDR_WIDTH-1:0] spi_addr;

// Buffer signals
logic [`DATA_WIDTH-1:0]         buffer_data_in;
logic                          buffer_wen;
logic [$clog2(`DATA_NUM)-1:0] buffer_waddr;
logic                          buffer_ren;
logic [$clog2(`DATA_NUM)-1:0] buffer_raddr;
logic [`DATA_WIDTH-1:0]         buffer_data_out;

logic [`DATA_WIDTH-1:0]         out_buffer_data_in;
logic                          out_buffer_wen;
logic [$clog2(`DATA_NUM)-1:0] out_buffer_waddr;
logic                          out_buffer_ren;
logic [$clog2(`DATA_NUM)-1:0] out_buffer_raddr;
logic [`DATA_WIDTH-1:0]         out_buffer_data_out;

logic                         nxt_err1, nxt_err2;

logic [`CMD_WIDTH-1:0]         cmd, nxt_cmd;

logic mult_dir, fa_dir;


// pipeline registers
// reg0 and reg2 are triggered by clk_0
// reg1 is triggered by clk_b
logic [15:0] output_reg, nxt_output_reg;
logic [`DATA_WIDTH-1:0]        pe_reg0, nxt_pe_reg0;
logic [23:0]        pe_reg1, nxt_pe_reg1;
logic [31:0]        pe_reg2, nxt_pe_reg2;
logic               pe_vld_stem, pe_vld0, pe_vld1, pe_vld2;

logic [7:0]  mult_f_a, mult_f_b, mult_f_a_b;
logic [15:0] mult_f_p;


logic [15:0] mult_rev_ab;

logic [15:0] add_f_a, add_f_b;
logic [15:0] add_rev_a, add_rev_b;

logic        unused_f_c0_b;
logic        unused_f_c15;
logic        unused_r_c0_f;
logic        unused_r_z;

assign nxt_cmd = spi_wen ? spi_wdata[`DATA_WIDTH +: `CMD_WIDTH] : NO_CMD;
assign buffer_data_in = spi_wdata[`DATA_WIDTH-1:0];
assign buffer_waddr = spi_addr;
assign buffer_wen = spi_wen & (nxt_cmd == WRITE_CMD); // decode command with current payload

assign buffer_ren = (current_state == WORK); // read command
assign buffer_raddr = counter;


assign out_buffer_data_in = pe_reg2[15:0];
assign out_buffer_waddr = wr_counter;
assign out_buffer_wen = pe_vld2 & (current_state == WORK);

assign out_buffer_ren = (spi_ren & (current_state == IDLE));
assign out_buffer_raddr = spi_addr;
assign spi_rdata = { {`CMD_WIDTH{1'b0}}, out_buffer_data_out };

assign nxt_pe_reg0 = buffer_data_out;

always_comb begin
    // Default assignments
    nxt_state = current_state;
    nxt_counter = counter;

    nxt_err1 = err1;
    nxt_err2 = err2;
 
    case (current_state)
        IDLE: begin
            if (cmd == START_CMD) begin
                nxt_state = WORK;
                nxt_counter = '0;
            end
        end

        WORK: begin
            if (counter == `DATA_NUM - 1) begin
                nxt_counter = '0;
                // nxt_state = IDLE;
            end else begin
                nxt_counter = counter + 1;
            end

            if (wr_counter == `DATA_NUM - 1) begin
                nxt_state = IDLE;
            end

            nxt_err1 = ((pe_reg0 != mult_rev_ab) && pe_vld0) ? 1'b1 : 1'b0;
            nxt_err2 = ((add_f_a != add_rev_a) && pe_vld1) ? 1'b1 : 1'b0;
        end

        default: begin
            nxt_state = IDLE;
        end
    endcase

end

//for the err flags
always_ff @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
        err2 <= 1'b0;
    end else begin
        err2 <= nxt_err2;
    end
end

always_ff @(negedge clk_b or negedge rst_n) begin
    if (!rst_n) begin
        err1 <= 1'b0;
    end else begin
        err1 <= nxt_err1;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pe_vld_stem <= 1'b0;
        pe_vld0 <= 1'b0;
        pe_vld1 <= 1'b0;
        pe_vld2 <= 1'b0;
        wr_counter <= '0;
    end else begin
        pe_vld_stem <= (current_state == WORK);
        pe_vld0 <= pe_vld_stem;
        pe_vld1 <= pe_vld0;
        pe_vld2 <= pe_vld0;   // delay by two cycles by design
        wr_counter <= (pe_vld1) ? wr_counter + 1 : 
                    (cmd == START_CMD) ? 0 : wr_counter;
    end
end

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
        output_reg <= (current_state == WORK) ? nxt_output_reg : output_reg;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        cmd <= '0;
        counter <= '0;
        spi_rvalid <= 1'b0;
    end else begin
        current_state <= nxt_state;
        cmd <= nxt_cmd;
        counter <= nxt_counter;
        spi_rvalid <= spi_ren & (current_state == IDLE);
    end
end

assign nxt_output_reg = nxt_pe_reg2[15:0];

assign fa_dir = (current_state == WORK) ? clk : 0;    // forward on clk_b, backward on clk
assign mult_dir = (current_state == WORK) ? clk_b : 0;    // forward on clk, backward on clk_b

assign add_f_a = pe_reg1[15:0];
assign add_f_b = output_reg;

fa16_rev u_fa16_rev (
    `ifdef USE_POWER_PINS
        .VDD     (VDD),
        .VSS     (VSS),
    `endif
    .dir     (fa_dir), // forward on clk, backward on clk_b
    .f_a     (add_f_a),
    .f_b     (add_f_b),
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
    .r_a     (add_rev_a),
    .r_b     (add_rev_b),
    .r_c0_f  (unused_r_c0_f),
    .r_z     (unused_r_z)
);    

assign mult_f_a = pe_reg0[7:0];
assign mult_f_b = pe_reg0[15:8];

assign nxt_pe_reg1 = { mult_f_a_b, mult_f_p };

mult8_rev u_mult8_rev (
    .dir     (mult_dir), // forward on clk, backward on clk_b
    .f_a     (mult_f_a),
    .f_b     (mult_f_b),
    .f_p     (mult_f_p),
    .f_b0_r_b(mult_f_a_b),
    .f_b2_r_b(),
    .f_b3_r_b(),
    .f_b4_r_b(),
    .f_b5_r_b(),
    .f_b6_r_b(),
    .f_b7_r_b(),
    .f_x_c0_b(),
    .r_p     (pe_reg1[15:0]),
    .r_b0_r_b(pe_reg1[23:16]),
    .r_b2_r_b(8'b0),
    .r_b3_r_b(8'b0),
    .r_b4_r_b(8'b0),
    .r_b5_r_b(8'b0),
    .r_b6_r_b(8'b0),
    .r_b7_r_b(8'b0),
    .r_x_c0_b(7'b0),
    .r_a     (mult_rev_ab[7:0]),
    .r_b     (mult_rev_ab[15:8])
);

spi_slave #(
    .DW (`SPI_DATA_WIDTH),
    .AW (`SPI_ADDR_WIDTH+2),
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
    .DEPTH(`DATA_NUM),
    .ADDR_WIDTH($clog2(`DATA_NUM))
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

pe_buffer #(
    .DATA_NUM(`DATA_NUM),
    .DATA_WIDTH(`DATA_WIDTH),
    .DEPTH(`DATA_NUM),
    .ADDR_WIDTH($clog2(`DATA_NUM))
) u_pe_out_buffer (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(out_buffer_data_in),
    .write_en(out_buffer_wen),
    .write_addr(out_buffer_waddr),

    .read_en(out_buffer_ren),
    .read_addr(out_buffer_raddr),
    .data_out(out_buffer_data_out) // connect to PE inputs
);

endmodule