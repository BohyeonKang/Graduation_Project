
`timescale 1ns / 1ps

module tb_eyeriss();

    parameter INST_BRAM_DEPTH = 64;
    parameter INST_BRAM_ADDR_WIDTH = $clog2(INST_BRAM_DEPTH);

    parameter BANK_NUM = 3;
    parameter BANK_DEPTH = 512;

    parameter DATA_BITWIDTH = 32;
    parameter ROW_LEN = 3;
    parameter COL_LEN = 3;
    parameter IFMAP_ROW_ID_BITWIDTH = 4;
    parameter WGHT_ROW_ID_BITWIDTH = 4;
    parameter PSUM_ROW_ID_BITWIDTH = 4;
    parameter IFMAP_COL_ID_BITWIDTH = 5;
    parameter WGHT_COL_ID_BITWIDTH = 4;
    parameter PSUM_COL_ID_BITWIDTH = 4;
    parameter IFMAP_BUS_BITWIDTH = 32;
    parameter WGHT_BUS_BITWIDTH = 32;
    parameter PSUM_BUS_BITWIDTH = 32;

    reg i_clk;
    reg i_rst;

    //// hypothetical signals from scan chain configuration ////

    reg [0:3*clogb2(BANK_NUM)-1] i_GLB_allocation;
    reg [3:0] i_total_pass;
    reg [7:0] i_layer_HW;
    reg [3:0] i_layer_RS;
    reg [6:0] i_layer_EF;
    reg [9:0] i_layer_C;
    reg [8:0] i_layer_M;
    reg [1:0] i_layer_U;
    reg [1:0] i_layer_PAD;
    reg [6:0] i_layer_m;
    reg [2:0] i_layer_n;
    reg [4:0] i_layer_e;
    reg [3:0] i_layer_p;
    reg [2:0] i_layer_q;
    reg [2:0] i_layer_r;
    reg [2:0] i_layer_t;
    reg [0:COL_LEN * IFMAP_ROW_ID_BITWIDTH-1] i_ifmap_row_id;
    reg [0:COL_LEN * WGHT_ROW_ID_BITWIDTH-1] i_wght_row_id;
    reg [0:COL_LEN * PSUM_ROW_ID_BITWIDTH-1] i_psum_row_id;
    reg [0:COL_LEN * ROW_LEN * IFMAP_COL_ID_BITWIDTH-1] i_ifmap_col_id;
    reg [0:COL_LEN * ROW_LEN * WGHT_COL_ID_BITWIDTH-1] i_wght_col_id;
    reg [0:COL_LEN * ROW_LEN * PSUM_COL_ID_BITWIDTH-1] i_psum_col_id;

    reg  [DATA_BITWIDTH-1:0] i_inst_bram_rd;
    wire [INST_BRAM_ADDR_WIDTH-1:0] o_inst_bram_ra;
    wire [INST_BRAM_ADDR_WIDTH-1:0] o_inst_bram_wa;
    wire [DATA_BITWIDTH-1:0] o_inst_bram_wd;
    wire o_inst_bram_we;

    //// Interconnects ////

    // TOP_ctrl → PE_array
    wire [2:0] inst_data_ctrl2arr;
    wire [10:0] conv_info_ctrl2arr;
    wire       inst_valid_ctrl2arr;

    wire [0:IFMAP_ROW_ID_BITWIDTH * COL_LEN-1] ifmap_row_id_ctrl2arr;
    wire [0:WGHT_ROW_ID_BITWIDTH * COL_LEN-1]  wght_row_id_ctrl2arr;
    wire [0:PSUM_ROW_ID_BITWIDTH * COL_LEN-1]  psum_row_id_ctrl2arr;

    wire ifmap_row_id_valid_ctrl2arr;
    wire wght_row_id_valid_ctrl2arr;
    wire psum_row_id_valid_ctrl2arr;

    wire [0:IFMAP_COL_ID_BITWIDTH * ROW_LEN-1] ifmap_col_id_ctrl2arr;
    wire [0:WGHT_COL_ID_BITWIDTH * ROW_LEN-1]  wght_col_id_ctrl2arr;
    wire [0:PSUM_COL_ID_BITWIDTH * ROW_LEN-1]  psum_col_id_ctrl2arr;

    wire [0:COL_LEN-1] ifmap_col_id_valid_ctrl2arr;
    wire [0:COL_LEN-1] wght_col_id_valid_ctrl2arr;
    wire [0:COL_LEN-1] psum_col_id_valid_ctrl2arr;

    wire [0:COL_LEN*ROW_LEN-1] ctrl_psum_in_sel_LNorGIN_ctrl2arr;
    wire [0:COL_LEN*ROW_LEN-1] ctrl_psum_out_sel_GON_ctrl2arr;

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


    GLB #(
        .DATA_BITWIDTH (DATA_BITWIDTH),
        .BANK_NUM      (BANK_NUM),
        .BANK_DEPTH    (BANK_DEPTH)
    ) u_GLB (
        .i_clk      (i_clk),  // clock
        .i_rst      (i_rst),  // reset
        .i_bank_sel (glb_bank_sel_ctrl2glb),  // [clogb2(BANK_NUM-1)-1:0]
        .i_re       (glb_re_ctrl2glb),  // read enable
        .i_we       (glb_we_ctrl2glb),  // write enable
        .i_ra       (glb_ra_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] read addr
        .i_wa       (glb_wa_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] write addr
        .i_wd       (psum_out_data_arr2glb),  // [DATA_BITWIDTH-1:0] write data
        .o_rd       (glb_rd_glb2ctrl)   // [DATA_BITWIDTH-1:0] read data
    );

    TOP_ctrl u_top_ctrl (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_GLB_allocation(i_GLB_allocation),
        .i_total_pass(i_total_pass),
        .i_layer_C(i_layer_C),
        .i_layer_HW(i_layer_HW),
        .i_layer_U(i_layer_U),
        .i_layer_RS(i_layer_RS),
        .i_layer_EF(i_layer_EF),
        .i_layer_PAD(i_layer_PAD),
        .i_layer_M(i_layer_M),
        .i_layer_n(i_layer_n),
        .i_layer_m(i_layer_m),
        .i_layer_e(i_layer_e),
        .i_layer_p(i_layer_p),
        .i_layer_q(i_layer_q),
        .i_layer_r(i_layer_r),
        .i_layer_t(i_layer_t),
        .i_ifmap_row_id(i_ifmap_row_id),
        .i_wght_row_id(i_wght_row_id),
        .i_psum_row_id(i_psum_row_id),
        .i_ifmap_col_id(i_ifmap_col_id),
        .i_wght_col_id(i_wght_col_id),
        .i_psum_col_id(i_psum_col_id),
        .o_inst_bram_ra(o_inst_bram_ra),
        .i_inst_bram_rd(i_inst_bram_rd),
        .o_inst_bram_wa(o_inst_bram_wa),
        .o_inst_bram_wd(o_inst_bram_wd),
        .o_inst_bram_we(o_inst_bram_we),
        .o_inst_data(inst_data_ctrl2arr),
        .o_conv_info(conv_info_ctrl2arr),
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

    PE_array #(
        .ROW_LEN(ROW_LEN),
        .COL_LEN(COL_LEN),
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
        .i_conv_info(conv_info_ctrl2arr),
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

        .i_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN_ctrl2arr),
        .i_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON_ctrl2arr),

        // GLB interface
        .i_ifmap_packet(ifmap_packet_ctrl2arr),
        .i_wght_packet(wght_packet_ctrl2arr),
        .i_psum_in_packet(psum_in_packet_ctrl2arr),
        .o_psum_out_data(o_psum_out_data),

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

    // Clock generation
    always #5 i_clk = ~i_clk;

    initial begin
        $readmemh("ifmap.mem", u_GLB.gen_GLB_BANKS[0].glb_bank_inst.BRAM);
        $readmemh("psum_init.mem", u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM);
        $readmemh("weight.mem", u_GLB.gen_GLB_BANKS[2].glb_bank_inst.BRAM);
        // Initialize Inputs
        i_clk = 0;
        i_rst = 1;

        i_GLB_allocation = {2'd1,2'b1,2'b1};
        i_total_pass = 4'd1;

        i_layer_HW = 8'd5;
        i_layer_RS = 4'd3;
        i_layer_EF = 7'd3;
        i_layer_C = 10'd5;
        i_layer_M = 9'd4;
        i_layer_U = 2'd1;
        i_layer_PAD = 2'd0;

        i_layer_m = 7'd4;
        i_layer_n = 3'd1;
        i_layer_e = 5'd3;
        i_layer_p = 4'd4;
        i_layer_q = 3'd5;
        i_layer_r = 2'd1;
        i_layer_t = 2'd1;
        i_ifmap_row_id = {4'd1, 4'd1, 4'd1};
        i_wght_row_id = {4'd1, 4'd2, 4'd3};
        i_psum_row_id = {4'd1, 4'd2, 4'd3};
        i_ifmap_col_id = {{5'd1, 5'd2, 5'd3}, {5'd2, 5'd3, 5'd4}, {5'd3, 5'd4, 5'd5}};
        i_wght_col_id = {{4'd1, 4'd1, 4'd1}, {4'd1, 4'd1, 4'd1}, {4'd1, 4'd1, 4'd1}};
        i_psum_col_id = {{4'd1, 4'd1, 4'd1}, {4'd1, 4'd1, 4'd1}, {4'd1, 4'd1, 4'd1}};

        i_inst_bram_rd = 32'hDEADBEEF;

        repeat (10) @(posedge i_clk); #1;
        i_rst = 0;
        i_inst_bram_rd = 32'd1;

        wait(u_top_ctrl.state == 4'd10) $finish;
    end

endmodule
