`timescale 1ps / 1ps

module eyeriss_wrapper #(
    parameter CONFIG_FILE = "./data/testcase/config.mem",
    parameter BANK_DEPTH = 8192,
    parameter DATA_BITWIDTH = 32,
    parameter NUM_ROWS = 3,
    parameter NUM_COLS = 3,
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
    input i_clk,
    input i_rst,
    input i_core_start,
    output o_core_done
);

    /////////////////////////////////////////////////////////////////////////////
    // Variables
    /////////////////////////////////////////////////////////////////////////////

    // Hypothetical scan chain configuration registers
    // You can replace this with actual scan chain implementation if needed
    // Here we just use a simple RAM to hold the configuration values
    // and assign them to the output wires
    // The configuration values should be loaded before starting the core
    reg [DATA_BITWIDTH-1:0] config_regs [0:30];

    integer i;
    initial begin
        if (CONFIG_FILE != "") begin
        $readmemh(CONFIG_FILE, config_regs);
        end
        else begin
        for (i = 0; i < 32; i = i + 1) begin
            config_regs[i] = 0;
        end
        end
    end

    wire [7:0] layer_HW;
    wire [2:0] layer_U;
    wire [1:0] layer_PAD;
    wire [6:0] layer_m;
    wire [2:0] layer_n;
    wire [4:0] layer_e;
    wire [4:0] layer_p;
    wire [2:0] layer_q;
    wire [2:0] layer_r;
    wire [3:0] layer_s;
    wire [2:0] layer_t;
    wire [NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1:0] ifmap_row_id;
    wire [NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1:0] wght_row_id;
    wire [NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1:0] psum_row_id;
    wire [NUM_ROWS * NUM_COLS * IFMAP_COL_ID_BITWIDTH-1:0] ifmap_col_id;
    wire [NUM_ROWS * NUM_COLS * WGHT_COL_ID_BITWIDTH-1:0] wght_col_id;
    wire [NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1:0] psum_col_id;

    assign layer_HW = config_regs[0][7:0];
    assign layer_U  = config_regs[1][2:0];
    assign layer_PAD= config_regs[2][1:0];
    assign layer_m  = config_regs[3][6:0];
    assign layer_n  = config_regs[4][2:0];
    assign layer_e  = config_regs[5][4:0];
    assign layer_p  = config_regs[6][4:0];
    assign layer_q  = config_regs[7][2:0];
    assign layer_r  = config_regs[8][2:0];
    assign layer_s  = config_regs[9][3:0];
    assign layer_t  = config_regs[10][2:0];
    assign ifmap_row_id = config_regs[11][NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1:0];
    assign wght_row_id  = config_regs[12][NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1:0];
    assign psum_row_id  = config_regs[13][NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1:0];
    assign ifmap_col_id = {config_regs[20][14:0], config_regs[19][29:0], config_regs[18][29:0], config_regs[17][29:0], config_regs[16][29:0], config_regs[15][29:0], config_regs[14][29:0]};
    assign wght_col_id  = {config_regs[25][27:0],config_regs[24],config_regs[23], config_regs[22], config_regs[21]};
    assign psum_col_id  = {config_regs[30][27:0],config_regs[29],config_regs[28], config_regs[27], config_regs[26]};

    //// Interconnects ////

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

    wire [0:NUM_ROWS*NUM_COLS-1] psum_in_sel_ctrl2arr;
    wire [0:NUM_ROWS*NUM_COLS-1] psum_out_sel_ctrl2arr;

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
    wire [DATA_BITWIDTH-1:0] psum_out_data_arr2ctrl;

    // GLB → TOP_ctrl
    wire [DATA_BITWIDTH-1:0] glb_rd_glb2ctrl;

    // TOP_ctrl → GLB
    wire [1:0] glb_bank_sel_ctrl2glb;
    wire glb_en_ctrl2glb;
    wire glb_we_ctrl2glb;
    wire [clogb2(BANK_DEPTH-1)-1:0] glb_addr_ctrl2glb;
    wire [DATA_BITWIDTH-1:0] psum_out_data_ctrl2glb;

    /////////////////////////////////////////////////////////////////////////////
    // Instantiation
    ////////////////////////////////////////////////////////////////////////////

    GLB #(
        .BANK_WIDTH(DATA_BITWIDTH),
        .BANK_DEPTH(BANK_DEPTH)
    ) u_glb (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_bank_sel(glb_bank_sel_ctrl2glb),
        .i_we(glb_we_ctrl2glb),
        .i_addr(glb_addr_ctrl2glb),
        .i_wd(psum_out_data_ctrl2glb),
        .o_rd(glb_rd_glb2ctrl)
    );

    top_ctrl #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .BANK_DEPTH(BANK_DEPTH),
        .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
        .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) u_top_ctrl (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(i_core_start),
        .o_done(o_core_done),
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
        .o_psum_in_sel(psum_in_sel_ctrl2arr),
        .o_psum_out_sel(psum_out_sel_ctrl2arr),
        .o_ifmap_packet(ifmap_packet_ctrl2arr),
        .o_wght_packet(wght_packet_ctrl2arr),
        .o_psum_in_packet(psum_in_packet_ctrl2arr),
        .o_ifmap_valid(ifmap_valid_ctrl2arr),
        .o_wght_valid(wght_valid_ctrl2arr),
        .o_psum_in_valid(psum_in_valid_ctrl2arr),
        .o_psum_out_ready(psum_out_ready_ctrl2arr),
        .i_psum_in_ready(psum_in_ready_arr2ctrl),
        .i_psum_out_valid(psum_out_valid_arr2ctrl),
        .i_psum_out_data(psum_out_data_arr2ctrl),
        .o_psum_out_data(psum_out_data_ctrl2glb),
        .i_glb_rd(glb_rd_glb2ctrl),
        .o_glb_bank_sel(glb_bank_sel_ctrl2glb),
        .o_glb_en(glb_en_ctrl2glb),
        .o_glb_we(glb_we_ctrl2glb),
        .o_glb_addr(glb_addr_ctrl2glb)
    );

    PE_array #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
        .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) u_pe_array (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_layer_p(layer_p),
        .i_layer_q(layer_q),
        .i_layer_s(layer_s),
        .i_inst_data(inst_data_ctrl2arr),
        .i_inst_valid(inst_valid_ctrl2arr),
        .o_inst_ready(inst_ready_arr2ctrl),
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
        .i_psum_in_sel(psum_in_sel_ctrl2arr),
        .i_psum_out_sel(psum_out_sel_ctrl2arr),
        .i_ifmap_packet(ifmap_packet_ctrl2arr),
        .i_wght_packet(wght_packet_ctrl2arr),
        .i_psum_in_packet(psum_in_packet_ctrl2arr),
        .o_psum_out_data(psum_out_data_arr2ctrl),
        .i_ifmap_valid(ifmap_valid_ctrl2arr),
        .i_wght_valid(wght_valid_ctrl2arr),
        .i_psum_in_valid(psum_in_valid_ctrl2arr),
        .i_psum_out_ready(psum_out_ready_ctrl2arr),
        .o_ifmap_ready(ifmap_ready_arr2ctrl),
        .o_wght_ready(wght_ready_arr2ctrl),
        .o_psum_in_ready(psum_in_ready_arr2ctrl),
        .o_psum_out_valid(psum_out_valid_arr2ctrl)
    );

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule