//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Create Date:
// Design Name: matbi_axis_adder
// Module Name: matbi_axis_adder
// Project Name:
// Target Devices: Zybo Z7-20
// Tool Versions:
// Description: wrapping dma.
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1ps / 1ps

module matbi_axis_adder #(
  parameter integer C_AXIS_TDATA_WIDTH = 512, // Data width of both input and output data
  parameter integer C_ADDER_BIT_WIDTH  = 32,
  parameter integer C_NUM_CLOCKS       = 1,
  parameter integer C_AXIS_TID_WIDTH = 1,
  parameter integer C_AXIS_TDEST_WIDTH = 1,
  parameter integer C_AXIS_TUSER_WIDTH = 1
)
(

  input wire  [C_ADDER_BIT_WIDTH-1:0]   ctrl_constant,

  input wire                             s_axis_aclk,
  input wire                             s_axis_areset,
  input wire                             s_axis_tvalid,
  output wire                            s_axis_tready,
  input wire  [C_AXIS_TDATA_WIDTH-1:0]   s_axis_tdata,
  // no use this datas.... if you want it? DIY~~~
  input wire  [C_AXIS_TDATA_WIDTH/8-1:0] s_axis_tkeep,
  input wire  [C_AXIS_TDATA_WIDTH/8-1:0] s_axis_tstrb,
  input wire                             s_axis_tlast,
  input wire [C_AXIS_TID_WIDTH-1:0]      s_axis_tid,
  input wire  [C_AXIS_TDEST_WIDTH-1:0]   s_axis_tdest,
  input wire  [C_AXIS_TUSER_WIDTH-1:0]   s_axis_tuser,
  ////////////////////////////////////////////////
  input wire                             m_axis_aclk,
  output wire                            m_axis_tvalid,
  input  wire                            m_axis_tready,
  output wire [C_AXIS_TDATA_WIDTH-1:0]   m_axis_tdata,
  output wire [C_AXIS_TDATA_WIDTH/8-1:0] m_axis_tkeep,
  output wire [C_AXIS_TDATA_WIDTH/8-1:0] m_axis_tstrb,
  output wire                            m_axis_tlast,
  output wire [C_AXIS_TID_WIDTH-1:0]     m_axis_tid,
  output wire [C_AXIS_TDEST_WIDTH-1:0]   m_axis_tdest,
  output wire [C_AXIS_TUSER_WIDTH-1:0]   m_axis_tuser

);

localparam integer LP_NUM_LOOPS = C_AXIS_TDATA_WIDTH/C_ADDER_BIT_WIDTH;
/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////
reg                              d1_tvalid = 1'b0;
reg                              d1_tready = 1'b0;
reg   [C_AXIS_TDATA_WIDTH-1:0]   d1_tdata;
reg   [C_AXIS_TDATA_WIDTH/8-1:0] d1_tkeep;
reg                              d1_tlast;
reg   [C_ADDER_BIT_WIDTH-1:0]    d1_constant;
reg   [C_AXIS_TDATA_WIDTH/8-1:0] d1_tstrb = {C_AXIS_TDATA_WIDTH/8{1'b1}};
reg   [C_AXIS_TID_WIDTH-1:0]     d1_tid = {C_AXIS_TID_WIDTH{1'b0}};
reg   [C_AXIS_TDEST_WIDTH-1:0]   d1_tdest = {C_AXIS_TDEST_WIDTH{1'b0}};
reg   [C_AXIS_TUSER_WIDTH-1:0]   d1_tuser = {C_AXIS_TUSER_WIDTH{1'b0}};
integer i;

reg                              d2_tvalid = 1'b0;
reg   [C_AXIS_TDATA_WIDTH-1:0]   d2_tdata;
reg   [C_AXIS_TDATA_WIDTH/8-1:0] d2_tkeep;
reg                              d2_tlast;


reg   [C_AXIS_TDATA_WIDTH/8-1:0] d2_tstrb;
reg   [C_AXIS_TID_WIDTH-1:0]     d2_tid;
reg   [C_AXIS_TDEST_WIDTH-1:0]   d2_tdest;
reg   [C_AXIS_TUSER_WIDTH-1:0]   d2_tuser;

wire                             prog_full_axis;
reg                              fifo_ready_r = 1'b0;
/////////////////////////////////////////////////////////////////////////////
// RTL Logic
/////////////////////////////////////////////////////////////////////////////

assign s_axis_tready = ~m_axis_tvalid | m_axis_tready;

// Register s_axis_interface/inputs
always @(posedge s_axis_aclk) begin 
	if(s_axis_tready) begin
  		d1_tvalid 	<= s_axis_tvalid;
  		d1_tdata  	<= s_axis_tdata;
		d1_tkeep  	<= s_axis_tkeep; 
		d1_tlast  	<= s_axis_tlast;
		d1_tid    	<= s_axis_tid;
		d1_tstrb  	<= s_axis_tstrb;
		d1_tuser   	<= s_axis_tuser;
		d1_tdest  	<= s_axis_tdest;
  		d1_constant <= ctrl_constant;
	end
end

// Adder function
always @(posedge s_axis_aclk) begin
	if(s_axis_tready) begin
		for (i = 0; i < LP_NUM_LOOPS; i = i + 1) begin
		  d2_tdata[i*C_ADDER_BIT_WIDTH+:C_ADDER_BIT_WIDTH] <= d1_tdata[C_ADDER_BIT_WIDTH*i+:C_ADDER_BIT_WIDTH] + d1_constant;
		end
	end
end

// Register inputs to fifo
always @(posedge s_axis_aclk) begin
	if(s_axis_tready) begin
		d2_tvalid <= d1_tvalid;
		d2_tkeep  <= d1_tkeep;
		d2_tlast  <= d1_tlast;
		d2_tid    <= d1_tid;
		d2_tstrb  <= d1_tstrb;
		d2_tuser   <= d1_tuser;
		d2_tdest  <= d1_tdest;
	end
end


assign m_axis_tvalid =  d2_tvalid;
assign m_axis_tdata = d2_tdata;

endmodule

`default_nettype wire
