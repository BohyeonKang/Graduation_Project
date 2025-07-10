`timescale 1ns / 1ps

module PE_vector #(
    parameter DATA_BITWIDTH = 8,
    parameter COL_LEN = 3
)(
    input i_clk,
    input i_rst,

    // TOP CTRL interface
    input [2:0] i_inst_data,
    input [8:0] i_conv_info,
    input i_inst_valid,
    output o_inst_ready,

    // GLB interface
    input [DATA_BITWIDTH-1:0] i_ifmap_data,
    input i_ifmap_valid,
    output o_ifmap_ready,

    input [DATA_BITWIDTH-1:0] i_wght_data,
    input i_wght_valid,
    output o_wght_ready,

    input [DATA_BITWIDTH-1:0] i_psum_in_data,
    input i_psum_in_valid,
    output o_psum_in_ready,

    output [DATA_BITWIDTH-1:0] o_psum_out_data,
    output o_psum_out_valid,
    input i_psum_out_ready
);

    wire [COL_LEN-1:0] inst_ready, ifmap_ready, wght_ready;
    wire [COL_LEN:0] psum_valid, psum_ready;
    wire [DATA_BITWIDTH-1:0] psum_data [COL_LEN:0];
    
    assign o_inst_ready = & inst_ready;

    assign o_ifmap_ready = & ifmap_ready;
    assign o_wght_ready = & wght_ready;

    assign psum_valid[0] = i_psum_in_valid;
    assign psum_ready[COL_LEN] = i_psum_out_ready;

    assign o_psum_in_ready = psum_ready[0];
    assign o_psum_out_valid = psum_valid[COL_LEN];

    assign psum_data[0] = i_psum_in_data;
    assign o_psum_out_data = psum_data[COL_LEN];

    genvar i;
    generate
        for(i=0; i<COL_LEN; i=i+1) begin: PE_gen
            PE_top #(
                .DATA_BITWIDTH       (DATA_BITWIDTH),
                .IFMAP_ADDR_BITWIDTH (4),
                .WGHT_ADDR_BITWIDTH  (7),
                .PSUM_ADDR_BITWIDTH  (3)
            ) u_PE_top (
                .i_clk                 (i_clk),
                .i_rst                 (i_rst),

                // TOP CTRL
                .i_inst_data           (i_inst_data),
                .i_conv_info           (i_conv_info),
                .i_inst_valid          (i_inst_valid),
                .o_inst_ready          (inst_ready[i]),

                // fifo interface I/O
                .i_ifmap_fifo_data     (i_ifmap_data),
                .i_ifmap_fifo_valid    (i_ifmap_valid),
                .o_ifmap_fifo_ready    (ifmap_ready[i]),

                .i_wght_fifo_data      (i_wght_data),
                .i_wght_fifo_valid     (i_wght_valid),
                .o_wght_fifo_ready     (wght_ready[i]),

                .i_psum_in_fifo_data   (psum_data[i]),
                .i_psum_in_fifo_valid  (psum_valid[i]),
                .o_psum_in_fifo_ready  (psum_ready[i]),

                .o_psum_out_fifo_data  (psum_data[i+1]),
                .o_psum_out_fifo_valid (psum_valid[i+1]),
                .i_psum_out_fifo_ready (psum_ready[i+1])
            );
        end
    endgenerate

endmodule