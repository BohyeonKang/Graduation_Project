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
    input       i_layer_r,
    input       i_layer_t,

    //// Final Outputs to GLB
    output          o_psum_glb_re,
    output [15:0]   o_psum_glb_ra,
    output [7:0]    o_psum_tag,
    output          o_load_done
);

    localparam IDLE     = 2'b00;
    localparam LOAD_SEQ = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] state, n_state;

    // 내부 카운터
    reg [3:0] cnt_P;
    reg [2:0] cnt_E;
    reg [2:0] cnt_Q;
    reg [7:0] cnt_F;

    reg [3:0] pe_set_sel;

    assign o_psum_glb_re = (state == LOAD_SEQ);
    assign o_psum_glb_ra = (cnt_P * i_layer_EF * i_layer_EF) + (cnt_E * i_layer_EF) + (cnt_Q * i_layer_EF * i_layer_EF) + cnt_F;
    
    assign o_psum_tag    = {i_layer_RS, 4'd0}; // PE set의 가장 밑에 공급되어야 하므로 row tag는 i_layer_RS로 고정
    assign o_load_done   = (state == DONE);
    
    wire pass_done = (cnt_P == i_layer_p - 1) && (cnt_E == i_layer_EF - 1) && (cnt_F == i_layer_EF - 1);

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
            cnt_E <= 0;
            cnt_Q <= 0;
            cnt_F <= 0;
        end else if (state == LOAD_SEQ) begin
            if (cnt_P == i_layer_p - 1) begin
                cnt_P <= 0;
                if (cnt_E == i_layer_EF - 1) begin
                    cnt_E <= 0;
                    if (cnt_F == i_layer_EF - 1) cnt_F <= 0;
                    else cnt_F <= cnt_F + 1;
                end else cnt_E <= cnt_E + 1;
            end else cnt_P <= cnt_P + 1;
        end
    end

endmodule