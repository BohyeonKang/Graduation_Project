`timescale 1ns / 1ps

module tb_PE_datapath;

	parameter DATA_BITWIDTH = 16;

	parameter IFMAP_ADDR_BITWIDTH = 4;
	parameter WGHT_ADDR_BITWIDTH = 7;
	parameter PSUM_ADDR_BITWIDTH = 3;

	//conv parameter
    parameter P = 6;
    parameter Q = 4;
    parameter S = 3;

	reg i_clk = 0;
	reg i_rst;

	reg i_acc_sel;
	reg i_rst_psum;

	reg [IFMAP_ADDR_BITWIDTH-1:0] i_ifmap_ra;
	reg [WGHT_ADDR_BITWIDTH-1:0] i_wght_ra;
	reg [PSUM_ADDR_BITWIDTH-1:0] i_psum_ra;

	reg [IFMAP_ADDR_BITWIDTH-1:0] i_ifmap_wa;
	reg [WGHT_ADDR_BITWIDTH-1:0]  i_wght_wa;
	reg [PSUM_ADDR_BITWIDTH-1:0] i_psum_wa;

	reg i_ifmap_we, i_wght_we, i_psum_we;

	reg [DATA_BITWIDTH-1:0] i_ifmap_data;
	reg [DATA_BITWIDTH-1:0] i_wght_data;
	reg [DATA_BITWIDTH-1:0] i_psum_data;

	wire [DATA_BITWIDTH-1:0] o_psum_data;

	PE_datapath #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.IFMAP_ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH),
		.WGHT_ADDR_BITWIDTH(WGHT_ADDR_BITWIDTH),
		.PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
	) uut (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_acc_sel(i_acc_sel),
		.i_rst_psum(i_rst_psum),
		.i_ifmap_ra(i_ifmap_ra),
		.i_wght_ra(i_wght_ra),
		.i_psum_ra(i_psum_ra),
		.i_ifmap_wa(i_ifmap_wa),
		.i_wght_wa(i_wght_wa),
		.i_psum_wa(i_psum_wa),
		.i_ifmap_we(i_ifmap_we),
		.i_wght_we(i_wght_we),
		.i_psum_we(i_psum_we),
		.i_ifmap_data(i_ifmap_data),
		.i_wght_data(i_wght_data),
		.i_psum_data(i_psum_data),
		.o_psum_data(o_psum_data)
	);

	always #5 i_clk = ~i_clk; // 10ns clock period

    integer i,j,k;
	initial begin
		$display("Start Testbench");

		// Reset
		i_rst = 1;
		i_acc_sel = 0;
		i_rst_psum = 0;
		i_ifmap_ra = 0;
		i_wght_ra = 0;
		i_psum_ra = 0;
		i_ifmap_wa = 0;
		i_wght_wa = 0;
		i_psum_wa = 0;
		i_ifmap_we = 0;
		i_wght_we = 0;
		i_psum_we = 0;
		i_ifmap_data = 0;
		i_wght_data = 0;
		i_psum_data = 0;

		repeat (10) @(posedge i_clk);
		i_rst = 0;

//////////////////////////////////////////////////////////

		// Load ifmap
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		for (i = 0; i < Q; i = i + 1) begin
			for (j = 0; j < S; j = j + 1) begin
				i_ifmap_wa = (i * S) + j;
				i_ifmap_data = j + 1;
				i_ifmap_we = 1;
				@(posedge i_clk);
			end
		end
		i_ifmap_we = 0;

//////////////////////////////////////////////////////////

		// Load weight
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		// [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3]
		for (i = 0; i < Q; i = i + 1) begin
			for(j = 0; j < S; j = j + 1) begin
				for (k = 0; k < P; k = k + 1) begin
					i_wght_wa = (i * S) + j + (k * Q * S);
					i_wght_data = j + 1;
					i_wght_we = 1;
					@(posedge i_clk);
				end
			end
		end
		i_wght_we = 0;

//////////////////////////////////////////////////////////

		repeat (10) @(posedge i_clk);

		// Convolution
		for (i = 0; i < Q; i = i + 1) begin
			for (j = 0; j < S; j = j + 1) begin
				for (k = 0; k < P; k = k + 1) begin
					i_ifmap_ra = (i * S) + j;
					i_wght_ra = (i * S) + j + (k * Q * S);
					i_psum_ra = k;
					i_psum_wa = k;
					i_psum_we = 1;
					i_rst_psum = 0;
					i_acc_sel = 0;
					@(posedge i_clk);
				end
			end
		end
		i_psum_wa = 0;
		i_psum_we = 0;

//////////////////////////////////////////////////////////
		
		repeat (10) @(posedge i_clk);

		// Psum Accumulation
		for (i = 0; i < 6; i = i + 1) begin
			i_psum_ra = i;
			i_acc_sel = 1;
			i_psum_data = 10;
			@(posedge i_clk);
		end

		i_psum_ra = 0;
		i_acc_sel = 0;
		i_psum_data = 0;
		

//////////////////////////////////////////////////////////

		repeat (10) @(posedge i_clk);

		// Reset Psum accumulation
		for (i = 0; i < 6; i = i + 1) begin
			i_rst_psum = 1;
			i_psum_data = 0;
			i_acc_sel = 1;
			i_psum_wa = i;
			i_psum_we = 1;
			@(posedge i_clk);
		end

		i_rst_psum = 0;
		i_psum_data = 0;
		i_acc_sel = 0;
		i_psum_wa = 0;
		i_psum_we = 0;

//////////////////////////////////////////////////////////

		repeat (10) @(posedge i_clk);

		// Reset Psum accumulation with i_psum_data
		for (i = 0; i < 6; i = i + 1) begin
			i_rst_psum = 1;
			i_psum_data = 10;
			i_acc_sel = 1;
			i_psum_wa = i;
			i_psum_we = 1;
			@(posedge i_clk);
		end

		i_rst_psum = 0;
		i_psum_data = 0;
		i_acc_sel = 0;
		i_psum_wa = 0;
		i_psum_we = 0;

//////////////////////////////////////////////////////////

		repeat (10) @(posedge i_clk);

		$display("Finish Simulation");
		$finish;
	end
endmodule