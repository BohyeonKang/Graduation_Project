//multicast controller
module MC #(
    parameter DATA_BITWIDTH = 16,
    parameter ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,

    input [ID_BITWIDTH-1:0] i_id, //comes from config scan chain
    input [ID_BITWIDTH-1:0] i_tag, //determined by GIN X-BUS and Y-BUS
    
    input [DATA_BITWIDTH-1:0] i_data,
    input i_valid,
    output o_ready,

    input i_ready,
    output o_valid,
    output [DATA_BITWIDTH-1:0] o_data
);

    reg [ID_BITWIDTH-1:0] id_reg;
    always @(posedge i_clk) begin
        if(i_rst)
            id_reg <= 0;
        else
            id_reg <= i_id;
    end

    wire is_match = (id_reg === i_tag);
    wire multicast_enable = i_valid && i_ready && (id_reg == i_tag);

    assign o_data = (multicast_enable) ? i_data : 0;
    assign o_ready = i_ready;
    assign o_valid = multicast_enable;

endmodule