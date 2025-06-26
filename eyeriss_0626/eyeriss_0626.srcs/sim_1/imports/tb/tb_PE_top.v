`timescale 1ns / 1ps

module tb_PE_top;

	parameter DATA_BITWIDTH = 8;
	parameter IFMAP_ADDR_BITWIDTH = 4;
	parameter WGHT_ADDR_BITWIDTH = 7;
	parameter PSUM_ADDR_BITWIDTH = 3;

    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
	localparam CMD_ACC          = 3'b101;

    reg i_clk = 0;
    reg i_rst;

    //TOP CTRL
    reg [2:0] i_inst_data;
    reg [8:0] i_conv_info;
    reg i_inst_valid;
    wire o_inst_ready;

    //fifo interface
	reg [DATA_BITWIDTH-1:0] i_ifmap_fifo_data;
    reg i_ifmap_fifo_valid;
    wire o_ifmap_fifo_ready;

    reg [DATA_BITWIDTH-1:0] i_wght_fifo_data;
    reg i_wght_fifo_valid;
    wire o_wght_fifo_ready;

    reg [DATA_BITWIDTH-1:0] i_psum_in_fifo_data;
    reg i_psum_in_fifo_valid;
    wire o_psum_in_fifo_ready;

    wire [DATA_BITWIDTH-1:0] o_psum_out_fifo_data;
    wire o_psum_out_fifo_valid;
    reg i_psum_out_fifo_ready;

	PE_top #(
		.DATA_BITWIDTH(DATA_BITWIDTH), 
		.IFMAP_ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH), 
		.WGHT_ADDR_BITWIDTH(WGHT_ADDR_BITWIDTH), 
		.PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
	) dut (
		.i_clk(i_clk),
		.i_rst(i_rst),

		// TOP CTRL
		.i_inst_data(i_inst_data),
		.i_conv_info(i_conv_info),
		.i_inst_valid(i_inst_valid),
		.o_inst_ready(o_inst_ready),

		// FIFO interface
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
		i_rst = 1;
		i_inst_data = 0;
		i_conv_info = 0;
		i_inst_valid = 0;
		i_ifmap_fifo_data = 0;
		i_ifmap_fifo_valid = 0;
		i_wght_fifo_data = 0;
		i_wght_fifo_valid = 0;
		i_psum_in_fifo_data = 0;
		i_psum_in_fifo_valid = 0;
		i_psum_out_fifo_ready = 0;
		
		repeat (10) @(posedge i_clk);
		i_rst = 0;

		///// SET /////
		i_inst_data = CMD_SET;
		i_conv_info = 9'b110100011; //(P=6, Q=4, S=3)
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

		i_ifmap_fifo_valid = 1;

		for(j=0; j<dut.u_PE_control.conv_info_reg[5:3]; j=j+1) begin  // loop for Q
			for(k=0; k<dut.u_PE_control.conv_info_reg[2:0]; k=k+1) begin // loop for S
				i_ifmap_fifo_data = k + 1;
				@(posedge i_clk);
			end
		end
		i_ifmap_fifo_valid = 0;

		repeat (5) @(posedge i_clk);


		///// LOAD_WGHT /////
		i_inst_data = CMD_LOAD_WGHT;
		i_inst_valid = 1;
		@(posedge i_clk);
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state
		
		i_wght_fifo_valid = 1;

		for(i=0; i<dut.u_PE_control.conv_info_reg[5:3]; i=i+1) begin  // loop for Q
			for(j=0; j<dut.u_PE_control.conv_info_reg[2:0]; j=j+1) begin // loop for S
				for(k=0; k<dut.u_PE_control.conv_info_reg[8:6]; k=k+1) begin // loop for P
					i_wght_fifo_data = j + 1;
					@(posedge i_clk);
				end
			end
		end
		i_wght_fifo_valid = 0;

		repeat (5) @(posedge i_clk);


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

		i_psum_in_fifo_valid = 1;
		for(i=0; i<dut.u_PE_control.conv_info_reg[8:6]; i=i+1) begin  // loop for P
			i_psum_in_fifo_data = 10;
			@(posedge i_clk);
		end
		i_psum_in_fifo_valid = 0;

		repeat (10) @(posedge i_clk);

		$stop;
	end

endmodule