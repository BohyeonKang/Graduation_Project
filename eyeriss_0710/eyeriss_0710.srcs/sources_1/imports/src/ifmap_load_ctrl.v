`timescale 1ns / 1ps
module ifmap_load_ctrl(
    input i_clk,
    input i_rst,

    input cmd_load_pass, // Start loading an entire pass

    //// Layer & Tiling/Mapping Parameters
    input [9:0] layer_C,
    input [7:0] layer_HW,
    input [1:0] layer_U,
    input [2:0] layer_RS,
    input [6:0] layer_EF,
    input [1:0] layer_PAD,
    input [3:0] layer_m,
    input [4:0] layer_e,
    input [2:0] layer_p,
    input [2:0] layer_q,
    input       layer_r,
    input       layer_t,

    //// Final Outputs to GLB
    output ifmap_GLB_re,
    output [15:0] ifmap_GLB_ra,
    output pass_done
);

    // FSM 상태 정의
    localparam FSM_IDLE         = 2'd0;
    localparam FSM_LOAD_SEQ     = 2'd1;
    localparam FSM_UPDATE_BASE  = 2'd2;

    // 내부 신호 정의
    reg  [1:0] fsm_state;
    reg  sequencer_cmd_load;

    // 베이스 좌표 및 시퀀스 카운터
    reg  [7:0] w_base_reg;
    reg  [6:0] seq_cnt_reg;

    // 하위 모듈 간 연결을 위한 wire
    wire [8:0] cur_C_wire;
    wire [7:0] cur_H_wire;
    wire [7:0] cur_W_wire;
    wire [7:0] tag_wire;
    wire       seq_done_wire;
    wire       is_zero_wire;

    // 패스 완료를 위한 전체 시퀀스 수 계산 (올림)
    wire [6:0] total_seq_per_pass = (layer_EF + layer_RS - 1) / layer_RS;

    // FSM 및 제어 로직
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            fsm_state <= FSM_IDLE;
            sequencer_cmd_load <= 1'b0;
            w_base_reg <= 0;
            seq_cnt_reg <= 0;
        end
        else begin
            case (fsm_state)
                FSM_IDLE: begin
                    if (cmd_load_pass) begin
                        w_base_reg <= 0;
                        seq_cnt_reg <= 0;
                        sequencer_cmd_load <= 1'b1;
                        fsm_state <= FSM_LOAD_SEQ;
                    end
                end

                FSM_LOAD_SEQ: begin
                    if (seq_done_wire) begin
                        sequencer_cmd_load <= 1'b0;
                        fsm_state <= FSM_UPDATE_BASE;
                    end
                end

                FSM_UPDATE_BASE: begin
                    if (seq_cnt_reg + 1 == total_seq_per_pass) begin
                        fsm_state <= FSM_IDLE;
                    end
                    else begin
                        seq_cnt_reg <= seq_cnt_reg + 1;
                        w_base_reg <= w_base_reg;// + layer_RS;
                        sequencer_cmd_load <= 1'b1;
                        fsm_state <= FSM_LOAD_SEQ;
                    end
                end

                default: begin
                    fsm_state <= FSM_IDLE;
                end
            endcase
        end
    end

    assign pass_done = (fsm_state == FSM_UPDATE_BASE) && (seq_cnt_reg + 1 == total_seq_per_pass);

    // --- 하위 모듈 인스턴스화 ---

    ifmap_sequencer u_ifmap_sequencer (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .cmd_load       (sequencer_cmd_load),

        // Layer & Tiling Info
        .layer_C        (layer_C),
        .layer_HW       (layer_HW),
        .layer_U        (layer_U),
        .layer_RS       (layer_RS),
        .layer_EF       (layer_EF),
        .layer_PAD      (layer_PAD),
        .layer_m        (layer_m),
        .layer_e        (layer_e),
        .layer_p        (layer_p),
        .layer_q        (layer_q),
        .layer_r        (layer_r),
        .layer_t        (layer_t),

        // Base Cnt
        .c_base_cnt     (0),
        .h_base_cnt     (0),
        .w_base_cnt     (w_base_reg),

        // Outputs
        .cur_C          (cur_C_wire),
        .cur_H          (cur_H_wire),
        .cur_W          (cur_W_wire),
        .tag            (tag_wire),
        .seq_done       (seq_done_wire)
    );

    ifmap_loader u_ifmap_loader (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .state          (3'b0),

        // Layer Info
        .layer_C        (layer_C),
        .layer_HW       (layer_HW),
        .layer_PAD      (layer_PAD),

        // Current Coords from Sequencer
        .cur_C          (cur_C_wire),
        .cur_H          (cur_H_wire),
        .cur_W          (cur_W_wire),

        // Final Outputs to GLB
        .ifmap_GLB_re   (ifmap_GLB_re),
        .ifmap_GLB_ra   (ifmap_GLB_ra),
        .is_zero        (is_zero_wire)
    );

endmodule
