`timescale 1ns / 1ps
//// Role of ifmap_sequencer ////
//// 1. Considering layer_RS(Filter size), layer_U(Stride), layer_PAD(Padding), layer_HW(ifmap Size), layer_EF(ofmap Size), calculate 끝 H and 끝 W (recommend appropriate name for those)
//// e.g. RS=3, HW=14, EF=14, Padding=1, Stride=1일때, 끝 H와 끝 W는 15이다. [{0,1,2}, {1,2,3}, ,,, {13,14,15}] => 총 14개, 끝=15
//// e.g. RS=3, HW=56, EF=28, Padding=1, Stride=2일때, 끝 H와 끝 W는 56이다. [{0,1,2},{2,3,4}, ,,, {54,55,56}] => 총 28개, 끝 56
//// 끝 H와 끝 W는 언제나 동일하므로, 변수명_HW으로 묶어주길 바람
//// 2.  load_begin 신호가 들어오면 layer_q, layer_RS, layer_HW을 고려하여 다음과 같이 순차적으로 데이터를 로드해주길 바람 + TAG 생성
            //LOAD IFMAP : Filter Size  * q amount per PE
            //IFMAP GLB : 만약에 RS = 3이고 q=4라면 IFMAP GLB (C,H,W)에서 (예를 들어 STRIDE=2일때,보내려는 ROW가 짝수면 0, ROW가 홀수면 1을 적용할 수 있음 + ZERO_PADDING=1)
            //(1,0,0){0,0}, (1,0,1){0,0}, (1,0,2){0,0},
            //(2,0,0){0,0}, (2,0,1){0,0}, {2,0,2){0,0},
            //(3,0,0){0,0}, (3,0,1){0,0}, {3,0,2){0,0},
            //(4,0,0){0,0}, (4,0,1){0,0}, {4,0,2){0,0}, => 모두 ZERO 전송 (GLB 접근 불필요) (이러면 BUS에 전송 완료), 다음에는 H를 바꿔서 입력 줘야하는데

            //(1,1,0){0,1}, (1,1,1){0,1}, (1,1,2){0,1}, 
            //(2,1,0){0,1}, (2,1,1){0,1}, (2,1,2){0,1}, 
            //(3,1,0){0,1}, (3,1,1){0,1}, (3,1,2){0,1}, 
            //(4,1,0){0,1}, (4,1,1){0,1}, (4,1,2){0,1}를 BUS로 전송 (mux를 통해 H,W에 0 또는 마지막 H/W 값이 있다면 GLB 데이터 말고 0 전송하도록 해야함)

            //(1,2,0){1,0}, (1,2,1){1,0}, (1,2,2){1,0}, 
            //(2,2,0){1,0}, (2,2,1){1,0}, (2,2,2){1,0}, 
            //(3,2,0){1,0}, (3,2,1){1,0}, (3,2,2){1,0}, 
            //(4,2,0){1,0}, (4,2,1){1,0}, (4,2,2){1,0}를 BUS로 전송 

            //(1,3,0){1,1}, (1,3,1){1,1}, (1,3,2){1,1},          
            //(2,3,0){1,1}, (2,3,1){1,1}, (2,3,2){1,1}, 
            //(3,3,0){1,1}, (3,3,1){1,1}, (3,3,2){1,1}, 
            //(4,3,0){1,1}, (4,3,1){1,1}, (4,3,2){1,1}를 BUS로 전송 

            //(1,4,0){2,0}, (1,4,1){2,0}, (1,4,2){2,0},
            //(2,4,0){2,0}, (2,4,1){2,0}, (2,4,2){2,0},
            //(3,4,0){2,0}, (3,4,1){2,0}, (3,4,2){2,0},
            //(4,4,0){2,0}, (4,4,1){2,0}, (4,4,2){2,0},를 BUS로 전송

            // ... 

            //(1,56,0){28,0}, (1,56,1){28,0}, (1,56,2){28,0},
            //(2,56,0){28,0}, (2,56,1){28,0}, (2,56,2){28,0},
            //(3,56,0){28,0}, (3,56,1){28,0}, (3,56,2){28,0},
            //(4,56,0){28,0}, (4,56,1){28,0}, (4,56,2){28,0},를 BUS로 전송 => 모든 PE에 IFMAP 전송 완료=>SEQ 하나 LOAD 완료, 이후 다시 load_begin이면 W=3,4,5에 대해서 진행 {6,7,8},,,{54,55,56}

            // ... => W=56까지 모두 LOAD를 마치면 새로운 PASS를 연산할 준비 
////tag={Y_tag,X_tag} 이며 stride가 2인 경우 Y TAG는 q*RS만큼 전송할때마다 홀짝 번갈아가면서, X TAG는 2*q*RS 전송할때마다 1씩 증가
////cur_H=끝_HW에 도달하고 모든 PE에 IFMAP 전송을 완료할때만다 seq_done을 올리고 cur_seq를 하나 올림
//// 3. 하나의 Pass를 완성하기 위해 필요한 seq의 개수에 도달하면 pass_done를 생성
module ifmap_sequencer(
    input i_clk,
    input i_rst,

    input cmd_load, // FSM control signal from outside (e.g., IDLE, LOAD_PE)

    //// Layer information
    input [9:0] layer_C,
    input [7:0] layer_HW,   // Ifmap Size (original)
    input [1:0] layer_U,    // Stride
    input [2:0] layer_RS,   // Filter Size
    input [6:0] layer_EF,   // Ofmap Size
    input [1:0] layer_PAD,

    // Tiling/Mapping Parameters
    input [3:0] layer_m,
    input [4:0] layer_e,
    input [2:0] layer_p,
    input [2:0] layer_q,    // # of channels processed by a PE set
    input       layer_r,
    input       layer_t,

    //
    input [8:0] c_base_cnt,
    input [7:0] h_base_cnt,
    input [7:0] w_base_cnt,

    //// Outputs
    output [8:0] cur_C,
    output [7:0] cur_H,
    output [7:0] cur_W,
    output [7:0] tag,
    output reg seq_done
);

    ////1.
    wire [7:0] end_HW = (layer_EF - 1) * layer_U + layer_RS - 1;
    //// e.g. EF=28, U=2, RS=3 (PAD=1) -> (27 * 2) + 3 - 1 = 54 + 2 = 56
    //// e.g. EF=14, U=1, RS=3 (PAD=1) -> 13*1 + 3 - 1 = 15
    //// e.g. EF=112, U=2, RS=7 (PAD=3) -> 111*2 + 7-1 = 228

    ////2.
    reg [2:0] c_filter_cnt;   // Counter for scanning within a filter (0 to RS-1)
    reg [7:0] h_filter_cnt;   // Counter for scanning within a filter (0 to RS-1)
    reg [2:0] w_filter_cnt;   // Counter for scanning within a filter (0 to RS-1)
    wire [4:0] X_tag;
    wire [2:0] Y_tag;

    always @(posedge i_clk)
    begin
        if (i_rst) begin
            c_filter_cnt <= 0;
            h_filter_cnt <= 0;
            seq_done <= 0;
            w_filter_cnt <= 0;
        end
        else if (cmd_load==1) begin
        seq_done <= 0; // 매 사이클 기본적으로 0으로 유지

        // 가장 안쪽 루프: w_filter_cnt (매 클럭 증가)
        if (w_filter_cnt == layer_RS - 1) begin
            w_filter_cnt <= 0;
            // 중간 루프: c_filter_cnt (w가 한 바퀴 돌 때마다 증가)
            if (c_filter_cnt == layer_q - 1) begin
                c_filter_cnt <= 0;
                // 가장 바깥쪽 루프: h_filter_cnt (w와 c가 모두 한 바퀴 돌 때마다 증가)
                if (h_filter_cnt == end_HW) begin
                    h_filter_cnt <= 0; // 여기서 리셋!
                    seq_done <= 1'b1;     // 시퀀스 종료 신호 발생
                end else begin
                    h_filter_cnt <= h_filter_cnt + 1;
                end
            end else begin
                c_filter_cnt <= c_filter_cnt + 1;
            end
        end else begin
            w_filter_cnt <= w_filter_cnt + 1;
        end
            // c_filter_cnt <= (w_filter_cnt != layer_RS - 1) ? c_filter_cnt : (c_filter_cnt == layer_q - 1) ? 0 : c_filter_cnt + 1;
            // w_filter_cnt <= (w_filter_cnt == layer_RS - 1) ? 0 : w_filter_cnt + 1;
            // h_filter_cnt <= ((w_filter_cnt == layer_RS - 1) && (c_filter_cnt == layer_q - 1)) ? h_filter_cnt + 1 : h_filter_cnt;
            // seq_done <= (w_filter_cnt == layer_RS - 1) && (c_filter_cnt == layer_q - 1) && (h_filter_cnt == end_HW) ? 1 : 0;
        end
        else begin
            c_filter_cnt <= c_filter_cnt;
            h_filter_cnt <= h_filter_cnt;
            seq_done <= seq_done;
            w_filter_cnt <= w_filter_cnt;
        end
    end
    assign tag = {X_tag,Y_tag};
    assign X_tag = (layer_U==2) ? (cur_H >> 1) : (layer_U==1) ? cur_H : 0;
    assign Y_tag = (layer_U==2) ? ({2'b00,cur_H[0]}) : 0;
    assign cur_C = c_base_cnt + c_filter_cnt;
    assign cur_H = h_base_cnt + h_filter_cnt;
    assign cur_W = w_base_cnt + w_filter_cnt;
endmodule
