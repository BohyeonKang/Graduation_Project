`timescale 1ns / 1ps
module SIPO #(
    parameter IN_WIDTH  = 8,
    parameter N_CHUNKS  = 4,
    parameter OUT_WIDTH = IN_WIDTH * N_CHUNKS
)(
    input                     i_clk,
    input                     i_rst,
    
    input                     i_flush,

    // SIPO interface as rx
    input                     i_valid,
    input  [IN_WIDTH-1:0]     i_data,
    output                    o_ready,

    // SIPO interface as tx
    input                     i_ready,
    output reg [OUT_WIDTH-1:0] o_data,
    output reg                o_valid
);

    generate
        if(N_CHUNKS == 1) begin: single_chunk
            assign o_ready = i_ready;
            always @(*) begin
                o_valid = i_valid;
                o_data = i_data;
            end
        end
        else begin: multi_chunk
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
                    if (i_flush && collecting) begin
                        o_data <= data_buf;
                        o_valid <= 1'b1;
                        collecting <= 1'b0;
                        chunk_index <= 0;
                        data_buf <= 0;
                    end
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
                    if (o_valid && i_ready) begin
                        o_valid <= 1'b0;
                        collecting <= 1'b0;
                        data_buf <= 0;
                        chunk_index <= 0;
                    end
                end
            end
        end
    endgenerate
endmodule
