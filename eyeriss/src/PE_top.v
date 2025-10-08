`timescale 1ns / 1ps

module PE_top #(
    parameter DATA_BITWIDTH = 8,
    parameter IFMAP_SPAD_AWIDTH = 4,
    parameter WGHT_SPAD_AWIDTH = 7,
    parameter PSUM_SPAD_AWIDTH = 3,
    parameter IFMAP_FIFO_AWIDTH = 4,
    parameter WGHT_FIFO_AWIDTH = 8,
    parameter PSUM_FIFO_AWIDTH = 4
)(
    input i_clk,
    input i_rst,

    //TOP CTRL
    input [2:0] i_opcode,
    input i_opcode_valid,
    output o_opcode_ready,
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [3:0] i_layer_s,

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

	/////////////////////////////////
	// internal signals
	/////////////////////////////////

    // FIFO interface
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
    wire psum_out_valid_ctrl2fifo;
    wire psum_out_ready_fifo2ctrl;

    // CTRL <=> Datapath
    wire psum_out_valid_datapath2ctrl;

    wire [IFMAP_SPAD_AWIDTH-1:0] ifmap_spad_addr_ctrl2datapath;
    wire [WGHT_SPAD_AWIDTH-1:0]  wght_spad_addr_ctrl2datapath;
    wire [PSUM_SPAD_AWIDTH-1:0]  psum_spad_addr_ctrl2datapath;

    wire ifmap_we_ctrl2datapath, wght_we_ctrl2datapath, psum_we_ctrl2datapath;
    wire acc_sel_ctrl2datapath, rst_psum_ctrl2datapath;

    /////////////////////////////////
	// Instantiation
	/////////////////////////////////

    fifo #(
        .QUEUE_PTR_BANDWIDTH(IFMAP_FIFO_AWIDTH),
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
        .QUEUE_PTR_BANDWIDTH(WGHT_FIFO_AWIDTH),
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
        .QUEUE_PTR_BANDWIDTH(PSUM_FIFO_AWIDTH),
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
        .QUEUE_PTR_BANDWIDTH(PSUM_FIFO_AWIDTH),
        .ELE_BANDWIDTH(DATA_BITWIDTH)
    ) u_psum_out_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(psum_out_data_datapath2fifo),
        .i_valid(psum_out_valid_ctrl2fifo),
        .o_ready(psum_out_ready_fifo2ctrl),

        //FIFO interface as tx
        .i_ready(i_psum_out_fifo_ready),
        .o_valid(o_psum_out_fifo_valid),
        .o_pop_data(o_psum_out_fifo_data)
    );

    PE_control #(
        .IFMAP_SPAD_AWIDTH(IFMAP_SPAD_AWIDTH),
        .WGHT_SPAD_AWIDTH(WGHT_SPAD_AWIDTH),
        .PSUM_SPAD_AWIDTH(PSUM_SPAD_AWIDTH)
    ) PE_control_inst (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_layer_p(i_layer_p),
        .i_layer_q(i_layer_q),
        .i_layer_s(i_layer_s),
        .i_opcode(i_opcode),
        .i_opcode_valid(i_opcode_valid),
        .o_opcode_ready(o_opcode_ready),

        .i_ifmap_fifo_valid(ifmap_valid_fifo2ctrl),
        .i_wght_fifo_valid(wght_valid_fifo2ctrl),
        .i_psum_in_fifo_valid(psum_in_valid_fifo2ctrl),
        .i_psum_out_fifo_ready(psum_out_ready_fifo2ctrl),
        .o_ifmap_fifo_ready(ifmap_ready_ctrl2fifo),
        .o_wght_fifo_ready(wght_ready_ctrl2fifo),
        .o_psum_in_fifo_ready(psum_in_ready_ctrl2fifo),
        .o_psum_out_fifo_valid(psum_out_valid_ctrl2fifo),

        .i_psum_out_valid(psum_out_valid_datapath2ctrl),
        .o_ifmap_spad_addr(ifmap_spad_addr_ctrl2datapath),
        .o_wght_spad_addr(wght_spad_addr_ctrl2datapath),
        .o_psum_spad_addr(psum_spad_addr_ctrl2datapath),
        .o_ifmap_spad_we(ifmap_we_ctrl2datapath),
        .o_wght_spad_we(wght_we_ctrl2datapath),
        .o_psum_spad_we(psum_we_ctrl2datapath),
        .o_acc_sel(acc_sel_ctrl2datapath),
        .o_rst_psum(rst_psum_ctrl2datapath)
    );

    PE_datapath #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .IFMAP_SPAD_AWIDTH(IFMAP_SPAD_AWIDTH),
        .WGHT_SPAD_AWIDTH(WGHT_SPAD_AWIDTH),
        .PSUM_SPAD_AWIDTH(PSUM_SPAD_AWIDTH)
    ) PE_datapath_inst (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_ifmap_data(ifmap_data_fifo2datapath),
        .i_wght_data(wght_data_fifo2datapath),
        .i_psum_data(psum_in_data_fifo2datapath),
        .o_psum_data(psum_out_data_datapath2fifo),

        .i_acc_sel(acc_sel_ctrl2datapath),
        .i_rst_psum(rst_psum_ctrl2datapath),

        .i_ifmap_spad_addr(ifmap_spad_addr_ctrl2datapath),
        .i_wght_spad_addr(wght_spad_addr_ctrl2datapath),
        .i_psum_spad_addr(psum_spad_addr_ctrl2datapath),

        .i_ifmap_spad_we(ifmap_we_ctrl2datapath),
        .i_wght_spad_we(wght_we_ctrl2datapath),
        .i_psum_spad_we(psum_we_ctrl2datapath),

        .o_psum_out_valid(psum_out_valid_datapath2ctrl)
    );

endmodule