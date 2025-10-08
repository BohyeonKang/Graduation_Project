`timescale 1ns / 1ps
// Dual-Port Distributed RAM with Synchronous Read
module rams_dist #(
    parameter DATA_BITWIDTH = 8,
    parameter ADDR_BITWIDTH = 7,
    parameter DEPTH = (1 << ADDR_BITWIDTH),
    parameter INIT_FILE = ""
)(
    input                      clk,
    input                      we0,
    input                      we1,
    input  [DATA_BITWIDTH-1:0] d0,
    input  [DATA_BITWIDTH-1:0] d1,
    input  [ADDR_BITWIDTH-1:0] addr0,
    input  [ADDR_BITWIDTH-1:0] addr1,
    output [DATA_BITWIDTH-1:0] q0,
    output [DATA_BITWIDTH-1:0] q1
);

    localparam RAM_DEPTH = 1 << ADDR_BITWIDTH;

    (* ram_style = "distributed" *)
    reg [DATA_BITWIDTH-1:0] mem [0:RAM_DEPTH-1];


    integer i;
    initial begin
        if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
        end
        else begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 0;
        end
        end
    end

    always @(posedge clk) begin
        if (we0)
        mem[addr0] <= d0;
    end

    always @(posedge clk) begin
        if (we1)
        mem[addr1] <= d1;
    end

    assign q0 = mem[addr0];
    assign q1 = mem[addr1];

endmodule