`timescale 1ns / 1ps

module tb_PE_array;

    parameter COL_LEN = 3;
	parameter ROW_LEN = 3;

	parameter IFMAP_ROW_ID_BITWIDTH = 4;
	parameter WGHT_ROW_ID_BITWIDTH = 4;
	parameter PSUM_ROW_ID_BITWIDTH = 4;

	parameter IFMAP_COL_ID_BITWIDTH = 4;
	parameter WGHT_COL_ID_BITWIDTH = 4;
	parameter PSUM_COL_ID_BITWIDTH = 4;

	parameter IFMAP_DATA_BITWIDTH = 16;
    parameter WGHT_DATA_BITWIDTH = 16;
    parameter PSUM_DATA_BITWIDTH = 16;

    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
	localparam CMD_ACC          = 3'b101;

	// Testbench signal declarations
	reg i_clk;
	reg i_rst;

	// TOP CTRL interface
	reg  [2:0]  i_inst_data;
	reg  [8:0]  i_conv_info;
	reg        i_inst_valid;
	wire       o_inst_ready;

	reg  [IFMAP_ROW_ID_BITWIDTH * COL_LEN-1:0] i_ifmap_row_id;
	reg  [WGHT_ROW_ID_BITWIDTH * COL_LEN-1:0]  i_wght_row_id;
	reg  [PSUM_ROW_ID_BITWIDTH * COL_LEN-1:0]  i_psum_row_id;

	reg        i_ifmap_row_id_valid;
	reg        i_wght_row_id_valid;
	reg        i_psum_row_id_valid;

	reg  [IFMAP_COL_ID_BITWIDTH * ROW_LEN - 1 :0] i_ifmap_col_id;
	reg  [WGHT_COL_ID_BITWIDTH * ROW_LEN - 1 :0]  i_wght_col_id;
	reg  [PSUM_COL_ID_BITWIDTH * ROW_LEN - 1 :0]  i_psum_col_id;

	// one-hot encoded valid signal
	reg  [COL_LEN-1:0] i_ifmap_col_id_valid;
	reg  [COL_LEN-1:0] i_wght_col_id_valid;
	reg  [COL_LEN-1:0] i_psum_col_id_valid;

	reg  [COL_LEN * ROW_LEN - 1:0] i_ctrl_psum_select;

	// GLB interface
	reg  [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH - 1:0] i_ifmap_packet;
	reg  [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH - 1:0]    i_wght_packet;
	reg  [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH - 1:0]    i_psum_in_packet;

	reg        i_ifmap_valid;
	reg        i_wght_valid;
	reg        i_psum_in_valid;

	wire       o_ifmap_ready;
	wire       o_wght_ready;
	wire       o_psum_in_ready;

	PE_array #(
		.ROW_LEN(ROW_LEN),
		.COL_LEN(COL_LEN),
		.IFMAP_DATA_BITWIDTH(IFMAP_DATA_BITWIDTH),
		.IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
		.IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
		.WGHT_DATA_BITWIDTH(WGHT_DATA_BITWIDTH),
		.WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
		.WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
		.PSUM_DATA_BITWIDTH(PSUM_DATA_BITWIDTH),
		.PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
		.PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
	) dut (
		.i_clk(i_clk),
		.i_rst(i_rst),

		// TOP CTRL interface
		.i_inst_data(i_inst_data),
		.i_conv_info(i_conv_info),
		.i_inst_valid(i_inst_valid),
		.o_inst_ready(o_inst_ready),

		.i_ifmap_row_id(i_ifmap_row_id),
		.i_wght_row_id(i_wght_row_id),
		.i_psum_row_id(i_psum_row_id),

		.i_ifmap_row_id_valid(i_ifmap_row_id_valid),
		.i_wght_row_id_valid(i_wght_row_id_valid),
		.i_psum_row_id_valid(i_psum_row_id_valid),

		.i_ifmap_col_id(i_ifmap_col_id),
		.i_wght_col_id(i_wght_col_id),
		.i_psum_col_id(i_psum_col_id),

		.i_ifmap_col_id_valid(i_ifmap_col_id_valid),
		.i_wght_col_id_valid(i_wght_col_id_valid),
		.i_psum_col_id_valid(i_psum_col_id_valid),

		.i_ctrl_psum_select(i_ctrl_psum_select),

		// GLB interface
		.i_ifmap_packet(i_ifmap_packet),
		.i_wght_packet(i_wght_packet),
		.i_psum_in_packet(i_psum_in_packet),

		.i_ifmap_valid(i_ifmap_valid),
		.i_wght_valid(i_wght_valid),
		.i_psum_in_valid(i_psum_in_valid),

		.o_ifmap_ready(o_ifmap_ready),
		.o_wght_ready(o_wght_ready),
		.o_psum_in_ready(o_psum_in_ready)
	);

    always #5 i_clk = ~i_clk; // 10ns clock period

	initial begin
		$display("Start Testbench");

		///// Reset /////
		i_clk = 0;
		i_rst = 1;

		i_inst_data           = 3'b0;                                     // [2:0]
		i_conv_info           = 9'b0;                                     // [8:0]
		i_inst_valid          = 1'b0;

		i_ifmap_row_id        = { (COL_LEN * IFMAP_ROW_ID_BITWIDTH) {1'b0} };
		i_wght_row_id         = { (COL_LEN * WGHT_ROW_ID_BITWIDTH) {1'b0} };
		i_psum_row_id         = { (COL_LEN * PSUM_ROW_ID_BITWIDTH) {1'b0} };

		i_ifmap_row_id_valid  = 1'b0;
		i_wght_row_id_valid   = 1'b0;
		i_psum_row_id_valid   = 1'b0;

		i_ifmap_col_id        = { (ROW_LEN * IFMAP_COL_ID_BITWIDTH) {1'b0} };
		i_wght_col_id         = { (ROW_LEN * WGHT_COL_ID_BITWIDTH) {1'b0} };
		i_psum_col_id         = { (ROW_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = { COL_LEN {1'b0} };
		i_wght_col_id_valid   = { COL_LEN {1'b0} };
		i_psum_col_id_valid   = { COL_LEN {1'b0} };

		i_ctrl_psum_select    = { (ROW_LEN * COL_LEN) {1'b0} };

		i_ifmap_packet        = { (IFMAP_DATA_BITWIDTH + IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH) {1'b0} };
		i_wght_packet         = { (WGHT_DATA_BITWIDTH + WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH) {1'b0} };
		i_psum_in_packet      = { (PSUM_DATA_BITWIDTH + PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_valid         = 1'b0;
		i_wght_valid          = 1'b0;
		i_psum_in_valid       = 1'b0;

		repeat (10) @(posedge i_clk);
		i_rst = 0;
		
		
		
		///// SET GIN row, col ID /////
		i_ifmap_row_id        = { 4'd1, 4'd1, 4'd1 };
		i_wght_row_id         = { 4'd3, 4'd2, 4'd1 };
		i_psum_row_id         = { (COL_LEN * PSUM_ROW_ID_BITWIDTH) {1'b0} };

		i_ifmap_row_id_valid  = 1'b1;
		i_wght_row_id_valid   = 1'b1;
		i_psum_row_id_valid   = 1'b1;

		@(posedge i_clk);
		@(posedge i_clk);

		i_ifmap_row_id_valid  = 1'b0;
		i_wght_row_id_valid   = 1'b0;
		i_psum_row_id_valid   = 1'b0;

		

		i_ifmap_col_id        = { 4'd3, 4'd2, 4'd1 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b001;
		i_wght_col_id_valid   = 3'b001;
		i_psum_col_id_valid   = 3'b001;

		@(posedge i_clk);
		@(posedge i_clk);

		i_ifmap_col_id        = { 4'd4, 4'd3, 4'd2 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b010;
		i_wght_col_id_valid   = 3'b010;
		i_psum_col_id_valid   = 3'b010;

		@(posedge i_clk);
		@(posedge i_clk);

		i_ifmap_col_id        = { 4'd5, 4'd4, 4'd3 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b100;
		i_wght_col_id_valid   = 3'b100;
		i_psum_col_id_valid   = 3'b100;

		@(posedge i_clk);
		@(posedge i_clk);

		repeat (5) @(posedge i_clk);


		///// SET CONV INFO /////
		i_inst_data = CMD_SET;
		i_conv_info = 9'b001001011; //(P=1, Q=1, S=3)
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;
		
		repeat (5) @(posedge i_clk);


		///// LOAD_IFMAP /////
		i_inst_data = CMD_LOAD_IFMAP;
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state

		i_ifmap_valid = 1;

		// LOAD ifmap row 1 (iter 1)
		i_ifmap_packet = {4'd1, 4'd1, 16'd1};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd1, 16'd2};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd1, 16'd3};
		@(posedge i_clk);

		// LOAD ifmap row 2 (iter 1)
		i_ifmap_packet = {4'd1, 4'd2, 16'd6};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd2, 16'd7};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd2, 16'd8};
		@(posedge i_clk);

		// LOAD ifmap row 3 (iter 1)
		i_ifmap_packet = {4'd1, 4'd3, 16'd11};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd3, 16'd12};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd3, 16'd13};
		@(posedge i_clk);

		// LOAD ifmap row 4 (iter 1)
		i_ifmap_packet = {4'd1, 4'd4, 16'd16};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd4, 16'd17};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd4, 16'd18};
		@(posedge i_clk);

		// LOAD ifmap row 5 (iter 1)
		i_ifmap_packet = {4'd1, 4'd5, 16'd21};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd5, 16'd22};
		@(posedge i_clk);
		i_ifmap_packet = {4'd1, 4'd5, 16'd23};
		@(posedge i_clk);

		i_ifmap_valid = 0;

		repeat (5) @(posedge i_clk);


		///// LOAD_WGHT /////
		i_inst_data = CMD_LOAD_WGHT;
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state
		
		i_wght_valid = 1;

		// LOAD wght row 1
		i_wght_packet = {4'd1, 4'd1, 16'd1};
		@(posedge i_clk);
		i_wght_packet = {4'd1, 4'd1, 16'd2};
		@(posedge i_clk);
		i_wght_packet = {4'd1, 4'd1, 16'd3};
		@(posedge i_clk);

		// LOAD wght row 2
		i_wght_packet = {4'd2, 4'd1, 16'd4};
		@(posedge i_clk);
		i_wght_packet = {4'd2, 4'd1, 16'd5};
		@(posedge i_clk);
		i_wght_packet = {4'd2, 4'd1, 16'd6};
		@(posedge i_clk);

		// LOAD wght row 3
		i_wght_packet = {4'd3, 4'd1, 16'd7};
		@(posedge i_clk);
		i_wght_packet = {4'd3, 4'd1, 16'd8};
		@(posedge i_clk);
		i_wght_packet = {4'd3, 4'd1, 16'd9};
		@(posedge i_clk);

		i_wght_valid = 0;

		repeat (5) @(posedge i_clk);

		$stop;

		///// CONV /////
		i_inst_data = CMD_CONV;
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state

		repeat (72) @(posedge i_clk);

		repeat (5) @(posedge i_clk);


		///// ACCRST /////
		i_inst_data = CMD_ACC;
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state

		repeat (10) @(posedge i_clk);

		$stop;
    end

endmodule