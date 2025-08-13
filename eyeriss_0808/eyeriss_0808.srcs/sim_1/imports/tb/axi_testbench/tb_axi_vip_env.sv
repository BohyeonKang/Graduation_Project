// Testbench environment for verifying a DMA IP using AXI VIPs.
// Purpose:
//  - Drive DUT control registers via AXI4-Lite Master VIP (ctrl).
//  - Emulate external memory with AXI4 Slave Memory VIP (m00_axi).
//  - Sequence: clock/reset → start VIPs → init memory (backdoor) → program DUT
//    → start (ap_start) → poll done/idle → read back and compare → report result.
// Dependencies: axi_vip_pkg, slv_m00_axi_vip_pkg, mst_s00_axi_lite_vip_pkg.

`timescale 1 ns / 1 ps
import axi_vip_pkg::*;
import slv_m00_axi_vip_pkg::*;
import mst_s00_axi_lite_vip_pkg::*;

module tb_axi_vip_env ();

parameter C_S_AXI_CONTROL_ADDR_WIDTH      = 12;
parameter C_S_AXI_CONTROL_DATA_WIDTH      = 32;
parameter C_M00_AXI_ADDR_WIDTH            = 32;
parameter C_M00_AXI_DATA_WIDTH            = 32;
parameter C_M00_AXI_DATA_WIDTH_BYTE       = C_M00_AXI_DATA_WIDTH/8;
parameter C_M00_AXI_DATA_WIDTH_BYTE_LOG   = $clog2(C_M00_AXI_DATA_WIDTH_BYTE);
parameter C_M00_AXI_ID_WIDTH     = 1;
parameter C_M00_AXI_AWUSER_WIDTH = 1;
parameter C_M00_AXI_ARUSER_WIDTH = 1;
parameter C_M00_AXI_WUSER_WIDTH  = 1;
parameter C_M00_AXI_RUSER_WIDTH  = 1;
parameter C_M00_AXI_BUSER_WIDTH  = 1;
parameter C_M00_AXI_USER_VALUE   = 0;
parameter C_M00_AXI_PROT_VALUE   = 0;
parameter C_M00_AXI_CACHE_VALUE  = 3;


// User input Param
parameter USER_TRANSFER_LEN               = 32'd1024;
parameter USER_RDMA_ADDR                  = 32'd0;

// MATBI DMA IP REG MAP
parameter ADDR_AP_CTRL                    = 6'h00;
parameter ADDR_GIE                        = 6'h04;
parameter ADDR_IER                        = 6'h08;
parameter ADDR_ISR                        = 6'h0c;
parameter ADDR_RDMA_TRANSFER_BYTE_DATA_0  = 6'h10;
parameter ADDR_RDMA_MEM_PTR_DATA_0        = 6'h14;
parameter ADDR_WDMA_TRANSFER_BYTE_DATA_0  = 6'h18;
parameter ADDR_WDMA_MEM_PTR_DATA_0        = 6'h1c;
parameter ADDR_AXI00_PTR0_DATA_0          = 6'h20;
parameter ADDR_VALUE_TO_ADD	           	  = 6'h24;

// Control Register
parameter KRNL_CTRL_REG_ADDR              = 32'h00000000;
parameter CTRL_START_MASK                 = 32'h00000001;
parameter CTRL_DONE_MASK                  = 32'h00000002;
parameter CTRL_IDLE_MASK                  = 32'h00000004;
parameter CTRL_READY_MASK                 = 32'h00000008;
parameter CTRL_CONTINUE_MASK              = 32'h00000010; // Only ap_ctrl_chain
parameter CTRL_AUTO_RESTART_MASK          = 32'h00000080; // Not used

parameter LP_CLK_PERIOD_PS = 10000; // 100 MHz

//System Signals
logic ap_clk = 0;

initial begin: AP_CLK
  forever begin
    ap_clk = #(LP_CLK_PERIOD_PS/2) ~ap_clk;
  end
end
 
//System Signals
logic ap_rst_n = 0;
logic initial_reset  =0;

task automatic ap_rst_n_sequence(input integer unsigned width = 20);
  @(posedge ap_clk);
  #1ps;
  ap_rst_n = 0;
  repeat (width) @(posedge ap_clk);
  #1ps;
  ap_rst_n = 1;
endtask

initial begin: AP_RST
  ap_rst_n_sequence(50);
  initial_reset =1;
end
//AXI4 master interface m00_axi
wire                                 	m00_axi_awvalid;
wire                                 	m00_axi_awready;
wire  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_awaddr;
wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_awid;
wire  [7:0]                          	m00_axi_awlen;
wire  [2:0]                          	m00_axi_awsize;
wire  [1:0]                          	m00_axi_awburst;
wire  [1:0]                          	m00_axi_awlock;
wire  [3:0]                          	m00_axi_awcache;
wire  [2:0]                          	m00_axi_awprot;
wire  [3:0]                          	m00_axi_awqos;
wire  [3:0]                          	m00_axi_awregion;
wire  [C_M00_AXI_AWUSER_WIDTH - 1:0] 	m00_axi_awuser;
wire                                 	m00_axi_wvalid;
wire                                 	m00_axi_wready;
wire  [C_M00_AXI_DATA_WIDTH - 1:0]   	m00_axi_wdata;
wire  [C_M00_AXI_DATA_WIDTH/8 - 1:0] 	m00_axi_wstrb;
wire                                 	m00_axi_wlast;
wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_wid;
wire  [C_M00_AXI_WUSER_WIDTH - 1:0]  	m00_axi_wuser;
wire                                 	m00_axi_arvalid;
wire                                 	m00_axi_arready;
wire  [C_M00_AXI_ADDR_WIDTH - 1:0]   	m00_axi_araddr;
wire  [C_M00_AXI_ID_WIDTH - 1:0]     	m00_axi_arid;
wire  [7:0]                          	m00_axi_arlen;
wire  [2:0]                          	m00_axi_arsize;
wire  [1:0]                          	m00_axi_arburst;
wire  [1:0]                          	m00_axi_arlock;
wire  [3:0]                          	m00_axi_arcache;
wire  [2:0]                          	m00_axi_arprot;
wire  [3:0]                          	m00_axi_arqos;
wire  [3:0]                          	m00_axi_arregion;
wire  [C_M00_AXI_ARUSER_WIDTH - 1:0] 	m00_axi_aruser;
wire                                 	m00_axi_rvalid;
wire                                 	m00_axi_rready;
wire [C_M00_AXI_DATA_WIDTH - 1:0]    	m00_axi_rdata;
wire                                 	m00_axi_rlast;
wire [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_rid;
wire [C_M00_AXI_RUSER_WIDTH - 1:0]   	m00_axi_ruser;
wire [1:0]                           	m00_axi_rresp;
wire                                 	m00_axi_bvalid;
wire                                 	m00_axi_bready;
wire [1:0]                           	m00_axi_bresp;
wire [C_M00_AXI_ID_WIDTH - 1:0]      	m00_axi_bid;
wire [C_M00_AXI_BUSER_WIDTH - 1:0]   	m00_axi_buser;

wire [1-1:0] s_axi_control_awvalid;
wire [1-1:0] s_axi_control_awready;
wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_awaddr;
wire [1-1:0] s_axi_control_wvalid;
wire [1-1:0] s_axi_control_wready;
wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_wdata;
wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb;
wire [1-1:0] s_axi_control_arvalid;
wire [1-1:0] s_axi_control_arready;
wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0] s_axi_control_araddr;
wire [1-1:0] s_axi_control_rvalid;
wire [1-1:0] s_axi_control_rready;
wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0] s_axi_control_rdata;
wire [2-1:0] s_axi_control_rresp;
wire [1-1:0] s_axi_control_bvalid;
wire [1-1:0] s_axi_control_bready;
wire [2-1:0] s_axi_control_bresp;
wire interrupt;


// DUT instantiation
axi_lite_slave u_axi_lite_slave (
    // Clock & Reset
    .ACLK    (ap_clk),          // input  wire
    .ARESETn (ap_rst_n),         // input  wire, active-low

    // Write address channel
    .AWADDR  (s_axi_control_awaddr),   // input  wire [31:0]
    .AWVALID (s_axi_control_awvalid),  // input  wire
    .AWREADY (s_axi_control_awready),  // output reg

    // Write data channel
    .WDATA   (s_axi_control_wdata),    // input  wire [31:0]
    .WSTRB   (s_axi_control_wstrb),    // input  wire [3:0]
    .WVALID  (s_axi_control_wvalid),   // input  wire
    .WREADY  (s_axi_control_wready),   // output reg

    // Write response channel
    .BRESP   (s_axi_control_bresp),    // output reg [1:0]
    .BVALID  (s_axi_control_bvalid),   // output reg
    .BREADY  (s_axi_control_bready),   // input  wire

    // Read address channel
    .ARADDR  (s_axi_control_araddr),   // input  wire [31:0]
    .ARVALID (s_axi_control_arvalid),  // input  wire
    .ARREADY (s_axi_control_arready),  // output reg

    // Read data channel
    .RDATA   (s_axi_control_rdata),    // output reg [31:0]
    .RRESP   (s_axi_control_rresp),    // output reg [1:0]
    .RVALID  (s_axi_control_rvalid),   // output reg
    .RREADY  (s_axi_control_rready)    // input  wire
);
/*
matbi_dma_ip_top #(
  .C_S_AXI_CONTROL_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_CONTROL_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH ),
  .C_M00_AXI_ID_WIDTH 		  ( C_M00_AXI_ID_WIDTH    	   ),
  .C_M00_AXI_AWUSER_WIDTH 	  ( C_M00_AXI_AWUSER_WIDTH	   ),
  .C_M00_AXI_ARUSER_WIDTH 	  ( C_M00_AXI_ARUSER_WIDTH	   ),
  .C_M00_AXI_WUSER_WIDTH 	  ( C_M00_AXI_WUSER_WIDTH 	   ),
  .C_M00_AXI_RUSER_WIDTH 	  ( C_M00_AXI_RUSER_WIDTH 	   ),
  .C_M00_AXI_BUSER_WIDTH 	  ( C_M00_AXI_BUSER_WIDTH 	   ),
  .C_M00_AXI_USER_VALUE 	  ( C_M00_AXI_USER_VALUE  	   ),
  .C_M00_AXI_PROT_VALUE 	  ( C_M00_AXI_PROT_VALUE  	   ),
  .C_M00_AXI_CACHE_VALUE 	  ( C_M00_AXI_CACHE_VALUE 	   ),
  .C_M00_AXI_ADDR_WIDTH       ( C_M00_AXI_ADDR_WIDTH       ),
  .C_M00_AXI_DATA_WIDTH       ( C_M00_AXI_DATA_WIDTH       )
)
inst_dut (
  .ap_clk                ( ap_clk                ),
  .ap_rst_n              ( ap_rst_n              ),
  .m00_axi_awvalid	  	 ( m00_axi_awvalid		 ),
  .m00_axi_awready	  	 ( m00_axi_awready		 ),
  .m00_axi_awaddr	  	 ( m00_axi_awaddr		 ),
  .m00_axi_awid		  	 ( m00_axi_awid		  	 ),
  .m00_axi_awlen	  	 ( m00_axi_awlen		 ),
  .m00_axi_awsize	  	 ( m00_axi_awsize		 ),
  .m00_axi_awburst	  	 ( m00_axi_awburst		 ),
  .m00_axi_awlock	  	 ( m00_axi_awlock		 ),
  .m00_axi_awcache	  	 ( m00_axi_awcache		 ),
  .m00_axi_awprot	  	 ( m00_axi_awprot		 ),
  .m00_axi_awqos	  	 ( m00_axi_awqos		 ),
  .m00_axi_awregion	  	 ( m00_axi_awregion	  	 ),
  .m00_axi_awuser	  	 ( m00_axi_awuser		 ),
  .m00_axi_wvalid	  	 ( m00_axi_wvalid		 ),
  .m00_axi_wready	  	 ( m00_axi_wready		 ),
  .m00_axi_wdata	  	 ( m00_axi_wdata		 ),
  .m00_axi_wstrb	  	 ( m00_axi_wstrb		 ),
  .m00_axi_wlast	  	 ( m00_axi_wlast		 ),
  .m00_axi_wid		  	 ( m00_axi_wid			 ),
  .m00_axi_wuser	  	 ( m00_axi_wuser		 ),
  .m00_axi_arvalid	  	 ( m00_axi_arvalid		 ),
  .m00_axi_arready	  	 ( m00_axi_arready		 ),
  .m00_axi_araddr	  	 ( m00_axi_araddr		 ),
  .m00_axi_arid		  	 ( m00_axi_arid		  	 ),
  .m00_axi_arlen	  	 ( m00_axi_arlen		 ),
  .m00_axi_arsize	  	 ( m00_axi_arsize		 ),
  .m00_axi_arburst	  	 ( m00_axi_arburst		 ),
  .m00_axi_arlock	  	 ( m00_axi_arlock		 ),
  .m00_axi_arcache	  	 ( m00_axi_arcache		 ),
  .m00_axi_arprot	  	 ( m00_axi_arprot		 ),
  .m00_axi_arqos	  	 ( m00_axi_arqos		 ),
  .m00_axi_arregion	  	 ( m00_axi_arregion	  	 ),
  .m00_axi_aruser	  	 ( m00_axi_aruser		 ),
  .m00_axi_rvalid	  	 ( m00_axi_rvalid		 ),
  .m00_axi_rready	  	 ( m00_axi_rready		 ),
  .m00_axi_rdata	  	 ( m00_axi_rdata		 ),
  .m00_axi_rlast	  	 ( m00_axi_rlast		 ),
  .m00_axi_rid		  	 ( m00_axi_rid			 ),
  .m00_axi_ruser	  	 ( m00_axi_ruser		 ),
  .m00_axi_rresp	  	 ( m00_axi_rresp		 ),
  .m00_axi_bvalid	  	 ( m00_axi_bvalid		 ),
  .m00_axi_bready	  	 ( m00_axi_bready		 ),
  .m00_axi_bresp	  	 ( m00_axi_bresp		 ),
  .m00_axi_bid		  	 ( m00_axi_bid			 ),
  .m00_axi_buser	  	 ( m00_axi_buser		 ),
  .s_axi_control_awvalid ( s_axi_control_awvalid ),
  .s_axi_control_awready ( s_axi_control_awready ),
  .s_axi_control_awaddr  ( s_axi_control_awaddr  ),
  .s_axi_control_wvalid  ( s_axi_control_wvalid  ),
  .s_axi_control_wready  ( s_axi_control_wready  ),
  .s_axi_control_wdata   ( s_axi_control_wdata   ),
  .s_axi_control_wstrb   ( s_axi_control_wstrb   ),
  .s_axi_control_arvalid ( s_axi_control_arvalid ),
  .s_axi_control_arready ( s_axi_control_arready ),
  .s_axi_control_araddr  ( s_axi_control_araddr  ),
  .s_axi_control_rvalid  ( s_axi_control_rvalid  ),
  .s_axi_control_rready  ( s_axi_control_rready  ),
  .s_axi_control_rdata   ( s_axi_control_rdata   ),
  .s_axi_control_rresp   ( s_axi_control_rresp   ),
  .s_axi_control_bvalid  ( s_axi_control_bvalid  ),
  .s_axi_control_bready  ( s_axi_control_bready  ),
  .s_axi_control_bresp   ( s_axi_control_bresp   ),
  .interrupt             ( interrupt             )
);
*/

// Master Control instantiation
mst_s00_axi_lite_vip u_mst_s00_axi_lite_vip (
  .aclk          ( ap_clk                ),
  .aresetn       ( ap_rst_n              ),
  .m_axi_awvalid ( s_axi_control_awvalid ),
  .m_axi_awready ( s_axi_control_awready ),
  .m_axi_awaddr  ( s_axi_control_awaddr  ),
  .m_axi_wvalid  ( s_axi_control_wvalid  ),
  .m_axi_wready  ( s_axi_control_wready  ),
  .m_axi_wdata   ( s_axi_control_wdata   ),
  .m_axi_wstrb   ( s_axi_control_wstrb   ),
  .m_axi_arvalid ( s_axi_control_arvalid ),
  .m_axi_arready ( s_axi_control_arready ),
  .m_axi_araddr  ( s_axi_control_araddr  ),
  .m_axi_rvalid  ( s_axi_control_rvalid  ),
  .m_axi_rready  ( s_axi_control_rready  ),
  .m_axi_rdata   ( s_axi_control_rdata   ),
  .m_axi_rresp   ( s_axi_control_rresp   ),
  .m_axi_bvalid  ( s_axi_control_bvalid  ),
  .m_axi_bready  ( s_axi_control_bready  ),
  .m_axi_bresp   ( s_axi_control_bresp   )
);

axi_lite_master_t  ctrl;

// Slave MM VIP instantiation
// only use 64b addr
slv_m00_axi_vip #(
  .C_S_AXI_ID_WIDTH 		  ( C_M00_AXI_ID_WIDTH    	   ),
  .C_S_AXI_AWUSER_WIDTH 	  ( C_M00_AXI_AWUSER_WIDTH	   ),
  .C_S_AXI_ARUSER_WIDTH 	  ( C_M00_AXI_ARUSER_WIDTH	   ),
  .C_S_AXI_WUSER_WIDTH 	  	  ( C_M00_AXI_WUSER_WIDTH 	   ),
  .C_S_AXI_RUSER_WIDTH 	  	  ( C_M00_AXI_RUSER_WIDTH 	   ),
  .C_S_AXI_BUSER_WIDTH 	  	  ( C_M00_AXI_BUSER_WIDTH 	   ),
  .C_S_AXI_USER_VALUE 	  	  ( C_M00_AXI_USER_VALUE  	   ),
  .C_S_AXI_PROT_VALUE 	  	  ( C_M00_AXI_PROT_VALUE  	   ),
  .C_S_AXI_CACHE_VALUE 	  	  ( C_M00_AXI_CACHE_VALUE 	   ),
  .C_S_AXI_ADDR_WIDTH         ( C_M00_AXI_ADDR_WIDTH       ),
  .C_S_AXI_DATA_WIDTH         ( C_M00_AXI_DATA_WIDTH       )
)
u_slv_m00_axi_vip (  
  .aclk          				( ap_clk          	),
  .aresetn       				( ap_rst_n        	),

  .s_axi_awvalid	  	 		( m00_axi_awvalid	),
  .s_axi_awready	  	 		( m00_axi_awready	),
  .s_axi_awaddr	  	 			( m00_axi_awaddr	),
  .s_axi_awid		  	 		( m00_axi_awid		),
  .s_axi_awlen	  	 			( m00_axi_awlen		),
  .s_axi_awsize	  	 			( m00_axi_awsize	),
  .s_axi_awburst	 	 	 	( m00_axi_awburst	),
  .s_axi_awlock	  	 			( m00_axi_awlock	),
  .s_axi_awcache	 			( m00_axi_awcache	),
  .s_axi_awprot	  	 			( m00_axi_awprot	),
  .s_axi_awqos	  	 			( m00_axi_awqos		),
  .s_axi_awregion	 			( m00_axi_awregion	),
  .s_axi_awuser	  	 			( m00_axi_awuser	),
  .s_axi_wvalid	  	 			( m00_axi_wvalid	),
  .s_axi_wready	  	 			( m00_axi_wready	),
  .s_axi_wdata	  	 			( m00_axi_wdata		),
  .s_axi_wstrb	  	 			( m00_axi_wstrb		),
  .s_axi_wlast	  	 			( m00_axi_wlast		),
  .s_axi_wid		 			( m00_axi_wid		),
  .s_axi_wuser	  	 			( m00_axi_wuser		),
  .s_axi_arvalid	 			( m00_axi_arvalid	),
  .s_axi_arready	 			( m00_axi_arready	),
  .s_axi_araddr	  	 			( m00_axi_araddr	),
  .s_axi_arid		 			( m00_axi_arid		),
  .s_axi_arlen	  	 			( m00_axi_arlen		),
  .s_axi_arsize	  	 			( m00_axi_arsize	),
  .s_axi_arburst	 			( m00_axi_arburst	),
  .s_axi_arlock	  	 			( m00_axi_arlock	),
  .s_axi_arcache	 			( m00_axi_arcache	),
  .s_axi_arprot	  	 			( m00_axi_arprot	),
  .s_axi_arqos	  	 			( m00_axi_arqos		),
  .s_axi_arregion	 			( m00_axi_arregion	),
  .s_axi_aruser	  	 			( m00_axi_aruser	),
  .s_axi_rvalid	  	 			( m00_axi_rvalid	),
  .s_axi_rready	  	 			( m00_axi_rready	),
  .s_axi_rdata	  	 			( m00_axi_rdata		),
  .s_axi_rlast	  	 			( m00_axi_rlast		),
  .s_axi_rid		 			( m00_axi_rid		),
  .s_axi_ruser	  	 			( m00_axi_ruser		),
  .s_axi_rresp	  	 			( m00_axi_rresp		),
  .s_axi_bvalid	  	 			( m00_axi_bvalid	),
  .s_axi_bready	  	 			( m00_axi_bready	),
  .s_axi_bresp	  	 			( m00_axi_bresp		),
  .s_axi_bid		 			( m00_axi_bid		),
  .s_axi_buser	  	 			( m00_axi_buser		)
);

slv_m00_axi_vip_slv_mem_t   m00_axi;

/////// Control interface blocking write
/////// The task will return when the BRESP has been returned from the kernel.
task automatic blocking_write_register (input bit [31:0] addr_in, input bit [31:0] data);
  axi_transaction   wr_xfer;
  axi_transaction   wr_rsp;
  wr_xfer = ctrl.wr_driver.create_transaction("wr_xfer");
  wr_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  assert(wr_xfer.randomize() with {addr == addr_in;});
  wr_xfer.set_data_beat(0, data);
  ctrl.wr_driver.send(wr_xfer);
  ctrl.wr_driver.wait_rsp(wr_rsp);
endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Control interface blocking read
// The task will return when the BRESP has been returned from the kernel.
task automatic read_register (input bit [31:0] addr, output bit [31:0] rddata);
  axi_transaction   rd_xfer;
  axi_transaction   rd_rsp;
  bit [31:0] rd_value;
  rd_xfer = ctrl.rd_driver.create_transaction("rd_xfer");
  rd_xfer.set_addr(addr);
  rd_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  ctrl.rd_driver.send(rd_xfer);
  ctrl.rd_driver.wait_rsp(rd_rsp);
  rd_value = rd_rsp.get_data_beat(0);
  rddata = rd_value;
endtask

task backdoor_memory_write_byte (
	input int unsigned addr,
	input byte    unsigned data 
);
	int unsigned aligned_offset;
	bit [C_M00_AXI_DATA_WIDTH-1:0] 			bus_data;
	bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;

	bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];

	bus_data       = bus_data + (data << (8*aligned_offset));
	bus_strb       = bus_strb + (1'b1 << aligned_offset);
	m00_axi.mem_model.backdoor_memory_write({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
endtask


task backdoor_memory_read_byte (
	input int unsigned addr,
	output byte   unsigned data 
);
	int unsigned aligned_offset;
	bit [C_M00_AXI_DATA_WIDTH-1:0] 			bus_data;
	bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;

	bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];

	bus_data = m00_axi.mem_model.backdoor_memory_read({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}});
	data = bus_data[(8*aligned_offset) +: 8];
endtask


/////////////////////////////////////////////////////////////////////////////////////////////////
// Start the control VIP, SLAVE memory models and AXI4-Stream.
//`define RANDOM_TRANSACTION
task automatic start_vips();
  axi_ready_gen     rgen;
  $display("///////////////////////////////////////////////////////////////////////////");
  $display("Control Master: ctrl");
  ctrl = new("ctrl", tb_axi_vip_env.u_mst_s00_axi_lite_vip.inst.IF);
  ctrl.start_master();

  $display("///////////////////////////////////////////////////////////////////////////");
  $display("Starting Memory slave: m00_axi");
  m00_axi = new("m00_axi", tb_axi_vip_env.u_slv_m00_axi_vip.inst.IF);
