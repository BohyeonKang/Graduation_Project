`timescale 1ns / 1ps

module GLB #( 
	parameter DATA_BITWIDTH = 16,
	parameter ADDR_BITWIDTH = 9 
)( 
	input i_clk,
	input i_rst,
	input i_re,
	input i_we,
	input [ADDR_BITWIDTH-1 : 0] i_ra,
	input [ADDR_BITWIDTH-1 : 0] i_wa,
	input signed [DATA_BITWIDTH-1 : 0] i_wd,
	output signed [DATA_BITWIDTH-1 : 0] o_rd
);

	reg [DATA_BITWIDTH-1 : 0] mem [0 : (1 << ADDR_BITWIDTH) - 1]; 
	reg [DATA_BITWIDTH-1 : 0] data;
	
	always@(posedge i_clk) begin : READ
		if(i_rst)
			data <= 0;
		else
		begin
			if(i_re) begin
				data <= mem[i_ra];
			end
			else begin
				data <= 10101;
			end
		end
	end

	assign o_rd = data;
	

	always@(posedge i_clk) begin : WRITE
		if(i_we && !i_rst) begin
			mem[i_wa] <= i_wd;
		end
	end
	
endmodule