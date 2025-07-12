module PISO_32to8 (
    input         i_clk,
    input         i_rst,

    // PISO interface as rx
    input  [31:0] i_data,       // 32-bit parallel input
    input         i_valid,      // Input data valid
    output        o_ready,      // Ready to accept new data

    // PISO interface as tx
    input         i_ready,      // Downstream ready
    output reg    o_valid,      // Output data valid
    output reg [7:0] o_data     // 8-bit output
);

    reg [31:0] data_buf;
    reg [1:0]  byte_index;
    reg        loaded;

    assign o_ready = ~loaded;  // Only accept new data when not loaded

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            data_buf    <= 32'd0;
            byte_index  <= 2'd0;
            o_data      <= 8'd0;
            o_valid     <= 1'b0;
            loaded      <= 1'b0;
        end
        else begin
            // Load 32-bit data when valid & ready
            if (i_valid && o_ready) begin
                data_buf    <= i_data;
                byte_index  <= 2'd0;
                o_data      <= i_data[31:24];  // MSB first
                o_valid     <= 1'b1;
                loaded      <= 1'b1;
            end
            // Send next byte when downstream is ready and current output is valid
            else if (o_valid && i_ready) begin
                byte_index <= byte_index + 1;
                case (byte_index)
                    2'd0: o_data <= data_buf[23:16];
                    2'd1: o_data <= data_buf[15:8];
                    2'd2: o_data <= data_buf[7:0];
                    2'd3: begin
                        o_data  <= 8'd0;
                        o_valid <= 1'b0;
                        loaded  <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
