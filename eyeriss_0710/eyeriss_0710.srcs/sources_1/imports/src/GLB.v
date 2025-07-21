`timescale 1ns / 1ps

module GLB #(
    parameter DATA_BITWIDTH = 32,
    parameter BANK_NUM = 32,
    parameter BANK_DEPTH = 1024
)(
    input i_clk,
    input i_rst,
    
	input [clogb2(BANK_NUM-1)-1:0] i_bank_sel,

    input  i_re,      // Read enable for each bank
    input  i_we,      // Write enable for each bank
    input  [clogb2(BANK_DEPTH-1)-1:0] i_ra, // Read addr
    input  [clogb2(BANK_DEPTH-1)-1:0] i_wa, // Write addr
    input  [DATA_BITWIDTH-1:0] i_wd,        // Write data
    output [DATA_BITWIDTH-1:0] o_rd         // Read data
);

	wire [BANK_NUM-1:0] bank_sel_one_hot;
    wire [DATA_BITWIDTH-1:0] read_data [BANK_NUM-1:0];

	assign bank_sel_one_hot = 1'b1 << i_bank_sel;
    assign o_rd = read_data[i_bank_sel];

    genvar i;
    generate
        for (i = 0; i < BANK_NUM; i = i + 1) begin: gen_GLB_BANKS
            true_dpbram #(
                .RAM_WIDTH(DATA_BITWIDTH),
                .RAM_DEPTH(BANK_DEPTH),
                .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
            ) glb_bank_inst (
                .addra   (i_ra),
                .addrb   (i_wa), // Port A: Read, Port B: Write
                .dina    ({DATA_BITWIDTH{1'b0}}), // Port A input not used (read-only)
                .dinb    (i_wd),              // Port B input data (write)
                .clka    (i_clk),
                .clkb    (i_clk),
                .wea     (1'b0),                 // Port A write disable
                .web     (i_we && bank_sel_one_hot[i]),              // Port B write enable
                .ena     (i_re && bank_sel_one_hot[i]),              // Port A enable for read
                .enb     (i_we && bank_sel_one_hot[i]),              // Port B enable for write
                .rsta    (i_rst),                // Synchronous reset
                .rstb    (i_rst),
                .regcea  (1'b1),                 // Output register always enabled
                .regceb  (1'b1),
                .douta   (read_data[i]),              // Read data
                .doutb   ()                      // Port B output unused
            );
        end
    endgenerate

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule