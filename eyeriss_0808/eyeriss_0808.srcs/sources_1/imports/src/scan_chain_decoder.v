module scan_chain_decoder(

    input i_valid,
    input [31:0] i_scan_chain_data,

    //// Layer & Tiling/Mapping Parameters from scan_chain_decoder.v
    output [3:0] o_pass_num,
    output [9:0] o_layer_C,
    output [7:0] o_layer_HW,
    output [1:0] o_layer_U,
    output [3:0] o_layer_RS,
    output [6:0] o_layer_EF,
    output [1:0] o_layer_PAD,
    output [3:0] o_layer_m,
    output [4:0] o_layer_e,
    output [3:0] o_layer_p,
    output [1:0] o_layer_q,
    output       o_layer_r,
    output       o_layer_t
    // output [IFMAP_ROW_ID_BITWIDTH * COL_LEN-1:0] o_ifmap_row_id,
    // output [WGHT_ROW_ID_BITWIDTH * COL_LEN-1:0] o_wght_row_id,
    // output [PSUM_ROW_ID_BITWIDTH * COL_LEN-1:0] o_psum_row_id,
    // output [IFMAP_ROW_ID_BITWIDTH * ROW_LEN-1:0] o_ifmap_col_id
);


endmodule