module PISO #(
    parameter OUT_WIDTH = 8,
    parameter N_CHUNKS  = 4,
    parameter IN_WIDTH  = OUT_WIDTH * N_CHUNKS
)(
    input                  i_clk,
    input                  i_rst,

    input                  i_flush,

    // PISO interface as rx
    input  [IN_WIDTH-1:0]  i_data, 
    input                  i_valid,
    output                 o_ready,

    // PISO interface as tx
    input                  i_ready,  
    output reg             o_valid,  
    output reg [OUT_WIDTH-1:0] o_data
);
    
    generate
        if(N_CHUNKS == 1) begin: single_chunk
            assign o_ready = 1;
            always @(*) begin
                o_valid = i_valid;
                o_data = i_data;
            end
        end
        else begin: multi_chunk
        
            localparam INDEX_WIDTH = $clog2(N_CHUNKS);

            reg [IN_WIDTH-1:0] data_buf;
            reg [INDEX_WIDTH-1:0] chunk_index;
            reg loaded;

            assign o_ready = ~loaded;

            always @(posedge i_clk or posedge i_rst) begin
                if (i_rst) begin
                    data_buf     <= 0;
                    chunk_index  <= 0;
                    o_data       <= 0;
                    o_valid      <= 0;
                    loaded       <= 0;
                end
                else begin
                    if (i_flush && loaded) begin
                        o_data <= {OUT_WIDTH{1'b0}};
                        o_valid <= 1'b0;
                        loaded <= 1'b0;
                        chunk_index <= 0;
                        data_buf <= 0;
                    end
                    else begin
                        if (i_valid && o_ready) begin
                            data_buf     <= i_data;
                            chunk_index  <= 0;
                            o_data       <= i_data[IN_WIDTH-1 -: OUT_WIDTH];  // MSB first
                            o_valid      <= 1'b1;
                            loaded       <= 1'b1;
                        end
                        if (o_valid && i_ready) begin
                            chunk_index <= chunk_index + 1;
                            if (chunk_index == N_CHUNKS - 1) begin
                                o_valid <= 1'b0;
                                loaded  <= 1'b0;
                            end
                            else begin
                                o_data <= data_buf[IN_WIDTH - 1 - chunk_index * OUT_WIDTH - OUT_WIDTH -: OUT_WIDTH];
                            end
                        end
                    end
                end
            end
        end
    endgenerate

endmodule
