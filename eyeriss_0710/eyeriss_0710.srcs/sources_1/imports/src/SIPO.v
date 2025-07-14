module SIPO #(
    parameter IN_WIDTH  = 8,
    parameter N_CHUNKS  = 4,
    parameter OUT_WIDTH = IN_WIDTH * N_CHUNKS
)(
    input                     i_clk,
    input                     i_rst,
    input                     i_flush,

    // RX interface
    input                     i_valid,
    input  [IN_WIDTH-1:0]     i_data,
    output                    o_ready,

    // TX interface
    input                     i_ready,
    output reg [OUT_WIDTH-1:0] o_data,
    output reg                o_valid
);

    localparam INDEX_WIDTH = $clog2(N_CHUNKS);

    reg [OUT_WIDTH-1:0] data_buf;
    reg [INDEX_WIDTH-1:0] chunk_index;
    reg collecting;

    assign o_ready = ~o_valid;

    integer i;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            data_buf    <= 0;
            chunk_index <= 0;
            o_data      <= 0;
            o_valid     <= 0;
            collecting  <= 0;
        end
        else begin
            // ✅ flush가 수신 중일 때 우선 처리
            if (i_flush && collecting) begin
                o_data <= data_buf;  // 남은 데이터 그대로 출력
                o_valid <= 1'b1;
                collecting <= 1'b0;
                chunk_index <= 0;
                data_buf <= 0;
            end

            // ✅ 유효한 데이터 수신 중
            else if (i_valid && o_ready) begin
                collecting <= 1'b1;

                data_buf[(OUT_WIDTH - 1 - chunk_index * IN_WIDTH) -: IN_WIDTH] <= i_data;
                chunk_index <= chunk_index + 1;

                if (chunk_index == N_CHUNKS - 1) begin
                    o_data <= {data_buf[OUT_WIDTH - IN_WIDTH - 1:0], i_data};
                    o_valid <= 1'b1;
                    collecting <= 1'b0;
                    chunk_index <= 0;
                    data_buf <= 0;
                end
            end

            // ✅ 출력 완료 후 상태 리셋
            if (o_valid && i_ready) begin
                o_valid <= 1'b0;
                collecting <= 1'b0;
                data_buf <= 0;
                chunk_index <= 0;
            end
        end
    end
endmodule
