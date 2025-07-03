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

    input [IFMAP_ROW_ID_BITWIDTH * COL_LEN-1:0] i_ifmap_row_id,
    input [WGHT_ROW_ID_BITWIDTH * COL_LEN-1:0] i_wght_row_id,
    input [PSUM_ROW_ID_BITWIDTH * COL_LEN-1:0] i_psum_row_id,

    input i_ifmap_row_id_valid,
    input i_wght_row_id_valid,
    input i_psum_row_id_valid,

    // col ID는 한번에 한 ROW씩 들어오는걸로 가정
    input [IFMAP_COL_ID_BITWIDTH * ROW_LEN - 1 :0] i_ifmap_col_id,
    input [WGHT_COL_ID_BITWIDTH * ROW_LEN - 1 :0] i_wght_col_id,
    input [PSUM_COL_ID_BITWIDTH * ROW_LEN - 1 :0] i_psum_col_id,

    // one-hot encoded valid signal
    input [COL_LEN-1:0] i_ifmap_col_id_valid,
    input [COL_LEN-1:0] i_wght_col_id_valid,
    input [COL_LEN-1:0] i_psum_col_id_valid,

    input [COL_LEN * ROW_LEN - 1:0] i_ctrl_psum_select,

    // GLB interface
    input [IFMAP_DATA_BITWIDTH + IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH - 1:0] i_ifmap_packet,
    input [WGHT_DATA_BITWIDTH + WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH - 1:0] i_wght_packet,
    input [PSUM_DATA_BITWIDTH + PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH - 1:0] i_psum_in_packet,

    input i_ifmap_valid,
    input i_wght_valid,
    input i_psum_in_valid,

    output o_ifmap_ready,
    output o_wght_ready,
    output o_psum_in_ready
);

    genvar col, row;

    wire inst_ready_pe [0:COL_LEN-1][0:ROW_LEN-1];
    wire [COL_LEN-1:0] inst_ready_rowwise;
    wire [COL_LEN * ROW_LEN-1:0] inst_ready_flatten;
    assign o_inst_ready = & inst_ready_flatten;

    generate
        for (col = 0; col < COL_LEN; col = col + 1) begin : gen_inst_ready_col
            for (row = 0; row < ROW_LEN; row = row + 1) begin : gen_inst_ready_row
                assign inst_ready_flatten[col * ROW_LEN + row] = inst_ready_pe[col][row];
            end
            assign inst_ready_rowwise[col] = &inst_ready_flatten[col * ROW_LEN +: ROW_LEN];
        end
    endgenerate

    // signals between ybus and xbus (GIN)
    wire [IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH - 1 : 0] ifmap_packet_ybus2xbus [0:COL_LEN-1];
    wire [WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH - 1 : 0] wght_packet_ybus2xbus [0:COL_LEN-1];
    wire [PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH - 1 : 0] psum_in_packet_ybus2xbus [0:COL_LEN-1];

    wire ifmap_valid_ybus2xbus [0:COL_LEN-1];
    wire wght_valid_ybus2xbus [0:COL_LEN-1];
    wire psum_in_valid_ybus2xbus [0:COL_LEN-1];

    wire ifmap_ready_xbus2ybus [0:COL_LEN-1];
    wire wght_ready_xbus2ybus [0:COL_LEN-1];
    wire psum_in_ready_xbus2ybus [0:COL_LEN-1];


    wire [COL_LEN * (IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH) - 1 : 0] ifmap_packet_ybus2xbus_flatten;
    wire [COL_LEN * (WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH) - 1 : 0] wght_packet_ybus2xbus_flatten;
    wire [COL_LEN * (PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH) - 1 : 0] psum_in_packet_ybus2xbus_flatten;

    wire [COL_LEN-1:0] ifmap_valid_ybus2xbus_flatten;
    wire [COL_LEN-1:0] wght_valid_ybus2xbus_flatten;
    wire [COL_LEN-1:0] psum_in_valid_ybus2xbus_flatten;

    wire [COL_LEN-1:0] ifmap_ready_xbus2ybus_flatten;
    wire [COL_LEN-1:0] wght_ready_xbus2ybus_flatten;
    wire [COL_LEN-1:0] psum_in_ready_xbus2ybus_flatten;


    // signals between xbus and PE (GIN)
    wire [IFMAP_DATA_BITWIDTH-1:0] ifmap_packet_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];
    wire [WGHT_DATA_BITWIDTH-1:0] wght_packet_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];
    wire [PSUM_DATA_BITWIDTH-1:0] psum_in_packet_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];

    wire ifmap_valid_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];
    wire wght_valid_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];
    wire psum_in_valid_xbus2PE [0:COL_LEN-1][0:ROW_LEN-1];

    wire ifmap_ready_PE2xbus [0:COL_LEN-1][0:ROW_LEN-1];
    wire wght_ready_PE2xbus [0:COL_LEN-1][0:ROW_LEN-1];
    wire psum_in_ready_PE2xbus [0:COL_LEN-1][0:ROW_LEN-1];

    wire [ROW_LEN * IFMAP_DATA_BITWIDTH - 1 : 0] ifmap_packet_xbus2PE_flatten [0:COL_LEN-1];
    wire [ROW_LEN * WGHT_DATA_BITWIDTH - 1 : 0] wght_packet_xbus2PE_flatten [0:COL_LEN-1];
    wire [ROW_LEN * PSUM_DATA_BITWIDTH - 1 : 0] psum_in_packet_xbus2PE_flatten [0:COL_LEN-1];

    wire [ROW_LEN-1:0] ifmap_valid_xbus2PE_flatten [0:COL_LEN-1];
    wire [ROW_LEN-1:0] wght_valid_xbus2PE_flatten [0:COL_LEN-1];
    wire [ROW_LEN-1:0] psum_in_valid_xbus2PE_flatten [0:COL_LEN-1];

    wire [ROW_LEN-1:0] ifmap_ready_PE2xbus_flatten [0:COL_LEN-1];
    wire [ROW_LEN-1:0] wght_ready_PE2xbus_flatten [0:COL_LEN-1];
    wire [ROW_LEN-1:0] psum_in_ready_PE2xbus_flatten [0:COL_LEN-1];

    // signals between interPE (LN)
    wire [PSUM_DATA_BITWIDTH-1:0] LN_psum_data [0:COL_LEN][0:ROW_LEN-1];
    wire LN_psum_valid [0:COL_LEN][0:ROW_LEN-1];
    wire LN_psum_ready [0:COL_LEN][0:ROW_LEN-1];

    generate
        for(row = 0; row < ROW_LEN; row = row + 1) begin : init_LN
            assign LN_psum_data[COL_LEN][row] = 0;
            assign LN_psum_valid[COL_LEN][row] = 1;
            assign LN_psum_ready[0][row] = 1; // GON
        end
    endgenerate

    generate
        for(col=0; col<COL_LEN; col=col+1) begin
            for(row=0; row<ROW_LEN; row=row+1) begin
                assign psum_in_ready_PE2xbus[col][row] = LN_psum_ready[col][row];
            end
        end
    endgenerate

    reg [PSUM_DATA_BITWIDTH-1:0] psum_in_data_mux_select [0:COL_LEN-1][0:ROW_LEN-1];
    reg psum_in_valid_mux_select [0:COL_LEN-1][0:ROW_LEN-1];

    integer i, j;
    always @(*) begin
        for(i=0; i<COL_LEN; i=i+1) begin
            for(j=0; j<ROW_LEN; j=j+1) begin
                if(i_ctrl_psum_select[i * ROW_LEN + j]) begin
                    psum_in_data_mux_select[i][j] = psum_in_packet_xbus2PE[i][j];
                    psum_in_valid_mux_select[i][j] = psum_in_valid_xbus2PE[i][j];
                end
                else begin
                    psum_in_data_mux_select[i][j] = LN_psum_data[i+1][j];
                    psum_in_valid_mux_select[i][j] = LN_psum_valid[i+1][j];
                end
            end
        end
    end

    generate
        for (col = 0; col < COL_LEN; col = col + 1) begin : gen_col_flatten
            assign ifmap_packet_ybus2xbus[col] = ifmap_packet_ybus2xbus_flatten[col * (IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH) +: (IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH)];
            assign wght_packet_ybus2xbus[col] = wght_packet_ybus2xbus_flatten[col * (WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH) +: (WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH)];
            assign psum_in_packet_ybus2xbus[col] = psum_in_packet_ybus2xbus_flatten[col * (PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH) +: (PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH)];

            assign ifmap_valid_ybus2xbus[col] = ifmap_valid_ybus2xbus_flatten[col];
            assign wght_valid_ybus2xbus[col] = wght_valid_ybus2xbus_flatten[col];
            assign psum_in_valid_ybus2xbus[col] = psum_in_valid_ybus2xbus_flatten[col];

            assign ifmap_ready_xbus2ybus_flatten[col] = ifmap_ready_xbus2ybus[col];
            assign wght_ready_xbus2ybus_flatten[col] = wght_ready_xbus2ybus[col];
            assign psum_in_ready_xbus2ybus_flatten[col] = psum_in_ready_xbus2ybus[col];

            for (row = 0; row < ROW_LEN; row = row + 1) begin : gen_row_flatten
                assign ifmap_packet_xbus2PE[col][row] = ifmap_packet_xbus2PE_flatten[col][row * IFMAP_DATA_BITWIDTH +: IFMAP_DATA_BITWIDTH];
                assign wght_packet_xbus2PE[col][row] = wght_packet_xbus2PE_flatten[col][row * WGHT_DATA_BITWIDTH +: WGHT_DATA_BITWIDTH];
                assign psum_in_packet_xbus2PE[col][row] = psum_in_packet_xbus2PE_flatten[col][row * PSUM_DATA_BITWIDTH +: PSUM_DATA_BITWIDTH];

                assign ifmap_valid_xbus2PE[col][row] = ifmap_valid_xbus2PE_flatten[col][row];
                assign wght_valid_xbus2PE[col][row] = wght_valid_xbus2PE_flatten[col][row];
                assign psum_in_valid_xbus2PE[col][row] = psum_in_valid_xbus2PE_flatten[col][row];

                assign ifmap_ready_PE2xbus_flatten[col][row] = ifmap_ready_PE2xbus[col][row];
                assign wght_ready_PE2xbus_flatten[col][row] = wght_ready_PE2xbus[col][row];
                assign psum_in_ready_PE2xbus_flatten[col][row] = psum_in_ready_PE2xbus[col][row];
            end
        end
    endgenerate

    GIN_BUS #(
        .ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_IFMAP_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_ifmap_packet),
        .i_valid    (i_ifmap_valid),
        .o_ready    (o_ifmap_ready),

        // tx
        .o_packet   (ifmap_packet_ybus2xbus_flatten),
        .i_ready    (ifmap_ready_xbus2ybus_flatten),
        .o_valid    (ifmap_valid_ybus2xbus_flatten),

        // TOP CTRL interface
        .i_id       (i_ifmap_row_id),
        .i_id_valid (i_ifmap_row_id_valid)
    );

    GIN_BUS #(
        .ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_WGHT_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_wght_packet),
        .i_valid    (i_wght_valid),
        .o_ready    (o_wght_ready),

        // tx
        .o_packet   (wght_packet_ybus2xbus_flatten),
        .i_ready    (wght_ready_xbus2ybus_flatten),
        .o_valid    (wght_valid_ybus2xbus_flatten),

        // TOP CTRL interface
        .i_id       (i_wght_row_id),
        .i_id_valid (i_wght_row_id_valid)
    );

    GIN_BUS #(
        .ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH),
        .SLV_NUM(COL_LEN)
    ) u_GIN_PSUM_YBUS (
        .i_clk      (i_clk),
        .i_rst      (i_rst),

        // rx
        .i_packet   (i_psum_in_packet),
        .i_valid    (i_psum_in_valid),
        .o_ready    (o_psum_in_ready),

        // tx
        .o_packet   (psum_in_packet_ybus2xbus_flatten),
        .i_ready    (psum_in_ready_xbus2ybus_flatten),
        .o_valid    (psum_in_valid_ybus2xbus_flatten),

        // TOP CTRL interface
        .i_id       (i_psum_row_id),
        .i_id_valid (i_psum_row_id_valid)
    );

    generate
        for(col = 0; col < COL_LEN; col = col + 1) begin: GIN_XBUS_gen        
            GIN_BUS #(
                .ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(IFMAP_COL_ID_BITWIDTH + IFMAP_DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(IFMAP_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_IFMAP_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (ifmap_packet_ybus2xbus[col]),
                .i_valid    (ifmap_valid_ybus2xbus[col]),
                .o_ready    (ifmap_ready_xbus2ybus[col]),

                // tx
                .o_packet   (ifmap_packet_xbus2PE_flatten[col]),
                .i_ready    (ifmap_ready_PE2xbus_flatten[col]),
                .o_valid    (ifmap_valid_xbus2PE_flatten[col]),

                // TOP CTRL interface
                .i_id       (i_ifmap_col_id),
                .i_id_valid (i_ifmap_col_id_valid[col])
            );

            GIN_BUS #(
                .ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(WGHT_COL_ID_BITWIDTH + WGHT_DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(WGHT_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_WGHT_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (wght_packet_ybus2xbus[col]),
                .i_valid    (wght_valid_ybus2xbus[col]),
                .o_ready    (wght_ready_xbus2ybus[col]),

                // tx
                .o_packet   (wght_packet_xbus2PE_flatten[col]),
                .i_ready    (wght_ready_PE2xbus_flatten[col]),
                .o_valid    (wght_valid_xbus2PE_flatten[col]),

                // TOP CTRL interface
                .i_id       (i_wght_col_id),
                .i_id_valid (i_wght_col_id_valid[col])
            );

            GIN_BUS #(
                .ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(PSUM_COL_ID_BITWIDTH + PSUM_DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(PSUM_DATA_BITWIDTH),
                .SLV_NUM(ROW_LEN)
            ) u_GIN_PSUM_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (psum_in_packet_ybus2xbus[col]),
                .i_valid    (psum_in_valid_ybus2xbus[col]),
                .o_ready    (psum_in_ready_xbus2ybus[col]),

                // tx
                .o_packet   (psum_in_packet_xbus2PE_flatten[col]),
                .i_ready    (psum_in_ready_PE2xbus_flatten[col]),
                .o_valid    (psum_in_valid_xbus2PE_flatten[col]),

                // TOP CTRL interface
                .i_id       (i_psum_col_id),
                .i_id_valid (i_psum_col_id_valid[col])
            );
        end
    endgenerate

    generate
        for(col = 0; col < COL_LEN; col = col + 1) begin: PE_gen_vertical
            for(row = 0; row < ROW_LEN; row = row + 1) begin: PE_gen_horizontal
            PE_top #(
                .DATA_BITWIDTH       (16),
                .IFMAP_ADDR_BITWIDTH (2),
                .WGHT_ADDR_BITWIDTH  (2),
                .PSUM_ADDR_BITWIDTH  (2)
            ) u_PE_top (
                .i_clk                 (i_clk),
                .i_rst                 (i_rst),

                // TOP CTRL
                .i_inst_data           (i_inst_data),
                .i_conv_info           (i_conv_info),
                .i_inst_valid          (i_inst_valid),
                .o_inst_ready          (inst_ready_pe[col][row]),

                // fifo interface I/O
                .i_ifmap_fifo_data     (ifmap_packet_xbus2PE[col][row]),
                .i_ifmap_fifo_valid    (ifmap_valid_xbus2PE[col][row]),
                .o_ifmap_fifo_ready    (ifmap_ready_PE2xbus[col][row]),

                .i_wght_fifo_data      (wght_packet_xbus2PE[col][row]),
                .i_wght_fifo_valid     (wght_valid_xbus2PE[col][row]),
                .o_wght_fifo_ready     (wght_ready_PE2xbus[col][row]),

                .i_psum_in_fifo_data   (psum_in_data_mux_select[col][row]),
                .i_psum_in_fifo_valid  (psum_in_valid_mux_select[col][row]),
                .o_psum_in_fifo_ready  (LN_psum_ready[col+1][row]),

                .o_psum_out_fifo_data  (LN_psum_data[col][row]),
                .o_psum_out_fifo_valid (LN_psum_valid[col][row]),
                .i_psum_out_fifo_ready (LN_psum_ready[col][row])
            );
            end
        end
    endgenerate
endmodule