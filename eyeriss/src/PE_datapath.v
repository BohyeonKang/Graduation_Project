`timescale 1ns / 1ps
(* use_dsp = "yes" *) 
module PE_datapath #(
	parameter DATA_BITWIDTH = 8,
	parameter IFMAP_SPAD_AWIDTH = 4,
	parameter WGHT_SPAD_AWIDTH = 7,
	parameter PSUM_SPAD_AWIDTH = 3
)(
	input i_clk, i_rst,

	// input, output data
	input 		[DATA_BITWIDTH-1:0] i_ifmap_data,
	input 		[DATA_BITWIDTH-1:0] i_wght_data,
	input 		[DATA_BITWIDTH-1:0] i_psum_data,
	output reg 	[DATA_BITWIDTH-1:0] o_psum_data,

	// PE controller interface
	input i_acc_sel,
	input i_rst_psum,

	input [IFMAP_SPAD_AWIDTH-1:0] i_ifmap_spad_addr,
	input [WGHT_SPAD_AWIDTH-1:0] i_wght_spad_addr,
	input [PSUM_SPAD_AWIDTH-1:0] i_psum_spad_addr,
	
	input i_ifmap_spad_we,
	input i_wght_spad_we,
	input i_psum_spad_we,

	output o_psum_out_valid
);

	/////////////////////////////////
	// internal signals
	/////////////////////////////////

	wire [DATA_BITWIDTH-1:0] ifmap_spad_rd;
	wire [DATA_BITWIDTH-1:0] wght_spad_rd;
	wire [DATA_BITWIDTH-1:0] psum_spad_rd;

	// control signals pipeline registers

	reg [DATA_BITWIDTH-1:0] r_ifmap_spad_rd_t0;
	reg [DATA_BITWIDTH-1:0] r_wght_spad_rd_t0;

	reg [DATA_BITWIDTH-1:0] r_psum_in_t0, r_psum_in_t1, r_psum_in_t2;

	reg [DATA_BITWIDTH-1:0] r_mul_reg_t1;
	reg [DATA_BITWIDTH-1:0] r_mul_reg_t2;
	
	reg [PSUM_SPAD_AWIDTH-1:0] r_psum_spad_addr_t0, r_psum_spad_addr_t1, r_psum_spad_addr_t2;
	reg r_psum_spad_we_t0, r_psum_spad_we_t1, r_psum_spad_we_t2;

	reg r_acc_sel_t0, r_acc_sel_t1, r_acc_sel_t2;
	reg r_rst_psum_t0, r_rst_psum_t1, r_rst_psum_t2;

	/////////////////////////////////
	// Instantiation
	/////////////////////////////////

	rams_dist #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.ADDR_BITWIDTH(IFMAP_SPAD_AWIDTH)
	) u_ifmap_spad (
		.clk(i_clk),
		.we0(i_ifmap_spad_we),
		.we1(1'b0),
		.d0(i_ifmap_data),
		.d1({DATA_BITWIDTH{1'b0}}),
		.addr0(i_ifmap_spad_addr),
		.addr1({IFMAP_SPAD_AWIDTH{1'b0}}),
		.q0(ifmap_spad_rd),
		.q1()
	);

	rams_dist #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.ADDR_BITWIDTH(WGHT_SPAD_AWIDTH)
	) u_wght_spad (
		.clk(i_clk),
		.we0(i_wght_spad_we),
		.we1(1'b0),
		.d0(i_wght_data),
		.d1({DATA_BITWIDTH{1'b0}}),
		.addr0(i_wght_spad_addr),
		.addr1({WGHT_SPAD_AWIDTH{1'b0}}),
		.q0(wght_spad_rd),
		.q1()
	);

	// psum spad write data comes from the output of this PE - signals should be delayed accordingly
	rams_dist #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.ADDR_BITWIDTH(PSUM_SPAD_AWIDTH)
	) u_psum_spad (
		.clk(i_clk),
		.we0(r_psum_spad_we_t2),
		.we1(1'b0),
		.d0(o_psum_data),
		.d1({DATA_BITWIDTH{1'b0}}),
		.addr0(r_psum_spad_addr_t2),
		.addr1({PSUM_SPAD_AWIDTH{1'b0}}),
		.q0(psum_spad_rd),
		.q1()
	);

	/////////////////////////////////
	// RTL Logic
	/////////////////////////////////

	// control signals
	always @(posedge i_clk) begin
		if(i_rst) begin
			r_psum_in_t0 <= 0;
			r_psum_in_t1 <= 0;
			r_psum_in_t2 <= 0;

			r_ifmap_spad_rd_t0 <= 0;
			r_wght_spad_rd_t0 <= 0;

			r_psum_spad_addr_t0 <= 0;
			r_psum_spad_addr_t1 <= 0;
			r_psum_spad_addr_t1 <= 0;

			r_psum_spad_we_t0 <= 0;
			r_psum_spad_we_t1 <= 0;
			r_psum_spad_we_t2 <= 0;

			r_rst_psum_t0 <= 0;
			r_rst_psum_t1 <= 0;
			r_rst_psum_t2 <= 0;
			r_acc_sel_t0 <= 0;
			r_acc_sel_t1 <= 0;
			r_acc_sel_t2 <= 0;
		end
		else begin
			r_psum_in_t0 <= i_psum_data;
			r_psum_in_t1 <= r_psum_in_t0;
			r_psum_in_t2 <= r_psum_in_t1;

			r_ifmap_spad_rd_t0 <= ifmap_spad_rd;
			r_wght_spad_rd_t0 <= wght_spad_rd;

			r_psum_spad_addr_t0 <= i_psum_spad_addr;
			r_psum_spad_addr_t1 <= r_psum_spad_addr_t0;
			r_psum_spad_addr_t2 <= r_psum_spad_addr_t1;
			
			r_psum_spad_we_t0 <= i_psum_spad_we;
			r_psum_spad_we_t1 <= r_psum_spad_we_t0;
			r_psum_spad_we_t2 <= r_psum_spad_we_t1;

			r_rst_psum_t0 <= i_rst_psum;
			r_rst_psum_t1 <= r_rst_psum_t0;
			r_rst_psum_t2 <= r_rst_psum_t1;
			r_acc_sel_t0 <= i_acc_sel;
			r_acc_sel_t1 <= r_acc_sel_t0;
			r_acc_sel_t2 <= r_acc_sel_t1;
		end
	end
	
	// multiplier
	always @(posedge i_clk) begin
		if(i_rst) begin
			r_mul_reg_t1 <= 0;
			r_mul_reg_t2 <= 0;
		end
		else begin
			r_mul_reg_t1 <= r_ifmap_spad_rd_t0 * r_wght_spad_rd_t0;
			r_mul_reg_t2 <= r_mul_reg_t1;
		end
	end

	always @(*) begin
		o_psum_data = {DATA_BITWIDTH{1'b0}};
		if(r_rst_psum_t2)
			o_psum_data = {DATA_BITWIDTH{1'b0}};
		else begin
			if(r_acc_sel_t2)
				o_psum_data = psum_spad_rd + r_psum_in_t2;
			else
				o_psum_data = psum_spad_rd + r_mul_reg_t2;
		end
	end

	assign o_psum_out_valid = r_acc_sel_t2;

endmodule