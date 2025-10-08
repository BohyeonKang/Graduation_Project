`timescale 1ns / 1ps
module PE_array #(
    parameter NUM_ROWS = 12,
    parameter NUM_COLS = 14,
    parameter DATA_BITWIDTH = 32,
    parameter IFMAP_ROW_ID_BITWIDTH = 4,
    parameter IFMAP_COL_ID_BITWIDTH = 5,
    parameter WGHT_ROW_ID_BITWIDTH = 4,
    parameter WGHT_COL_ID_BITWIDTH = 4,
    parameter PSUM_ROW_ID_BITWIDTH = 4,
    parameter PSUM_COL_ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,
    
    // TOP CTRL interface
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [3:0] i_layer_s,
    input [2:0] i_inst_data,
    input i_inst_valid,
    output o_inst_ready,

    input [IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1:0] i_ifmap_row_id,
    input [WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1:0] i_wght_row_id,
    input [PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1:0] i_psum_row_id,

    input i_ifmap_row_id_valid,
    input i_wght_row_id_valid,
    input i_psum_row_id_valid,

    // gcol ID는 한번에 한 ROW씩 들어오는걸로 가정
    input [IFMAP_COL_ID_BITWIDTH * NUM_COLS-1:0] i_ifmap_col_id,
    input [WGHT_COL_ID_BITWIDTH * NUM_COLS-1:0] i_wght_col_id,
    input [PSUM_COL_ID_BITWIDTH * NUM_COLS-1:0] i_psum_col_id,

    // one-hot encoded valid signal
    input [NUM_ROWS-1:0] i_ifmap_col_id_valid,
    input [NUM_ROWS-1:0] i_wght_col_id_valid,
    input [NUM_ROWS-1:0] i_psum_col_id_valid,

    input [NUM_ROWS*NUM_COLS-1:0] i_psum_in_sel,
    input [NUM_ROWS*NUM_COLS-1:0] i_psum_out_sel,
    
    // GLB interface
    input [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] i_ifmap_packet,
    input [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] i_wght_packet,
    input [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] i_psum_in_packet,
    output reg [DATA_BITWIDTH-1:0] o_psum_out_data,

    input i_ifmap_valid,
    input i_wght_valid,
    input i_psum_in_valid,
    input i_psum_out_ready,

    output o_ifmap_ready,
    output o_wght_ready,
    output o_psum_in_ready,
    output reg o_psum_out_valid
);
    
    // (r,c) 위치의 inst_ready가 1이 될 조건
    // 1. 실제로 연산이 끝나서 해당 PE에서 opcode_ready 신호를 set 하고 있는 경우
    // 2. 해당 PE의 모든 col id(ifmap, wght, col)가 명시적으로 0으로 설정된 경우 >> inactive PE
    wire inst_ready [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [NUM_ROWS * NUM_COLS - 1 :0] inst_ready_flatten;

    wire opcode_ready [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire is_inactive [0:NUM_ROWS-1][0:NUM_COLS-1];

    // control signal
    reg [DATA_BITWIDTH-1:0] psum_in_data  [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg                     psum_in_valid [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_in_sel [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_out_sel [0:NUM_ROWS-1][0:NUM_COLS-1];

    // current row id, col id information from GIN
    wire [IFMAP_ROW_ID_BITWIDTH-1:0] cur_ifmap_row_id [0:NUM_ROWS-1];
    wire [WGHT_ROW_ID_BITWIDTH-1:0] cur_wght_row_id [0:NUM_ROWS-1];
    wire [PSUM_ROW_ID_BITWIDTH-1:0] cur_psum_row_id [0:NUM_ROWS-1];

    wire [IFMAP_COL_ID_BITWIDTH-1:0] cur_ifmap_col_id [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [WGHT_COL_ID_BITWIDTH-1:0] cur_wght_col_id [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [PSUM_COL_ID_BITWIDTH-1:0] cur_psum_col_id [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire [NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1:0] cur_ifmap_row_id_flatten;
    wire [NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1:0] cur_wght_row_id_flatten;
    wire [NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1:0] cur_psum_row_id_flatten;

    wire [NUM_COLS * IFMAP_COL_ID_BITWIDTH-1:0] cur_ifmap_col_id_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * WGHT_COL_ID_BITWIDTH-1:0] cur_wght_col_id_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * PSUM_COL_ID_BITWIDTH-1:0] cur_psum_col_id_flatten [0:NUM_ROWS-1];

    // signals between ybus and xbus (GIN)
    wire [IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH - 1 : 0] ifmap_packet_ybus2xbus [0:NUM_ROWS-1];
    wire [WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH - 1 : 0] wght_packet_ybus2xbus [0:NUM_ROWS-1];
    wire [PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH - 1 : 0] psum_in_packet_ybus2xbus [0:NUM_ROWS-1];

    wire ifmap_valid_ybus2xbus [0:NUM_ROWS-1];
    wire wght_valid_ybus2xbus [0:NUM_ROWS-1];
    wire psum_in_valid_ybus2xbus [0:NUM_ROWS-1];

    wire ifmap_ready_xbus2ybus [0:NUM_ROWS-1];
    wire wght_ready_xbus2ybus [0:NUM_ROWS-1];
    wire psum_in_ready_xbus2ybus [0:NUM_ROWS-1];

    wire [NUM_ROWS * (IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH) - 1 : 0] ifmap_packet_ybus2xbus_flatten;
    wire [NUM_ROWS * (WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH) - 1 : 0] wght_packet_ybus2xbus_flatten;
    wire [NUM_ROWS * (PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH) - 1 : 0] psum_in_packet_ybus2xbus_flatten;

    wire [NUM_ROWS-1:0] ifmap_valid_ybus2xbus_flatten;
    wire [NUM_ROWS-1:0] wght_valid_ybus2xbus_flatten;
    wire [NUM_ROWS-1:0] psum_in_valid_ybus2xbus_flatten;

    wire [NUM_ROWS-1:0] ifmap_ready_xbus2ybus_flatten;
    wire [NUM_ROWS-1:0] wght_ready_xbus2ybus_flatten;
    wire [NUM_ROWS-1:0] psum_in_ready_xbus2ybus_flatten;

    // signals between xbus and PE (GIN)
    wire [DATA_BITWIDTH-1:0] ifmap_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [DATA_BITWIDTH-1:0] wght_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire [DATA_BITWIDTH-1:0] psum_in_packet_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire ifmap_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire wght_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_in_valid_xbus2PE [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire ifmap_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire wght_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];
    wire psum_in_ready_PE2xbus [0:NUM_ROWS-1][0:NUM_COLS-1];

    wire [NUM_COLS * DATA_BITWIDTH - 1 : 0] ifmap_packet_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * DATA_BITWIDTH - 1 : 0] wght_packet_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS * DATA_BITWIDTH - 1 : 0] psum_in_packet_xbus2PE_flatten [0:NUM_ROWS-1];

    wire [NUM_COLS-1:0] ifmap_valid_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] wght_valid_xbus2PE_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] psum_in_valid_xbus2PE_flatten [0:NUM_ROWS-1];

    wire [NUM_COLS-1:0] ifmap_ready_PE2xbus_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] wght_ready_PE2xbus_flatten [0:NUM_ROWS-1];
    wire [NUM_COLS-1:0] psum_in_ready_PE2xbus_flatten [0:NUM_ROWS-1];

    // Local Network signal (interPE communication)
    wire [DATA_BITWIDTH-1:0] LN_psum_data [0:NUM_ROWS][0:NUM_COLS-1];
    wire LN_psum_valid [0:NUM_ROWS][0:NUM_COLS-1];
    wire LN_psum_ready [0:NUM_ROWS][0:NUM_COLS-1];

    // Psum out local buffer
    reg [DATA_BITWIDTH-1:0]     psum_out_data_buffer [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg                         psum_out_valid_buffer [0:NUM_ROWS-1][0:NUM_COLS-1];

    genvar grow, gcol;
    generate
        for (grow = 0; grow < NUM_ROWS; grow = grow + 1) begin : gen_row_flatten
            assign cur_ifmap_row_id[grow] = cur_ifmap_row_id_flatten[grow * IFMAP_ROW_ID_BITWIDTH +: IFMAP_ROW_ID_BITWIDTH];
            assign cur_wght_row_id[grow] = cur_wght_row_id_flatten[grow * WGHT_ROW_ID_BITWIDTH +: WGHT_ROW_ID_BITWIDTH];
            assign cur_psum_row_id[grow] = cur_psum_row_id_flatten[grow * PSUM_ROW_ID_BITWIDTH +: PSUM_ROW_ID_BITWIDTH];

            assign ifmap_packet_ybus2xbus[grow] = ifmap_packet_ybus2xbus_flatten[grow * (IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH) +: (IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH)];
            assign wght_packet_ybus2xbus[grow] = wght_packet_ybus2xbus_flatten[grow * (WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH) +: (WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH)];
            assign psum_in_packet_ybus2xbus[grow] = psum_in_packet_ybus2xbus_flatten[grow * (PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH) +: (PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH)];

            assign ifmap_valid_ybus2xbus[grow] = ifmap_valid_ybus2xbus_flatten[grow];
            assign wght_valid_ybus2xbus[grow] = wght_valid_ybus2xbus_flatten[grow];
            assign psum_in_valid_ybus2xbus[grow] = psum_in_valid_ybus2xbus_flatten[grow];

            assign ifmap_ready_xbus2ybus_flatten[grow] = ifmap_ready_xbus2ybus[grow];
            assign wght_ready_xbus2ybus_flatten[grow] = wght_ready_xbus2ybus[grow];
            assign psum_in_ready_xbus2ybus_flatten[grow] = psum_in_ready_xbus2ybus[grow];

            for (gcol = 0; gcol < NUM_COLS; gcol = gcol + 1) begin : gen_row_flatten
                assign inst_ready_flatten[grow * NUM_COLS + gcol] = inst_ready[grow][gcol];
                assign is_inactive[grow][gcol] = (cur_ifmap_col_id[grow][gcol] == 0) && (cur_wght_col_id[grow][gcol] == 0) && (cur_psum_col_id[grow][gcol] == 0);
                assign inst_ready[grow][gcol] = opcode_ready[grow][gcol] || is_inactive[grow][gcol];
                assign psum_in_sel[grow][gcol] = i_psum_in_sel[grow * NUM_COLS + gcol];
                assign psum_out_sel[grow][gcol] = i_psum_out_sel[grow * NUM_COLS + gcol];

                assign cur_ifmap_col_id[grow][gcol] = cur_ifmap_col_id_flatten[grow][gcol * IFMAP_COL_ID_BITWIDTH +: IFMAP_COL_ID_BITWIDTH];
                assign cur_wght_col_id[grow][gcol] = cur_wght_col_id_flatten[grow][gcol * WGHT_COL_ID_BITWIDTH +: WGHT_COL_ID_BITWIDTH];
                assign cur_psum_col_id[grow][gcol] = cur_psum_col_id_flatten[grow][gcol * PSUM_COL_ID_BITWIDTH +: PSUM_COL_ID_BITWIDTH];

                assign ifmap_packet_xbus2PE[grow][gcol] = ifmap_packet_xbus2PE_flatten[grow][gcol * DATA_BITWIDTH +: DATA_BITWIDTH];
                assign wght_packet_xbus2PE[grow][gcol] = wght_packet_xbus2PE_flatten[grow][gcol * DATA_BITWIDTH +: DATA_BITWIDTH];
                assign psum_in_packet_xbus2PE[grow][gcol] = psum_in_packet_xbus2PE_flatten[grow][gcol * DATA_BITWIDTH +: DATA_BITWIDTH];

                assign ifmap_valid_xbus2PE[grow][gcol] = ifmap_valid_xbus2PE_flatten[grow][gcol];
                assign wght_valid_xbus2PE[grow][gcol] = wght_valid_xbus2PE_flatten[grow][gcol];
                assign psum_in_valid_xbus2PE[grow][gcol] = psum_in_valid_xbus2PE_flatten[grow][gcol];

                assign ifmap_ready_PE2xbus_flatten[grow][gcol] = ifmap_ready_PE2xbus[grow][gcol];
                assign wght_ready_PE2xbus_flatten[grow][gcol] = wght_ready_PE2xbus[grow][gcol];
                assign psum_in_ready_PE2xbus_flatten[grow][gcol] = psum_in_ready_PE2xbus[grow][gcol];

                // initialize Local Network
                assign psum_in_ready_PE2xbus[grow][gcol] = LN_psum_ready[grow][gcol];
                assign LN_psum_data[NUM_ROWS][gcol] = 0;
                assign LN_psum_valid[NUM_ROWS][gcol] = 0; // bottom line of PE set always get input psum from GIN.
                assign LN_psum_ready[0][gcol] = i_psum_out_sel[0 * NUM_COLS + gcol]; // top line of PE set

                always @(posedge i_clk) begin
                    if(i_rst) begin
                        psum_out_data_buffer[grow][gcol] <= 0;
                        psum_out_valid_buffer[grow][gcol] <= 0;
                    end
                    else begin
                        if(LN_psum_valid[grow][gcol]) begin
                            psum_out_data_buffer[grow][gcol] <= LN_psum_data[grow][gcol];
                            psum_out_valid_buffer[grow][gcol] <= 1'b1;
                        end
                        else if(LN_psum_ready[grow][gcol])begin
                            psum_out_data_buffer[grow][gcol] <= {DATA_BITWIDTH{1'b0}};
                            psum_out_valid_buffer[grow][gcol] <= 1'b0;
                        end
                    end
                end

                always @(*) begin
                    psum_in_data[grow][gcol] = (psum_in_sel[grow][gcol]) ? psum_in_packet_xbus2PE[grow][gcol] : LN_psum_data[grow+1][gcol];
                    psum_in_valid[grow][gcol] = (psum_in_sel[grow][gcol]) ? psum_in_valid_xbus2PE[grow][gcol] : LN_psum_valid[grow+1][gcol];
                end
            end
        end
    endgenerate

    GIN_BUS #(
        .ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH),
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
        .i_id_valid (i_ifmap_row_id_valid),
        .o_cur_id   (cur_ifmap_row_id_flatten)
    );

    GIN_BUS #(
        .ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH),
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
        .i_id_valid (i_wght_row_id_valid),
        .o_cur_id   (cur_wght_row_id_flatten)
    );

    GIN_BUS #(
        .ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PACKET_IN_BITWIDTH(PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH),
        .PACKET_OUT_BITWIDTH(PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH),
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
        .i_id_valid (i_psum_row_id_valid),
        .o_cur_id   (cur_psum_row_id_flatten)
    );

    generate
        for(grow = 0; grow < NUM_ROWS; grow = grow + 1) begin: GIN_XBUS_gen        
            GIN_BUS #(
                .ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(DATA_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_IFMAP_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (ifmap_packet_ybus2xbus[grow]),
                .i_valid    (ifmap_valid_ybus2xbus[grow]),
                .o_ready    (ifmap_ready_xbus2ybus[grow]),

                // tx
                .o_packet   (ifmap_packet_xbus2PE_flatten[grow]),
                .i_ready    (ifmap_ready_PE2xbus_flatten[grow]),
                .o_valid    (ifmap_valid_xbus2PE_flatten[grow]),

                // TOP CTRL interface
                .i_id       (i_ifmap_col_id),
                .i_id_valid (i_ifmap_col_id_valid[grow]),
                .o_cur_id   (cur_ifmap_col_id_flatten[grow])
            );

            GIN_BUS #(
                .ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(DATA_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_WGHT_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (wght_packet_ybus2xbus[grow]),
                .i_valid    (wght_valid_ybus2xbus[grow]),
                .o_ready    (wght_ready_xbus2ybus[grow]),

                // tx
                .o_packet   (wght_packet_xbus2PE_flatten[grow]),
                .i_ready    (wght_ready_PE2xbus_flatten[grow]),
                .o_valid    (wght_valid_xbus2PE_flatten[grow]),

                // TOP CTRL interface
                .i_id       (i_wght_col_id),
                .i_id_valid (i_wght_col_id_valid[grow]),
                .o_cur_id   (cur_wght_col_id_flatten[grow])
            );

            GIN_BUS #(
                .ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
                .PACKET_IN_BITWIDTH(PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH),
                .PACKET_OUT_BITWIDTH(DATA_BITWIDTH),
                .SLV_NUM(NUM_COLS)
            ) u_GIN_PSUM_XBUS (
                .i_clk      (i_clk),
                .i_rst      (i_rst),

                // rx
                .i_packet   (psum_in_packet_ybus2xbus[grow]),
                .i_valid    (psum_in_valid_ybus2xbus[grow]),
                .o_ready    (psum_in_ready_xbus2ybus[grow]),

                // tx
                .o_packet   (psum_in_packet_xbus2PE_flatten[grow]),
                .i_ready    (psum_in_ready_PE2xbus_flatten[grow]),
                .o_valid    (psum_in_valid_xbus2PE_flatten[grow]),

                // TOP CTRL interface
                .i_id       (i_psum_col_id),
                .i_id_valid (i_psum_col_id_valid[grow]),
                .o_cur_id   (cur_psum_col_id_flatten[grow])
            );
        end
    endgenerate

    generate
        for(grow = 0; grow < NUM_ROWS; grow = grow + 1) begin: PE_gen_vertical
            for(gcol = 0; gcol < NUM_COLS; gcol = gcol + 1) begin: PE_gen_horizontal
                PE_top #(
                    .DATA_BITWIDTH     (DATA_BITWIDTH),
                    .IFMAP_SPAD_AWIDTH (4),
                    .WGHT_SPAD_AWIDTH  (8),
                    .PSUM_SPAD_AWIDTH  (4)
                ) u_PE_top (
                    .i_clk                 (i_clk),
                    .i_rst                 (i_rst),

                    // TOP CTRL
                    .i_layer_p             (i_layer_p),
                    .i_layer_q             (i_layer_q),
                    .i_layer_s             (i_layer_s),
                    .i_opcode_valid        (i_inst_valid),
                    .i_opcode              (i_inst_data),
                    .o_opcode_ready        (opcode_ready[grow][gcol]),

                    // fifo interface I/O
                    .i_ifmap_fifo_data     (ifmap_packet_xbus2PE[grow][gcol]),
                    .i_ifmap_fifo_valid    (ifmap_valid_xbus2PE[grow][gcol]),
                    .o_ifmap_fifo_ready    (ifmap_ready_PE2xbus[grow][gcol]),

                    .i_wght_fifo_data      (wght_packet_xbus2PE[grow][gcol]),
                    .i_wght_fifo_valid     (wght_valid_xbus2PE[grow][gcol]),
                    .o_wght_fifo_ready     (wght_ready_PE2xbus[grow][gcol]),

                    .i_psum_in_fifo_data   (psum_in_data[grow][gcol]),
                    .i_psum_in_fifo_valid  (psum_in_valid[grow][gcol]),
                    .o_psum_in_fifo_ready  (LN_psum_ready[grow+1][gcol]),

                    .o_psum_out_fifo_data  (LN_psum_data[grow][gcol]),
                    .o_psum_out_fifo_valid (LN_psum_valid[grow][gcol]),
                    .i_psum_out_fifo_ready (LN_psum_ready[grow][gcol])
                );
            end
        end
    endgenerate


	/////////////////////////////////
	// RTL logic
	/////////////////////////////////

    integer row, col;

    // determine output psum to send to GON with one-hot control signal
    always @(*) begin
        o_psum_out_data = {DATA_BITWIDTH{1'b0}};
        o_psum_out_valid = 1'b0;
        for (row = 0; row < NUM_ROWS; row = row + 1) begin
            for (col = 0; col < NUM_COLS; col = col + 1) begin
                if (psum_out_sel[row][col]) begin
                    o_psum_out_data = LN_psum_data[row][col];
                    o_psum_out_valid = LN_psum_valid[row][col];
                end
            end
        end
    end

    assign o_inst_ready = & inst_ready_flatten;

endmodule