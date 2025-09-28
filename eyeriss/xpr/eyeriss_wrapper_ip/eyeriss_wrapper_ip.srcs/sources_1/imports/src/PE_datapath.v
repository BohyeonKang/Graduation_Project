`timescale 1ns / 1ps

(* use_dsp = "yes" *)
module PE_datapath #(
	parameter DATA_BITWIDTH = 8,
	parameter IFMAP_ADDR_BITWIDTH = 4,
	parameter WGHT_ADDR_BITWIDTH = 7,
	parameter PSUM_ADDR_BITWIDTH = 3
)(
	input i_clk, i_rst,

	// input, output data
	input [DATA_BITWIDTH-1:0] i_ifmap_data,
	input [DATA_BITWIDTH-1:0] i_wght_data,
	input [DATA_BITWIDTH-1:0] i_psum_data,
	output reg [DATA_BITWIDTH-1:0] o_psum_data,

	// PE controller interface
	input i_acc_sel,
	input i_rst_psum,

	input [IFMAP_ADDR_BITWIDTH-1:0] i_ifmap_ra,
	input [WGHT_ADDR_BITWIDTH-1:0] i_wght_ra,
	input [PSUM_ADDR_BITWIDTH-1:0] i_psum_ra,
	
	input [IFMAP_ADDR_BITWIDTH-1:0] i_ifmap_wa,
	input [WGHT_ADDR_BITWIDTH-1:0] i_wght_wa,
	input [PSUM_ADDR_BITWIDTH-1:0] i_psum_wa,

	input i_ifmap_we,
	input i_wght_we,
	input i_psum_we,

	// TOP controller interface
	output o_psum_out_valid
);

	//delayed input psum data
	reg [DATA_BITWIDTH-1:0] psum_in_reg, psum_in_reg_d, psum_in_reg_d2;

	//delayed spad data
	wire [DATA_BITWIDTH-1:0] ifmap_rd;
	wire [DATA_BITWIDTH-1:0] wght_rd;
	wire [DATA_BITWIDTH-1:0] psum_rd;

	reg [DATA_BITWIDTH-1:0] ifmap_reg;
	reg [DATA_BITWIDTH-1:0] psum_reg, psum_reg_d, psum_reg_d2;
	reg [DATA_BITWIDTH-1:0] wght_reg;

	//control signal delayed for 3 cycles
	reg [2:0] acc_sel_sft_reg;
	reg [2:0] rst_psum_sft_reg;
	reg [PSUM_ADDR_BITWIDTH-1:0] psum_wa_reg, psum_wa_reg_d1, psum_wa_reg_d2;
	reg [2:0] psum_we_sftreg;

	wire rst_psum = rst_psum_sft_reg[2];
	wire psum_we = psum_we_sftreg[2];
	wire [PSUM_ADDR_BITWIDTH-1:0] psum_wa = psum_wa_reg_d2;

	wire acc_sel = acc_sel_sft_reg[2];

	RF #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH)
	) spad_ifmap (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_ra(i_ifmap_ra),
		.o_rd(ifmap_rd),
		.i_we(i_ifmap_we),
		.i_wa(i_ifmap_wa),
		.i_wd(i_ifmap_data)
	);

	// spo for write only, dpo for read only
	rams_dist #(
		.DATA_BITWIDTH (DATA_BITWIDTH),   // 예: 8
		.ADDR_BITWIDTH (WGHT_ADDR_BITWIDTH)    // 예: 7
	) spad_weight (
		.clk(i_clk),
		.we(i_wght_we),
		.a(i_wght_wa),
		.dpra(i_wght_ra),
		.di(i_wght_data),
		.spo(),
		.dpo(wght_rd)
	);

	RF #(
		.DATA_BITWIDTH(DATA_BITWIDTH),
		.ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
	) spad_psum (
		.i_clk(i_clk),
		.i_rst(i_rst),
		.i_ra(i_psum_ra),
		.o_rd(psum_rd),
		.i_we(psum_we),
		.i_wa(psum_wa),
		.i_wd(o_psum_data)
	);

	always @(posedge i_clk) begin
		if(i_rst) begin
			psum_in_reg <= 0;
			psum_in_reg_d <= 0;

			ifmap_reg <= 0;
			wght_reg <= 0;

			psum_reg <= 0;
			psum_reg_d <= 0;

			psum_we_sftreg <= 0;
			psum_wa_reg <= 0;
			psum_wa_reg_d1 <= 0;

			rst_psum_sft_reg <= 0;
			acc_sel_sft_reg <= 0;
		end
		else begin
			psum_in_reg <= (rst_psum) ? 0 : i_psum_data ;
			psum_in_reg_d <= psum_in_reg;
			psum_in_reg_d2 <= psum_in_reg_d;

			ifmap_reg <= ifmap_rd;
			wght_reg <= wght_rd;
			psum_reg <= psum_rd;
			psum_reg_d <= psum_reg;
			psum_reg_d2 <= (rst_psum) ? 0 : psum_reg_d;

			psum_we_sftreg <= {psum_we_sftreg[1:0], i_psum_we};
			psum_wa_reg <= i_psum_wa;
			psum_wa_reg_d1 <= psum_wa_reg;
			psum_wa_reg_d2 <= psum_wa_reg_d1;
			
			rst_psum_sft_reg <= {rst_psum_sft_reg[1:0], i_rst_psum};
			acc_sel_sft_reg <= {acc_sel_sft_reg[1:0], i_acc_sel};
		end
	end


	reg [DATA_BITWIDTH-1:0] mul_reg;
	reg [DATA_BITWIDTH-1:0] mul_reg_d;
	
	always @(posedge i_clk) begin
		if(i_rst) begin
			mul_reg <= 0;
			mul_reg_d <= 0;
		end
		else begin
			mul_reg <= ifmap_reg * wght_reg;
			mul_reg_d <= mul_reg;
		end
	end

	always @(*) begin
		case({rst_psum, acc_sel})
			2'b00: o_psum_data = psum_reg_d2 + mul_reg_d;
			2'b01: o_psum_data = psum_reg_d2 + psum_in_reg_d2;
			2'b10: o_psum_data = 0;
			2'b11: o_psum_data = 0;
		endcase
	end

	assign o_psum_out_valid = acc_sel_sft_reg[2];

endmodule