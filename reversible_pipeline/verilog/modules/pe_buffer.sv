`include "sysdef.svh"

module pe_buffer #(
    parameter DATA_NUM   = `DATA_NUM,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter DEPTH      = 2*`DATA_NUM,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic [DATA_WIDTH-1:0]         data_in,
    input  logic                          write_en,
    input  logic [ADDR_WIDTH-1:0]         write_addr,

    input  logic                          read_en,
    input  logic [ADDR_WIDTH-1:0]         read_addr,
    output logic [DATA_WIDTH-1:0]         data_out
);

    logic [DATA_WIDTH-1:0] mem_array [0:DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++) begin
                mem_array[i] <= '0;
            end
        end else if (write_en) begin
            mem_array[write_addr] <= data_in;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= '0;
        end else if (read_en) begin
            data_out <= mem_array[read_addr];
        end
    end

    
endmodule