//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Create Date:
// Design Name: matbi_dma_ip_top
// Module Name: matbi_dma_ip_top
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

//`define BYPASS_RDMA_TO_WDMA_DATA
`timescale 1 ns / 1 ps
// Top level of the kernel. Do not modify module name, parameters or ports.
module matbi_dma_ip_top #(
  parameter integer C_S_AXI_CONTROL_ADDR_WIDTH = 12,
  parameter integer C_S_AXI_CONTROL_DATA_WIDTH = 32,

  parameter integer C_M00_AXI_ID_WIDTH     = 1,
  parameter integer C_M00_AXI_AWUSER_WIDTH = 1,
  parameter integer C_M00_AXI_ARUSER_WIDTH = 1,
  parameter integer C_M00_AXI_WUSER_WIDTH  = 1,
  parameter integer C_M00_AXI_RUSER_WIDTH  = 1,
  parameter integer C_M00_AXI_BUSER_WIDTH  = 1,
  parameter integer C_M00_AXI_USER_VALUE   = 0,
  parameter integer C_M00_AXI_PROT_VALUE   = 0,
  parameter integer C_M00_AXI_CACHE_VALUE  = 3,
  parameter integer C_M00_AXI_ADDR_WIDTH   = 32,  // Zybo Z7-20's Address Range.
  parameter integer C_M00_AXI_DATA_WIDTH   = 64
)
(
  // System Signals
  input  wire                                    ap_clk               ,
  input  wire                                    ap_rst_n             ,

  // AXI4 master interface m00_axi
  output                                 			m00_axi_awvalid,
  input                                  			m00_axi_awready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   			m00_axi_awaddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_awid,
  output  [7:0]                          			m00_axi_awlen,
  output  [2:0]                          			m00_axi_awsize,
  output  [1:0]                          			m00_axi_awburst,
  output  [1:0]                          			m00_axi_awlock,
  output  [3:0]                          			m00_axi_awcache,
  output  [2:0]                          			m00_axi_awprot,
  output  [3:0]                          			m00_axi_awqos,
  output  [3:0]                          			m00_axi_awregion,
  output  [C_M00_AXI_AWUSER_WIDTH - 1:0] 			m00_axi_awuser,
  output                                 			m00_axi_wvalid,
  input                                  			m00_axi_wready,
  output  [C_M00_AXI_DATA_WIDTH - 1:0]   			m00_axi_wdata,
  output  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 			m00_axi_wstrb,
  output                                 			m00_axi_wlast,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_wid,
  output  [C_M00_AXI_WUSER_WIDTH - 1:0]  			m00_axi_wuser,
  output                                 			m00_axi_arvalid,
  input                                  			m00_axi_arready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   			m00_axi_araddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     			m00_axi_arid,
  output  [7:0]                          			m00_axi_arlen,
  output  [2:0]                          			m00_axi_arsize,
  output  [1:0]                          			m00_axi_arburst,
  output  [1:0]                          			m00_axi_arlock,
  output  [3:0]                          			m00_axi_arcache,
  output  [2:0]                          			m00_axi_arprot,
  output  [3:0]                          			m00_axi_arqos,
  output  [3:0]                          			m00_axi_arregion,
  output  [C_M00_AXI_ARUSER_WIDTH - 1:0] 			m00_axi_aruser,
  input                                  			m00_axi_rvalid,
  output                                 			m00_axi_rready,
  input  [C_M00_AXI_DATA_WIDTH - 1:0]    			m00_axi_rdata,
  input                                  			m00_axi_rlast,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      			m00_axi_rid,
  input  [C_M00_AXI_RUSER_WIDTH - 1:0]   			m00_axi_ruser,
  input  [1:0]                           			m00_axi_rresp,
  input                                  			m00_axi_bvalid,
  output                                 			m00_axi_bready,
  input  [1:0]                           			m00_axi_bresp,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      			m00_axi_bid,
  input  [C_M00_AXI_BUSER_WIDTH - 1:0]   			m00_axi_buser,

  // AXI4-Lite slave interface
  input  wire                                    	s_axi_control_awvalid,
  output wire                                    	s_axi_control_awready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   	s_axi_control_awaddr ,
  input  wire                                    	s_axi_control_wvalid ,
  output wire                                    	s_axi_control_wready ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   	s_axi_control_wdata  ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] 	s_axi_control_wstrb  ,
  input  wire                                    	s_axi_control_arvalid,
  output wire                                    	s_axi_control_arready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   	s_axi_control_araddr ,
  output wire                                    	s_axi_control_rvalid ,
  input  wire                                    	s_axi_control_rready ,
  output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   	s_axi_control_rdata  ,
  output wire [2-1:0]                            	s_axi_control_rresp  ,
  output wire                                    	s_axi_control_bvalid ,
  input  wire                                    	s_axi_control_bready ,
  output wire [2-1:0]                            	s_axi_control_bresp  ,
  output wire                                    	interrupt            
);

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////
localparam C_ADDER_BIT_WIDTH = 8;
///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
reg           areset                        ;
wire          ap_start                      ;
wire          ap_idle                       ;
wire          ap_done                       ;
wire          ap_ready                      ;
wire [32-1:0] rdma_transfer_byte            ;
wire [32-1:0] rdma_mem_ptr                  ;
wire [32-1:0] wdma_transfer_byte            ;
wire [32-1:0] wdma_mem_ptr                  ;
wire [32-1:0] axi00_ptr0                    ;
wire [32-1:0] value_to_add                  ;

// Stream I/F TODO use core
wire [64-1:0] out_r_din		                ;
wire          out_r_full_n		            ;
wire          out_r_write		            ;
wire [64-1:0] in_r_dout		                ;
wire          in_r_empty_n		            ;
wire          in_r_read		                ;

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

///////////////////////////////////////////////////////////////////////////////
// Begin control interface RTL.  Modifying not recommended.
///////////////////////////////////////////////////////////////////////////////

// AXI4-Lite slave interface
matbi_dma_ip_control_s_axi #(
  .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
)
inst_control_s_axi (
  .ACLK               ( ap_clk                ),
  .ARESET             ( areset                ),
  .ACLK_EN            ( 1'b1                  ),
  .AWVALID            ( s_axi_control_awvalid ),
  .AWREADY            ( s_axi_control_awready ),
  .AWADDR             ( s_axi_control_awaddr  ),
  .WVALID             ( s_axi_control_wvalid  ),
  .WREADY             ( s_axi_control_wready  ),
  .WDATA              ( s_axi_control_wdata   ),
  .WSTRB              ( s_axi_control_wstrb   ),
  .ARVALID            ( s_axi_control_arvalid ),
  .ARREADY            ( s_axi_control_arready ),
  .ARADDR             ( s_axi_control_araddr  ),
  .RVALID             ( s_axi_control_rvalid  ),
  .RREADY             ( s_axi_control_rready  ),
  .RDATA              ( s_axi_control_rdata   ),
  .RRESP              ( s_axi_control_rresp   ),
  .BVALID             ( s_axi_control_bvalid  ),
  .BREADY             ( s_axi_control_bready  ),
  .BRESP              ( s_axi_control_bresp   ),
  .interrupt          ( interrupt             ),
  .ap_start           ( ap_start              ),
  .ap_done            ( ap_done               ),
  .ap_ready           ( ap_ready              ),
  .ap_idle            ( ap_idle               ),
  .rdma_transfer_byte ( rdma_transfer_byte    ),
  .rdma_mem_ptr       ( rdma_mem_ptr          ),
  .wdma_transfer_byte ( wdma_transfer_byte    ),
  .wdma_mem_ptr       ( wdma_mem_ptr          ),
  .axi00_ptr0         ( axi00_ptr0            ),
  .value_to_add       ( value_to_add          )
);

matbi_dma_wrapper #(
  .C_M00_AXI_ID_WIDTH 		(C_M00_AXI_ID_WIDTH    ),
  .C_M00_AXI_AWUSER_WIDTH 	(C_M00_AXI_AWUSER_WIDTH),
  .C_M00_AXI_ARUSER_WIDTH 	(C_M00_AXI_ARUSER_WIDTH),
  .C_M00_AXI_WUSER_WIDTH 	(C_M00_AXI_WUSER_WIDTH ),
  .C_M00_AXI_RUSER_WIDTH 	(C_M00_AXI_RUSER_WIDTH ),
  .C_M00_AXI_BUSER_WIDTH 	(C_M00_AXI_BUSER_WIDTH ),
  .C_M00_AXI_USER_VALUE 	(C_M00_AXI_USER_VALUE  ),
  .C_M00_AXI_PROT_VALUE 	(C_M00_AXI_PROT_VALUE  ),
  .C_M00_AXI_CACHE_VALUE 	(C_M00_AXI_CACHE_VALUE ),
  .C_M00_AXI_ADDR_WIDTH 	( C_M00_AXI_ADDR_WIDTH ),
  .C_M00_AXI_DATA_WIDTH 	( C_M00_AXI_DATA_WIDTH )
)
u_matbi_dma_wrapper (
  .ap_clk             ( ap_clk                ),
  .ap_rst_n           ( ap_rst_n              ),
  .m00_axi_awvalid	  ( m00_axi_awvalid		  ),
  .m00_axi_awready	  ( m00_axi_awready		  ),
  .m00_axi_awaddr	  ( m00_axi_awaddr		  ),
  .m00_axi_awid		  ( m00_axi_awid		  ),
  .m00_axi_awlen	  ( m00_axi_awlen		  ),
  .m00_axi_awsize	  ( m00_axi_awsize		  ),
  .m00_axi_awburst	  ( m00_axi_awburst		  ),
  .m00_axi_awlock	  ( m00_axi_awlock		  ),
  .m00_axi_awcache	  ( m00_axi_awcache		  ),
  .m00_axi_awprot	  ( m00_axi_awprot		  ),
  .m00_axi_awqos	  ( m00_axi_awqos		  ),
  .m00_axi_awregion	  ( m00_axi_awregion	  ),
  .m00_axi_awuser	  ( m00_axi_awuser		  ),
  .m00_axi_wvalid	  ( m00_axi_wvalid		  ),
  .m00_axi_wready	  ( m00_axi_wready		  ),
  .m00_axi_wdata	  ( m00_axi_wdata		  ),
  .m00_axi_wstrb	  ( m00_axi_wstrb		  ),
  .m00_axi_wlast	  ( m00_axi_wlast		  ),
  .m00_axi_wid		  ( m00_axi_wid			  ),
  .m00_axi_wuser	  ( m00_axi_wuser		  ),
  .m00_axi_arvalid	  ( m00_axi_arvalid		  ),
  .m00_axi_arready	  ( m00_axi_arready		  ),
  .m00_axi_araddr	  ( m00_axi_araddr		  ),
  .m00_axi_arid		  ( m00_axi_arid		  ),
  .m00_axi_arlen	  ( m00_axi_arlen		  ),
  .m00_axi_arsize	  ( m00_axi_arsize		  ),
  .m00_axi_arburst	  ( m00_axi_arburst		  ),
  .m00_axi_arlock	  ( m00_axi_arlock		  ),
  .m00_axi_arcache	  ( m00_axi_arcache		  ),
  .m00_axi_arprot	  ( m00_axi_arprot		  ),
  .m00_axi_arqos	  ( m00_axi_arqos		  ),
  .m00_axi_arregion	  ( m00_axi_arregion	  ),
  .m00_axi_aruser	  ( m00_axi_aruser		  ),
  .m00_axi_rvalid	  ( m00_axi_rvalid		  ),
  .m00_axi_rready	  ( m00_axi_rready		  ),
  .m00_axi_rdata	  ( m00_axi_rdata		  ),
  .m00_axi_rlast	  ( m00_axi_rlast		  ),
  .m00_axi_rid		  ( m00_axi_rid			  ),
  .m00_axi_ruser	  ( m00_axi_ruser		  ),
  .m00_axi_rresp	  ( m00_axi_rresp		  ),
  .m00_axi_bvalid	  ( m00_axi_bvalid		  ),
  .m00_axi_bready	  ( m00_axi_bready		  ),
  .m00_axi_bresp	  ( m00_axi_bresp		  ),
  .m00_axi_bid		  ( m00_axi_bid			  ),
  .m00_axi_buser	  ( m00_axi_buser		  ),
  .ap_start           ( ap_start              ),
  .ap_done            ( ap_done               ),
  .ap_idle            ( ap_idle               ),
  .ap_ready           ( ap_ready              ),
  .rdma_transfer_byte ( rdma_transfer_byte    ),
  .rdma_mem_ptr       ( rdma_mem_ptr          ),
  .wdma_transfer_byte ( wdma_transfer_byte    ),
  .wdma_mem_ptr       ( wdma_mem_ptr          ),
  .axi00_ptr0         ( axi00_ptr0            ),
// stream I/F
  .out_r_din          ( out_r_din             ),
  .out_r_full_n       ( out_r_full_n          ),
  .out_r_write        ( out_r_write           ),
  .in_r_dout          ( in_r_dout             ),
  .in_r_empty_n       ( in_r_empty_n          ),
  .in_r_read          ( in_r_read             )
  );

`ifdef BYPASS_RDMA_TO_WDMA_DATA
matbi_sync_fifo 
# (
	.FIFO_IN_REG	(1),
	.FIFO_OUT_REG	(1),
	.FIFO_CMD_LENGTH(C_M00_AXI_DATA_WIDTH),
	.FIFO_DEPTH     (64),
	.FIFO_LOG2_DEPTH(6 + 1)
) u_matbi_sync_fifo (
	.clk			(ap_clk),
	.reset			(areset),

	.s_valid		(out_r_write	),
	.s_ready		(out_r_full_n	),
	.s_data			(out_r_din		),

	.m_valid		(in_r_empty_n	),
	.m_ready		(in_r_read		),
	.m_data			(in_r_dout		)
);

