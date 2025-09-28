`timescale 1ns / 1ps

module tb_psum_selection_decoder;

    // Parameters
    parameter NUM_ROWS = 3;
    parameter NUM_COLS = 3;
    parameter PSUM_ROW_ID_BITWIDTH = 4;
    parameter PSUM_COL_ID_BITWIDTH = 4;

    // Inputs
    reg [3:0] i_layer_RS;
    reg [0:NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1] i_psum_row_id;
    reg [0:NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1] i_psum_col_id;

    // Outputs
    wire [0:NUM_ROWS*NUM_COLS-1] o_ctrl_psum_in_sel_LNorGIN;
    wire [0:NUM_ROWS*NUM_COLS-1] o_ctrl_psum_out_sel_GON;

    // Instantiate the Unit Under Test (UUT)
    psum_selection_decoder #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) uut (
        .i_layer_RS(i_layer_RS),
        .i_psum_row_id(i_psum_row_id),
        .i_psum_col_id(i_psum_col_id),
        .o_ctrl_psum_in_sel_LNorGIN(o_ctrl_psum_in_sel_LNorGIN),
        .o_ctrl_psum_out_sel_GON(o_ctrl_psum_out_sel_GON)
    );

    initial begin
        // Test vector 1
        i_layer_RS = 4'd3;
        i_psum_row_id = {4'd1, 4'd2, 4'd3}; // row-wise: [3][1][3]
        i_psum_col_id = {36{1'b0}}; // Not used in logic
        #10;

        // Test vector 2
        i_layer_RS = 4'd1;
        i_psum_row_id = {4'd1, 4'd1, 4'd1}; // All match layer_RS
        #10;

        // Test vector 3
        i_layer_RS = 4'd0;
        i_psum_row_id = {4'd0, 4'd1, 4'd2}; // Only first matches
        #10;

        $finish;
    end

endmodule