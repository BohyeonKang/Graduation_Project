///////////////////////////////////////////////////////////////////////////
//NOTE: This file is refactored to follow the same naming convention/style
//      as 'slv_m00_axi_vip_pkg', for an AXI4-Lite MASTER VIP.
///////////////////////////////////////////////////////////////////////////
`timescale 1ps/1ps
package mst_s00_axi_lite_vip_pkg;
  import axi_vip_pkg::*;
///////////////////////////////////////////////////////////////////////////
// These parameters are named after the component for use in your verification 
// environment.
///////////////////////////////////////////////////////////////////////////
      localparam int    AXI_PROTOCOL    = 2;           // 2 = AXI4-Lite
      // localparam string READ_WRITE_MODE = "READ_WRITE"; // (unused: doc only)
      // localparam int    INTERFACE_MODE  = 1;            // 1 = MASTER (unused)
      localparam int    ADDR_WIDTH      = 12;
      localparam int    DATA_WIDTH      = 32;
      localparam int    ID_WIDTH        = 0;
      localparam int    AWUSER_WIDTH    = 0;
      localparam int    ARUSER_WIDTH    = 0;
      localparam int    RUSER_WIDTH     = 0;
      localparam int    WUSER_WIDTH     = 0;
      localparam int    BUSER_WIDTH     = 0;
      localparam bit    SUPPORTS_NARROW = 0;
      localparam bit    HAS_BURST       = 0;           // AXI4-Lite 특성
      localparam bit    HAS_LOCK        = 0;
      localparam bit    HAS_CACHE       = 0;
      localparam bit    HAS_REGION      = 0;
      localparam bit    HAS_QOS         = 0;
      localparam bit    HAS_PROT        = 0;
      localparam bit    HAS_WSTRB       = 1;
      localparam bit    HAS_BRESP       = 1;
      localparam bit    HAS_RRESP       = 1;
      localparam bit    HAS_ACLKEN      = 0;
      localparam bit    HAS_ARESETN     = 1;
///////////////////////////////////////////////////////////////////////////

  typedef axi_mst_agent #(
                        AXI_PROTOCOL, 
                        ADDR_WIDTH,
                        DATA_WIDTH,
                        DATA_WIDTH,
                        ID_WIDTH,
                        ID_WIDTH,
                        AWUSER_WIDTH, 
                        WUSER_WIDTH, 
                        BUSER_WIDTH, 
                        ARUSER_WIDTH,
                        RUSER_WIDTH, 
                        SUPPORTS_NARROW, 
                        HAS_BURST,
                        HAS_LOCK,
                        HAS_CACHE,
                        HAS_REGION,
                        HAS_PROT,
                        HAS_QOS,
                        HAS_WSTRB,
                        HAS_BRESP,
                        HAS_RRESP,
                        HAS_ARESETN
  ) mst_s00_axi_lite_vip_mst_t;

  // Short alias (optional)
  typedef mst_s00_axi_lite_vip_mst_t axi_lite_master_t;

///////////////////////////////////////////////////////////////////////////
// How to start the verification component
///////////////////////////////////////////////////////////////////////////
//      mst_s00_axi_lite_vip_mst_t  mst_s00_axi_lite_vip_mst;
//      // or: axi_lite_master_t mst;
//      initial begin : START_mst_s00_axi_lite_vip_MASTER
//        mst_s00_axi_lite_vip_mst = new("mst_s00_axi_lite_vip_mst", `mst_s00_axi_lite_vip_PATH_TO_INTERFACE);
//        mst_s00_axi_lite_vip_mst.start_master();
//      end

endpackage : mst_s00_axi_lite_vip_pkg
