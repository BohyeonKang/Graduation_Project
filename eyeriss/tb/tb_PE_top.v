`timescale 1ns / 1ps

module tb_PE_top;

	parameter DWIDTH = 32;
	parameter IFMAP_SPAD_AWIDTH = 4;
	parameter WGHT_SPAD_AWIDTH = 7;
	parameter PSUM_SPAD_AWIDTH = 3;
	parameter IFMAP_FIFO_AWIDTH = 4;
	parameter WGHT_FIFO_AWIDTH = 8;
	parameter PSUM_FIFO_AWIDTH = 4;

    localparam CMD_SET          = 3'b000;
    localparam CMD_LOAD_IFMAP   = 3'b001;
    localparam CMD_LOAD_WGHT    = 3'b010;
    localparam CMD_CONV         = 3'b011;
	localparam CMD_ACC          = 3'b100;

	reg i_clk;
	reg i_rst;

	// TOP CTRL
	reg [2:0] i_opcode;
	reg i_opcode_valid;
	wire o_opcode_ready;

	reg [4:0] i_layer_p;
	reg [2:0] i_layer_q;
	reg [3:0] i_layer_s;

	// FIFO interface I/O
	reg [DWIDTH-1:0] i_ifmap_fifo_data;
	reg i_ifmap_fifo_valid;
	wire o_ifmap_fifo_ready;

	reg [DWIDTH-1:0] i_wght_fifo_data;
	reg i_wght_fifo_valid;
	wire o_wght_fifo_ready;

	reg [DWIDTH-1:0] i_psum_in_fifo_data;
	reg i_psum_in_fifo_valid;
	wire o_psum_in_fifo_ready;

	reg i_psum_out_fifo_ready;
	wire [DWIDTH-1:0] o_psum_out_fifo_data;
	wire o_psum_out_fifo_valid;
	

	PE_top #(
		.DWIDTH(DWIDTH),
		.IFMAP_SPAD_AWIDTH(IFMAP_SPAD_AWIDTH),
		.WGHT_SPAD_AWIDTH(WGHT_SPAD_AWIDTH),
		.PSUM_SPAD_AWIDTH(PSUM_SPAD_AWIDTH),
		.IFMAP_FIFO_AWIDTH(IFMAP_FIFO_AWIDTH),
		.WGHT_FIFO_AWIDTH(WGHT_FIFO_AWIDTH),
		.PSUM_FIFO_AWIDTH(PSUM_FIFO_AWIDTH)
	) U_PE_top (
		.i_clk(i_clk),
		.i_rst(i_rst),

		//TOP CTRL
		.i_opcode(i_opcode),
		.i_opcode_valid(i_opcode_valid),
		.o_opcode_ready(o_opcode_ready),
		.i_layer_p(i_layer_p),
		.i_layer_q(i_layer_q),
		.i_layer_s(i_layer_s),

		//fifo interface I/O
		.i_ifmap_fifo_data(i_ifmap_fifo_data),
		.i_ifmap_fifo_valid(i_ifmap_fifo_valid),
		.o_ifmap_fifo_ready(o_ifmap_fifo_ready),

		.i_wght_fifo_data(i_wght_fifo_data),
		.i_wght_fifo_valid(i_wght_fifo_valid),
		.o_wght_fifo_ready(o_wght_fifo_ready),

		.i_psum_in_fifo_data(i_psum_in_fifo_data),
		.i_psum_in_fifo_valid(i_psum_in_fifo_valid),
		.o_psum_in_fifo_ready(o_psum_in_fifo_ready),

		.o_psum_out_fifo_data(o_psum_out_fifo_data),
		.o_psum_out_fifo_valid(o_psum_out_fifo_valid),
		.i_psum_out_fifo_ready(i_psum_out_fifo_ready)
	);

	always #5 i_clk = ~i_clk; // 10ns clock period

    integer i,j,k;
	initial begin
		$display("Start Testbench");

		// Reset
		i_clk = 0;
		i_rst = 1;
		i_layer_p = 0;
		i_layer_q = 0;
		i_layer_s = 0;
		i_opcode = 0;
		i_opcode_valid = 0;
		i_ifmap_fifo_data = 0;
		i_ifmap_fifo_valid = 0;
		i_wght_fifo_data = 0;
		i_wght_fifo_valid = 0;
		i_psum_in_fifo_data = 0;
		i_psum_in_fifo_valid = 0;
		i_psum_out_fifo_ready = 0;
		
		repeat (10) @(posedge i_clk); #1;
		i_rst = 0;

		///// SET /////
		@(posedge i_clk); #1;
		i_layer_p = 5'h6;
		i_layer_q = 3'h4;
		i_layer_s = 4'h3;
		i_opcode = CMD_SET;
		i_opcode_valid = 1;

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_opcode_valid = 0;

		wait(o_opcode_ready);


		///// LOAD_IFMAP /////
		@(posedge i_clk); #1;
		i_opcode = CMD_LOAD_IFMAP;
		i_opcode_valid = 1;

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_opcode_valid = 0;

		for(j=0; j<dut.u_PE_control.conv_info_reg[5:3]; j=j+1) begin  // loop for Q
			for(k=0; k<dut.u_PE_control.conv_info_reg[2:0]; k=k+1) begin // loop for S
				@(posedge i_clk); #1
				i_ifmap_fifo_valid = 1;
				i_ifmap_fifo_data = k + 1;
			end
		end

		@(posedge i_clk); #1
		i_ifmap_fifo_valid = 0;
		i_ifmap_fifo_data = 0;

		wait(o_opcode_ready);


		///// LOAD_WGHT /////
		@(posedge i_clk); #1;
		i_opcode = CMD_LOAD_WGHT;
		i_opcode_valid = 1;
		
		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_opcode_valid = 0;


		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd3, 8'd3};
		
		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd3, 8'd3};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd3, 8'd3};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd3, 8'd3};
		
		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd1, 8'd1, 8'd1, 8'd1};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd2, 8'd2};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd2, 8'd2, 8'd3, 8'd3};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 1;
		i_wght_fifo_data = {8'd3, 8'd3, 8'd3, 8'd3};

		@(posedge i_clk); #1;
		i_wght_fifo_valid = 0;

		wait(o_opcode_ready);


		///// CONV /////
		@(posedge i_clk); #1;
		i_opcode = CMD_CONV;
		i_opcode_valid = 1;

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_opcode_valid = 0;

		repeat (72) @(posedge i_clk);

		wait(o_opcode_ready);


		///// ACCRST /////
		@(posedge i_clk); #1;
		i_opcode = CMD_ACC;
		i_opcode_valid = 1;

		@(posedge i_clk); #1; //wait 1 cycle for DEC state
		i_opcode_valid = 0;

		@(posedge i_clk); #1;
		i_psum_in_fifo_valid = 1;
		i_psum_in_fifo_data = {8'd10, 8'd10, 8'd10, 8'd10};

		@(posedge i_clk); #1;
		i_psum_in_fifo_valid = 1;
		i_psum_in_fifo_data = {8'd10, 8'd10, 8'd0, 8'd0};

		@(posedge i_clk); #1;
		i_psum_in_fifo_valid = 0;

		repeat (10) @(posedge i_clk);

		wait(o_opcode_ready);

		$stop;
	end

endmodule