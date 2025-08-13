module axi_lite_slave (
    input  wire         ACLK,
    input  wire         ARESETn,

    // Write address channel
    input  wire [31:0]  AWADDR,
    input  wire         AWVALID,
    output reg          AWREADY,

    // Write data channel
    input  wire [31:0]  WDATA,
    input  wire [3:0]   WSTRB,
    input  wire         WVALID,
    output reg          WREADY,

    // Write response channel
    output reg  [1:0]   BRESP,
    output reg          BVALID,
    input  wire         BREADY,

    // Read address channel
    input  wire [31:0]  ARADDR,
    input  wire         ARVALID,
    output reg          ARREADY,

    // Read data channel
    output reg  [31:0]  RDATA,
    output reg  [1:0]   RRESP,
    output reg          RVALID,
    input  wire         RREADY
);

    // 32 x 32-bit register file: reg0 .. reg31 (주소 0x00 ~ 0x7C, 워드 인덱스 0..31)
    reg [31:0] regfile [0:31];

    // 공통: 주소를 워드 인덱스로 사용
    wire [5:0] widx = AWADDR[7:2]; // 0..31만 유효
    wire [5:0] ridx = ARADDR[7:2];

    integer i;

    // ---------------------------
    // Write path
    // ---------------------------
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            AWREADY <= 1'b0;
            WREADY  <= 1'b0;
            BVALID  <= 1'b0;
            BRESP   <= 2'b00; // OKAY
            for (i = 0; i < 32; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            // Handshake toggles (1사이클 펄스형 ready)
            AWREADY <= (AWVALID && !AWREADY);
            WREADY  <= (WVALID  && !WREADY);

            // 실제 쓰기: AW & W 동시 핸드셰이크 완료 시
            if (AWVALID && AWREADY && WVALID && WREADY) begin
                if (widx < 32) begin
                    // WSTRB 바이트 마스킹 적용
                    if (WSTRB[0]) regfile[widx][ 7:0]  <= WDATA[ 7:0];
                    if (WSTRB[1]) regfile[widx][15:8]  <= WDATA[15:8];
                    if (WSTRB[2]) regfile[widx][23:16] <= WDATA[23:16];
                    if (WSTRB[3]) regfile[widx][31:24] <= WDATA[31:24];
                    BRESP <= 2'b00; // OKAY
                end else begin
                    // 정의되지 않은 주소: DECERR로 처리하려면 2'b11 등으로 변경 가능
                    BRESP <= 2'b00; // 여기선 OKAY로 관대 처리
                end
                BVALID <= 1'b1;
            end else if (BVALID && BREADY) begin
                BVALID <= 1'b0;
            end
        end
    end

    // ---------------------------
    // Read path
    // ---------------------------
    always @(posedge ACLK) begin
        if (!ARESETn) begin
            ARREADY <= 1'b0;
            RVALID  <= 1'b0;
            RRESP   <= 2'b00;
            RDATA   <= 32'd0;
        end else begin
            // Read address ready (1사이클 펄스형)
            ARREADY <= (ARVALID && !ARREADY);

            // 실제 읽기 동작: 주소 핸드셰이크 완료 후 데이터 발행
            if (ARVALID && ARREADY && !RVALID) begin
                if (ridx < 32) begin
                    RDATA <= regfile[ridx];
                    RRESP <= 2'b00; // OKAY
                end else begin
                    RDATA <= 32'hDEADBEEF; // 정의되지 않은 주소 응답
                    RRESP <= 2'b00;        // 필요 시 DECERR로 변경 가능
                end
                RVALID <= 1'b1;
            end else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

endmodule