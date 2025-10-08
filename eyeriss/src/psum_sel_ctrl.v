`timescale 1ns / 1ps
// generate psum_in_sel, psum_out_sel control signal based on row & col id
module psum_sel_ctrl #(
    parameter NUM_ROWS = 3,
    parameter NUM_COLS = 3,
    parameter IFMAP_ROW_ID_BITWIDTH = 4,
    parameter WGHT_ROW_ID_BITWIDTH = 4,
    parameter PSUM_ROW_ID_BITWIDTH = 4,
    parameter IFMAP_COL_ID_BITWIDTH = 5,
    parameter WGHT_COL_ID_BITWIDTH = 4,
    parameter PSUM_COL_ID_BITWIDTH = 4
)(
    input  [3:0] i_layer_s,
    input  [NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1:0] i_psum_row_id,
    input  [NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1:0] i_psum_col_id,
    output [NUM_ROWS*NUM_COLS-1:0] o_psum_in_sel,
    output [NUM_ROWS*NUM_COLS-1:0] o_psum_out_sel
);

    reg  [PSUM_ROW_ID_BITWIDTH-1:0] psum_row_id     [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg  [PSUM_COL_ID_BITWIDTH-1:0] psum_col_id     [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg                             psum_in_sel     [0:NUM_ROWS-1][0:NUM_COLS-1];
    reg                             psum_out_sel    [0:NUM_ROWS-1][0:NUM_COLS-1];

    genvar row, col;
    generate
        for(row=0; row<NUM_ROWS; row=row+1) begin
            for(col=0; col<NUM_COLS; col=col+1) begin
                always @(*) begin
                    psum_row_id[row][col] = i_psum_row_id[row * PSUM_ROW_ID_BITWIDTH +: PSUM_ROW_ID_BITWIDTH];
                    psum_col_id[row][col] = i_psum_col_id[row * NUM_COLS * PSUM_COL_ID_BITWIDTH + col * PSUM_COL_ID_BITWIDTH +: PSUM_COL_ID_BITWIDTH];
                    psum_in_sel[row][col] = (psum_row_id[row][col] == i_layer_s);
                    psum_out_sel[row][col] = (psum_row_id[row][col] == 1'd1);
                end
                assign o_psum_in_sel[row * NUM_COLS + col] = psum_in_sel[row][col];
                assign o_psum_out_sel[row * NUM_COLS + col] = psum_out_sel[row][col];
            end 
        end
    endgenerate
endmodule