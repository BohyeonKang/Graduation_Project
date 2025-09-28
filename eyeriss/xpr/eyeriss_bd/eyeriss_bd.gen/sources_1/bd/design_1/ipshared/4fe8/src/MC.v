`timescale 1ns / 1ps
//multicast controller
module MC #(
    parameter DATA_BITWIDTH = 8,
    parameter ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,
        
    // rx
    input [DATA_BITWIDTH-1:0] i_data,
    input i_valid,
    output o_ready,

    // tx
    input i_ready,
    output o_valid,
    output [DATA_BITWIDTH-1:0] o_data,

    // ctrl
    input [ID_BITWIDTH-1:0] i_id, // determined by TOP CTRL config scan chain
    input                   i_id_valid,
    input [ID_BITWIDTH-1:0] i_tag // packet from data
);

    reg [ID_BITWIDTH-1:0] id_reg;
    always @(posedge i_clk) begin
        if(i_rst)
            id_reg <= 0;
        else if(i_id_valid)
            id_reg <= i_id;
    end
    
    wire multicast_enable = i_valid && i_ready && (id_reg == i_tag);

    assign o_data = (multicast_enable) ? i_data : 0;
    assign o_ready = i_ready;
    assign o_valid = multicast_enable;

endmodule