`ifdef RANDOM_TRANSACTION
  $display("MATBI random transaction for checking DMA controller :) ");
  rgen = new("m00_axi_random transaction"); 
  m00_axi.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
  m00_axi.mem_model.set_inter_beat_gap_range(0,10);
`else
  $display("MATBI Ideal Case. for checking best performance :)");
  rgen = new("m00_axi_no_backpressure_allready"); 
  rgen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
  m00_axi.wr_driver.set_wready_gen(rgen);
  m00_axi.wr_driver.set_awready_gen(rgen);
  m00_axi.rd_driver.set_arready_gen(rgen);
`endif
/////////
 m00_axi.start_slave();

endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Main Function
/////////////////////////////////////////////////////////////////////////////////////////////////
initial begin : STIMULUS
  bit [31:0] lite_rddata;
  bit [31:0] mask_data;
  bit [31:0] adding_value; // TODO Added
  byte unsigned ret_rd_value;
  byte unsigned ret_wr_value;
  bit error_found;
  integer error_counter;

  adding_value = 'd1; // TODO Added
  ret_rd_value = 'd0;
  ret_wr_value = 'd0;
  error_found = 'd0;
  error_counter = 'd0;
  #200;
  $display( "================================================");
  $display( "=====TestBench for verification AMBA System=====");
  $display( "================================================");
  start_vips();

  for (longint unsigned slot = 0; slot < USER_TRANSFER_LEN; slot = slot+1) begin
    ret_wr_value = slot;
    backdoor_memory_write_byte(USER_RDMA_ADDR + slot, ret_wr_value);
  end

  blocking_write_register(ADDR_AXI00_PTR0_DATA_0, 32'd0); // baseaddr is 0.
  blocking_write_register(ADDR_RDMA_TRANSFER_BYTE_DATA_0, USER_TRANSFER_LEN);
  blocking_write_register(ADDR_RDMA_MEM_PTR_DATA_0, USER_RDMA_ADDR);

  blocking_write_register(ADDR_WDMA_TRANSFER_BYTE_DATA_0, USER_TRANSFER_LEN);
  blocking_write_register(ADDR_WDMA_MEM_PTR_DATA_0, USER_RDMA_ADDR + USER_TRANSFER_LEN);

  blocking_write_register(ADDR_VALUE_TO_ADD, adding_value); // adding value

  // start. polling
  // 1. check idle 
  while(1) begin
    read_register(ADDR_AP_CTRL, lite_rddata); // addr / data
    $display( "ADDR_AP_CTRL check idle (hex) : %x", lite_rddata);
    if( (lite_rddata & CTRL_IDLE_MASK) == 32'b100) // IDLE
      break;
  end
  // 2. ap_start
  blocking_write_register(ADDR_AP_CTRL, 32'b1); // start!
  // 3. wait done.
  while(1) begin
    read_register(ADDR_AP_CTRL, lite_rddata); // addr / data
    $display( "ADDR_AP_CTRL wait done (hex) : %x", lite_rddata);
    if( (lite_rddata & CTRL_DONE_MASK) == 32'b10) // DONE
      break;
  end

  for (longint unsigned slot = 0; slot < USER_TRANSFER_LEN; slot = slot+1) begin
    backdoor_memory_read_byte(USER_RDMA_ADDR + USER_TRANSFER_LEN + slot, ret_rd_value);
    ret_wr_value = slot + adding_value;
    if(ret_rd_value != ret_wr_value) begin
        $error("Memory Mismatch: m00_axi : @0x%x : Expected 0x%x -> Got 0x%x ", USER_RDMA_ADDR + USER_TRANSFER_LEN + slot, ret_wr_value, ret_rd_value, );
        error_found |= 1;
        error_counter++;
    end
    else begin // Match. If you want to check read data from external memory.
//        $display("Memory Match: m00_axi : @0x%x : Expected 0x%x -> Got 0x%x ", USER_RDMA_ADDR + USER_TRANSFER_LEN + slot, slot/4, ret_rd_value);
    end
  end

  $display( "================================================");
  $display( "==============Finish Simulation!!===============");
  $display( "================================================");
  $finish;
end

endmodule
