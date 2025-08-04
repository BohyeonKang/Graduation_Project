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

    // FSM 상태 정의
    localparam IDLE         = 2'd0;
    localparam LOAD_SEQ     = 2'd1;
    localparam UPDATE_BASE  = 2'd2;
    localparam DONE         = 2'd3;

    // 내부 신호 정의
    reg  [1:0] state, n_state;

    reg     sequencer_cmd_load;
    //베이스 좌표 및 시퀀스 카운터
    reg   [7:0] w_base;
    reg   [6:0] iter_cnt;

    // 하위 모듈 간 연결을 위한 wire
    wire [8:0] cur_C_wire;
    wire [7:0] cur_H_wire;
    wire [7:0] cur_W_wire;
    wire       seq_done;
    wire       is_zero_wire;

    // state register & counter
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
            iter_cnt <= 0;
        end
        else begin
            state <= n_state;
            if(state == UPDATE_BASE) iter_cnt <= iter_cnt + 1;
            else if(state == DONE) iter_cnt <= 0;
        end
    end

    // next state logic
    always @(*) begin
        case(state)
            IDLE:           n_state = (i_load_start) ? LOAD_SEQ : IDLE;
            LOAD_SEQ:       n_state = (seq_done) ? UPDATE_BASE : LOAD_SEQ;
            UPDATE_BASE:    n_state = (iter_cnt == i_layer_EF - 1) ? DONE : IDLE;
            DONE:           n_state = IDLE;
        endcase
    end

    // output logic
    always @(*) begin
        sequencer_cmd_load = 1'b0;
        w_base = 0;
        case(state)
            IDLE: begin
            end
            LOAD_SEQ: begin
                sequencer_cmd_load = 1;
                w_base = iter_cnt * i_layer_U;
            end
            UPDATE_BASE: begin
            end
        endcase
    end

    assign o_load_done = (state == UPDATE_BASE) && (iter_cnt == i_layer_EF - 1);

    ifmap_sequencer u_ifmap_sequencer (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_load         (sequencer_cmd_load),

        // Layer & Tiling Info
        .i_layer_C        (i_layer_C),
        .i_layer_HW       (i_layer_HW),
        .i_layer_U        (i_layer_U),
        .i_layer_RS       (i_layer_RS),
        .i_layer_EF       (i_layer_EF),
        .i_layer_PAD      (i_layer_PAD),
        .i_layer_m        (i_layer_m),
        .i_layer_e        (i_layer_e),
        .i_layer_p        (i_layer_p),
        .i_layer_q        (i_layer_q),
        .i_layer_r        (i_layer_r),
        .i_layer_t        (i_layer_t),

        // Base Cnt
        .c_base_cnt     (0),
        .h_base_cnt     (0),
        .w_base_cnt     (w_base),

        // Outputs
        .cur_C          (cur_C_wire),
        .cur_H          (cur_H_wire),
        .cur_W          (cur_W_wire),
        .tag            (o_ifmap_tag),
        .seq_done       (seq_done)
    );

    ifmap_loader u_ifmap_loader (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_ready        (state == LOAD_SEQ),

        // Layer Info
        .i_layer_C        (i_layer_C),
        .i_layer_HW       (i_layer_HW),
        .i_layer_PAD      (i_layer_PAD),

        // Current Coords from Sequencer
        .cur_C          (cur_C_wire),
        .cur_H          (cur_H_wire),
        .cur_W          (cur_W_wire),

        // Final Outputs to GLB
        .ifmap_glb_re   (o_ifmap_glb_re),
        .ifmap_glb_ra   (o_ifmap_glb_ra),
        .is_zero        (is_zero_wire)
    );

endmodule
