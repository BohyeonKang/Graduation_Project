`timescale 1ns / 1ps

module tb_PE_control;

    parameter DATA_BITWIDTH = 8;
    parameter IFMAP_ADDR_BITWIDTH = 4;
    parameter WGHT_ADDR_BITWIDTH = 8;
    parameter PSUM_ADDR_BITWIDTH = 5;

    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
	localparam CMD_ACC          = 3'b101;

    // Clock & Reset
    reg i_clk;
    reg i_rst;

    // Interface to TOP CTRL instruction
    reg  [2:0] i_opcode;
    reg  [8:0] i_conv_info;
    reg        i_inst_valid;
    wire       o_inst_ready;

    // Interface to IFMAP FIFO & MUX
    reg  i_ifmap_fifo_valid;
    wire o_ifmap_fifo_ready;
    wire o_ifmap_mux_select;

    // Interface to WGHT FIFO
    reg  i_wght_fifo_valid;
    wire o_wght_fifo_ready;
    wire o_wght_mux_select;

    // Interface to INPUT PSUM FIFO
    reg  i_psum_in_fifo_valid;
    wire o_psum_in_fifo_ready;
    wire o_psum_in_mux_select;

    // Interface to OUTPUT PSUM FIFO
    reg  i_psum_out_fifo_ready;
    reg  i_psum_out_fifo_valid;
    wire o_psum_out_demux_select;

    // Interface to PE_datapath.v
    wire [IFMAP_ADDR_BITWIDTH-1:0] o_ifmap_ra;
    wire [WGHT_ADDR_BITWIDTH-1:0]  o_wght_ra;
    wire [PSUM_ADDR_BITWIDTH-1:0]  o_psum_ra;

    wire [IFMAP_ADDR_BITWIDTH-1:0] o_ifmap_wa;
    wire [WGHT_ADDR_BITWIDTH-1:0]  o_wght_wa;
    wire [PSUM_ADDR_BITWIDTH-1:0]  o_psum_wa;

    wire o_ifmap_we;
    wire o_wght_we;
    wire o_psum_we;

    wire o_acc_sel;
    wire o_rst_psum;

    PE_control #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .IFMAP_ADDR_BITWIDTH(IFMAP_ADDR_BITWIDTH),
        .WGHT_ADDR_BITWIDTH(WGHT_ADDR_BITWIDTH),
        .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)
    ) dut (
        // Clock & Reset
        .i_clk(i_clk),
        .i_rst(i_rst),

        // Interface to TOP CTRL instruction
        .i_opcode(i_opcode),
        .i_conv_info(i_conv_info),
        .i_inst_valid(i_inst_valid),
        .o_inst_ready(o_inst_ready),

        // Interface to IFMAP FIFO & MUX
        .i_ifmap_fifo_valid(i_ifmap_fifo_valid),
        .o_ifmap_fifo_ready(o_ifmap_fifo_ready),
        .o_ifmap_mux_select(o_ifmap_mux_select),

        // Interface to WGHT FIFO
        .i_wght_fifo_valid(i_wght_fifo_valid),
        .o_wght_fifo_ready(o_wght_fifo_ready),
        .o_wght_mux_select(o_wght_mux_select),

        // Interface to INPUT PSUM FIFO
        .i_psum_in_fifo_valid(i_psum_in_fifo_valid),
        .o_psum_in_fifo_ready(o_psum_in_fifo_ready),
        .o_psum_in_mux_select(o_psum_in_mux_select),

        // Interface to OUTPUT PSUM FIFO
        .i_psum_out_fifo_ready(i_psum_out_fifo_ready),
        .i_psum_out_fifo_valid(i_psum_out_fifo_valid),
        .o_psum_out_demux_select(o_psum_out_demux_select),

        // Interface to PE_datapath.v
        .o_ifmap_ra(o_ifmap_ra),
        .o_wght_ra(o_wght_ra),
        .o_psum_ra(o_psum_ra),

        .o_ifmap_wa(o_ifmap_wa),
        .o_wght_wa(o_wght_wa),
        .o_psum_wa(o_psum_wa),

        .o_ifmap_we(o_ifmap_we),
        .o_wght_we(o_wght_we),
        .o_psum_we(o_psum_we),

        .o_acc_sel(o_acc_sel),
        .o_rst_psum(o_rst_psum)
    );

    // Clock
    always #5 i_clk = ~i_clk;

    integer i,j,k;
    initial begin

        ///// RESET /////
        i_clk = 0;
        i_rst = 1;

        i_opcode = 0;
        i_conv_info = 0;
        i_inst_valid = 0;

        i_ifmap_fifo_valid = 0;
        i_wght_fifo_valid = 0;
        i_psum_in_fifo_valid = 0;

        i_psum_out_fifo_ready = 0;
        i_psum_out_fifo_valid = 0;

        repeat (5) @(posedge i_clk); #1;
		i_rst = 0;



		///// SET /////
		@(posedge i_clk); #1;
		i_opcode = CMD_SET;
		i_conv_info = 9'b110100011; //(P=6, Q=4, S=3)
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		wait(o_inst_ready);
		i_inst_valid = 0;
		
		repeat (5) @(posedge i_clk);


		///// LOAD_IFMAP /////
		@(posedge i_clk); #1;
		i_opcode = CMD_LOAD_IFMAP;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk) #1; //wait 1 cycle for DEC state
		i_ifmap_fifo_valid = 1;

		for(j=0; j<dut.conv_info_reg[5:3]; j=j+1) begin  // loop for Q
			for(k=0; k<dut.conv_info_reg[2:0]; k=k+1) begin // loop for S
				@(posedge i_clk); #1;
			end
		end
		i_ifmap_fifo_valid = 0;

		repeat (5) @(posedge i_clk);


		///// LOAD_WGHT /////
        @(posedge i_clk); #1;
		i_opcode = CMD_LOAD_WGHT;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); #1 //wait 1 cycle for DEC state
		
        i_wght_fifo_valid = 1;
		for(i=0; i<dut.u_PE_control.conv_info_reg[5:3]; i=i+1) begin  // loop for Q
			for(j=0; j<dut.u_PE_control.conv_info_reg[2:0]; j=j+1) begin // loop for S
				for(k=0; k<dut.u_PE_control.conv_info_reg[8:6]; k=k+1) begin // loop for P
					@(posedge i_clk); #1;
				end
			end
		end
		i_wght_fifo_valid = 0;

		repeat (5) @(posedge i_clk);


		///// CONV /////
        @(posedge i_clk); #1;
		i_opcode = CMD_CONV;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); #1 //wait 1 cycle for DEC state

		repeat (72) @(posedge i_clk);

		repeat (5) @(posedge i_clk);


		///// ACCRST /////
        @(posedge i_clk); #1;
		i_opcode = CMD_ACC;
		i_inst_valid = 1;

		@(posedge i_clk); #1;
		wait(o_inst_ready);
		i_inst_valid = 0;

		@(posedge i_clk); //wait 1 cycle for DEC state

		#1; i_psum_in_fifo_valid = 1;
		for(i=0; i<dut.u_PE_control.conv_info_reg[8:6]; i=i+1) begin  // loop for P
			@(posedge i_clk);
		end
		#1; i_psum_in_fifo_valid = 0;

		repeat (10) @(posedge i_clk);

		$stop;
    end

endmodule
