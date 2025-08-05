`timescale 1ns / 1ps
module wght_load_ctrl(
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
    input       i_layer_r,
    input       i_layer_t,

    //// Final Outputs to GLB
    output          o_wght_glb_re,
    output [15:0]   o_wght_glb_ra,
    output [7:0]    o_wght_tag,
    output          o_load_done
);

    // FSM 정의
    localparam IDLE     = 2'b00;
    localparam LOAD_SEQ = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] state, n_state;

    wire [7:0] wght_tag;
    reg [7:0] wght_tag_d;
    reg [7:0] wght_tag_d2;

    // 내부 카운터
    reg [3:0] cnt_P;
    reg [2:0] cnt_S;
    reg [2:0] cnt_Q;
    reg [7:0] cnt_R;

    assign o_wght_glb_re = (state == LOAD_SEQ);
    assign o_wght_glb_ra = (cnt_P * i_layer_RS * i_layer_RS * i_layer_q) + (cnt_R * i_layer_RS) + (cnt_Q * i_layer_RS * i_layer_RS) + cnt_S;
    
    assign wght_tag    = {cnt_R[3:0] + 1, 4'd1}; // col_tag = 1
    always @(posedge i_clk) begin
        if(i_rst) begin
            wght_tag_d <= 0;
            wght_tag_d2 <= 0;
        end
        else begin
            wght_tag_d <= wght_tag;
            wght_tag_d2 <= wght_tag_d;
        end
    end

    assign o_load_done = (state == DONE);
    assign o_wght_tag = wght_tag_d2;
    
    wire pass_done = (cnt_P == i_layer_p - 1) && (cnt_S == i_layer_RS - 1) &&
                (cnt_Q == i_layer_q - 1) && (cnt_R == i_layer_RS - 1);

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

    always @(posedge i_clk) begin
        if (i_rst) begin
            cnt_P <= 0;
            cnt_S <= 0;
            cnt_Q <= 0;
            cnt_R <= 0;
        end else if (state == LOAD_SEQ) begin
            if (cnt_P == i_layer_p - 1) begin
                cnt_P <= 0;
                if (cnt_S == i_layer_RS - 1) begin
                    cnt_S <= 0;
                    if (cnt_Q == i_layer_q - 1) begin
                        cnt_Q <= 0;
                        if (cnt_R == i_layer_RS - 1) cnt_R <= 0;
                        else cnt_R <= cnt_R + 1;
                    end else cnt_Q <= cnt_Q + 1;
                end else cnt_S <= cnt_S + 1;
            end else cnt_P <= cnt_P + 1;
        end
    end

endmodule