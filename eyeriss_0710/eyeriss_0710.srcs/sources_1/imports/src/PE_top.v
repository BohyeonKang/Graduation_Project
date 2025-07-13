`timescale 1ns / 1ps

module PE_top #(
    parameter DATA_BITWIDTH = 8,
    parameter IFMAP_BUS_BITWIDTH = 8,
    parameter WGHT_BUS_BITWIDTH = 32,
    parameter PSUM_BUS_BITWIDTH = 32,
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
	input [IFMAP_BUS_BITWIDTH-1:0] i_ifmap_fifo_data,
    input i_ifmap_fifo_valid,
    output o_ifmap_fifo_ready,

    input [WGHT_BUS_BITWIDTH-1:0] i_wght_fifo_data,
    input i_wght_fifo_valid,
    output o_wght_fifo_ready,

    input [PSUM_BUS_BITWIDTH-1:0] i_psum_in_fifo_data,
    input i_psum_in_fifo_valid,
    output o_psum_in_fifo_ready,

    output [PSUM_BUS_BITWIDTH-1:0] o_psum_out_fifo_data,
    output o_psum_out_fifo_valid,
    input i_psum_out_fifo_ready
);

    // Local FIFO & PISO, SIPO interface signals

    wire [IFMAP_BUS_BITWIDTH-1:0] ifmap_data_fifo2datapath;
    wire ifmap_valid_fifo2ctrl;
    wire ifmap_ready_ctrl2fifo;

    wire [WGHT_BUS_BITWIDTH-1:0] wght_data_fifo2piso;
    wire wght_valid_fifo2piso;
    wire wght_ready_piso2fifo;

    wire wght_ready_ctrl2piso;
    wire wght_valid_piso2ctrl;
    wire [DATA_BITWIDTH-1:0] wght_data_piso2datapath;

    wire [PSUM_BUS_BITWIDTH-1:0] psum_in_data_fifo2piso;
    wire psum_in_valid_fifo2piso;
    wire psum_in_ready_piso2fifo;

    wire psum_in_ready_ctrl2piso;
    wire psum_in_valid_piso2ctrl;
    wire [DATA_BITWIDTH-1:0] psum_in_data_piso2datapath;

    wire psum_out_valid_datapath2sipo;
    wire [DATA_BITWIDTH-1:0] psum_out_data_datapath2sipo;
    wire psum_out_ready_sipo2ctrl;

    wire [PSUM_BUS_BITWIDTH-1:0] psum_out_data_sipo2fifo;
    wire psum_out_valid_sipo2fifo;
    wire psum_out_ready_fifo2sipo;


    // Local control signals
    wire [IFMAP_ADDR_BITWIDTH-1:0] ifmap_ra_ctrl2datapath, ifmap_wa_ctrl2datapath;
    wire [WGHT_ADDR_BITWIDTH-1:0]  wght_ra_ctrl2datapath, wght_wa_ctrl2datapath;
    wire [PSUM_ADDR_BITWIDTH-1:0]  psum_ra_ctrl2datapath, psum_wa_ctrl2datapath;

    wire ifmap_we_ctrl2datapath, wght_we_ctrl2datapath, psum_we_ctrl2datapath;
    wire acc_sel_ctrl2datapath, rst_psum_ctrl2datapath;

    fifo #(
        .QUEUE_PTR_BANDWIDTH(4),
        .ELE_BANDWIDTH(IFMAP_BUS_BITWIDTH)
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
        .QUEUE_PTR_BANDWIDTH(5),
        .ELE_BANDWIDTH(WGHT_BUS_BITWIDTH)
    ) u_wght_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(i_wght_fifo_data),
        .i_valid(i_wght_fifo_valid),
        .o_ready(o_wght_fifo_ready),

        //FIFO interface as tx
        .i_ready(wght_ready_piso2fifo),         
        .o_valid(wght_valid_fifo2piso),
        .o_pop_data(wght_data_fifo2piso)
    );

    PISO_32to8 u_wght_piso (
        .i_clk    (i_clk),  
        .i_rst    (i_rst),  

        .i_data   (wght_data_fifo2piso), 
        .i_valid  (wght_valid_fifo2piso),
        .o_ready  (wght_ready_piso2fifo),

        .i_ready  (wght_ready_ctrl2piso),
        .o_valid  (wght_valid_piso2ctrl),
        .o_data   (wght_data_piso2datapath)  
    );

    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(PSUM_BUS_BITWIDTH)
    ) u_psum_in_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(i_psum_in_fifo_data),
        .i_valid(i_psum_in_fifo_valid),
        .o_ready(o_psum_in_fifo_ready),

        //FIFO interface as tx
        .i_ready(psum_in_ready_piso2fifo),         
        .o_valid(psum_in_valid_fifo2piso),
        .o_pop_data(psum_in_data_fifo2piso)
    );

    PISO_32to8 u_psum_piso (
        .i_clk    (i_clk),  
        .i_rst    (i_rst),  

        .i_data   (psum_in_data_fifo2piso), 
        .i_valid  (psum_in_valid_fifo2piso),
        .o_ready  (psum_in_ready_piso2fifo),

        .i_ready  (psum_in_ready_ctrl2piso),
        .o_valid  (psum_in_valid_piso2ctrl),
        .o_data   (psum_in_data_piso2datapath)   
    );


    fifo #(
        .QUEUE_PTR_BANDWIDTH(),
        .ELE_BANDWIDTH(PSUM_BUS_BITWIDTH)
    ) u_psum_out_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),

        //FIFO interface as rx
        .i_push_data(psum_out_data_sipo2fifo),
        .i_valid(psum_out_valid_sipo2fifo),
        .o_ready(psum_out_ready_fifo2sipo),

        //FIFO interface as tx
        .i_ready(i_psum_out_fifo_ready),
        .o_valid(o_psum_out_fifo_valid),
        .o_pop_data(o_psum_out_fifo_data)
    );

    SIPO_8to32 u_sipo_8to32 (
        .i_clk    (i_clk),      // 클럭
        .i_rst    (i_rst),      // 리셋

        .i_flush  (o_inst_ready),

        // 직렬 입력 인터페이스 (rx)
        .i_valid  (psum_out_valid_datapath2sipo),    // 입력 데이터 유효
        .i_data   (psum_out_data_datapath2sipo),     // 8비트 입력
        .o_ready  (psum_out_ready_sipo2ctrl),    // 입력 수신 가능

        // 병렬 출력 인터페이스 (tx)
        .i_ready  (psum_out_ready_fifo2sipo),    // 출력 수신 가능
        .o_valid  (psum_out_valid_sipo2fifo),    // 출력 데이터 유효
        .o_data   (psum_out_data_sipo2fifo)      // 32비트 병렬 출력
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
        .i_wght_piso_valid(wght_valid_piso2ctrl),
        .o_wght_piso_ready(wght_ready_ctrl2piso),
        .i_psum_in_piso_valid(psum_in_valid_piso2ctrl),
        .o_psum_in_piso_ready(psum_in_ready_ctrl2piso),
        .i_psum_out_sipo_ready(psum_out_ready_sipo2ctrl),

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
        .i_wght_data(wght_data_piso2datapath),
        .i_psum_data(psum_in_data_piso2datapath),
        .o_psum_data(psum_out_data_datapath2sipo),

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
        .o_psum_out_valid(psum_out_valid_datapath2sipo)
    );

endmodule