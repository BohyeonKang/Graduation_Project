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

    input [COL_LEN * ROW_LEN - 1:0] i_ctrl_psum_select,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_ifmap_id,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_wght_id,
    input [SLV_NUM * ID_BITWIDTH - 1:0] i_psum_id,

    // GIN interface
    input [IFMAP_DATA_BITWIDTH + IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH - 1:0] i_ifmap_packet,
    input [WGHT_DATA_BITWIDTH + WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH - 1:0] i_wght_packet,
    input [PSUM_DATA_BITWIDTH + PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH - 1:0] i_psum_packet,
    input i_ifmap_valid,
    input i_wght_valid,
    input i_psum_valid,
    output o_ifmap_ready,
    output o_wght_ready,
    output o_psum_ready,

    input i_ifmap_id_valid,
    input i_wght_id_valid,
    input i_psum_id_valid
);

    wire [ROW_LEN-1:0] ctrl_psum_select [COL_LEN-1:0];
    genvar col;
    generate
        for (col = 0; col < COL_LEN; col = col + 1) begin : gen_ctrl_unpack
            assign ctrl_psum_select[col] = i_ctrl_psum_select[col * ROW_LEN +: ROW_LEN];
        end
    endgenerate

    // local wire between ybus and xbus
    wire [COL_LEN * (IFMAP_DATA_BITWIDTH + IFMAP_COL_ID_BITWIDTH) - 1:0] ifmap_packet_ybus2xbus;
    wire [COL_LEN * (WGHT_DATA_BITWIDTH + WGHT_COL_ID_BITWIDTH) - 1:0] wght_packet_ybus2xbus;
    wire [COL_LEN * (PSUM_DATA_BITWIDTH + PSUM_COL_ID_BITWIDTH) - 1:0] psum_packet_ybus2xbus;
    wire [COL_LEN-1:0] ifmap_ready_xbus2ybus;
    wire [COL_LEN-1:0] ifmap_valid_ybus2xbus;
    wire [COL_LEN-1:0] wght_ready_xbus2ybus;
    wire [COL_LEN-1:0] wght_valid_ybus2xbus;
    wire [COL_LEN-1:0] psum_ready_xbus2ybus;
    wire [COL_LEN-1:0] psum_valid_ybus2xbus;

    // local wire between xbus and PEs
    wire [COL_LEN * IFMAP_DATA_BITWIDTH - 1:0] ifmap_packet_xbus2PE;
    wire [COL_LEN * WGHT_DATA_BITWIDTH - 1:0] wght_packet_xbus2PE;
    wire [COL_LEN * PSUM_DATA_BITWIDTH - 1:0] psum_packet_xbus2PE;
    wire ifmap_valid_xbus2PE [COL_LEN-1:0];
    wire wght_valid_xbus2PE [COL_LEN-1:0];
    wire psum_valid_xbus2PE [COL_LEN-1:0];
    wire [ROW_LEN-1:0] ifmap_ready_PE2xbus [COL_LEN-1:0];
    wire [ROW_LEN-1:0] wght_ready_PE2xbus [COL_LEN-1:0];
    wire [ROW_LEN-1:0] psum_ready_PE2xbus [COL_LEN-1:0];

    // wire for Local Network (i.e. Inter PE communication for PSUM)
    wire [(PSUM_DATA_BITWIDTH * ROW_LEN) -1:0] LN_data [COL_LEN:0];
    wire [ROW_LEN-1:0] LN_valid [COL_LEN:0];
    wire [ROW_LEN-1:0] LN_ready [COL_LEN:0];

    // psum dataflow determined by control i_psum_select
    wire [(PSUM_DATA_BITWIDTH * ROW_LEN)-1:0] psum_data_GINorLN [COL_LEN:0];
    wire [ROW_LEN-1:0] psum_valid_GINorLN [COL_LEN:0];
    wire [ROW_LEN-1:0] psum_ready_GINorLN [COL_LEN:0];

    wire [ROW_LEN-1:0] inst_ready [COL_LEN-1:0];
    assign o_inst_ready = & inst_ready;

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
        .o_packet   (ifmap_packet_ybus2xbus),
        .i_ready    (ifmap_ready_xbus2ybus),
        .o_valid    (ifmap_valid_ybus2xbus),

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
        .o_packet   (wght_packet_ybus2xbus),
        .i_ready    (wght_ready_xbus2ybus),
        .o_valid    (wght_valid_ybus2xbus),

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
        .o_packet   (psum_packet_ybus2xbus),
        .i_ready    (psum_ready_xbus2ybus),
        .o_valid    (psum_valid_ybus2xbus),

        // TOP CTRL interface
        .i_id       (i_psum_id),
        .i_id_valid (i_psum_id_valid)
    );

    genvar i, j;
    generate
        for(i=0; i<COL_LEN; i=i+1) begin: GIN_XBUS_gen        
            GIN_BUS #(
                .ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(IFMAP_DATA_BITWIDTH + IFMAP_COL_ID_BITWIDTH),
                .PACKET_OUT_BITWIDTH(IFMAP_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_IFMAP_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (ifmap_packet_ybus2xbus),
                .i_valid    (ifmap_valid_ybus2xbus),
                .o_ready    (ifmap_ready_xbus2ybus),

                // tx
                .o_packet   (ifmap_packet_xbus2PE),
                .i_ready    (i_ifmap_ready),
                .o_valid    (o_ifmap_valid),

                // TOP CTRL interface
                .i_id       (i_ifmap_id),
                .i_id_valid (i_ifmap_id_valid)
            );

            GIN_BUS #(
                .ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(WGHT_DATA_BITWIDTH + WGHT_COL_ID_BITWIDTH),
                .PACKET_OUT_BITWIDTH(WGHT_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_WGHT_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (wght_packet_ybus2xbus),
                .i_valid    (wght_valid_ybus2xbus),
                .o_ready    (wght_ready_xbus2ybus),

                // tx
                .o_packet   (o_wght_packet),
                .i_ready    (i_wght_ready),
                .o_valid    (o_wght_valid),

                // TOP CTRL interface
                .i_id       (i_wght_id),
                .i_id_valid (i_wght_id_valid)
            );

            GIN_BUS #(
                .ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(PSUM_DATA_BITWIDTH + PSUM_COL_ID_BITWIDTH),
                .PACKET_OUT_BITWIDTH(PSUM_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_PSUM_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (psum_packet_ybus2xbus),
                .i_valid    (psum_valid_ybus2xbus),
                .o_ready    (psum_ready_xbus2ybus[i]),

                // tx
                .o_packet   (psum_data_xbus2PE),
                .i_ready    (),
                .o_valid    (),

                // TOP CTRL interface
                .i_id       (i_psum_id),
                .i_id_valid (i_psum_id_valid)
            );
            

            for(j=0; j<ROW_LEN; j=j+1) begin: PE_gen
                assign psum_data_GINorLN[i][j] = (i_psum_select[])
                assign psum_valid_GINorLN[i][j] = 
                assign psum_ready_GINorLN[i][j] = 
                PE_top #(
                    .DATA_BITWIDTH       (8),
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
                    .o_inst_ready          (inst_ready[i][j]),

                    // fifo interface I/O
                    .i_ifmap_fifo_data     (ifmap_packet_xbus2PE[j * IFMAP_DATA_BITWIDTH +: IFMAP_DATA_BITWIDTH]),
                    .i_ifmap_fifo_valid    (ifmap_valid_xbus2PE[i]),
                    .o_ifmap_fifo_ready    (ifmap_ready_PE2xbus[i][j]),

                    .i_wght_fifo_data      (wght_packet_xbus2PE[j * IFMAP_DATA_BITWIDTH +: IFMAP_DATA_BITWIDTH]),
                    .i_wght_fifo_valid     (wght_valid_xbus2PE[i]),
                    .o_wght_fifo_ready     (wght_ready_PE2xbus[i][j]),

                    .i_psum_in_fifo_data   (psum_packet_xbus2PE),
                    .i_psum_in_fifo_valid  (psum_valid_xbus2PE[i]),
                    .o_psum_in_fifo_ready  (psum_ready_PE2xbus[i][j]),

                    .o_psum_out_fifo_data  (psum_data[i+1]),
                    .o_psum_out_fifo_valid (psum_valid[i+1]),
                    .i_psum_out_fifo_ready (psum_ready[i+1])
                );
            end
        end
    endgenerate
endmodule