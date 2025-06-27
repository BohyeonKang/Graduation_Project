module PE_array #(
    parameter ROW_LEN = 3,
    parameter COL_LEN = 3,
    parameter IFMAP_DATA_BITWIDTH = 8,
    parameter IFMAP_ROW_ID_BITWIDTH = 4,
    parameter IFMAP_COL_ID_BITWIDTH = 4,
    parameter WGHT_DATA_BITWIDTH = 8,
    parameter WGHT_ROW_ID_BITWIDTH = 4,
    parameter WGHT_COL_ID_BITWIDTH = 4,
    parameter PSUM_DATA_BITWIDTH = 8,
    parameter PSUM_ROW_ID_BITWIDTH = 4,
    parameter PSUM_COL_ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,
    
    // TOP CTRL interface
    input [2:0] i_inst_data,
    input [8:0] i_conv_info,
    input i_inst_valid,
    output o_inst_ready,

    // GIN interface
    input [PACKET_IN_BITWIDTH-1:0] i_ifmap_packet,
    input [PACKET_IN_BITWIDTH-1:0] i_wght_packet,
    input [PACKET_IN_BITWIDTH-1:0] i_psum_packet,
    input i_ifmap_valid,
    input i_wght_valid,
    input i_psum_valid,
    output o_ifmap_ready,
    output o_wght_ready,
    output o_psum_ready,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_ifmap_id,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_wght_id,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_psum_id,
    input i_ifmap_id_valid,
    input i_wght_id_valid,
    input i_psum_id_valid
);

    wire [COL_LEN * (IFMAP_DATA_BITWIDTH + IFMAP_COL_ID_BITWIDTH) - 1:0] ifmap_packet_ybus2xbus;
    wire [COL_LEN * (WGHT_DATA_BITWIDTH + WGHT_COL_ID_BITWIDTH) - 1:0] wght_packet_ybus2xbus;
    wire [COL_LEN * (PSUM_DATA_BITWIDTH + PSUM_COL_ID_BITWIDTH) - 1:0] psum_packet_ybus2xbus;

    //generate 문 안에서?
    wire [COL_LEN * IFMAP_DATA_BITWIDTH - 1:0] ifmap_packet_xbus2PE;
    wire [COL_LEN * WGHT_DATA_BITWIDTH - 1:0] wght_packet_xbus2PE;
    wire [COL_LEN * PSUM_DATA_BITWIDTH - 1:0] psum_packet_xbus2PE;


    input [SLV_NUM-1:0] i_ifmap_ready,
    output [SLV_NUM-1:0] o_ifmap_valid,


    GIN_BUS #(
        .ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(IFMAP_DATA_BITWIDTH + IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH),
        .PACKET_OUT_BITWIDTH(IFMAP_DATA_BITWIDTH + IFMAP_COL_ID_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_IFMAP_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_ifmap_packet),
        .i_valid    (i_ifmap_valid),
        .o_ready    (o_ifmap_ready),

        // tx
        .o_packet   (o_ifmap_packet),
        .i_ready    (i_ifmap_ready),
        .o_valid    (o_ifmap_valid),

        // TOP CTRL interface
        .i_id       (i_ifmap_id),
        .i_id_valid (i_ifmap_id_valid)
    );

    GIN_BUS #(
        .ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(WGHT_DATA_BITWIDTH + WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH),
        .PACKET_OUT_BITWIDTH(WGHT_DATA_BITWIDTH + WGHT_COL_ID_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_WGHT_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_wght_packet),
        .i_valid    (i_wght_valid),
        .o_ready    (o_wght_ready),

        // tx
        .o_packet   (o_wght_packet),
        .i_ready    (i_wght_ready),
        .o_valid    (o_wght_valid),

        // TOP CTRL interface
        .i_id       (i_wght_id),
        .i_id_valid (i_wght_id_valid)
    );

    GIN_BUS #(
        .ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(PSUM_DATA_BITWIDTH + PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH),
        .PACKET_OUT_BITWIDTH(PSUM_DATA_BITWIDTH + PSUM_COL_ID_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_PSUM_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_psum_packet),
        .i_valid    (i_psum_valid),
        .o_ready    (o_psum_ready),

        // tx
        .o_packet   (o_psum_packet),
        .i_ready    (i_psum_ready),
        .o_valid    (o_psum_valid),

        // TOP CTRL interface
        .i_id       (i_psum_id),
        .i_id_valid (i_psum_id_valid)
    );

    genvar i;
    generate
        for(i=0; i<COL_LEN; i=i+1) begin: GIN_XBUS_gen
            GIN_BUS #(
                .ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(IFMAP_PACKET_IN_BITWIDTH),
                .PACKET_OUT_BITWIDTH(IFMAP_PACKET_OUT_BITWIDTH),
                .SLV_NUM(COL_LEN)
            ) u_GIN_IFMAP_YBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (i_ifmap_packet),
                .i_valid    (i_ifmap_valid),
                .o_ready    (o_ifmap_ready),

                // tx
                .o_packet   (o_ifmap_packet),
                .i_ready    (i_ifmap_ready),
                .o_valid    (o_ifmap_valid),

                // TOP CTRL interface
                .i_id       (i_ifmap_id),
                .i_id_valid (i_ifmap_id_valid)
            );

            GIN_BUS #(
                .ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(WGHT_PACKET_IN_BITWIDTH),
                .PACKET_OUT_BITWIDTH(WGHT_PACKET_OUT_BITWIDTH),
                .SLV_NUM(COL_LEN)
            ) u_GIN_WGHT_YBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (i_wght_packet),
                .i_valid    (i_wght_valid),
                .o_ready    (o_wght_ready),

                // tx
                .o_packet   (o_wght_packet),
                .i_ready    (i_wght_ready),
                .o_valid    (o_wght_valid),

                // TOP CTRL interface
                .i_id       (i_wght_id),
                .i_id_valid (i_wght_id_valid)
            );

            GIN_BUS #(
                .ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(PSUM_PACKET_IN_BITWIDTH),
                .PACKET_OUT_BITWIDTH(PSUM_PACKET_OUT_BITWIDTH),
                .SLV_NUM(COL_LEN)
            ) u_GIN_PSUM_YBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (i_psum_packet),
                .i_valid    (i_psum_valid),
                .o_ready    (o_psum_ready),

                // tx
                .o_packet   (o_psum_packet),
                .i_ready    (i_psum_ready),
                .o_valid    (o_psum_valid),

                // TOP CTRL interface
                .i_id       (i_psum_id),
                .i_id_valid (i_psum_id_valid)
            );
        end
    endgenerate

    genvar i, j;
    generate
        for(i=0; i<COL_LEN; i=i+1) begin: PE_gen_vertical
            for(j=0; j<ROW_LEN; j=j+1) begin: PE_gen_horizontal
                PE_top #(
                    .DATA_BITWIDTH       (DATA_BITWIDTH),
                    .IFMAP_ADDR_BITWIDTH (4),
                    .WGHT_ADDR_BITWIDTH  (7),
                    .PSUM_ADDR_BITWIDTH  (3)
                ) u_PE_top (
                    .i_clk                 (i_clk),
                    .i_rst                 (i_rst),

                    // TOP CTRL
                    .i_inst_data           (i_inst_data),
                    .i_conv_info           (i_conv_info),
                    .i_inst_valid          (i_inst_valid),
                    .o_inst_ready          (inst_ready[i]),

                    // fifo interface I/O
                    .i_ifmap_fifo_data     (i_ifmap_data),
                    .i_ifmap_fifo_valid    (i_ifmap_valid),
                    .o_ifmap_fifo_ready    (ifmap_ready[i]),

                    .i_wght_fifo_data      (i_wght_data),
                    .i_wght_fifo_valid     (i_wght_valid),
                    .o_wght_fifo_ready     (wght_ready[i]),

                    .i_psum_in_fifo_data   (psum_data[i]),
                    .i_psum_in_fifo_valid  (psum_valid[i]),
                    .o_psum_in_fifo_ready  (psum_ready[i]),

                    .o_psum_out_fifo_data  (psum_data[i+1]),
                    .o_psum_out_fifo_valid (psum_valid[i+1]),
                    .i_psum_out_fifo_ready (psum_ready[i+1])
                );
        end
    endgenerate

endmodule