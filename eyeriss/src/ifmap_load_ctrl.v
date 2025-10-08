`timescale 1ns / 1ps
module ifmap_load_ctrl(
    input i_clk,
    input i_rst,

    input [5:0] i_iter_cnt,
    input i_load_start,

    input [7:0] i_layer_HW,
    input [2:0] i_layer_U,
    input [1:0] i_layer_PAD,

    input [4:0] i_layer_e,
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [2:0] i_layer_r,
    input [3:0] i_layer_s,
    input [2:0] i_layer_t,

    //// Final Outputs to GLB
    output          o_ifmap_glb_en,
    output [15:0]   o_ifmap_glb_ra,
    output          o_ifmap_valid,
    output [8:0]    o_ifmap_tag
);

    localparam IDLE         = 2'h0;
    localparam LOAD         = 2'h1;
    localparam DONE         = 2'h2;

    reg  [2:0] state, n_state;
    
    reg [2:0] cnt_C;
    reg [4:0] cnt_H;
    reg [2:0] cnt_W;
    wire load_done;
    
    wire [7:0] window_offset = i_layer_U * i_iter_cnt;
    wire [7:0] last_row_idx = (i_layer_e - 1) * i_layer_U + i_layer_s - 1;
    
    wire [3:0] row_tag;
    wire [4:0] col_tag;
    wire [8:0] ifmap_tag;
    reg [8:0] ifmap_tag_d1, ifmap_tag_d2;
    reg       ifmap_valid_d1, ifmap_valid_d2;

    // signals needed to determine if a given logical address is in a zero padded region
    wire [7:0] lower_bound = i_layer_PAD;
    wire [7:0] upper_bound = i_layer_HW + i_layer_PAD;

    wire is_top_padded_region;
    wire is_bottom_padded_region;
    wire is_left_padded_region;
    wire is_right_padded_region;
    wire is_padded_region;

    // effective H, W to calculate the actual GLB address
    wire [7:0] eff_H = cnt_H - i_layer_PAD;
    wire [7:0] eff_W = cnt_W + window_offset - i_layer_PAD;

    // ifmap tag delayed by 2 cycle to meet GLB read timing
    always @(posedge i_clk) begin
        if (i_rst) begin
            ifmap_tag_d1 <= 0;
            ifmap_tag_d2 <= 0;
            ifmap_valid_d1 <= 0;
            ifmap_valid_d2 <= 0;
        end
        else begin
            ifmap_tag_d1 <= ifmap_tag;
            ifmap_tag_d2 <= ifmap_tag_d1;
            ifmap_valid_d1 <= (state == LOAD) && !(is_padded_region);
            ifmap_valid_d2 <= ifmap_valid_d1;
        end
    end

    // counter logic
    always @(posedge i_clk)
    begin
        if (i_rst) begin
            cnt_C <= 0;
            cnt_H <= 0;
            cnt_W <= 0;
        end
        else if(state == LOAD) begin
            if (cnt_W == i_layer_s - 1) begin
                cnt_W <= 0;
                if (cnt_C == i_layer_q - 1) begin
                    cnt_C <= 0;
                    if (cnt_H == last_row_idx) begin
                        cnt_H <= 0;
                    end 
                    else begin
                        cnt_H <= cnt_H + 1;
                    end
                end
                else begin
                    cnt_C <= cnt_C + 1;
                end
            end 
            else begin
                cnt_W <= cnt_W + 1;
            end
        end
        else begin
            cnt_C <= 0;
            cnt_H <= 0;
            cnt_W <= 0;
        end
    end

    // state register
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
        end
        else begin
            state <= n_state;
        end
    end
    
    // next state logic
    always @(*) begin
        case(state)
            IDLE:           n_state = (i_load_start) ? LOAD : IDLE;
            LOAD:           n_state = (load_done) ? DONE : LOAD;
            DONE:           n_state = IDLE;
        endcase
    end

    assign load_done = (cnt_W == i_layer_s - 1) && (cnt_C == i_layer_q - 1) && (cnt_H == last_row_idx);
    
    assign row_tag = 4'd1;
    assign col_tag = cnt_H + 1;
    assign ifmap_tag = {row_tag, col_tag};

    assign is_top_padded_region = (cnt_H < lower_bound);
    assign is_bottom_padded_region = (cnt_H >= upper_bound);
    assign is_left_padded_region = (cnt_W + window_offset < lower_bound);
    assign is_right_padded_region = (cnt_W + window_offset >= upper_bound);
    assign is_padded_region = is_top_padded_region || is_bottom_padded_region || is_left_padded_region || is_right_padded_region;

    // read GLB only if the address is not in zero padded region
    assign o_ifmap_glb_en = (state == LOAD) && !(is_padded_region);
    assign o_ifmap_glb_ra = (cnt_C * i_layer_HW * i_layer_HW) + (eff_H * i_layer_HW) + eff_W;
    assign o_ifmap_valid = ifmap_valid_d2;
    assign o_ifmap_tag = ifmap_tag_d2;

endmodule