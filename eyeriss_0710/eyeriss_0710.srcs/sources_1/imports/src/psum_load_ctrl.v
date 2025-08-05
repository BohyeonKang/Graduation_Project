`timescale 1ns / 1ps
module psum_load_ctrl(
    input i_clk,
    input i_rst,

    input i_load_start, // Start loading an entire pass

    //// Layer & Tiling/Mapping Parameters
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
    input [2:0] i_layer_p,
    input [2:0] i_layer_q,
    input [1:0] i_layer_r,
    input [1:0] i_layer_t,

    //// Final Outputs to GLB
    output          o_psum_glb_re,
    output [15:0]   o_psum_glb_ra,
    output [7:0]    o_psum_tag,
    output          o_load_done
);

    localparam IDLE         = 3'd0;
    localparam LOAD_SEQ     = 3'd1;
    localparam UPDATE_BASE  = 3'd2;
    localparam UPDATE_BATCH = 3'd3;
    localparam DONE         = 3'd4;

    reg [2:0] state, n_state;

    wire [7:0]    psum_tag;
    reg [7:0]     psum_tag_d;
    reg [7:0]     psum_tag_d2;

    // counter
    reg [2:0] batch_cnt;
    reg [6:0] iter_cnt;
    reg [3:0] cnt_P;
    reg [2:0] cnt_E;

    reg [3:0] pe_set_sel;

    wire iter_done = (cnt_P == i_layer_p - 1) && (cnt_E == i_layer_EF - 1);
    wire pass_done = (cnt_P == i_layer_p - 1) && (cnt_E == i_layer_EF - 1) && (iter_cnt == i_layer_EF - 1) && (batch_cnt == i_layer_n - 1);

    wire [3:0] row_tag = i_layer_RS;
    wire [3:0] col_tag = {1'b0, (batch_cnt + 1)};
    assign psum_tag = {row_tag, col_tag};
    always @(posedge i_clk) begin
        if(i_rst) begin
            psum_tag_d <= 0;
            psum_tag_d2 <= 0;
        end
        else begin
            psum_tag_d <= psum_tag;
            psum_tag_d2 <= psum_tag_d;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst)
            state <= IDLE;
        else
            state <= n_state;
    end

    always @(*) begin
        case(state)
            IDLE:     n_state = (i_load_start) ? LOAD_SEQ : IDLE;
            LOAD_SEQ: n_state = (iter_done) ? UPDATE_BASE : LOAD_SEQ;
            UPDATE_BASE: n_state = (iter_cnt == i_layer_EF - 1) ? UPDATE_BATCH : IDLE;
            UPDATE_BATCH: n_state = (batch_cnt == i_layer_n - 1) ? DONE : IDLE;
            DONE:     n_state = IDLE;
            default:  n_state = IDLE;
        endcase
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            batch_cnt <= 0;
            iter_cnt <= 0;
            cnt_P <= 0;
            cnt_E <= 0;
        end
        else if (state == LOAD_SEQ) begin
            if (cnt_P == i_layer_p - 1) begin
                cnt_P <= 0;
                if (cnt_E == i_layer_EF - 1) begin
                    cnt_E <= 0;
                end
                else cnt_E <= cnt_E + 1;
            end 
            else cnt_P <= cnt_P + 1;
        end
        else if(state == UPDATE_BASE)
            iter_cnt <= (iter_cnt == i_layer_EF - 1) ? 0 : iter_cnt + 1;
        else if(state == UPDATE_BATCH) 
            batch_cnt <= (batch_cnt == i_layer_n - 1) ? 0 : batch_cnt + 1;
        else begin
            cnt_P <= 0;
            cnt_E <= 0;
        end
    end

    assign o_psum_glb_re = (state == LOAD_SEQ);
    assign o_psum_glb_ra = (cnt_P * i_layer_EF * i_layer_EF) + (cnt_E * i_layer_EF) + iter_cnt;
    assign o_load_done   = (state == DONE);
    assign o_psum_tag = psum_tag_d2;

endmodule