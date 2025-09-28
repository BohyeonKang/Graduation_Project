`timescale 1ns / 1ps
module PE_array #(
    parameter NUM_ROWS = 3,
    parameter NUM_COLS = 3,
    parameter DATA_BITWIDTH = 8,

    parameter IFMAP_BUS_BITWIDTH = 8,
    parameter IFMAP_ROW_ID_BITWIDTH = 4,
    parameter IFMAP_COL_ID_BITWIDTH = 5,

    parameter WGHT_BUS_BITWIDTH = 32,
    parameter WGHT_ROW_ID_BITWIDTH = 4,
    parameter WGHT_COL_ID_BITWIDTH = 4,

    parameter PSUM_BUS_BITWIDTH = 32,
    parameter PSUM_ROW_ID_BITWIDTH = 4,
    parameter PSUM_COL_ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,
    
    // TOP CTRL interface
    input [2:0] i_inst_data,
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [3:0] i_layer_s,
    input i_inst_valid,
    output o_inst_ready,

    input [0:IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1] i_ifmap_row_id,
    input [0:WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1] i_wght_row_id,
    input [0:PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1] i_psum_row_id,

    input i_ifmap_row_id_valid,
    input i_wght_row_id_valid,
    input i_psum_row_id_valid,

    // col ID는 한번에 한 ROW씩 들어오는걸로 가정
    input [0:IFMAP_COL_ID_BITWIDTH * NUM_COLS-1] i_ifmap_col_id,
    input [0:WGHT_COL_ID_BITWIDTH * NUM_COLS-1] i_wght_col_id,
    input [0:PSUM_COL_ID_BITWIDTH * NUM_COLS-1] i_psum_col_id,

    // one-hot encoded valid signal
    input [0:NUM_ROWS-1] i_ifmap_col_id_valid,
    input [0:NUM_ROWS-1] i_wght_col_id_valid,
    input [0:NUM_ROWS-1] i_psum_col_id_valid,

    input [0:NUM_ROWS*NUM_COLS-1] i_ctrl_psum_in_sel_LNorGIN,
    input [0:NUM_ROWS*NUM_COLS-1] i_ctrl_psum_out_sel_GON,

    // GLB interface
    input [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1:0] i_ifmap_packet,
    input [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1:0] i_wght_packet,
    input [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1:0] i_psum_in_packet,
    output reg [PSUM_BUS_BITWIDTH-1:0] o_psum_out_data,

    input i_ifmap_valid,
    input i_wght_valid,
    input i_psum_in_valid,
    input i_psum_out_ready,

    output o_ifmap_ready,
    output o_wght_ready,
    output o_psum_in_ready,
    output reg o_psum_out_valid
);

    genvar row, col;

    wire inst_ready_pe [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [NUM_ROWS-1:0] inst_ready_rowwise;
    wire [NUM_ROWS * NUM_COLS-1:0] inst_ready_flatten;
    assign o_inst_ready = & inst_ready_flatten;

    generate
        for (row = 0; row < NUM_ROWS; row = row + 1) begin : gen_inst_ready_row
            for (col = 0; col < NUM_COLS; col = col + 1) begin : gen_inst_ready_col
                assign inst_ready_flatten[row * NUM_COLS + col] = inst_ready_pe[row][col];
            end
            assign inst_ready_rowwise[row] = &inst_ready_flatten[row * NUM_COLS +: NUM_COLS];
        end
    endgenerate

    // signals between ybus and xbus (GIN)
    wire [IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1 : 0] ifmap_packet_ybus2xbus [0:NUM_ROWS-1];
    wire [WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1 : 0] wght_packet_ybus2xbus [0:NUM_ROWS-1];
    wire [PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1 : 0] psum_in_packet_ybus2xbus [0:NUM_ROWS-1];

    wire ifmap_valid_ybus2xbus [0:NUM_ROWS-1];
    wire wght_valid_ybus2xbus [0:NUM_ROWS-1];
    wire psum_in_valid_ybus2xbus [0:NUM_ROWS-1];

    wire ifmap_ready_xbus2ybus [0:NUM_ROWS-1];
    wire wght_ready_xbus2ybus [0:NUM_ROWS-1];
    wire psum_in_ready_xbus2ybus [0:NUM_ROWS-1];


    wire [NUM_ROWS * (IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH) - 1 : 0] ifmap_packet_ybus2xbus_flatten;
    wire [NUM_ROWS * (WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH) - 1 : 0] wght_packet_ybus2xbus_flatten;
    wire [NUM_ROWS * (PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH) - 1 : 0] psum_in_packet_ybus2xbus_flatten;

    wire [NUM_ROWS-1:0] ifmap_valid_ybus2xbus_flatten;
    wire [NUM_ROWS-1:0] wght_valid_ybus2xbus_flatten;
    wire [NUM_ROWS-1:0] psum_in_valid_ybus2xbus_flatten;

    wire [NUM_ROWS-1:0] ifmap_ready_xbus2ybus_flatten;
    wire [NUM_ROWS-1:0] wght_ready_xbus2ybus_flatten;
    wire [NUM_ROWS-1:0] psum_in_ready_xbus2ybus_flatten;


    // signals between xbus and PE (GIN)
    wire [IFMAP_BUS_BITWIDTH-1:0] ifmap_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [WGHT_BUS_BITWIDTH-1:0] wght_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [PSUM_BUS_BITWIDTH-1:0] psum_in_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire ifmap_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire wght_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_in_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire ifmap_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire wght_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_in_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire [NUM_COLS * IFMAP_BUS_BITWIDTH - 1 : 0] ifmap_packet_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * WGHT_BUS_BITWIDTH - 1 : 0] wght_packet_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * PSUM_BUS_BITWIDTH - 1 : 0] psum_in_packet_xbus2PE_flatten [0:NUM_ROWS-1];

    wire [NUM_COLS-1:0] ifmap_valid_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] wght_valid_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] psum_in_valid_xbus2PE_flatten [0:NUM_ROWS-1];

    wire [NUM_COLS-1:0] ifmap_ready_PE2xbus_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] wght_ready_PE2xbus_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] psum_in_ready_PE2xbus_flatten [0:NUM_ROWS-1];

    // signals between interPE (LN)
    wire [PSUM_BUS_BITWIDTH-1:0] LN_psum_data [0:NUM_ROWS][0:NUM_COLS-1];
    wire LN_psum_valid [0:NUM_ROWS][0:NUM_COLS-1];
    wire LN_psum_ready [0:NUM_ROWS][0:NUM_COLS-1];

    generate
        for(col = 0; col < NUM_COLS; col = col + 1) begin : init_LN_col
            assign LN_psum_data[NUM_ROWS][col] = 0;
            assign LN_psum_valid[NUM_ROWS][col] = 0; // bottom line of PE set always get input psum from GIN.
            assign LN_psum_ready[0][col] = i_ctrl_psum_out_sel_GON[0 * NUM_COLS + col]; // top line of PE set
        end
    endgenerate

    generate
        for(row=0; row<NUM_ROWS; row=row+1) begin
            for(col=0; col<NUM_COLS; col=col+1) begin
                assign psum_in_ready_PE2xbus[row][col] = LN_psum_ready[row][col];
            end
        end
    endgenerate

    reg [PSUM_BUS_BITWIDTH-1:0] psum_in_data_mux_select [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg psum_in_valid_mux_select [0:NUM_ROWS-1][0:NUM_COLS-1];

    integer i, j;
    always @(*) begin
        for(i=0; i<NUM_ROWS; i=i+1) begin
            for(j=0; j<NUM_COLS; j=j+1) begin
                if(i_ctrl_psum_in_sel_LNorGIN[i * NUM_COLS + j]) begin
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
        for (row = 0; row < NUM_ROWS; row = row + 1) begin : gen_row_flatten
            assign ifmap_packet_ybus2xbus[row] = ifmap_packet_ybus2xbus_flatten[row * (IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH) +: (IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH)];
            assign wght_packet_ybus2xbus[row] = wght_packet_ybus2xbus_flatten[row * (WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH) +: (WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH)];
            assign psum_in_packet_ybus2xbus[row] = psum_in_packet_ybus2xbus_flatten[row * (PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH) +: (PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH)];

            assign ifmap_valid_ybus2xbus[row] = ifmap_valid_ybus2xbus_flatten[row];
            assign wght_valid_ybus2xbus[row] = wght_valid_ybus2xbus_flatten[row];
            assign psum_in_valid_ybus2xbus[row] = psum_in_valid_ybus2xbus_flatten[row];

            assign ifmap_ready_xbus2ybus_flatten[row] = ifmap_ready_xbus2ybus[row];
            assign wght_ready_xbus2ybus_flatten[row] = wght_ready_xbus2ybus[row];
            assign psum_in_ready_xbus2ybus_flatten[row] = psum_in_ready_xbus2ybus[row];

            for (col = 0; col < NUM_COLS; col = col + 1) begin : gen_row_flatten
                assign ifmap_packet_xbus2PE[row][col] = ifmap_packet_xbus2PE_flatten[row][col * IFMAP_BUS_BITWIDTH +: IFMAP_BUS_BITWIDTH];
                assign wght_packet_xbus2PE[row][col] = wght_packet_xbus2PE_flatten[row][col * WGHT_BUS_BITWIDTH +: WGHT_BUS_BITWIDTH];
                assign psum_in_packet_xbus2PE[row][col] = psum_in_packet_xbus2PE_flatten[row][col * PSUM_BUS_BITWIDTH +: PSUM_BUS_BITWIDTH];

                assign ifmap_valid_xbus2PE[row][col] = ifmap_valid_xbus2PE_flatten[row][col];
                assign wght_valid_xbus2PE[row][col] = wght_valid_xbus2PE_flatten[row][col];
                assign psum_in_valid_xbus2PE[row][col] = psum_in_valid_xbus2PE_flatten[row][col];

                assign ifmap_ready_PE2xbus_flatten[row][col] = ifmap_ready_PE2xbus[row][col];
                assign wght_ready_PE2xbus_flatten[row][col] = wght_ready_PE2xbus[row][col];
                assign psum_in_ready_PE2xbus_flatten[row][col] = psum_in_ready_PE2xbus[row][col];
            end
        end
    endgenerate

    GIN_BUS #(
        .ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH),
        .PACKET_OUT_BITWIDTH(IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH),
        .SLV_NUM(NUM_ROWS)
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
        .PACKET_IN_BITWIDTH(WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH),
        .PACKET_OUT_BITWIDTH(WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH),
        .SLV_NUM(NUM_ROWS)
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
        .PACKET_IN_BITWIDTH(PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH),
        .PACKET_OUT_BITWIDTH(PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH),
        .SLV_NUM(NUM_ROWS)
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
        for(row = 0; row < NUM_ROWS; row = row + 1) begin: GIN_XBUS_gen        
            GIN_BUS #(
                .ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH),
                .PACKET_OUT_BITWIDTH(IFMAP_BUS_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_IFMAP_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (ifmap_packet_ybus2xbus[row]),
                .i_valid    (ifmap_valid_ybus2xbus[row]),
                .o_ready    (ifmap_ready_xbus2ybus[row]),

                // tx
                .o_packet   (ifmap_packet_xbus2PE_flatten[row]),
                .i_ready    (ifmap_ready_PE2xbus_flatten[row]),
                .o_valid    (ifmap_valid_xbus2PE_flatten[row]),

                // TOP CTRL interface
                .i_id       (i_ifmap_col_id),
                .i_id_valid (i_ifmap_col_id_valid[row])
            );

            GIN_BUS #(
                .ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH),
                .PACKET_OUT_BITWIDTH(WGHT_BUS_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_WGHT_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (wght_packet_ybus2xbus[row]),
                .i_valid    (wght_valid_ybus2xbus[row]),
                .o_ready    (wght_ready_xbus2ybus[row]),

                // tx
                .o_packet   (wght_packet_xbus2PE_flatten[row]),
                .i_ready    (wght_ready_PE2xbus_flatten[row]),
                .o_valid    (wght_valid_xbus2PE_flatten[row]),

                // TOP CTRL interface
                .i_id       (i_wght_col_id),
                .i_id_valid (i_wght_col_id_valid[row])
            );

            GIN_BUS #(
                .ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH),
                .PACKET_OUT_BITWIDTH(PSUM_BUS_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_PSUM_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (psum_in_packet_ybus2xbus[row]),
                .i_valid    (psum_in_valid_ybus2xbus[row]),
                .o_ready    (psum_in_ready_xbus2ybus[row]),

                // tx
                .o_packet   (psum_in_packet_xbus2PE_flatten[row]),
                .i_ready    (psum_in_ready_PE2xbus_flatten[row]),
                .o_valid    (psum_in_valid_xbus2PE_flatten[row]),

                // TOP CTRL interface
                .i_id       (i_psum_col_id),
                .i_id_valid (i_psum_col_id_valid[row])
            );
        end
    endgenerate

    reg [PSUM_BUS_BITWIDTH-1:0] psum_out_data_buffer [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg                         psum_out_valid_buffer [0:NUM_ROWS-1][0:NUM_COLS-1];

    generate
        for(row = 0; row < NUM_ROWS; row = row + 1) begin: PE_gen_vertical
            for(col = 0; col < NUM_COLS; col = col + 1) begin: PE_gen_horizontal
                PE_top #(
                    .DATA_BITWIDTH       (DATA_BITWIDTH),
                    .IFMAP_BUS_BITWIDTH  (IFMAP_BUS_BITWIDTH),
                    .WGHT_BUS_BITWIDTH   (WGHT_BUS_BITWIDTH),
                    .PSUM_BUS_BITWIDTH   (PSUM_BUS_BITWIDTH),
                    .IFMAP_ADDR_BITWIDTH (4),
                    .WGHT_ADDR_BITWIDTH  (8),
                    .PSUM_ADDR_BITWIDTH  (4)
                ) u_PE_top (
                    .i_clk                 (i_clk),
                    .i_rst                 (i_rst),

                    // TOP CTRL
                    .i_inst_data           (i_inst_data),
                    .i_layer_p             (i_layer_p),
                    .i_layer_q             (i_layer_q),
                    .i_layer_s             (i_layer_s),
                    .i_inst_valid          (i_inst_valid),
                    .o_inst_ready          (inst_ready_pe[row][col]),

                    // fifo interface I/O
                    .i_ifmap_fifo_data     (ifmap_packet_xbus2PE[row][col]),
                    .i_ifmap_fifo_valid    (ifmap_valid_xbus2PE[row][col]),
                    .o_ifmap_fifo_ready    (ifmap_ready_PE2xbus[row][col]),

                    .i_wght_fifo_data      (wght_packet_xbus2PE[row][col]),
                    .i_wght_fifo_valid     (wght_valid_xbus2PE[row][col]),
                    .o_wght_fifo_ready     (wght_ready_PE2xbus[row][col]),

                    .i_psum_in_fifo_data   (psum_in_data_mux_select[row][col]),
                    .i_psum_in_fifo_valid  (psum_in_valid_mux_select[row][col]),
                    .o_psum_in_fifo_ready  (LN_psum_ready[row+1][col]),

                    .o_psum_out_fifo_data  (LN_psum_data[row][col]),
                    .o_psum_out_fifo_valid (LN_psum_valid[row][col]),
                    .i_psum_out_fifo_ready (LN_psum_ready[row][col])
                );

                always @(posedge i_clk) begin
                    if(i_rst) begin
                        psum_out_data_buffer[row][col] <= 0;
                        psum_out_valid_buffer[row][col] <= 0;
                    end
                    else begin
                        if(LN_psum_valid[row][col]) begin
                            psum_out_data_buffer[row][col] <= LN_psum_data[row][col];
                            psum_out_valid_buffer[row][col] <= LN_psum_valid[row][col];
                        end
                        else if(LN_psum_ready[row][col])begin
                            psum_out_data_buffer[row][col] <= {PSUM_BUS_BITWIDTH{1'b0}};
                            psum_out_valid_buffer[row][col] <= 1'b0;
                        end
                    end
                end
            end
        end
    endgenerate

    always @(*) begin
        o_psum_out_data = {PSUM_BUS_BITWIDTH{1'b0}};
        o_psum_out_valid = 1'b0;
        for (i = 0; i < NUM_ROWS; i = i + 1) begin
            for (j = 0; j < NUM_COLS; j = j + 1) begin
                if (i_ctrl_psum_out_sel_GON[i * NUM_COLS + j]) begin
                    o_psum_out_data = LN_psum_data[i][j];
                    o_psum_out_valid = LN_psum_valid[i][j];
                end
            end
        end
    end

endmodule