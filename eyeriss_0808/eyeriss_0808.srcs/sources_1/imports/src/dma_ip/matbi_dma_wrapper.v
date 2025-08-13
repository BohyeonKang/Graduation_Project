//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Create Date:
// Design Name: matbi_dma_wrapper
// Module Name: matbi_dma_wrapper
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

module matbi_dma_wrapper #(
  parameter integer C_M00_AXI_ID_WIDTH = 1,
  parameter integer C_M00_AXI_AWUSER_WIDTH = 1,
  parameter integer C_M00_AXI_ARUSER_WIDTH = 1,
  parameter integer C_M00_AXI_WUSER_WIDTH = 1,
  parameter integer C_M00_AXI_RUSER_WIDTH = 1,
  parameter integer C_M00_AXI_BUSER_WIDTH = 1,
  parameter integer C_M00_AXI_USER_VALUE = 0,
  parameter integer C_M00_AXI_PROT_VALUE = 0,
  parameter integer C_M00_AXI_CACHE_VALUE = 3,
  parameter integer C_M00_AXI_ADDR_WIDTH = 32,
  parameter integer C_M00_AXI_DATA_WIDTH = 32
)
(
  // System Signals
  input                                		ap_clk            ,
  input                                		ap_rst_n          ,
    // AXI4 master interface m00_axi
  output                                 	m00_axi_awvalid,
  input                                  	m00_axi_awready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_awaddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_awid,
  output  [7:0]                          	m00_axi_awlen,
  output  [2:0]                          	m00_axi_awsize,
  output  [1:0]                          	m00_axi_awburst,
  output  [1:0]                          	m00_axi_awlock,
  output  [3:0]                          	m00_axi_awcache,
  output  [2:0]                          	m00_axi_awprot,
  output  [3:0]                          	m00_axi_awqos,
  output  [3:0]                          	m00_axi_awregion,
  output  [C_M00_AXI_AWUSER_WIDTH - 1:0] 	m00_axi_awuser,
  output                                 	m00_axi_wvalid,
  input                                  	m00_axi_wready,
  output  [C_M00_AXI_DATA_WIDTH - 1:0]   	m00_axi_wdata,
  output  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 	m00_axi_wstrb,
  output                                 	m00_axi_wlast,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_wid,
  output  [C_M00_AXI_WUSER_WIDTH - 1:0]  	m00_axi_wuser,
  output                                 	m00_axi_arvalid,
  input                                  	m00_axi_arready,
  output  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_araddr,
  output  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_arid,
  output  [7:0]                          	m00_axi_arlen,
  output  [2:0]                          	m00_axi_arsize,
  output  [1:0]                          	m00_axi_arburst,
  output  [1:0]                          	m00_axi_arlock,
  output  [3:0]                          	m00_axi_arcache,
  output  [2:0]                          	m00_axi_arprot,
  output  [3:0]                          	m00_axi_arqos,
  output  [3:0]                          	m00_axi_arregion,
  output  [C_M00_AXI_ARUSER_WIDTH - 1:0] 	m00_axi_aruser,
  input                                  	m00_axi_rvalid,
  output                                 	m00_axi_rready,
  input  [C_M00_AXI_DATA_WIDTH - 1:0]    	m00_axi_rdata,
  input                                  	m00_axi_rlast,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_rid,
  input  [C_M00_AXI_RUSER_WIDTH - 1:0]   	m00_axi_ruser,
  input  [1:0]                           	m00_axi_rresp,
  input                                  	m00_axi_bvalid,
  output                                 	m00_axi_bready,
  input  [1:0]                           	m00_axi_bresp,
  input  [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_bid,
  input  [C_M00_AXI_BUSER_WIDTH - 1:0]   	m00_axi_buser,

  // Control Signals
  input                               		ap_start          ,
  output                              		ap_idle           ,
  output                              		ap_done           ,
  output                              		ap_ready          ,
  input  [32-1:0]                     		rdma_transfer_byte,
  input  [32-1:0]                     		rdma_mem_ptr      ,
  input  [32-1:0]                     		wdma_transfer_byte,
  input  [32-1:0]                     		wdma_mem_ptr      ,
  input  [32-1:0]                     		axi00_ptr0        ,

// Stream from RDMA
  output  [64-1:0] 					   		out_r_din		 ,
  input   							   		out_r_full_n	 ,
  output   							   		out_r_write		 ,
// Stream to WDMA
  input   [64-1:0] 					   		in_r_dout		 ,
  input   							   		in_r_empty_n	 ,
  output 							   		in_r_read		 
);

reg areset 		= 1'b0;
reg ap_start_r	= 1'b0;

wire ap_start_pulse;

wire  ap_start_rdma	;
wire  ap_done_rdma	; // no use
wire  ap_idle_rdma	; // no use
wire  ap_ready_rdma	; // no use

wire  ap_start_wdma	;
wire  ap_done_wdma	;
wire  ap_idle_wdma	;
wire  ap_ready_wdma	;

// make ap_ctrl_sig
// after power on, initial value is 0;
reg   r_ap_start_rdma	= 1'b0 ;
reg   r_ap_start_wdma	= 1'b0 ;

// Register and invert reset signal.
always @(posedge ap_clk) begin
	areset <= ~ap_rst_n;
end

// create pulse when ap_start transitions to 1
always @(posedge ap_clk) begin
  	begin
    	ap_start_r <= ap_start;
  	end
end

assign ap_start_pulse = ap_start & ~ap_start_r;

always @(posedge ap_clk) begin
	if (areset) begin
		r_ap_start_rdma <= 1'b0;
	end else if (ap_start_pulse) begin
		r_ap_start_rdma <= 1'b1;
	end else if (ap_ready_rdma) begin
		r_ap_start_rdma <= 1'b0;
  	end
end

always @(posedge ap_clk) begin
	if (areset) begin
		r_ap_start_wdma <= 1'b0;
	end else if (ap_start_pulse) begin
		r_ap_start_wdma <= 1'b1;
	end else if (ap_ready_wdma) begin
		r_ap_start_wdma <= 1'b0;
  	end
end

assign ap_idle	= ap_idle_wdma;          
assign ap_done	= ap_done_wdma;
assign ap_ready = ap_ready_wdma;          

matbi_hls_rdma u_matbi_hls_rdma(
	.ap_clk						(ap_clk				),
	.ap_rst_n					(ap_rst_n			),
	.ap_start					(r_ap_start_rdma	),
	.ap_done					(ap_done_rdma		),
	.ap_idle					(ap_idle_rdma		),
	.ap_ready					(ap_ready_rdma		),
// No use aw, w, b channel in rdma
	.m_axi_gmem_AWVALID			(					),
	.m_axi_gmem_AWREADY			('b0				),
	.m_axi_gmem_AWADDR			(					),
	.m_axi_gmem_AWID			(					),
	.m_axi_gmem_AWLEN			(					),
	.m_axi_gmem_AWSIZE			(					),
	.m_axi_gmem_AWBURST			(					),
	.m_axi_gmem_AWLOCK			(					),
	.m_axi_gmem_AWCACHE			(					),
	.m_axi_gmem_AWPROT			(					),
	.m_axi_gmem_AWQOS			(					),
	.m_axi_gmem_AWREGION		(					),
	.m_axi_gmem_AWUSER			(					),
	.m_axi_gmem_WVALID			(					),
	.m_axi_gmem_WREADY			('b0				),
	.m_axi_gmem_WDATA			(					),
	.m_axi_gmem_WSTRB			(					),
	.m_axi_gmem_WLAST			(					),
	.m_axi_gmem_WID				(					),
	.m_axi_gmem_WUSER			(					),

	.m_axi_gmem_ARVALID			(m00_axi_arvalid	),
	.m_axi_gmem_ARREADY			(m00_axi_arready	),
	.m_axi_gmem_ARADDR			(m00_axi_araddr		),
	.m_axi_gmem_ARID			(m00_axi_arid		),
	.m_axi_gmem_ARLEN			(m00_axi_arlen		),
	.m_axi_gmem_ARSIZE			(m00_axi_arsize		),
	.m_axi_gmem_ARBURST			(m00_axi_arburst	),
	.m_axi_gmem_ARLOCK			(m00_axi_arlock		),
	.m_axi_gmem_ARCACHE			(m00_axi_arcache	),
	.m_axi_gmem_ARPROT			(m00_axi_arprot		),
	.m_axi_gmem_ARQOS			(m00_axi_arqos		),
	.m_axi_gmem_ARREGION		(m00_axi_arregion	),
	.m_axi_gmem_ARUSER			(m00_axi_aruser		),
	.m_axi_gmem_RVALID			(m00_axi_rvalid		),
	.m_axi_gmem_RREADY			(m00_axi_rready		),
	.m_axi_gmem_RDATA			(m00_axi_rdata		),
	.m_axi_gmem_RLAST			(m00_axi_rlast		),
	.m_axi_gmem_RID				('b0				),
	.m_axi_gmem_RUSER			('b0				),
	.m_axi_gmem_RRESP			('b0				),

	.m_axi_gmem_BVALID			('b0				),
	.m_axi_gmem_BREADY			(					),
	.m_axi_gmem_BRESP			('b0				),
	.m_axi_gmem_BID				('b0				),
	.m_axi_gmem_BUSER			('b0				),
	.tranfer_byte				(rdma_transfer_byte	),
	.mem						(rdma_mem_ptr		),
	.out_r_din					(out_r_din			),
	.out_r_full_n				(out_r_full_n		),
	.out_r_write				(out_r_write		)
);

matbi_hls_wdma u_matbi_hls_wdma(
	.ap_clk						(ap_clk				),
	.ap_rst_n					(ap_rst_n			),
	.ap_start					(r_ap_start_wdma	),
	.ap_done					(ap_done_wdma		),
	.ap_idle					(ap_idle_wdma		),
	.ap_ready					(ap_ready_wdma		),

// No use ar, r channel in wdma
	.m_axi_gmem_AWVALID			(m00_axi_awvalid	),
	.m_axi_gmem_AWREADY			(m00_axi_awready	),
	.m_axi_gmem_AWADDR			(m00_axi_awaddr		),
	.m_axi_gmem_AWID			(m00_axi_awid		),
	.m_axi_gmem_AWLEN			(m00_axi_awlen		),
	.m_axi_gmem_AWSIZE			(m00_axi_awsize		),
	.m_axi_gmem_AWBURST			(m00_axi_awburst	),
	.m_axi_gmem_AWLOCK			(m00_axi_awlock		),
	.m_axi_gmem_AWCACHE			(m00_axi_awcache	),
	.m_axi_gmem_AWPROT			(m00_axi_awprot		),
	.m_axi_gmem_AWQOS			(m00_axi_awqos		),
	.m_axi_gmem_AWREGION		(m00_axi_awregion	),
	.m_axi_gmem_AWUSER			(m00_axi_awuser		),
	.m_axi_gmem_WVALID			(m00_axi_wvalid		),
	.m_axi_gmem_WREADY			(m00_axi_wready		),
	.m_axi_gmem_WDATA			(m00_axi_wdata		),
	.m_axi_gmem_WSTRB			(m00_axi_wstrb		),
	.m_axi_gmem_WLAST			(m00_axi_wlast		),
	.m_axi_gmem_WID				(m00_axi_wid		),
	.m_axi_gmem_WUSER			(m00_axi_wuser		),

	.m_axi_gmem_ARVALID			(					),
	.m_axi_gmem_ARREADY			('b0				),
	.m_axi_gmem_ARADDR			(					),
	.m_axi_gmem_ARID			(					),
	.m_axi_gmem_ARLEN			(					),
	.m_axi_gmem_ARSIZE			(					),
	.m_axi_gmem_ARBURST			(					),
	.m_axi_gmem_ARLOCK			(					),
	.m_axi_gmem_ARCACHE			(					),
	.m_axi_gmem_ARPROT			(					),
	.m_axi_gmem_ARQOS			(					),
	.m_axi_gmem_ARREGION		(					),
	.m_axi_gmem_ARUSER			(					),
	.m_axi_gmem_RVALID			('b0				),
	.m_axi_gmem_RREADY			(					),
	.m_axi_gmem_RDATA			('b0				),
	.m_axi_gmem_RLAST			('b0				),
	.m_axi_gmem_RID				('b0				),
	.m_axi_gmem_RUSER			('b0				),
	.m_axi_gmem_RRESP			('b0				),

	.m_axi_gmem_BVALID			(m00_axi_bvalid		),
	.m_axi_gmem_BREADY			(m00_axi_bready		),
	.m_axi_gmem_BRESP			(m00_axi_bresp		),
	.m_axi_gmem_BID				(m00_axi_bid	 	),
	.m_axi_gmem_BUSER			(m00_axi_buser		),
	.tranfer_byte				(wdma_transfer_byte	),
	.in_r_dout					(in_r_dout			),
	.in_r_empty_n				(in_r_empty_n		),
	.in_r_read					(in_r_read			),
	.mem						(wdma_mem_ptr		)
);

endmodule : matbi_dma_wrapper
