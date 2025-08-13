`timescale 1ns/1ps
module axi_lite_slave #(
    parameter C_S_AXI_ADDR_WIDTH = 12,     // 4KB aperture
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                             ACLK,
    input  wire                             ARESET,
    input  wire                             ACLK_EN,

    // AXI-Lite
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    AWADDR,
    input  wire                             AWVALID,
    output wire                             AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]    WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]  WSTRB,
    input  wire                             WVALID,
    output wire                             WREADY,
    output wire [1:0]                       BRESP,
    output wire                             BVALID,
    input  wire                             BREADY,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    ARADDR,
    input  wire                             ARVALID,
    output wire                             ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]    RDATA,
    output wire [1:0]                       RRESP,
    output wire                             RVALID,
    input  wire                             RREADY,

    // Control/Status (표준 HLS 스타일)
    output wire                             ap_start,
    input  wire                             ap_done,
    input  wire                             ap_ready,
    input  wire                             ap_idle

    // NOTE: interrupt, DMA 관련 포트/레지스터는 설계에서 제거됨
);

//------------------------Address Info-------------------
// 0x00 : Control signals
//        bit 0  - ap_start (Read/Write/COH)
//        bit 1  - ap_done  (Read/COR)
//        bit 2  - ap_idle  (Read)
//        bit 3  - ap_ready (Read/COR)
//        bit 7  - auto_restart (Read/Write)
//        others - reserved
// 0x04 : Global Interrupt Enable Register
//        bit 0  - Global Interrupt Enable (Read/Write)
//        others - reserved
// 0x08 : IP Interrupt Enable Register (Read/Write)
//        bit 0 - enable ap_done interrupt  (Read/Write)
//        bit 1 - enable ap_ready interrupt (Read/Write)
//        others - reserved
// 0x0C : IP Interrupt Status Register (Read/COR)
//        bit 0 - ap_done  (Read/COR)
//        bit 1 - ap_ready (Read/COR)
//        others - reserved
//
//------------------------Scalar Parameters--------------
// 0x20 : total_pass        [3:0]   (R/W)
// 0x24 : layer_HW          [7:0]   (R/W)
// 0x28 : layer_RS          [3:0]   (R/W)
// 0x2C : layer_EF          [6:0]   (R/W)
// 0x30 : layer_C           [9:0]   (R/W)
// 0x34 : layer_M           [8:0]   (R/W)
// 0x38 : layer_U           [1:0]   (R/W)
// 0x3C : layer_PAD         [1:0]   (R/W)
// 0x40 : layer_m           [3:0]   (R/W)
// 0x44 : layer_n           [2:0]   (R/W)
// 0x48 : layer_e           [4:0]   (R/W)
// 0x4C : layer_p           [3:0]   (R/W)
// 0x50 : layer_q           [2:0]   (R/W)
// 0x54 : layer_r           [1:0]   (R/W)
// 0x58 : layer_t           [1:0]   (R/W)
//
//------------------------Row ID Tables------------------
// 0x100~0x10B : IFMAP_ROW_ID[i] (i=0..11) [4:0] (R/W) ; 1B/entry
// 0x120~0x12B : WGHT_ROW_ID[i]  (i=0..11) [4:0] (R/W) ; 1B/entry
// 0x140~0x14B : PSUM_ROW_ID[i]  (i=0..11) [4:0] (R/W) ; 1B/entry
//
//------------------------Col ID Tables------------------
// 0x200~0x2BF : IFMAP_COL_ID[row][col] [4:0] (R/W)
//               addr = 0x200 + row*16 + col, row=0..11, col=0..13
// 0x300~0x3BF : WGHT_COL_ID[row][col]  [4:0] (R/W)
//               addr = 0x300 + row*16 + col
// 0x400~0x4BF : PSUM_COL_ID[row][col]  [4:0] (R/W)
//               addr = 0x400 + row*16 + col
//
// (SC = Self Clear, COR = Clear on Read, COH = Clear on Handshake)


// ---------------- AXI4-Lite CSR Offsets (byte address) ----------------
localparam CSR_AP_CTRL       = 12'h000;
localparam CSR_GIE           = 12'h004;
localparam CSR_IER           = 12'h008;
localparam CSR_ISR           = 12'h00C;

localparam CSR_TOTAL_PASS    = 12'h020; // [3:0]
localparam CSR_LAYER_HW      = 12'h024; // [7:0]
localparam CSR_LAYER_RS      = 12'h028; // [3:0]
localparam CSR_LAYER_EF      = 12'h02C; // [6:0]
localparam CSR_LAYER_C       = 12'h030; // [9:0]
localparam CSR_LAYER_M       = 12'h034; // [8:0]
localparam CSR_LAYER_U       = 12'h038; // [1:0]
localparam CSR_LAYER_PAD     = 12'h03C; // [1:0]
localparam CSR_LAYER_m       = 12'h040; // [3:0]
localparam CSR_LAYER_n       = 12'h044; // [2:0]
localparam CSR_LAYER_e       = 12'h048; // [4:0]
localparam CSR_LAYER_p       = 12'h04C; // [3:0]
localparam CSR_LAYER_q       = 12'h050; // [2:0]
localparam CSR_LAYER_r       = 12'h054; // [1:0]
localparam CSR_LAYER_t       = 12'h058; // [1:0]

// Row-ID tables (1B per entry, [4:0] valid)
localparam IFMAP_ROW_ID_BASE = 12'h100;
localparam WGHT_ROW_ID_BASE  = 12'h120;
localparam PSUM_ROW_ID_BASE  = 12'h140;
localparam ROW_ID_STRIDE     = 1;
localparam NUM_ROWS_MAX      = 12;

// Col-ID tables (row-major, 1B per entry, [4:0] valid)
localparam IFMAP_COL_ID_BASE = 12'h200;
localparam WGHT_COL_ID_BASE  = 12'h300;
localparam PSUM_COL_ID_BASE  = 12'h400;
localparam COL_STRIDE        = 16;    // bytes/row
localparam NUM_COLS_MAX      = 14;

// AXI write/read FSM states
localparam WRIDLE = 2'd0, WRDATA = 2'd1, WRRESP = 2'd2, WRRESET = 2'd3;
localparam RDIDLE = 2'd0, RDDATA = 2'd1, RDRESET = 2'd2;

// local address width
localparam ADDR_BITS = 12;

// === 패킹 폭 정의 (5비트 유효) ===
localparam ROW_BITS         = 5;
localparam COL_BITS         = 5;
localparam ROW_PACK_WIDTH   = NUM_ROWS_MAX * ROW_BITS;                    // 60
localparam COL_PACK_WIDTH   = NUM_ROWS_MAX * NUM_COLS_MAX * COL_BITS;     // 840
localparam COL_STRIDE_L2    = 4;  // log2(16)

//------------------------Local signal-------------------
reg  [1:0]                    wstate = WRRESET;
reg  [1:0]                    wnext;
reg  [ADDR_BITS-1:0]          waddr;
wire [C_S_AXI_DATA_WIDTH-1:0] wmask;   // soft-coded by WSTRB
wire                          aw_hs;
wire                          w_hs;

reg  [1:0]                    rstate = RDRESET;
reg  [1:0]                    rnext;
reg  [C_S_AXI_DATA_WIDTH-1:0] rdata;
wire                          ar_hs;
wire [ADDR_BITS-1:0]          raddr;

//------------------------Internal registers----------------------
reg        int_ap_idle;
reg        int_ap_ready            = 1'b0;
wire       task_ap_ready;
reg        int_ap_done             = 1'b0;
wire       task_ap_done;
reg        int_task_ap_done        = 1'b0;
reg        int_ap_start            = 1'b0;
reg        int_auto_restart        = 1'b0;
reg        auto_restart_status     = 1'b0;
wire       auto_restart_done;
reg        int_gie                 = 1'b0;
reg  [1:0] int_ier                 = 2'b00;
reg  [1:0] int_isr                 = 2'b00;

//------------------------Scalars (32b, 하위 비트 유효)---
reg [31:0] int_total_pass          = 32'b0;
reg [31:0] int_layer_HW            = 32'b0;
reg [31:0] int_layer_RS            = 32'b0;
reg [31:0] int_layer_EF            = 32'b0;
reg [31:0] int_layer_C             = 32'b0;
reg [31:0] int_layer_M             = 32'b0;
reg [31:0] int_layer_U             = 32'b0;
reg [31:0] int_layer_PAD           = 32'b0;
reg [31:0] int_layer_m             = 32'b0;
reg [31:0] int_layer_n             = 32'b0;
reg [31:0] int_layer_e             = 32'b0;
reg [31:0] int_layer_p             = 32'b0;
reg [31:0] int_layer_q             = 32'b0;
reg [31:0] int_layer_r             = 32'b0;
reg [31:0] int_layer_t             = 32'b0;

//------------------------Row/Col ID tables----------------------
reg [7:0] int_ifmap_row_id [0:NUM_ROWS_MAX-1];
reg [7:0] int_wght_row_id  [0:NUM_ROWS_MAX-1];
reg [7:0] int_psum_row_id  [0:NUM_ROWS_MAX-1];

reg [7:0] int_ifmap_col_id [0:NUM_ROWS_MAX-1][0:NUM_COLS_MAX-1];
reg [7:0] int_wght_col_id  [0:NUM_ROWS_MAX-1][0:NUM_COLS_MAX-1];
reg [7:0] int_psum_col_id  [0:NUM_ROWS_MAX-1][0:NUM_COLS_MAX-1];

//------------------------Packed snapshot (Option A)-------------
reg [ROW_PACK_WIDTH-1:0] ifmap_row_id_packed, wght_row_id_packed, psum_row_id_packed;
reg [COL_PACK_WIDTH-1:0] ifmap_col_id_packed, wght_col_id_packed, psum_col_id_packed;

// (필요 시) 컨트롤러에 직접 연결할 출력 와이어
wire [ROW_PACK_WIDTH-1:0] o_ifmap_row_id = ifmap_row_id_packed;
wire [ROW_PACK_WIDTH-1:0] o_wght_row_id  = wght_row_id_packed;
wire [ROW_PACK_WIDTH-1:0] o_psum_row_id  = psum_row_id_packed;
wire [COL_PACK_WIDTH-1:0] o_ifmap_col_id = ifmap_col_id_packed;
wire [COL_PACK_WIDTH-1:0] o_wght_col_id  = wght_col_id_packed;
wire [COL_PACK_WIDTH-1:0] o_psum_col_id  = psum_col_id_packed;

// 스칼라 슬라이스 (컨트롤러 포트에 연결용)
wire [3:0]  o_total_pass = int_total_pass[3:0];
wire [7:0]  o_layer_HW   = int_layer_HW[7:0];
wire [3:0]  o_layer_RS   = int_layer_RS[3:0];
wire [6:0]  o_layer_EF   = int_layer_EF[6:0];
wire [9:0]  o_layer_C    = int_layer_C[9:0];
wire [8:0]  o_layer_M    = int_layer_M[8:0];
wire [1:0]  o_layer_U    = int_layer_U[1:0];
wire [1:0]  o_layer_PAD  = int_layer_PAD[1:0];
wire [3:0]  o_layer_m    = int_layer_m[3:0];
wire [2:0]  o_layer_n    = int_layer_n[2:0];
wire [4:0]  o_layer_e    = int_layer_e[4:0];
wire [3:0]  o_layer_p    = int_layer_p[3:0];
wire [2:0]  o_layer_q    = int_layer_q[2:0];
wire [1:0]  o_layer_r    = int_layer_r[1:0];
wire [1:0]  o_layer_t    = int_layer_t[1:0];

//------------------------Helpers for packing--------------------
function integer idx_row; input integer r; begin idx_row = r*ROW_BITS; end endfunction
function integer idx_col; input integer r,c; begin idx_col = (r*NUM_COLS_MAX + c)*COL_BITS; end endfunction
integer r, c;

//------------------------AXI write fsm--------------------------
assign AWREADY = (wstate == WRIDLE);
assign WREADY  = (wstate == WRDATA);
assign BRESP   = 2'b00;  // OKAY
assign BVALID  = (wstate == WRRESP);
assign aw_hs   = AWVALID & AWREADY;
assign w_hs    = WVALID & WREADY;

// wmask (soft-coded by WSTRB)
genvar gi;
generate
  for (gi=0; gi<C_S_AXI_DATA_WIDTH/8; gi=gi+1) begin : G_WMASK
    assign wmask[8*gi +: 8] = {8{WSTRB[gi]}};
  end
endgenerate

// wstate / next
always @(posedge ACLK) begin
  if (ARESET) wstate <= WRRESET;
  else if (ACLK_EN) wstate <= wnext;
end
always @(*) begin
  case (wstate)
    WRIDLE: wnext = AWVALID ? WRDATA : WRIDLE;
    WRDATA: wnext = WVALID  ? WRRESP : WRDATA;
    WRRESP: wnext = BREADY  ? WRIDLE : WRRESP;
    default: wnext = WRIDLE;
  endcase
end

// waddr (byte address)
always @(posedge ACLK) begin
  if (ACLK_EN) begin
    if (aw_hs) waddr <= AWADDR[ADDR_BITS-1:0];
  end
end

//------------------------AXI read fsm---------------------------
assign ARREADY = (rstate == RDIDLE);
assign RDATA   = rdata;
assign RRESP   = 2'b00;  // OKAY
assign RVALID  = (rstate == RDDATA);
assign ar_hs   = ARVALID & ARREADY;
assign raddr   = ARADDR[ADDR_BITS-1:0];

// rstate / next
always @(posedge ACLK) begin
  if (ARESET) rstate <= RDRESET;
  else if (ACLK_EN) rstate <= rnext;
end
always @(*) begin
  case (rstate)
    RDIDLE: rnext = ARVALID ? RDDATA : RDIDLE;
    RDDATA: rnext = (RREADY & RVALID) ? RDIDLE : RDDATA;
    default: rnext = RDIDLE;
  endcase
end

//------------------------READ decode (scalars + tables)---------
always @(posedge ACLK) begin
  if (ACLK_EN) begin
    if (ar_hs) begin
      integer line_idx;
      reg [ADDR_BITS-1:0] base;
      reg [ADDR_BITS-1:0] a_word;   // aligned word base
      reg [ADDR_BITS-1:0] ba;       // base-relative byte addr
      reg [7:0]           bval [0:3];

      rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
      a_word  = {raddr[ADDR_BITS-1:2], 2'b00};

      // default byte values = 0
      for (line_idx=0; line_idx<4; line_idx=line_idx+1) bval[line_idx] = 8'h00;

      // Scalars (exact match)
      case (raddr)
        CSR_AP_CTRL: begin
          rdata[0] <= int_ap_start;
          rdata[1] <= int_task_ap_done;  // COR
          rdata[2] <= int_ap_idle;
          rdata[3] <= int_ap_ready;      // COR
          rdata[7] <= int_auto_restart;
        end
        CSR_GIE:        rdata <= {{(C_S_AXI_DATA_WIDTH-1){1'b0}}, int_gie};
        CSR_IER:        rdata <= {{(C_S_AXI_DATA_WIDTH-2){1'b0}}, int_ier};
        CSR_ISR:        rdata <= {{(C_S_AXI_DATA_WIDTH-2){1'b0}}, int_isr};
        CSR_TOTAL_PASS: rdata <= int_total_pass;
        CSR_LAYER_HW:   rdata <= int_layer_HW;
        CSR_LAYER_RS:   rdata <= int_layer_RS;
        CSR_LAYER_EF:   rdata <= int_layer_EF;
        CSR_LAYER_C:    rdata <= int_layer_C;
        CSR_LAYER_M:    rdata <= int_layer_M;
        CSR_LAYER_U:    rdata <= int_layer_U;
        CSR_LAYER_PAD:  rdata <= int_layer_PAD;
        CSR_LAYER_m:    rdata <= int_layer_m;
        CSR_LAYER_n:    rdata <= int_layer_n;
        CSR_LAYER_e:    rdata <= int_layer_e;
        CSR_LAYER_p:    rdata <= int_layer_p;
        CSR_LAYER_q:    rdata <= int_layer_q;
        CSR_LAYER_r:    rdata <= int_layer_r;
        CSR_LAYER_t:    rdata <= int_layer_t;
        default: begin
          // Tables: return a 32b word (4 bytes), collecting from each block if in-range
          // IFMAP_ROW_ID
          if ((a_word >= IFMAP_ROW_ID_BASE) && (a_word < IFMAP_ROW_ID_BASE + NUM_ROWS_MAX)) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1)
              if ((a_word+line_idx) < (IFMAP_ROW_ID_BASE + NUM_ROWS_MAX))
                bval[line_idx] = int_ifmap_row_id[(a_word+line_idx) - IFMAP_ROW_ID_BASE];
          end
          // WGHT_ROW_ID
          else if ((a_word >= WGHT_ROW_ID_BASE) && (a_word < WGHT_ROW_ID_BASE + NUM_ROWS_MAX)) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1)
              if ((a_word+line_idx) < (WGHT_ROW_ID_BASE + NUM_ROWS_MAX))
                bval[line_idx] = int_wght_row_id[(a_word+line_idx) - WGHT_ROW_ID_BASE];
          end
          // PSUM_ROW_ID
          else if ((a_word >= PSUM_ROW_ID_BASE) && (a_word < PSUM_ROW_ID_BASE + NUM_ROWS_MAX)) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1)
              if ((a_word+line_idx) < (PSUM_ROW_ID_BASE + NUM_ROWS_MAX))
                bval[line_idx] = int_psum_row_id[(a_word+line_idx) - PSUM_ROW_ID_BASE];
          end
          // IFMAP_COL_ID (row-major, stride 16)
          else if ((a_word >= IFMAP_COL_ID_BASE) && (a_word < (IFMAP_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE))) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1) begin
              ba = (a_word + line_idx) - IFMAP_COL_ID_BASE;
              if ( ((a_word+line_idx) < (IFMAP_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE)) ) begin
                integer row, col;
                row = ba >> COL_STRIDE_L2;
                col = ba & (COL_STRIDE-1);
                if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) bval[line_idx] = int_ifmap_col_id[row][col];
              end
            end
          end
          // WGHT_COL_ID
          else if ((a_word >= WGHT_COL_ID_BASE) && (a_word < (WGHT_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE))) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1) begin
              ba = (a_word + line_idx) - WGHT_COL_ID_BASE;
              integer row, col;
              row = ba >> COL_STRIDE_L2;
              col = ba & (COL_STRIDE-1);
              if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) bval[line_idx] = int_wght_col_id[row][col];
            end
          end
          // PSUM_COL_ID
          else if ((a_word >= PSUM_COL_ID_BASE) && (a_word < (PSUM_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE))) begin
            for (line_idx=0; line_idx<4; line_idx=line_idx+1) begin
              ba = (a_word + line_idx) - PSUM_COL_ID_BASE;
              integer row, col;
              row = ba >> COL_STRIDE_L2;
              col = ba & (COL_STRIDE-1);
              if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) bval[line_idx] = int_psum_col_id[row][col];
            end
          end

          // pack to rdata
          rdata[7:0]   <= bval[0];
          rdata[15:8]  <= bval[1];
          rdata[23:16] <= bval[2];
          rdata[31:24] <= bval[3];
        end
      endcase
    end
  end
end

//------------------------WRITE decode (scalars + tables)--------
assign task_ap_done       = (ap_done && !auto_restart_status) || auto_restart_done;
assign task_ap_ready      = ap_ready && !int_auto_restart;
assign auto_restart_done  = auto_restart_status && (ap_idle && !int_ap_idle);

// ap_start (COH semantics)
always @(posedge ACLK) begin
  if (ARESET) int_ap_start <= 1'b0;
  else if (ACLK_EN) begin
    if (w_hs && (waddr == CSR_AP_CTRL) && WSTRB[0] && WDATA[0]) int_ap_start <= 1'b1;
    else if (ap_ready)                                          int_ap_start <= int_auto_restart;
  end
end
assign ap_start = int_ap_start;

// status mirroring / COR 구현
always @(posedge ACLK) begin
  if (ARESET) int_ap_done <= 1'b0;
  else if (ACLK_EN) int_ap_done <= ap_done;
end

always @(posedge ACLK) begin
  if (ARESET) int_ap_idle <= 1'b0;
  else if (ACLK_EN) int_ap_idle <= ap_idle;
end

always @(posedge ACLK) begin
  if (ARESET) int_ap_ready <= 1'b0;
  else if (ACLK_EN) begin
    if (task_ap_ready)                 int_ap_ready <= 1'b1;
    else if (ar_hs && raddr==CSR_AP_CTRL) int_ap_ready <= 1'b0;
  end
end

always @(posedge ACLK) begin
  if (ARESET) int_task_ap_done <= 1'b0;
  else if (ACLK_EN) begin
    if (task_ap_done)                  int_task_ap_done <= 1'b1;
    else if (ar_hs && raddr==CSR_AP_CTRL) int_task_ap_done <= 1'b0;
  end
end

always @(posedge ACLK) begin
  if (ARESET) int_auto_restart <= 1'b0;
  else if (ACLK_EN) begin
    if (w_hs && (waddr==CSR_AP_CTRL) && WSTRB[0]) int_auto_restart <= WDATA[7];
  end
end

always @(posedge ACLK) begin
  if (ARESET) auto_restart_status <= 1'b0;
  else if (ACLK_EN) begin
    if (int_auto_restart) auto_restart_status <= 1'b1;
    else if (ap_idle)     auto_restart_status <= 1'b0;
  end
end

// GIE/IER/ISR
always @(posedge ACLK) begin
  if (ARESET) int_gie <= 1'b0;
  else if (ACLK_EN) begin
    if (w_hs && (waddr==CSR_GIE) && WSTRB[0]) int_gie <= WDATA[0];
  end
end

always @(posedge ACLK) begin
  if (ARESET) int_ier <= 2'b00;
  else if (ACLK_EN) begin
    if (w_hs && (waddr==CSR_IER) && WSTRB[0]) int_ier <= WDATA[1:0];
  end
end

always @(posedge ACLK) begin
  if (ARESET) int_isr <= 2'b00;
  else if (ACLK_EN) begin
    if (int_ier[0] & ap_done)  int_isr[0] <= 1'b1;
    else if (ar_hs && raddr==CSR_ISR) int_isr[0] <= 1'b0; // COR
    if (int_ier[1] & ap_ready) int_isr[1] <= 1'b1;
    else if (ar_hs && raddr==CSR_ISR) int_isr[1] <= 1'b0; // COR
  end
end

// Scalars write
always @(posedge ACLK) begin
  if (ARESET) begin
    int_total_pass <= 0; int_layer_HW <= 0; int_layer_RS <= 0; int_layer_EF <= 0;
    int_layer_C    <= 0; int_layer_M  <= 0; int_layer_U  <= 0; int_layer_PAD<= 0;
    int_layer_m    <= 0; int_layer_n  <= 0; int_layer_e  <= 0; int_layer_p  <= 0;
    int_layer_q    <= 0; int_layer_r  <= 0; int_layer_t  <= 0;
  end else if (ACLK_EN) begin
    if (w_hs) begin
      case (waddr)
        CSR_TOTAL_PASS: int_total_pass <= (WDATA & wmask) | (int_total_pass & ~wmask);
        CSR_LAYER_HW  : int_layer_HW   <= (WDATA & wmask) | (int_layer_HW   & ~wmask);
        CSR_LAYER_RS  : int_layer_RS   <= (WDATA & wmask) | (int_layer_RS   & ~wmask);
        CSR_LAYER_EF  : int_layer_EF   <= (WDATA & wmask) | (int_layer_EF   & ~wmask);
        CSR_LAYER_C   : int_layer_C    <= (WDATA & wmask) | (int_layer_C    & ~wmask);
        CSR_LAYER_M   : int_layer_M    <= (WDATA & wmask) | (int_layer_M    & ~wmask);
        CSR_LAYER_U   : int_layer_U    <= (WDATA & wmask) | (int_layer_U    & ~wmask);
        CSR_LAYER_PAD : int_layer_PAD  <= (WDATA & wmask) | (int_layer_PAD  & ~wmask);
        CSR_LAYER_m   : int_layer_m    <= (WDATA & wmask) | (int_layer_m    & ~wmask);
        CSR_LAYER_n   : int_layer_n    <= (WDATA & wmask) | (int_layer_n    & ~wmask);
        CSR_LAYER_e   : int_layer_e    <= (WDATA & wmask) | (int_layer_e    & ~wmask);
        CSR_LAYER_p   : int_layer_p    <= (WDATA & wmask) | (int_layer_p    & ~wmask);
        CSR_LAYER_q   : int_layer_q    <= (WDATA & wmask) | (int_layer_q    & ~wmask);
        CSR_LAYER_r   : int_layer_r    <= (WDATA & wmask) | (int_layer_r    & ~wmask);
        CSR_LAYER_t   : int_layer_t    <= (WDATA & wmask) | (int_layer_t    & ~wmask);
        default: ;
      endcase
    end
  end
end

// Tables write (byte-정밀; 32b 쓰기에서도 각 byte lane 별 반영)
always @(posedge ACLK) begin
  if (ARESET) begin
    // 기본 0; 필요 시 초기화 로직 추가 가능
  end else if (ACLK_EN) begin
    if (w_hs) begin
      integer line_idx, row, col;
      reg [ADDR_BITS-1:0] a_word;
      reg [ADDR_BITS-1:0] baddr; // per-lane byte address
      reg [7:0]           wbyte;

      a_word = {waddr[ADDR_BITS-1:2], 2'b00};

      for (line_idx=0; line_idx<4; line_idx=line_idx+1) if (WSTRB[line_idx]) begin
        baddr = a_word + line_idx;
        wbyte = WDATA[8*line_idx +: 8];

        // Row blocks
        if (baddr >= IFMAP_ROW_ID_BASE && baddr < IFMAP_ROW_ID_BASE + NUM_ROWS_MAX) begin
          int_ifmap_row_id[baddr - IFMAP_ROW_ID_BASE] <= wbyte;
        end else if (baddr >= WGHT_ROW_ID_BASE && baddr < WGHT_ROW_ID_BASE + NUM_ROWS_MAX) begin
          int_wght_row_id[baddr - WGHT_ROW_ID_BASE] <= wbyte;
        end else if (baddr >= PSUM_ROW_ID_BASE && baddr < PSUM_ROW_ID_BASE + NUM_ROWS_MAX) begin
          int_psum_row_id[baddr - PSUM_ROW_ID_BASE] <= wbyte;
        end
        // Col blocks (row-major, stride 16)
        else if (baddr >= IFMAP_COL_ID_BASE && baddr < IFMAP_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE) begin
          integer row, col;
          reg [ADDR_BITS-1:0] off; off = baddr - IFMAP_COL_ID_BASE;
          row = off >> COL_STRIDE_L2;
          col = off & (COL_STRIDE-1);
          if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) int_ifmap_col_id[row][col] <= wbyte;
        end else if (baddr >= WGHT_COL_ID_BASE && baddr < WGHT_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE) begin
          integer row, col;
          reg [ADDR_BITS-1:0] off; off = baddr - WGHT_COL_ID_BASE;
          row = off >> COL_STRIDE_L2;
          col = off & (COL_STRIDE-1);
          if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) int_wght_col_id[row][col] <= wbyte;
        end else if (baddr >= PSUM_COL_ID_BASE && baddr < PSUM_COL_ID_BASE + NUM_ROWS_MAX*COL_STRIDE) begin
          integer row, col;
          reg [ADDR_BITS-1:0] off; off = baddr - PSUM_COL_ID_BASE;
          row = off >> COL_STRIDE_L2;
          col = off & (COL_STRIDE-1);
          if (row < NUM_ROWS_MAX && col < NUM_COLS_MAX) int_psum_col_id[row][col] <= wbyte;
        end
        // else: reserved 영역 → 무시
      end
    end
  end
end

//------------------------Snapshot (Option A)--------------------
wire start_capture = (int_ap_start & ap_ready) | (int_auto_restart & ap_ready);

always @(posedge ACLK) begin
  if (ARESET) begin
    ifmap_row_id_packed <= {ROW_PACK_WIDTH{1'b0}};
    wght_row_id_packed  <= {ROW_PACK_WIDTH{1'b0}};
    psum_row_id_packed  <= {ROW_PACK_WIDTH{1'b0}};
    ifmap_col_id_packed <= {COL_PACK_WIDTH{1'b0}};
    wght_col_id_packed  <= {COL_PACK_WIDTH{1'b0}};
    psum_col_id_packed  <= {COL_PACK_WIDTH{1'b0}};
  end else if (ACLK_EN) begin
    if (start_capture) begin
      for (r=0; r<NUM_ROWS_MAX; r=r+1) begin
        ifmap_row_id_packed[idx_row(r)+:ROW_BITS] <= int_ifmap_row_id[r][4:0];
        wght_row_id_packed [idx_row(r)+:ROW_BITS] <= int_wght_row_id [r][4:0];
        psum_row_id_packed [idx_row(r)+:ROW_BITS] <= int_psum_row_id [r][4:0];
      end
      for (r=0; r<NUM_ROWS_MAX; r=r+1)
        for (c=0; c<NUM_COLS_MAX; c=c+1) begin
          ifmap_col_id_packed[idx_col(r,c)+:COL_BITS] <= int_ifmap_col_id[r][c][4:0];
          wght_col_id_packed [idx_col(r,c)+:COL_BITS] <= int_wght_col_id [r][c][4:0];
          psum_col_id_packed [idx_col(r,c)+:COL_BITS] <= int_psum_col_id [r][c][4:0];
        end
    end
  end
end

//------------------------AXI read/write handshake --------------
assign BRESP = 2'b00;
assign RRESP = 2'b00;

endmodule