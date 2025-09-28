// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1ps / 1ps

module eyeriss_wrapper #(
  parameter BANK_NUM = 3,
  parameter BANK_DEPTH = 8192,
  parameter DATA_BITWIDTH = 32,
  parameter NUM_ROWS = 3,
  parameter NUM_COLS = 13,
  parameter IFMAP_ROW_ID_BITWIDTH = 4,
  parameter WGHT_ROW_ID_BITWIDTH = 4,
  parameter PSUM_ROW_ID_BITWIDTH = 4,
  parameter IFMAP_COL_ID_BITWIDTH = 5,
  parameter WGHT_COL_ID_BITWIDTH = 4,
  parameter PSUM_COL_ID_BITWIDTH = 4,
  parameter IFMAP_BUS_BITWIDTH = 32,
  parameter WGHT_BUS_BITWIDTH = 32,
  parameter PSUM_BUS_BITWIDTH = 32
)(
  input wire i_clk,
  input wire i_rst,
  input wire i_core_start,
  output wire o_core_done
);

/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////

// Config signals from BRAM to Core Top_ctrl
wire [5:0] GLB_allocation;
wire [3:0] total_pass;
wire [7:0] layer_HW;
wire [1:0] layer_U;
wire [1:0] layer_PAD;
wire [6:0] layer_m;
wire [2:0] layer_n;
wire [4:0] layer_e;
wire [4:0] layer_p;
wire [2:0] layer_q;
wire [2:0] layer_r;
wire [3:0] layer_s;
wire [2:0] layer_t;
wire [11:0] ifmap_row_id;
wire [11:0] wght_row_id;
wire [11:0] psum_row_id;
wire [194:0] ifmap_col_id;
wire [155:0] wght_col_id;
wire [155:0] psum_col_id;

// TOP_ctrl → PE_array
wire [2:0] inst_data_ctrl2arr;
wire       inst_valid_ctrl2arr;

wire [0:IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1] ifmap_row_id_ctrl2arr;
wire [0:WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1]  wght_row_id_ctrl2arr;
wire [0:PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1]  psum_row_id_ctrl2arr;

wire ifmap_row_id_valid_ctrl2arr;
wire wght_row_id_valid_ctrl2arr;
wire psum_row_id_valid_ctrl2arr;

wire [0:IFMAP_COL_ID_BITWIDTH * NUM_COLS-1] ifmap_col_id_ctrl2arr;
wire [0:WGHT_COL_ID_BITWIDTH * NUM_COLS-1]  wght_col_id_ctrl2arr;
wire [0:PSUM_COL_ID_BITWIDTH * NUM_COLS-1]  psum_col_id_ctrl2arr;

wire [0:NUM_ROWS-1] ifmap_col_id_valid_ctrl2arr;
wire [0:NUM_ROWS-1] wght_col_id_valid_ctrl2arr;
wire [0:NUM_ROWS-1] psum_col_id_valid_ctrl2arr;

wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_in_sel_LNorGIN_ctrl2arr;
wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_out_sel_GON_ctrl2arr;

wire [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1:0] ifmap_packet_ctrl2arr;
wire [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1:0] wght_packet_ctrl2arr;
wire [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1:0] psum_in_packet_ctrl2arr;

wire ifmap_valid_ctrl2arr;
wire wght_valid_ctrl2arr;
wire psum_in_valid_ctrl2arr;
wire psum_out_ready_ctrl2arr;

// PE_array → TOP_ctrl
wire inst_ready_arr2ctrl;
wire ifmap_ready_arr2ctrl;
wire wght_ready_arr2ctrl;
wire psum_in_ready_arr2ctrl;
wire psum_out_valid_arr2ctrl;

// GLB → TOP_ctrl
wire [DATA_BITWIDTH-1:0] glb_rd_glb2ctrl;

// TOP_ctrl → GLB
wire [clogb2(BANK_NUM-1)-1:0] glb_bank_sel_ctrl2glb;
wire glb_re_ctrl2glb;
wire glb_we_ctrl2glb;
wire [clogb2(BANK_DEPTH-1)-1:0] glb_ra_ctrl2glb;
wire [clogb2(BANK_DEPTH-1)-1:0] glb_wa_ctrl2glb;

// PE_array → GLB
wire [DATA_BITWIDTH-1:0] psum_out_data_arr2glb;

reg [15:0] addra, addra_reg;

wire ifmap_bank_select = (glb_bank_sel_ctrl2glb == 0);
wire psum_bank_select = (glb_bank_sel_ctrl2glb == 1);
wire wght_bank_select = (glb_bank_sel_ctrl2glb == 2);

wire [DATA_BITWIDTH-1:0] glb_ifmap_rd;
wire [DATA_BITWIDTH-1:0] glb_wght_rd;
wire [DATA_BITWIDTH-1:0] glb_psum_rd;

