`timescale 1ns / 1ps

// GIN for communication between GLB and PE Array
module GIN_BUS #(
    parameter ID_BITWIDTH = 4,
    parameter PACKET_IN_BITWIDTH = 12,
    parameter PACKET_OUT_BITWIDTH = 8,
    parameter SLV_NUM = 6
)(
    input i_clk,
    input i_rst,

    // rx
    input [PACKET_IN_BITWIDTH-1:0] i_packet,
    input i_valid,
    output o_ready,

    // tx
    output [SLV_NUM * PACKET_OUT_BITWIDTH - 1:0] o_packet,
    input [SLV_NUM-1:0] i_ready,
    output [SLV_NUM-1:0] o_valid,

    // TOP CTRL interface
    input [0:SLV_NUM * ID_BITWIDTH - 1] i_id,
    input i_id_valid
);

    wire [ID_BITWIDTH-1:0] tag;
    wire [PACKET_OUT_BITWIDTH-1:0] data;
    assign {tag, data} = i_packet;

    wire [ID_BITWIDTH-1:0] id [0:SLV_NUM-1];

    wire [SLV_NUM-1:0] slv_MC_ready;

    assign o_ready = & slv_MC_ready;

    genvar i;
    generate
        for(i=0; i<SLV_NUM; i=i+1) begin: BUS_MC_gen
            assign id[i] = i_id[i * ID_BITWIDTH +: ID_BITWIDTH];

            MC #(
                .DATA_BITWIDTH(PACKET_OUT_BITWIDTH),
                .ID_BITWIDTH(ID_BITWIDTH)
            ) u_MC (
                .i_clk(i_clk),
                .i_rst(i_rst),

                .i_id(id[i]),
                .i_id_valid(i_id_valid),
                .i_tag(tag),
                
                .i_data(data),
                .i_valid(i_valid),
                .o_ready(slv_MC_ready[i]),

                .i_ready(i_ready[i]),
                .o_valid(o_valid[i]),
                .o_data(o_packet[i * PACKET_OUT_BITWIDTH +: PACKET_OUT_BITWIDTH])
            );
        end
    endgenerate
endmodule