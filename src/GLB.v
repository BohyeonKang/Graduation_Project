`timescale 1ns / 1ps

module GLB #(
    parameter DATA_BITWIDTH = 32,
    parameter BANK_NUM = 32,
    parameter BANK_DEPTH = 1024
)(
    input i_clk,
    input i_rst,
    // Bank별로 개별 접근
    input  [BANK_NUM-1:0] i_re,      // Read enable for each bank
    input  [BANK_NUM-1:0] i_we,      // Write enable for each bank
    input  [BANK_NUM-1:0][clogb2(BANK_DEPTH-1)-1:0] i_ra, // Read addr
    input  [BANK_NUM-1:0][clogb2(BANK_DEPTH-1)-1:0] i_wa, // Write addr
    input  [BANK_NUM-1:0][DATA_BITWIDTH-1:0] i_wd,        // Write data
    output [BANK_NUM-1:0][DATA_BITWIDTH-1:0] o_rd         // Read data
);

    genvar i;
    generate
        for (i = 0; i < BANK_NUM; i = i + 1) begin: GLB_BANKS
            true_dpbram #(
                .RAM_WIDTH(DATA_BITWIDTH),
                .RAM_DEPTH(BANK_DEPTH),
                .RAM_PERFORMANCE("HIGH_PERFORMANCE")
            ) glb_bank_inst (
                .addra   (i_ra[i]),
                .addrb   (i_wa[i]), // Port A: Read, Port B: Write
                .dina    ({DATA_BITWIDTH{1'b0}}), // Port A input not used (read-only)
                .dinb    (i_wd[i]),              // Port B input data (write)
                .clka    (i_clk),
                .clkb    (i_clk),
                .wea     (1'b0),                 // Port A write disable
                .web     (i_we[i]),              // Port B write enable
                .ena     (i_re[i]),              // Port A enable for read
                .enb     (i_we[i]),              // Port B enable for write
                .rsta    (i_rst),                // Synchronous reset
                .rstb    (i_rst),
                .regcea  (1'b1),                 // Output register always enabled
                .regceb  (1'b1),
                .douta   (o_rd[i]),              // Read data
                .doutb   ()                      // Port B output unused
            );
        end
    endgenerate

    // clogb2 함수 (copy-paste)
    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule