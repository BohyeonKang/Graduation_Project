
`timescale 1ns / 1ps

module tb_TOP_ctrl();

    // Parameters
    parameter INST_BRAM_DEPTH = 64;
    parameter INST_BRAM_ADDR_WIDTH = $clog2(INST_BRAM_DEPTH);
    parameter DATA_BITWIDTH = 32;
    parameter ROW_LEN = 3;
    parameter COL_LEN = 3;
    parameter BANK_NUM = 3;
    parameter BANK_DEPTH = 512;
    parameter IFMAP_ROW_ID_BITWIDTH = 4;
    parameter WGHT_ROW_ID_BITWIDTH = 4;
    parameter PSUM_ROW_ID_BITWIDTH = 4;
    parameter IFMAP_COL_ID_BITWIDTH = 5;
    parameter WGHT_COL_ID_BITWIDTH = 4;
    parameter PSUM_COL_ID_BITWIDTH = 4;
    parameter IFMAP_BUS_BITWIDTH = 32;
    parameter WGHT_BUS_BITWIDTH = 32;
    parameter PSUM_BUS_BITWIDTH = 32;

    // Inputs
    reg i_clk;
    reg i_rst;
    reg [0:3*clogb2(BANK_NUM)-1] i_GLB_allocation;

    reg [3:0] i_pass_num;
    reg [7:0] i_layer_HW;
    reg [9:0] i_layer_C;
    reg [1:0] i_layer_U;
    reg [3:0] i_layer_RS;
    reg [6:0] i_layer_EF;
    reg [1:0] i_layer_PAD;
    reg [3:0] i_layer_m;
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

    wire [INST_BRAM_ADDR_WIDTH-1:0] o_inst_bram_ra;
    reg  [DATA_BITWIDTH-1:0] i_inst_bram_rd;
    wire [INST_BRAM_ADDR_WIDTH-1:0] o_inst_bram_wa;
    wire [DATA_BITWIDTH-1:0] o_inst_bram_wd;
    wire o_inst_bram_we;

    wire [2:0] o_inst_data;
    wire [8:0] o_conv_info;
    wire o_inst_valid;
    reg  i_inst_ready;

    wire [0:IFMAP_ROW_ID_BITWIDTH * COL_LEN-1] o_ifmap_row_id;
    wire [0:WGHT_ROW_ID_BITWIDTH * COL_LEN-1] o_wght_row_id;
    wire [0:PSUM_ROW_ID_BITWIDTH * COL_LEN-1] o_psum_row_id;
    wire o_ifmap_row_id_valid;
    wire o_wght_row_id_valid;
    wire o_psum_row_id_valid;

    wire [0:IFMAP_COL_ID_BITWIDTH*ROW_LEN-1] o_ifmap_col_id;
    wire [0:WGHT_COL_ID_BITWIDTH*ROW_LEN-1] o_wght_col_id;
    wire [0:PSUM_COL_ID_BITWIDTH*ROW_LEN-1] o_psum_col_id;
    wire [0:COL_LEN-1] o_ifmap_col_id_valid;
    wire [0:COL_LEN-1] o_wght_col_id_valid;
    wire [0:COL_LEN-1] o_psum_col_id_valid;

    wire [0:COL_LEN*ROW_LEN-1] o_ctrl_psum_in_sel_LNorGIN;
    wire [0:COL_LEN*ROW_LEN-1] o_ctrl_psum_out_sel_GON;

    wire [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH - 1:0] o_ifmap_packet;
    wire [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH - 1:0] o_wght_packet;
    wire [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH - 1:0] o_psum_in_packet;

    wire o_ifmap_valid;
    wire o_wght_valid;
    wire o_psum_in_valid;
    wire o_psum_out_ready;

    reg  i_ifmap_ready;
    reg  i_wght_ready;
    reg  i_psum_in_ready;
    reg  i_psum_out_valid;

    wire [DATA_BITWIDTH-1:0] glb_rd;
    wire [clogb2(BANK_NUM-1)-1:0] o_glb_bank_sel;
    wire o_glb_re;
    wire o_glb_we;
    wire [clogb2(BANK_DEPTH-1)-1:0] o_glb_ra;
    wire [clogb2(BANK_DEPTH-1)-1:0] o_glb_wa;

    GLB #(
        .DATA_BITWIDTH (DATA_BITWIDTH),
        .BANK_NUM      (BANK_NUM),
        .BANK_DEPTH    (BANK_DEPTH)
    ) u_GLB (
        .i_clk      (i_clk),  // clock
        .i_rst      (i_rst),  // reset
        .i_bank_sel (o_glb_bank_sel),  // [clogb2(BANK_NUM-1)-1:0]
        .i_re       (o_glb_re),  // read enable
        .i_we       (1'b0),  // write enable
        .i_ra       (o_glb_ra),  // [clogb2(BANK_DEPTH-1)-1:0] read addr
        .i_wa       (o_glb_wa),  // [clogb2(BANK_DEPTH-1)-1:0] write addr
        .i_wd       (1'b0),  // [DATA_BITWIDTH-1:0] write data
        .o_rd       (glb_rd)   // [DATA_BITWIDTH-1:0] read data
    );

    TOP_ctrl dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_GLB_allocation(i_GLB_allocation),
        .i_pass_num(i_pass_num),
        .i_layer_C(i_layer_C),
        .i_layer_HW(i_layer_HW),
        .i_layer_U(i_layer_U),
        .i_layer_RS(i_layer_RS),
        .i_layer_EF(i_layer_EF),
        .i_layer_PAD(i_layer_PAD),
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
        .o_inst_data(o_inst_data),
        .o_conv_info(o_conv_info),
        .o_inst_valid(o_inst_valid),
        .i_inst_ready(i_inst_ready),
        .o_ifmap_row_id(o_ifmap_row_id),
        .o_wght_row_id(o_wght_row_id),
        .o_psum_row_id(o_psum_row_id),
        .o_ifmap_row_id_valid(o_ifmap_row_id_valid),
        .o_wght_row_id_valid(o_wght_row_id_valid),
        .o_psum_row_id_valid(o_psum_row_id_valid),
        .o_ifmap_col_id(o_ifmap_col_id),
        .o_wght_col_id(o_wght_col_id),
        .o_psum_col_id(o_psum_col_id),
        .o_ifmap_col_id_valid(o_ifmap_col_id_valid),
        .o_wght_col_id_valid(o_wght_col_id_valid),
        .o_psum_col_id_valid(o_psum_col_id_valid),
        .o_ctrl_psum_in_sel_LNorGIN(o_ctrl_psum_in_sel_LNorGIN),
        .o_ctrl_psum_out_sel_GON(o_ctrl_psum_out_sel_GON),
        .o_ifmap_packet(o_ifmap_packet),
        .o_wght_packet(o_wght_packet),
        .o_psum_in_packet(o_psum_in_packet),
        .o_ifmap_valid(o_ifmap_valid),
        .o_wght_valid(o_wght_valid),
        .o_psum_in_valid(o_psum_in_valid),
        .o_psum_out_ready(o_psum_out_ready),
        .i_ifmap_ready(i_ifmap_ready),
        .i_wght_ready(i_wght_ready),
        .i_psum_in_ready(i_psum_in_ready),
        .i_psum_out_valid(i_psum_out_valid),
        .i_glb_rd(glb_rd),
        .o_glb_bank_sel(o_glb_bank_sel),
        .o_glb_re(o_glb_re),
        .o_glb_we(o_glb_we),
        .o_glb_ra(o_glb_ra),
        .o_glb_wa(o_glb_wa)
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
        $readmemh("weight.mem", u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM);
        $readmemh("psum_init.mem", u_GLB.gen_GLB_BANKS[2].glb_bank_inst.BRAM);
        // Initialize Inputs
        i_clk = 0;
        i_rst = 1;
        i_GLB_allocation = {2'd1,2'b1,2'b1};
        i_pass_num = 4'd1;
        i_layer_C = 10'd5;
        i_layer_HW = 8'd5;
        i_layer_U = 2'd1;
        i_layer_RS = 4'd3;
        i_layer_EF = 7'd3;
        i_layer_PAD = 2'd0;
        i_layer_m = 4'd1;
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
        i_inst_ready = 1'b1;
        i_ifmap_ready = 1'b1;
        i_wght_ready = 1'b1;
        i_psum_in_ready = 1'b1;
        i_psum_out_valid = 1'b0;

        repeat (10) @(posedge i_clk); #1;
        i_rst = 0;
        i_inst_bram_rd = 32'd1;
        

        // Simulate for some time
        wait(dut.state == 4'd10) $finish;
    end

endmodule