/////////////////////////////////////////////////////////////////////////////
// Instantiation
////////////////////////////////////////////////////////////////////////////

true_dpbram_config #(
  .RAM_WIDTH(DATA_BITWIDTH),
  .RAM_DEPTH(64),
  .RAM_PERFORMANCE("LOW_LATENCY"),
  .INIT_FILE("pe_set_config.mem")
) u_config_bram (
  .addra('b0),
  .addrb('b0),
  .dina('b0),
  .dinb('b0),
  .clka(i_clk),
  .clkb(i_clk),
  .wea('b0),
  .web('b0),
  .ena('b0),
  .enb('b0),
  .rsta(i_rst),
  .rstb(i_rst),
  .regcea('b0),
  .regceb('b0),
  .douta(),
  .doutb(),

  .GLB_allocation(GLB_allocation),
  .total_pass(total_pass),
  .layer_HW(layer_HW),
  .layer_U(layer_U),
  .layer_PAD(layer_PAD),
  .layer_m(layer_m),
  .layer_n(layer_n),
  .layer_e(layer_e),
  .layer_p(layer_p),
  .layer_q(layer_q),
  .layer_r(layer_r),
  .layer_s(layer_s),
  .layer_t(layer_t),
  .ifmap_row_id(ifmap_row_id),
  .wght_row_id(wght_row_id),
  .psum_row_id(psum_row_id),
  .ifmap_col_id(ifmap_col_id),
  .wght_col_id(wght_col_id),
  .psum_col_id(psum_col_id)
);


TOP_ctrl #(
  .DATA_BITWIDTH(DATA_BITWIDTH),
  .NUM_ROWS(NUM_ROWS),
  .NUM_COLS(NUM_COLS),
  .BANK_NUM(BANK_NUM),
  .BANK_DEPTH(BANK_DEPTH),
  .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
  .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
  .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
  .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
  .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
  .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
  .IFMAP_BUS_BITWIDTH(IFMAP_BUS_BITWIDTH),
  .WGHT_BUS_BITWIDTH(WGHT_BUS_BITWIDTH),
  .PSUM_BUS_BITWIDTH(PSUM_BUS_BITWIDTH)
) top_ctrl_inst (
  .i_clk(i_clk),
  .i_rst(i_rst),
  .i_ap_start(i_core_start),
  .o_ap_done(o_core_done),
  .i_GLB_allocation(GLB_allocation),
  .i_total_pass(total_pass),
  .i_layer_HW(layer_HW),
  .i_layer_U(layer_U),
  .i_layer_PAD(layer_PAD),
  .i_layer_m(layer_m),
  .i_layer_n(layer_n),
  .i_layer_e(layer_e),
  .i_layer_p(layer_p),
  .i_layer_q(layer_q),
  .i_layer_r(layer_r),
  .i_layer_s(layer_s),
  .i_layer_t(layer_t),
  .i_ifmap_row_id(ifmap_row_id),
  .i_wght_row_id(wght_row_id),
  .i_psum_row_id(psum_row_id),
  .i_ifmap_col_id(ifmap_col_id),
  .i_wght_col_id(wght_col_id),
  .i_psum_col_id(psum_col_id),
  .o_inst_data(inst_data_ctrl2arr),
  .o_inst_valid(inst_valid_ctrl2arr),
  .i_inst_ready(inst_ready_arr2ctrl),
  .o_ifmap_row_id(ifmap_row_id_ctrl2arr),
  .o_wght_row_id(wght_row_id_ctrl2arr),
  .o_psum_row_id(psum_row_id_ctrl2arr),
  .o_ifmap_row_id_valid(ifmap_row_id_valid_ctrl2arr),
  .o_wght_row_id_valid(wght_row_id_valid_ctrl2arr),
  .o_psum_row_id_valid(psum_row_id_valid_ctrl2arr),
  .o_ifmap_col_id(ifmap_col_id_ctrl2arr),
  .o_wght_col_id(wght_col_id_ctrl2arr),
  .o_psum_col_id(psum_col_id_ctrl2arr),
  .o_ifmap_col_id_valid(ifmap_col_id_valid_ctrl2arr),
  .o_wght_col_id_valid(wght_col_id_valid_ctrl2arr),
  .o_psum_col_id_valid(psum_col_id_valid_ctrl2arr),
  .o_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN_ctrl2arr),
  .o_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON_ctrl2arr),
  .o_ifmap_packet(ifmap_packet_ctrl2arr),
  .o_wght_packet(wght_packet_ctrl2arr),
  .o_psum_in_packet(psum_in_packet_ctrl2arr),
  .o_ifmap_valid(ifmap_valid_ctrl2arr),
  .o_wght_valid(wght_valid_ctrl2arr),
  .o_psum_in_valid(psum_in_valid_ctrl2arr),
  .o_psum_out_ready(psum_out_ready_ctrl2arr),
  .i_ifmap_ready(ifmap_ready_arr2ctrl),
  .i_wght_ready(wght_ready_arr2ctrl),
  .i_psum_in_ready(psum_in_ready_arr2ctrl),
  .i_psum_out_valid(psum_out_valid_arr2ctrl),
  .i_glb_rd(glb_rd_glb2ctrl),
  .o_glb_bank_sel(glb_bank_sel_ctrl2glb),
  .o_glb_re(glb_re_ctrl2glb),
  .o_glb_we(glb_we_ctrl2glb),
  .o_glb_ra(glb_ra_ctrl2glb),
  .o_glb_wa(glb_wa_ctrl2glb)
);

GLB #(
  .DATA_BITWIDTH(32),
  .BANK_NUM(3),
  .BANK_DEPTH(8192)
) glb_inst (
  .i_clk(i_clk),
  .i_rst(i_rst),
  .i_bank_sel (glb_bank_sel_ctrl2glb),  // [clogb2(BANK_NUM-1)-1:0]
  .i_re       (glb_re_ctrl2glb),  // read enable
  .i_we       (glb_we_ctrl2glb),  // write enable
  .i_ra       (glb_ra_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] read addr
  .i_wa       (glb_wa_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] write addr
  .i_wd       (psum_out_data_arr2glb),  // [DATA_BITWIDTH-1:0] write data
  .o_rd       (glb_rd_glb2ctrl)   // [DATA_BITWIDTH-1:0] read data
);

PE_array #(
    .NUM_ROWS(NUM_ROWS),
    .NUM_COLS(NUM_COLS),
    .DATA_BITWIDTH(DATA_BITWIDTH),

    .IFMAP_BUS_BITWIDTH(IFMAP_BUS_BITWIDTH),
    .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
    .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),

    .WGHT_BUS_BITWIDTH(WGHT_BUS_BITWIDTH),
    .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
    .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),

    .PSUM_BUS_BITWIDTH(PSUM_BUS_BITWIDTH),
    .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
    .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
) u_PE_array (
    .i_clk(i_clk),
    .i_rst(i_rst),

    // TOP CTRL interface
    .i_inst_data(inst_data_ctrl2arr),
    .i_inst_valid(inst_valid_ctrl2arr),
    .o_inst_ready(inst_ready_arr2ctrl),
    .i_layer_p(layer_p),
    .i_layer_q(layer_q),
    .i_layer_s(layer_s),

    .i_ifmap_row_id(ifmap_row_id_ctrl2arr),
    .i_wght_row_id(wght_row_id_ctrl2arr),
    .i_psum_row_id(psum_row_id_ctrl2arr),

    .i_ifmap_row_id_valid(ifmap_row_id_valid_ctrl2arr),
    .i_wght_row_id_valid(wght_row_id_valid_ctrl2arr),
    .i_psum_row_id_valid(psum_row_id_valid_ctrl2arr),

    .i_ifmap_col_id(ifmap_col_id_ctrl2arr),
    .i_wght_col_id(wght_col_id_ctrl2arr),
    .i_psum_col_id(psum_col_id_ctrl2arr),

    .i_ifmap_col_id_valid(ifmap_col_id_valid_ctrl2arr),
    .i_wght_col_id_valid(wght_col_id_valid_ctrl2arr),
    .i_psum_col_id_valid(psum_col_id_valid_ctrl2arr),

    .i_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN_ctrl2arr),
    .i_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON_ctrl2arr),

    // GLB interface
    .i_ifmap_packet(ifmap_packet_ctrl2arr),
    .i_wght_packet(wght_packet_ctrl2arr),
    .i_psum_in_packet(psum_in_packet_ctrl2arr),
    .o_psum_out_data(psum_out_data_arr2glb),

    .i_ifmap_valid(ifmap_valid_ctrl2arr),
    .i_wght_valid(wght_valid_ctrl2arr),
    .i_psum_in_valid(psum_in_valid_ctrl2arr),
    .i_psum_out_ready(psum_out_ready_ctrl2arr),

    .o_ifmap_ready(ifmap_ready_arr2ctrl),
    .o_wght_ready(wght_ready_arr2ctrl),
    .o_psum_in_ready(psum_in_ready_arr2ctrl),
    .o_psum_out_valid(psum_out_valid_arr2ctrl)
);

/////////////////////////////////////////////////////////////////////////////
// RTL Logic
/////////////////////////////////////////////////////////////////////////////

function integer clogb2;
    input integer depth;
    begin
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    end
endfunction

endmodule

`default_nettype wire