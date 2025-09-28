`timescale 1ns / 1ps
// Dual-Port Register File
module RF #(
    parameter DATA_BITWIDTH = 8,
    parameter ADDR_BITWIDTH = 3
)(
    input  wire                   i_clk,
    input  wire                   i_rst,
    
    // Read Port
    input  wire [ADDR_BITWIDTH-1:0]  i_ra,
    output wire [DATA_BITWIDTH-1:0]  o_rd,

    // Write Port
    input  wire                      i_we,
    input  wire [ADDR_BITWIDTH-1:0]  i_wa,
    input  wire [DATA_BITWIDTH-1:0]  i_wd
);

    localparam REG_COUNT = 1 << ADDR_BITWIDTH;

    integer i;

    // Register file memory
    reg [DATA_BITWIDTH-1:0] registers [0:REG_COUNT-1];

    // Write operation (synchronous)
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (i = 0; i < REG_COUNT; i = i + 1) begin
                registers[i] <= {DATA_BITWIDTH{1'b0}};
            end
        end 
        else if(i_we) begin
            registers[i_wa] <= i_wd;
        end
    end

    // Read operation (combinational)
    assign o_rd = registers[i_ra];
    
endmodule