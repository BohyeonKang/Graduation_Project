`timescale 1ns / 1ps

module tb_Processing_Pass;

    parameter DATA_BITWIDTH = 32;

    parameter COL_LEN = 3;
	parameter ROW_LEN = 3;

    parameter BANK_NUM = 32;
    parameter BANK_DEPTH = 1024;

	parameter IFMAP_ROW_ID_BITWIDTH = 4;
	parameter WGHT_ROW_ID_BITWIDTH = 4;
	parameter PSUM_ROW_ID_BITWIDTH = 4;

	parameter IFMAP_COL_ID_BITWIDTH = 4;
	parameter WGHT_COL_ID_BITWIDTH = 4;
	parameter PSUM_COL_ID_BITWIDTH = 4;

	parameter IFMAP_BUS_BITWIDTH = 32;
    parameter WGHT_BUS_BITWIDTH = 32;
    parameter PSUM_BUS_BITWIDTH = 32;

    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
	localparam CMD_ACC          = 3'b101;

    // Clock & Reset
    reg i_clk;
    reg i_rst;

    // GLB interface
    reg [4:0] i_bank_sel;
    reg i_we, i_re;
    reg [9:0] i_wa, i_ra;  // BANK_DEPTH = 1024 -> 10 bits
    reg [31:0] i_wd;
    wire [31:0] o_rd;

	// TOP CTRL interface
	reg  [2:0]  i_inst_data;
	reg  [8:0]  i_conv_info;
	reg        i_inst_valid;
	wire       o_inst_ready;

	// 의도적으로 비트 배열 바꿈(보기 편하게)
	reg  [0:IFMAP_ROW_ID_BITWIDTH * COL_LEN-1] i_ifmap_row_id;
	reg  [0:WGHT_ROW_ID_BITWIDTH * COL_LEN-1]  i_wght_row_id;
	reg  [0:PSUM_ROW_ID_BITWIDTH * COL_LEN-1]  i_psum_row_id;

	reg        i_ifmap_row_id_valid;
	reg        i_wght_row_id_valid;
	reg        i_psum_row_id_valid;

	reg  [0:IFMAP_COL_ID_BITWIDTH * ROW_LEN - 1] i_ifmap_col_id;
	reg  [0:WGHT_COL_ID_BITWIDTH * ROW_LEN - 1]  i_wght_col_id;
	reg  [0:PSUM_COL_ID_BITWIDTH * ROW_LEN - 1]  i_psum_col_id;

	// one-hot encoded valid signal
	reg  [0:COL_LEN-1] i_ifmap_col_id_valid;
	reg  [0:COL_LEN-1] i_wght_col_id_valid;
	reg  [0:COL_LEN-1] i_psum_col_id_valid;

    reg [0:COL_LEN * ROW_LEN - 1] i_ctrl_psum_in_sel_LNorGIN;
    reg [0:COL_LEN * ROW_LEN - 1] i_ctrl_psum_out_sel_GON;

	// GLB interface
	reg  [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1:0] i_ifmap_packet;
	reg  [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1:0]    i_wght_packet;
	reg  [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1:0]    i_psum_in_packet;
	wire [PSUM_BUS_BITWIDTH-1:0] o_psum_out_data;

	reg        i_ifmap_valid;
	reg        i_wght_valid;
	reg        i_psum_in_valid;
	reg 	   i_psum_out_ready;

	wire       o_ifmap_ready;
	wire       o_wght_ready;
	wire       o_psum_in_ready;
	wire	   o_psum_out_valid;

    // Instantiate GLB
    GLB #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .BANK_NUM(32),
        .BANK_DEPTH(1024)
    ) u_GLB (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_bank_sel(i_bank_sel),
        .i_we(i_we),
        .i_re(i_re),
        .i_wa(i_wa),
        .i_ra(i_ra),
        .i_wd(i_wd),
        .o_rd(o_rd)
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

		.i_ctrl_psum_in_sel_LNorGIN(i_ctrl_psum_in_sel_LNorGIN),
		.i_ctrl_psum_out_sel_GON(i_ctrl_psum_out_sel_GON),

		// GLB interface
		.i_ifmap_packet(i_ifmap_packet),
		.i_wght_packet(i_wght_packet),
		.i_psum_in_packet(i_psum_in_packet),
		.o_psum_out_data(o_psum_out_data),

		.i_ifmap_valid(i_ifmap_valid),
		.i_wght_valid(i_wght_valid),
		.i_psum_in_valid(i_psum_in_valid),
		.i_psum_out_ready(i_psum_out_ready),

		.o_ifmap_ready(o_ifmap_ready),
		.o_wght_ready(o_wght_ready),
		.o_psum_in_ready(o_psum_in_ready),
		.o_psum_out_valid(o_psum_out_valid)
	);

    // Clock generation
    always #5 i_clk = ~i_clk;

	reg [31:0] ifmap_ra_iter0_row0 [0:14];
	reg [31:0] ifmap_ra_iter0_row1 [0:14];
	reg [31:0] ifmap_ra_iter0_row2 [0:14];
	reg [31:0] ifmap_ra_iter0_row3 [0:14];
	reg [31:0] ifmap_ra_iter0_row4 [0:14];
	reg [31:0] ifmap_ra_iter1_row0 [0:14];
	reg [31:0] ifmap_ra_iter1_row1 [0:14];
	reg [31:0] ifmap_ra_iter1_row2 [0:14];
	reg [31:0] ifmap_ra_iter1_row3 [0:14];
	reg [31:0] ifmap_ra_iter1_row4 [0:14];
	reg [31:0] ifmap_ra_iter2_row0 [0:14];
	reg [31:0] ifmap_ra_iter2_row1 [0:14];
	reg [31:0] ifmap_ra_iter2_row2 [0:14];
	reg [31:0] ifmap_ra_iter2_row3 [0:14];
	reg [31:0] ifmap_ra_iter2_row4 [0:14];

	reg [31:0] wght_ra_row0 [0:60];
	reg [31:0] wght_ra_row1 [0:60];
	reg [31:0] wght_ra_row2 [0:60];

	integer i;

    // Initial block for simulation
    initial begin
		$readmemh("ifmap_ra_iter0_row0.mem", ifmap_ra_iter0_row0);
		$readmemh("ifmap_ra_iter0_row1.mem", ifmap_ra_iter0_row1);
		$readmemh("ifmap_ra_iter0_row2.mem", ifmap_ra_iter0_row2);
		$readmemh("ifmap_ra_iter0_row3.mem", ifmap_ra_iter0_row3);
		$readmemh("ifmap_ra_iter0_row4.mem", ifmap_ra_iter0_row4);
		$readmemh("ifmap_ra_iter1_row0.mem", ifmap_ra_iter1_row0);
		$readmemh("ifmap_ra_iter1_row1.mem", ifmap_ra_iter1_row1);
		$readmemh("ifmap_ra_iter1_row2.mem", ifmap_ra_iter1_row2);
		$readmemh("ifmap_ra_iter1_row3.mem", ifmap_ra_iter1_row3);
		$readmemh("ifmap_ra_iter1_row4.mem", ifmap_ra_iter1_row4);
		$readmemh("ifmap_ra_iter2_row0.mem", ifmap_ra_iter2_row0);
		$readmemh("ifmap_ra_iter2_row1.mem", ifmap_ra_iter2_row1);
		$readmemh("ifmap_ra_iter2_row2.mem", ifmap_ra_iter2_row2);
		$readmemh("ifmap_ra_iter2_row3.mem", ifmap_ra_iter2_row3);
		$readmemh("ifmap_ra_iter2_row4.mem", ifmap_ra_iter2_row4);
		
		$readmemh("wght_ra_row0.mem", wght_ra_row0);
		$readmemh("wght_ra_row1.mem", wght_ra_row1);
		$readmemh("wght_ra_row2.mem", wght_ra_row2);

        $display("Start tb_Processing_Pass");

        i_clk = 0;
        i_rst = 1;
        i_bank_sel = 0;
        i_we = 0;
        i_re = 0;
        i_wa = 0;
        i_ra = 0;
        i_wd = 0;

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

		i_ctrl_psum_in_sel_LNorGIN = { (ROW_LEN * COL_LEN) {1'b0} };

		i_ifmap_packet        = { (IFMAP_BUS_BITWIDTH + IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH) {1'b0} };
		i_wght_packet         = { (WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH) {1'b0} };
		i_psum_in_packet      = { (PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH) {1'b0} };

		i_ifmap_valid         = 1'b0;
		i_wght_valid          = 1'b0;
		i_psum_in_valid       = 1'b0;

		repeat (5) @(posedge i_clk);

        @(posedge i_clk); #1;
		i_rst = 0;

        // Initialize GLB banks from memh file (예: ifmap.memh => bank 0)
        @(posedge i_clk); #1;
        $readmemh("ifmap.mem", u_GLB.gen_GLB_BANKS[0].glb_bank_inst.BRAM);
        $readmemh("weight.mem", u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM);
        $readmemh("psum_init.mem", u_GLB.gen_GLB_BANKS[2].glb_bank_inst.BRAM);

		repeat (5) @(posedge i_clk);

		///// SET GIN row, col ID /////
        @(posedge i_clk); #1;
		i_ifmap_row_id        = { 4'd1, 4'd1, 4'd1 };
		i_wght_row_id         = { 4'd1, 4'd2, 4'd3 };
		i_psum_row_id         = { (COL_LEN * PSUM_ROW_ID_BITWIDTH) {1'b0} };

		i_ifmap_row_id_valid  = 1'b1;
		i_wght_row_id_valid   = 1'b1;
		i_psum_row_id_valid   = 1'b1;

        @(posedge i_clk); #1;
		i_ifmap_row_id_valid  = 1'b0;
		i_wght_row_id_valid   = 1'b0;
		i_psum_row_id_valid   = 1'b0;


        @(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd1, 4'd2, 4'd3 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b100;
		i_wght_col_id_valid   = 3'b100;
		i_psum_col_id_valid   = 3'b100;

		@(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd2, 4'd3, 4'd4 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b010;
		i_wght_col_id_valid   = 3'b010;
		i_psum_col_id_valid   = 3'b010;

		@(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd3, 4'd4, 4'd5 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b001;
		i_wght_col_id_valid   = 3'b001;
		i_psum_col_id_valid   = 3'b001;

		repeat (5) @(posedge i_clk);


		///// SET CONV INFO /////
		@(posedge i_clk); #1;
		i_inst_data = CMD_SET;
		i_conv_info = 9'b100101011; //(P=4, Q=5, S=3)
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		i_inst_valid = 0;
		
		wait(o_inst_ready);


		///// LOAD_IFMAP /////

		/////// ROW 0 ///////
        @(posedge i_clk); #1; 
		i_inst_data = CMD_LOAD_IFMAP;
		i_inst_valid = 1;

        i_bank_sel = 0;
        i_re = 1;
        i_ra = ifmap_ra_iter0_row0[0]; // read GLB in advance (it takes 2 cycle for mem read)

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_inst_valid = 0;

        i_bank_sel = 0;
        i_re = 1;
        i_ra = ifmap_ra_iter0_row0[1];

        for (i = 2; i < 15; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 0;
			i_re = 1;
            i_ra = ifmap_ra_iter0_row0[i];

			i_ifmap_valid = 1;		
			i_ifmap_packet = {4'd1, 4'd1, o_rd[31:0]};
        end

        for (i = 0; i < 15; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 0;
			i_re = 1;
            i_ra = ifmap_ra_iter0_row1[i];

			i_ifmap_valid = 1;		
			if(i<2)		i_ifmap_packet = {4'd1, 4'd1, o_rd[31:0]};
			else 		i_ifmap_packet = {4'd1, 4'd2, o_rd[31:0]};
        end

        for (i = 0; i < 15; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 0;
			i_re = 1;
            i_ra = ifmap_ra_iter0_row2[i];

			i_ifmap_valid = 1;		
			if(i<2)		i_ifmap_packet = {4'd1, 4'd2, o_rd[31:0]};
			else 		i_ifmap_packet = {4'd1, 4'd3, o_rd[31:0]};
        end

        for (i = 0; i < 15; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 0;
			i_re = 1;
            i_ra = ifmap_ra_iter0_row3[i];

			i_ifmap_valid = 1;		
			if(i<2)		i_ifmap_packet = {4'd1, 4'd3, o_rd[31:0]};
			else 		i_ifmap_packet = {4'd1, 4'd4, o_rd[31:0]};
        end

        for (i = 0; i < 15; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 0;
			i_re = 1;
            i_ra = ifmap_ra_iter0_row4[i];

			i_ifmap_valid = 1;		
			if(i<2)		i_ifmap_packet = {4'd1, 4'd4, o_rd[31:0]};
			else 		i_ifmap_packet = {4'd1, 4'd5, o_rd[31:0]};
        end

		@(posedge i_clk); #1;
		i_re = 0;
        i_ra = 0;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd5, o_rd[31:0]};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd5, o_rd[31:0]};

		@(posedge i_clk); #1;
		i_ifmap_valid = 0;
		i_ifmap_packet = 0;

//////////////////////////////////////////////////

		wait(o_inst_ready);

		repeat (5) @(posedge i_clk);


		///// LOAD_WGHT /////
		@(posedge i_clk); #1;
		i_inst_data = CMD_LOAD_WGHT;
		i_inst_valid = 1;

		i_bank_sel = 1;
        i_re = 1;
        i_ra = wght_ra_row0[0]; // read GLB in advance (it takes 2 cycle for mem read)

		@(posedge i_clk); #1;
		i_inst_valid = 0;

        i_bank_sel = 1;
        i_re = 1;
        i_ra = wght_ra_row0[1];

        for (i = 2; i < 60; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 1;
			i_re = 1;
            i_ra = wght_ra_row0[i];

			i_wght_valid = 1;		
			i_wght_packet = {4'd1, 4'd1, o_rd};
        end

        for (i = 0; i < 60; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 1;
			i_re = 1;
            i_ra = wght_ra_row1[i];

			i_wght_valid = 1;		
			if(i<2)		i_wght_packet = {4'd1, 4'd1, o_rd};
			else 		i_wght_packet = {4'd2, 4'd1, o_rd};
        end

        for (i = 0; i < 60; i = i + 1) begin
			@(posedge i_clk); #1;
			i_bank_sel= 1;
			i_re = 1;
            i_ra = wght_ra_row2[i];

			i_wght_valid = 1;		
			if(i<2)		i_wght_packet = {4'd2, 4'd1, o_rd};
			else 		i_wght_packet = {4'd3, 4'd1, o_rd};
        end

		@(posedge i_clk); #1;
		i_re = 0;
        i_ra = 0;
		i_wght_valid = 1;
		i_wght_packet = {4'd3, 4'd1, o_rd};

		@(posedge i_clk); #1;
		i_wght_valid = 1;
		i_wght_packet = {4'd3, 4'd1, o_rd};

		@(posedge i_clk); #1;
		i_wght_valid = 0;
		i_wght_packet = 0;

		wait(o_inst_ready);

		repeat (5) @(posedge i_clk);

		$stop;

		///// CONV /////
		@(posedge i_clk); #1;
		i_inst_data = CMD_CONV;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		i_inst_valid = 0;

		wait(o_inst_ready);

		repeat (5) @(posedge i_clk);


		///// ACCRST /////
		@(posedge i_clk); #1;
		i_inst_data = CMD_ACC;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		i_inst_valid = 0;

		wait(o_inst_ready);

		repeat (10) @(posedge i_clk);

		
		
		///// SEND TO GLB /////
		@(posedge i_clk); #1;
		i_psum_out_ready = 1;
		i_ctrl_psum_out_sel_GON = 9'b100000000;
		@(posedge i_clk); #1;
		i_psum_out_ready = 1;
		i_ctrl_psum_out_sel_GON = 9'b010000000;
		@(posedge i_clk); #1;
		i_psum_out_ready = 1;
		i_ctrl_psum_out_sel_GON = 9'b001000000;

		@(posedge i_clk); #1;
		i_psum_out_ready = 0;
		i_ctrl_psum_out_sel_GON = 9'b0;
		
		repeat (10) @(posedge i_clk);

		$stop;

        $display("End tb_Processing_Pass");

        $finish;
    end
endmodule