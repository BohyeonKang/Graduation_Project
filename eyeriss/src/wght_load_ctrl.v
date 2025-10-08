`timescale 1ns / 1ps
module wght_load_ctrl(
    input i_clk,
    input i_rst,

    input i_load_start,

    //// Layer & Tiling/Mapping Parameters
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [3:0] i_layer_s,

    //// Final Outputs to GLB
    output          o_wght_glb_en,
    output [15:0]   o_wght_glb_ra,
    output [7:0]    o_wght_tag,
    output          o_wght_valid
);

    localparam IDLE     = 2'b00;
    localparam LOAD_SEQ = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] state, n_state;

    reg [3:0] cnt_p;
    reg [2:0] cnt_s;
    reg [2:0] cnt_q;
    reg [3:0] cnt_row;

    wire [3:0] row_tag, col_tag;
    wire [7:0] wght_tag;
    reg [7:0] wght_tag_d1, wght_tag_d2;
    reg       wght_valid_d1, wght_valid_d2;

    wire pass_done;

    always @(posedge i_clk) begin
        if (i_rst) begin
            cnt_p <= 0;
            cnt_s <= 0;
            cnt_q <= 0;
            cnt_row <= 0;
        end else if (state == LOAD_SEQ) begin
            if (cnt_p == i_layer_p - 1) begin
                cnt_p <= 0;
                if (cnt_s == i_layer_s - 1) begin
                    cnt_s <= 0;
                    if (cnt_q == i_layer_q - 1) begin
                        cnt_q <= 0;
                        if (cnt_row == i_layer_s - 1) begin
                            cnt_row <= 0;
                        end
                        else cnt_row <= cnt_row + 1;
                    end
                    else cnt_q <= cnt_q + 1;
                end 
                else cnt_s <= cnt_s + 1;
            end 
            else cnt_p <= cnt_p + 1;
        end
        else begin
            cnt_p <= 0;
            cnt_s <= 0;
            cnt_q <= 0;
            cnt_row <= 0;
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            wght_tag_d1 <= 0;
            wght_tag_d2 <= 0;
            wght_valid_d1 <= 0;
            wght_valid_d2 <= 0;
        end
        else begin
            wght_tag_d1 <= wght_tag;
            wght_tag_d2 <= wght_tag_d1;
            wght_valid_d1 <= (state == LOAD_SEQ);
            wght_valid_d2 <= wght_valid_d1;
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
            LOAD_SEQ: n_state = (pass_done) ? DONE : LOAD_SEQ;
            DONE:     n_state = IDLE;
            default:  n_state = IDLE;
        endcase
    end

    assign pass_done = (cnt_p == i_layer_p - 1) && (cnt_s == i_layer_s - 1) && (cnt_q == i_layer_q - 1) && (cnt_row == i_layer_s - 1);

    assign row_tag = cnt_row + 1;
    assign col_tag = 4'd1;
    assign wght_tag = {row_tag, col_tag};

    assign o_wght_glb_en = (state == LOAD_SEQ);
    assign o_wght_glb_ra = (cnt_p * i_layer_s * i_layer_s * i_layer_q) + (cnt_row * i_layer_s) + (cnt_q * i_layer_s * i_layer_s) + cnt_s;
    assign o_wght_valid = wght_valid_d2;
    assign o_wght_tag = wght_tag_d2;

endmodule