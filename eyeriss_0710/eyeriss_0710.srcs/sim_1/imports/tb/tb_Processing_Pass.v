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
    parameter WGHT_BUS_BITWIDTH = 128;
    parameter PSUM_BUS_BITWIDTH = 128;

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

    reg [COL_LEN * ROW_LEN - 1:0] i_ctrl_psum_in_sel_LNorGIN;
    reg [COL_LEN * ROW_LEN - 1:0] i_ctrl_psum_out_sel_GON;

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

    // Initial block for simulation
    initial begin
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
		i_wght_row_id         = { 4'd3, 4'd2, 4'd1 };
		i_psum_row_id         = { (COL_LEN * PSUM_ROW_ID_BITWIDTH) {1'b0} };

		i_ifmap_row_id_valid  = 1'b1;
		i_wght_row_id_valid   = 1'b1;
		i_psum_row_id_valid   = 1'b1;

        @(posedge i_clk); #1;
		i_ifmap_row_id_valid  = 1'b0;
		i_wght_row_id_valid   = 1'b0;
		i_psum_row_id_valid   = 1'b0;


        @(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd3, 4'd2, 4'd1 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b001;
		i_wght_col_id_valid   = 3'b001;
		i_psum_col_id_valid   = 3'b001;

		@(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd4, 4'd3, 4'd2 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b010;
		i_wght_col_id_valid   = 3'b010;
		i_psum_col_id_valid   = 3'b010;

		@(posedge i_clk); #1;
		i_ifmap_col_id        = { 4'd5, 4'd4, 4'd3 };
		i_wght_col_id         = { 4'd1, 4'd1, 4'd1 };
		i_psum_col_id         = { (COL_LEN * PSUM_COL_ID_BITWIDTH) {1'b0} };

		i_ifmap_col_id_valid  = 3'b100;
		i_wght_col_id_valid   = 3'b100;
		i_psum_col_id_valid   = 3'b100;

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

        // // GLB interface
        // reg [4:0] i_bank_sel;
        // reg i_we, i_re;
        // reg [9:0] i_wa, i_ra;  // BANK_DEPTH = 1024 -> 10 bits
        // reg [31:0] i_wd;
        // wire [31:0] o_rd;

        @(posedge i_clk); #1; 
		i_inst_data = CMD_LOAD_IFMAP;
		i_inst_valid = 1;

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 0; // read GLB in advance (it takes 2 cycle for mem read)

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_inst_valid = 0;

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 1;

        for (i = 0; i <= 14; i = i + 1) begin
            ifmap_ra.mem[i];
        end
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd1, o_rd};

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 2;

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd1, o_rd};

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 25;

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd1, o_rd};

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 26;

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;		
		i_ifmap_packet = {4'd1, 4'd1, o_rd};

        i_bank_sel = 0;
        i_re = 1;
        i_ra = 27;
        

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd1, 16'd2};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd1, 16'd3};

		// LOAD ifmap row 2 (iter 1)
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd2, 16'd6};
		
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd2, 16'd7};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd2, 16'd8};

		// LOAD ifmap row 3 (iter 1)
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd3, 16'd11};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd3, 16'd12};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;	
		i_ifmap_packet = {4'd1, 4'd3, 16'd13};

		// LOAD ifmap row 4 (iter 1)
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd4, 16'd16};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd4, 16'd17};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd4, 16'd18};

		// LOAD ifmap row 5 (iter 1)
		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd5, 16'd21};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd5, 16'd22};

		@(posedge i_clk); #1;
		i_ifmap_valid = 1;
		i_ifmap_packet = {4'd1, 4'd5, 16'd23};

		@(posedge i_clk); #1;
		i_ifmap_valid = 0;

		wait(o_inst_ready);

		repeat (5) @(posedge i_clk);


		///// LOAD_WGHT /////
		@(posedge i_clk); #1;
		i_inst_data = CMD_LOAD_WGHT;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		i_inst_valid = 0;

		// LOAD wght row 1
		@(posedge i_clk); #1;
		i_wght_valid = 1;
		i_wght_packet = {4'd1, 4'd1, 16'd1, 16'd2, 16'd3, 16'd0}; // 1, 2, 3 for row one

		// LOAD wght row 2
		@(posedge i_clk); #1;
		i_wght_valid = 1;
		i_wght_packet = {4'd2, 4'd1, 16'd4, 16'd5, 16'd6, 16'd0}; // 4, 5, 6 for row two

		// LOAD wght row 3
		@(posedge i_clk); #1;
		i_wght_valid = 1;
		i_wght_packet = {4'd3, 4'd1, 16'd7, 16'd8, 16'd9, 16'd0};

		@(posedge i_clk); #1;
		i_wght_valid = 0;

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