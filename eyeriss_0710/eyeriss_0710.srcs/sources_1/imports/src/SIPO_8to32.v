module SIPO_8to32 (
    input         i_clk,
    input         i_rst,

    // SIPO interface as rx
    input         i_valid,      // Serial input data valid
    input  [7:0]  i_data,       // Serial 8-bit input
    output        o_ready,      // Ready to accept 8-bit input

    // SIPO interface as tx
    input         i_ready,      // Downstream ready to accept 32-bit output
    output reg [31:0] o_data,   // 32-bit parallel output
    output reg        o_valid   // Output valid when 32-bit data is ready
);

    reg [31:0] data_buf;
    reg [1:0]  byte_index;
    reg        collecting;      // 내부 수신 중 상태

    assign o_ready = ~o_valid;  // 32비트 완성 전에는 항상 ready

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            data_buf    <= 32'd0;
            byte_index  <= 2'd0;
            o_data      <= 32'd0;
            o_valid     <= 1'b0;
            collecting  <= 1'b0;
        end
        else begin
            // 입력 수신 (8비트씩)
            if (i_valid && o_ready) begin
                collecting <= 1'b1;
                case (byte_index)
                    2'd0: data_buf[31:24] <= i_data;
                    2'd1: data_buf[23:16] <= i_data;
                    2'd2: data_buf[15:8]  <= i_data;
                    2'd3: begin
                        data_buf[7:0] <= i_data;
                        o_data <= {data_buf[31:8], i_data};
                        o_valid <= 1'b1;
                        collecting <= 1'b0;
                    end
                endcase

                if (byte_index == 2'd3)
                    byte_index <= 2'd0;
                else
                    byte_index <= byte_index + 1;
            end

            // 출력 수신 완료 시 valid 떨어뜨리기
            if (o_valid && i_ready) begin
                o_valid <= 1'b0;
            end
        end
    end

endmodule
