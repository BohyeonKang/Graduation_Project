// GIN for communication between GLB and PE Array
module GON_BUS #(
    parameter ID_BITWIDTH = 4,
    parameter PACKET_IN_BITWIDTH = 8,
    parameter PACKET_OUT_BITWIDTH = 8,
    parameter SLV_NUM = 6
)(
    input i_clk,
    input i_rst,

    // rx
    input [SLV_NUM * PACKET_IN_BITWIDTH - 1:0] i_packet,
    output [SLV_NUM-1:0] o_ready,
    input [SLV_NUM-1:0] i_valid,

    // tx
    output [SLV_NUM * PACKET_OUT_BITWIDTH-1:0] o_packet,
    output [SLV_NUM-1:0] o_valid,
    input [SLV_NUM-1:0] i_ready,

    // TOP CTRL interface
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_id,
    input i_id_valid,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_tag // for selecting which output to send to GLB
);

    wire [ID_BITWIDTH-1:0] id [SLV_NUM-1:0];

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

                .i_id(id[i]), //comes from config scan chain
                .i_id_valid(i_id_valid),
                .i_tag(i_tag[i * ID_BITWIDTH +: ID_BITWIDTH]), //determined by GIN X-BUS and Y-BUS
                
                .i_data(data),
                .i_valid(i_valid),
                .o_ready(o_ready),

                .i_ready(i_ready[i]),
                .o_valid(o_valid[i]),
                .o_data(o_packet[i * PACKET_OUT_BITWIDTH +: PACKET_OUT_BITWIDTH])
            );
        end
    endgenerate
endmodule