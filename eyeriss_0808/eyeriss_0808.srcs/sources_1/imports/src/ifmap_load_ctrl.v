`timescale 1ns / 1ps
module ifmap_load_ctrl(
    input i_clk,
    input i_rst,

    input i_load_start, // Start loading an entire pass

    //// Layer & Tiling/Mapping Parameters
    input [3:0] i_pass_num,
    input [7:0] i_layer_HW,
    input [3:0] i_layer_RS,
    input [6:0] i_layer_EF,
    input [9:0] i_layer_C,
    input [8:0] i_layer_M,
    input [1:0] i_layer_U,
    input [1:0] i_layer_PAD,
    input [3:0] i_layer_m,
    input [2:0] i_layer_n,
    input [4:0] i_layer_e,
    input [3:0] i_layer_p,
    input [2:0] i_layer_q,
    input [1:0] i_layer_r,
    input [1:0] i_layer_t,

    //// Final Outputs to GLB
    output          o_ifmap_glb_re,
    output [15:0]   o_ifmap_glb_ra,
    output [8:0]    o_ifmap_tag,
    output o_load_done
);

    localparam IDLE         = 3'd0;
    localparam LOAD_SEQ     = 3'd1;
    localparam UPDATE_BASE  = 3'd2;
    localparam UPDATE_BATCH = 3'd3;
    localparam DONE         = 3'd4;

    reg  [2:0] state, n_state;
    
    wire [8:0]    ifmap_tag;
    reg [8:0]     ifmap_tag_d;
    reg [8:0]     ifmap_tag_d2;
    
    // counters
    reg [2:0] batch_cnt;
    reg [6:0] iter_cnt;
    reg [2:0] cnt_C;
    reg [7:0] cnt_H;
    reg [2:0] cnt_W;

    wire [7:0] w_offset = iter_cnt * i_layer_U;
    wire       iter_done;

    wire [3:0] row_tag;
    wire [4:0] col_tag;

    // signals needed to determine if a given logical address is in a zero padded region
    wire [7:0] ifmap_end_idx = (i_layer_EF - 1) * i_layer_U + i_layer_RS - 1;
    wire [7:0] upper_bound =  i_layer_HW + i_layer_PAD;
    wire is_zero =  (cnt_H < i_layer_PAD) || // Top padding
                    (cnt_W + w_offset < i_layer_PAD) || // Left padding
                    (cnt_H >= upper_bound) || // Bottom padding
                    (cnt_W + w_offset >= upper_bound);   // Right padding

    // effective H, W to calculate the actual GLB address
    wire [7:0] eff_H = cnt_H - i_layer_PAD;
    wire [7:0] eff_W = cnt_W + w_offset - i_layer_PAD;



    // state register
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
        end
        else begin
            state <= n_state;
            if(state == UPDATE_BASE) iter_cnt <= iter_cnt + 1;
            else if(state == DONE) iter_cnt <= 0;
        end
    end

    // counter logic
    always @(posedge i_clk)
    begin
        if (i_rst) begin
            batch_cnt <= 0;
            iter_cnt <= 0;
            cnt_C <= 0;
            cnt_H <= 0;
            cnt_W <= 0;
        end
        else if(state == LOAD_SEQ) begin
            if (cnt_W == i_layer_RS - 1) begin
                cnt_W <= 0;
                if (cnt_C == i_layer_q - 1) begin
                    cnt_C <= 0;
                    if (cnt_H == ifmap_end_idx) begin
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
        else if(state == UPDATE_BASE)
            iter_cnt <= (iter_cnt == i_layer_EF - 1) ? 0 : iter_cnt + 1;
        else if(state == UPDATE_BATCH) 
            batch_cnt <= (batch_cnt == i_layer_n - 1) ? 0 : batch_cnt + 1;
        else begin
            cnt_C <= 0;
            cnt_H <= 0;
            cnt_W <= 0;
        end
    end

    // next state logic
    always @(*) begin
        case(state)
            IDLE:           n_state = (i_load_start) ? LOAD_SEQ : IDLE;
            LOAD_SEQ:       n_state = (iter_done) ? UPDATE_BASE : LOAD_SEQ;
            UPDATE_BASE:    n_state = (iter_cnt == i_layer_EF - 1) ? UPDATE_BATCH : IDLE;
            UPDATE_BATCH:   n_state = (batch_cnt == i_layer_n - 1) ? DONE : IDLE;
            DONE:           n_state = IDLE;
        endcase
    end

    assign row_tag = 4'd1;
    assign col_tag = cnt_H + 1;

    assign ifmap_tag = {row_tag, col_tag};
    always @(posedge i_clk) begin
        if(i_rst) begin
            ifmap_tag_d <= 0;
            ifmap_tag_d2 <= 0;
        end
        else begin
            ifmap_tag_d <= ifmap_tag;
            ifmap_tag_d2 <= ifmap_tag_d;
        end
    end

    assign iter_done = (cnt_W == i_layer_RS - 1) && (cnt_C == i_layer_q - 1) && (cnt_H == ifmap_end_idx);
    
    // read GLB only if the address is not in zero padded region
    assign o_ifmap_glb_re = (state == LOAD_SEQ) && ~is_zero;
    assign o_ifmap_glb_ra = (cnt_C * i_layer_HW * i_layer_HW) + (eff_H * i_layer_HW) + eff_W;
    assign o_ifmap_tag = ifmap_tag_d2;
    assign o_load_done = (state == DONE);

endmodule
