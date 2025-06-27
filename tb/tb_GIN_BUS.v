`timescale 1ns / 1ps

module tb_PE_datapath;

    parameter ID_BITWIDTH = 4;
    parameter PACKET_IN_BITWIDTH = 12;
    parameter PACKET_OUT_BITWIDTH = 8;
    parameter SLV_NUM = 6;

    reg i_clk;
    reg i_rst;

    // rx
    reg [PACKET_IN_BITWIDTH-1:0] i_data;
    reg i_valid;
    wire o_ready;

    // tx
    wire [SLV_NUM * PACKET_OUT_BITWIDTH-1:0] o_data;
    reg [SLV_NUM-1:0] i_ready;
    wire [SLV_NUM-1:0] o_valid;

    // TOP CTRL interface
    reg [SLV_NUM * ID_BITWIDTH - 1:0] i_id;
    reg i_id_valid;


    GIN_BUS #(
        .ID_BITWIDTH(ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(PACKET_IN_BITWIDTH),
        .PACKET_OUT_BITWIDTH(PACKET_OUT_BITWIDTH),
        .SLV_NUM(SLV_NUM)
    ) u_gin_bus (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_data     (i_data),
        .i_valid    (i_valid),
        .o_ready    (o_ready),

        // tx
        .o_data     (o_data),
        .i_ready    (i_ready),
        .o_valid    (o_valid),

        // TOP CTRL interface
        .i_id       (i_id),
        .i_id_valid (i_id_valid)
    );


	always #5 i_clk = ~i_clk; // 10ns clock period

    integer i;
	initial begin
		$display("Start Testbench");

		// Reset
        i_clk = 0;
        i_rst = 1;

        i_data = 0;
        i_valid = 0;
        i_ready = 0;

        i_id = 0;
        i_id_valid = 0;

		repeat (10) @(posedge i_clk);
		i_rst = 0;

//////////////////////////////////////////////////////////

		// id configuration
        i_id = {4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5};
        i_id_valid = 1;

        @(posedge i_clk);

        i_id = 0;
        i_id_valid = 0;

		repeat (10) @(posedge i_clk);

//////////////////////////////////////////////////////////

        // tag matching
        i_data = {4'd2, 4'd5, 8'b00000000};
        i_valid = 1;
        i_ready = 6'b111111;

        @(posedge i_clk);
        i_data = 0;
        i_valid = 0;
        i_ready = 0;

        repeat (10) @(posedge i_clk);
        
		$display("Finish Simulation");
		$finish;
	end
endmodule