`else // If you use core, you'll fill code here~~
// TODO

wire [64-1:0] 		w_in_r_dout		                  ;
wire 				w_in_r_empty_n		              ;
wire				w_in_r_read		                  ;
	
matbi_axis_adder #(
  .C_AXIS_TDATA_WIDTH ( C_M00_AXI_DATA_WIDTH ) ,
  .C_ADDER_BIT_WIDTH  ( C_ADDER_BIT_WIDTH  ) ,
  .C_NUM_CLOCKS       ( 1                  )
)
inst_adder  (
  .s_axis_aclk   ( ap_clk                   		) ,
  .s_axis_areset ( areset                   		) ,
  .ctrl_constant ( value_to_add[C_ADDER_BIT_WIDTH-1:0]) ,
  .s_axis_tvalid ( out_r_write              		) ,
  .s_axis_tready ( out_r_full_n             		) ,
  .s_axis_tdata  ( out_r_din                		) ,
  .s_axis_tkeep	 ( 'b0								),
  .s_axis_tstrb	 ( {C_M00_AXI_DATA_WIDTH/8{1'b1}}	),
  .s_axis_tlast	 ( 'b0								),
  .s_axis_tid	 ( 'b0								),
  .s_axis_tdest	 ( 'b0								),
  .s_axis_tuser	 ( 'b0								),

  .m_axis_aclk   ( ap_clk                   		),
  .m_axis_tvalid ( w_in_r_empty_n             		),
  .m_axis_tready ( w_in_r_read	             		),
  .m_axis_tdata  ( w_in_r_dout                		),
  // unused signals
  .m_axis_tkeep	 (									),
  .m_axis_tstrb	 (									),
  .m_axis_tlast	 (									),
  .m_axis_tid	 (									),
  .m_axis_tdest	 (									),
  .m_axis_tuser	 (									)

);

matbi_sync_fifo 
# (
	.FIFO_IN_REG	(1),
	.FIFO_OUT_REG	(1),
	.FIFO_CMD_LENGTH(C_M00_AXI_DATA_WIDTH),
	.FIFO_DEPTH     (64),
	.FIFO_LOG2_DEPTH(6 + 1)
) u_matbi_sync_fifo (
	.clk			(ap_clk),
	.reset			(areset),

	.s_valid		(w_in_r_empty_n	),
	.s_ready		(w_in_r_read	),
	.s_data			(w_in_r_dout	),

	.m_valid		(in_r_empty_n	),
	.m_ready		(in_r_read		),
	.m_data			(in_r_dout		)
);


`endif
endmodule
