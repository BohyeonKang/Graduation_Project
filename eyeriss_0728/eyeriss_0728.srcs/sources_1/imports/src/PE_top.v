`timescale 1ns / 1ps

module PE_top #(
    parameter DATA_BITWIDTH = 8,
    parameter IFMAP_ADDR_BITWIDTH = 4,
    parameter WGHT_ADDR_BITWIDTH = 7,
    parameter PSUM_ADDR_BITWIDTH = 3
)(
    input i_clk,
    input i_rst,

    //TOP CTRL
    input [2:0] i_inst_data,
    input [8:0] i_conv_info,
    input i_inst_valid,
    output o_inst_ready,

    //fifo interface I/O
	input [DATA_BITWIDTH-1:0] i_ifmap_fifo_data,
    input i_ifmap_fifo_valid,
    output o_ifmap_fifo_ready,

    input [DATA_BITWIDTH-1:0] i_wght_fifo_data,
    input i_wght_fifo_valid,
    output o_wght_fifo_ready,

    input [DATA_BITWIDTH-1:0] i_psum_in_fifo_data,
    input i_psum_in_fifo_valid,
    output o_psum_in_fifo_ready,

    output [DATA_BITWIDTH-1:0] o_psum_out_fifo_data,
    output o_psum_out_fifo_valid,
    input i_psum_out_fifo_ready
);

    //Local FIFO interface signals
    wire [DATA_BITWIDTH-1:0] ifmap_data_fifo2datapath;
    wire ifmap_valid_fifo2ctrl;
    wire ifmap_ready_ctrl2fifo;

    wire [DATA_BITWIDTH-1:0] wght_data_fifo2datapath;
    wire wght_valid_fifo2ctrl;
    wire wght_ready_ctrl2fifo;

    wire [DATA_BITWIDTH-1:0] psum_in_data_fifo2datapath;
    wire psum_in_valid_fifo2ctrl;
    wire psum_in_ready_ctrl2fifo;

    wire [DATA_BITWIDTH-1:0] psum_out_data_datapath2fifo;
    wire psum_out_valid_datapath2ctrl;
    wire psum_out_ready_fifo2ctrl;

    //Local control signals
    wire [IFMAP_ADDR_BITWIDTH-1:0] ifmap_ra_ctrl2datapath, ifmap_wa_ctrl2datapath;
    wire [WGHT_ADDR_BITWIDTH-1:0]  wght_ra_ctrl2datapath, wght_wa_ctrl2datapath;
    wire [PSUM_ADDR_BITWIDTH-1:0]  psum_ra_ctrl2datapath, psum_wa_ctrl2datapath;

    wire ifmap_we_ctrl2datapath, wght_we_ctrl2datapath, psum_we_ctrl2datapath;
    wire acc_sel_ctrl2datapath, rst_psum_ctrl2datapath;

    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(DATA_BITWIDTH)
    ) u_ifmap_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(i_ifmap_fifo_data),
        .i_valid(i_ifmap_fifo_valid),
        .o_ready(o_ifmap_fifo_ready),

        //FIFO interface as tx
        .i_ready(ifmap_ready_ctrl2fifo),         
        .o_valid(ifmap_valid_fifo2ctrl),
        .o_pop_data(ifmap_data_fifo2datapath)
    );

    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(DATA_BITWIDTH)
    ) u_wght_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(i_wght_fifo_data),
        .i_valid(i_wght_fifo_valid),
        .o_ready(o_wght_fifo_ready),

        //FIFO interface as tx
        .i_ready(wght_ready_ctrl2fifo),         
        .o_valid(wght_valid_fifo2ctrl),
        .o_pop_data(wght_data_fifo2datapath)
    );

    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(DATA_BITWIDTH)
    ) u_psum_in_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(i_psum_in_fifo_data),
        .i_valid(i_psum_in_fifo_valid),
        .o_ready(o_psum_in_fifo_ready),

        //FIFO interface as tx
        .i_ready(psum_in_ready_ctrl2fifo),         
        .o_valid(psum_in_valid_fifo2ctrl),
        .o_pop_data(psum_in_data_fifo2datapath)
    );

    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(DATA_BITWIDTH)
    ) u_psum_out_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(psum_out_data_datapath2fifo),
        .i_valid(psum_out_valid_datapath2ctrl),
        .o_ready(psum_out_ready_fifo2ctrl),

        //FIFO interface as tx
        .i_ready(i_psum_out_fifo_ready),
        .o_valid(o_psum_out_fifo_valid),
        .o_pop_data(o_psum_out_fifo_data)
    );

    PE_control #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .IFMAP_ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH),
        .WGHT_ADDR_BITWIDTH(WGHT_ADDR_BITWIDTH),
        .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
    ) u_PE_control (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_opcode(i_inst_data),
        .i_conv_info(i_conv_info),
        .i_inst_valid(i_inst_valid),
        .o_inst_ready(o_inst_ready),

        .i_ifmap_fifo_valid(ifmap_valid_fifo2ctrl),
        .o_ifmap_fifo_ready(ifmap_ready_ctrl2fifo),
        .i_wght_fifo_valid(wght_valid_fifo2ctrl),
        .o_wght_fifo_ready(wght_ready_ctrl2fifo),
        .i_psum_in_fifo_valid(psum_in_valid_fifo2ctrl),
        .o_psum_in_fifo_ready(psum_in_ready_ctrl2fifo),
        .i_psum_out_fifo_ready(psum_out_ready_fifo2ctrl),
        .i_psum_out_fifo_valid(psum_out_valid_datapath2ctrl),

        .o_ifmap_ra(ifmap_ra_ctrl2datapath),
        .o_wght_ra(wght_ra_ctrl2datapath),
        .o_psum_ra(psum_ra_ctrl2datapath),
        .o_ifmap_wa(ifmap_wa_ctrl2datapath),
        .o_wght_wa(wght_wa_ctrl2datapath),
        .o_psum_wa(psum_wa_ctrl2datapath),
        .o_ifmap_we(ifmap_we_ctrl2datapath),
        .o_wght_we(wght_we_ctrl2datapath),
        .o_psum_we(psum_we_ctrl2datapath),
        .o_acc_sel(acc_sel_ctrl2datapath),
        .o_rst_psum(rst_psum_ctrl2datapath)
    );

    PE_datapath #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .IFMAP_ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH),
        .WGHT_ADDR_BITWIDTH(WGHT_ADDR_BITWIDTH),
        .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
    ) u_PE_datapath (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_ifmap_data(ifmap_data_fifo2datapath),
        .i_wght_data(wght_data_fifo2datapath),
        .i_psum_data(psum_in_data_fifo2datapath),
        .o_psum_data(psum_out_data_datapath2fifo),

        //controller interface
        .i_ifmap_ra(ifmap_ra_ctrl2datapath),
        .i_wght_ra(wght_ra_ctrl2datapath),
        .i_psum_ra(psum_ra_ctrl2datapath),
        .i_ifmap_wa(ifmap_wa_ctrl2datapath),
        .i_wght_wa(wght_wa_ctrl2datapath),
        .i_psum_wa(psum_wa_ctrl2datapath),
        .i_ifmap_we(ifmap_we_ctrl2datapath),
        .i_wght_we(wght_we_ctrl2datapath),
        .i_psum_we(psum_we_ctrl2datapath),
        .i_acc_sel(acc_sel_ctrl2datapath),
        .i_rst_psum(rst_psum_ctrl2datapath),
        .o_psum_out_valid(psum_out_valid_datapath2ctrl)
    );

endmodule