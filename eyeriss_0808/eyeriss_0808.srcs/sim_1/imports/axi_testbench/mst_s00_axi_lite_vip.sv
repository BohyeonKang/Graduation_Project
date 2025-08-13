//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Create Date:
// Design Name: mst_s00_axi_lite_vip
// Module Name: mst_s00_axi_lite_vip
// Project Name:
// Target Devices: Zybo Z7-20
// Tool Versions:
// Description: AXI4-Lite MASTER VIP wrapper (targets DUT's S00 AXI-Lite slave)
// Dependencies: axi_vip_v1_1_11_top
//
// Revision:
// Revision 0.01 - File Renamed/Refactored
// Additional Comments:
//   - Ensure C_AXI_INTERFACE_MODE matches MASTER for your Vivado version.
//     (Some versions use 0=MASTER, others 1=MASTER. Adjust if needed.)
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module mst_s00_axi_lite_vip (
  input  wire        aclk,
  input  wire        aresetn,

  // AXI4-Lite Master (connect to DUT S00 AXI-Lite slave)
  output wire [11:0] m_axi_awaddr,
  output wire        m_axi_awvalid,
  input  wire        m_axi_awready,

  output wire [31:0] m_axi_wdata,
  output wire [3:0]  m_axi_wstrb,
  output wire        m_axi_wvalid,
  input  wire        m_axi_wready,

  input  wire [1:0]  m_axi_bresp,
  input  wire        m_axi_bvalid,
  output wire        m_axi_bready,

  output wire [11:0] m_axi_araddr,
  output wire        m_axi_arvalid,
  input  wire        m_axi_arready,

  input  wire [31:0] m_axi_rdata,
  input  wire [1:0]  m_axi_rresp,
  input  wire        m_axi_rvalid,
  output wire        m_axi_rready
);

  // AXI VIP core instance (configured as AXI4-Lite MASTER)
  axi_vip_v1_1_11_top #(
    .C_AXI_PROTOCOL       (2),    // 2 = AXI4-Lite
    .C_AXI_INTERFACE_MODE (0),    // MASTER (change to 0 if your Vivado maps 0=MASTER)
    .C_AXI_ADDR_WIDTH     (12),
    .C_AXI_WDATA_WIDTH    (32),
    .C_AXI_RDATA_WIDTH    (32),
    .C_AXI_WID_WIDTH      (0),
    .C_AXI_RID_WIDTH      (0),
    .C_AXI_AWUSER_WIDTH   (0),
    .C_AXI_ARUSER_WIDTH   (0),
    .C_AXI_WUSER_WIDTH    (0),
    .C_AXI_RUSER_WIDTH    (0),
    .C_AXI_BUSER_WIDTH    (0),
    .C_AXI_SUPPORTS_NARROW(0),
    .C_AXI_HAS_BURST      (0),
    .C_AXI_HAS_LOCK       (0),
    .C_AXI_HAS_CACHE      (0),
    .C_AXI_HAS_REGION     (0),
    .C_AXI_HAS_PROT       (0),
    .C_AXI_HAS_QOS        (0),
    .C_AXI_HAS_WSTRB      (1),
    .C_AXI_HAS_BRESP      (1),
    .C_AXI_HAS_RRESP      (1),
    .C_AXI_HAS_ARESETN    (1)
  ) inst (
    .aclk           (aclk),
    .aclken         (1'b1),
    .aresetn        (aresetn),

    // Unused SLAVE-side (tie-off)
    .s_axi_awid     (1'b0),
    .s_axi_awaddr   (12'b0),
    .s_axi_awlen    (8'b0),
    .s_axi_awsize   (3'b0),
    .s_axi_awburst  (2'b01),
    .s_axi_awlock   (1'b0),
    .s_axi_awcache  (4'b0),
    .s_axi_awprot   (3'b0),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (4'b0),
    .s_axi_awuser   (1'b0),
    .s_axi_awvalid  (1'b0),
    .s_axi_awready  (/* unused */),

    .s_axi_wid      (1'b0),
    .s_axi_wdata    (32'b0),
    .s_axi_wstrb    (4'hF),
    .s_axi_wlast    (1'b0),
    .s_axi_wuser    (1'b0),
    .s_axi_wvalid   (1'b0),
    .s_axi_wready   (/* unused */),

    .s_axi_bid      (/* unused */),
    .s_axi_bresp    (/* unused */),
    .s_axi_buser    (/* unused */),
    .s_axi_bvalid   (/* unused */),
    .s_axi_bready   (1'b0),

    .s_axi_arid     (1'b0),
    .s_axi_araddr   (12'b0),
    .s_axi_arlen    (8'b0),
    .s_axi_arsize   (3'b0),
    .s_axi_arburst  (2'b01),
    .s_axi_arlock   (1'b0),
    .s_axi_arcache  (4'b0),
    .s_axi_arprot   (3'b0),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (4'b0),
    .s_axi_aruser   (1'b0),
    .s_axi_arvalid  (1'b0),
    .s_axi_arready  (/* unused */),

    .s_axi_rid      (/* unused */),
    .s_axi_rdata    (/* unused */),
    .s_axi_rresp    (/* unused */),
    .s_axi_rlast    (/* unused */),
    .s_axi_ruser    (/* unused */),
    .s_axi_rvalid   (/* unused */),
    .s_axi_rready   (1'b0),

    // MASTER-side (used)
    .m_axi_awid     (/* unused */),
    .m_axi_awaddr   (m_axi_awaddr),
    .m_axi_awlen    (/* unused */),
    .m_axi_awsize   (/* unused */),
    .m_axi_awburst  (/* unused */),
    .m_axi_awlock   (/* unused */),
    .m_axi_awcache  (/* unused */),
    .m_axi_awprot   (/* unused */),
    .m_axi_awregion (/* unused */),
    .m_axi_awqos    (/* unused */),
    .m_axi_awuser   (/* unused */),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),

    .m_axi_wid      (/* unused */),
    .m_axi_wdata    (m_axi_wdata),
    .m_axi_wstrb    (m_axi_wstrb),
    .m_axi_wlast    (/* unused */),
    .m_axi_wuser    (/* unused */),
    .m_axi_wvalid   (m_axi_wvalid),
    .m_axi_wready   (m_axi_wready),

    .m_axi_bid      (1'b0),
    .m_axi_bresp    (m_axi_bresp),
    .m_axi_buser    (1'b0),
    .m_axi_bvalid   (m_axi_bvalid),
    .m_axi_bready   (m_axi_bready),

    .m_axi_arid     (/* unused */),
    .m_axi_araddr   (m_axi_araddr),
    .m_axi_arlen    (/* unused */),
    .m_axi_arsize   (/* unused */),
    .m_axi_arburst  (/* unused */),
    .m_axi_arlock   (/* unused */),
    .m_axi_arcache  (/* unused */),
    .m_axi_arprot   (/* unused */),
    .m_axi_arregion (/* unused */),
    .m_axi_arqos    (/* unused */),
    .m_axi_aruser   (/* unused */),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_arready  (m_axi_arready),

    .m_axi_rid      (1'b0),
    .m_axi_rdata    (m_axi_rdata),
    .m_axi_rresp    (m_axi_rresp),
    .m_axi_rlast    (1'b0),
    .m_axi_ruser    (1'b0),
    .m_axi_rvalid   (m_axi_rvalid),
    .m_axi_rready   (m_axi_rready)
  );

endmodule
