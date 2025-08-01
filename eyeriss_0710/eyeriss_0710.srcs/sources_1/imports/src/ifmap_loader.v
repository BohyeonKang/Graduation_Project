`timescale 1ns / 1ps
//// Role of ifmap_loader ////
//// 1. Convert (C,H,W) to Real Address of GLB ////
//// 2. Determine whether (C,H,W) is zero_padded region or not ////
module ifmap_loader(
    input i_clk,
    input i_rst,

    input [2:0] state,

    //// Layer information : To convert Real Address from (C,H,W)
    input [9:0] layer_C, //3~512 : 10bit can be cut down
    input [7:0] layer_HW, //8bit is enough - not padded feature map size
    // input [1:0] layer_U, //U is stride, 2 or 1 : 2bit can be cut down to 1bit
    // input [2:0] layer_RS,
    // input [6:0] layer_EF,
    input [1:0] layer_PAD, //1~3, 2bit is enough

    input [8:0] cur_C,
    input [7:0] cur_H,
    input [7:0] cur_W,

    output ifmap_GLB_re,
    output [15:0] ifmap_GLB_ra, //can be optimized later
    output is_zero
);

    // ## 1. 제로 패딩 영역 판별 로직 ##
    // 유효 데이터의 경계(exclusive)를 계산합니다.
    // cur_H/W가 이 값과 같거나 커지면 패딩 영역입니다.
    wire [7:0] upper_bound;
    assign upper_bound = layer_HW + layer_PAD;

    // is_zero는 현재 좌표(cur_H, cur_W)가 패딩 영역에 있을 때 1이 됩니다.
    // 상/하/좌/우 네 방향의 경계를 모두 확인합니다.
    assign is_zero =  (cur_H < layer_PAD) || // Top padding
                      (cur_W < layer_PAD) || // Left padding
                      (cur_H >= upper_bound) || // Bottom padding
                      (cur_W >= upper_bound);   // Right padding


    // ## 2. Read Enable 신호 생성 로직 ##
    // 패딩 영역이 아닐 때만 GLB에서 데이터를 읽어오도록 re 신호를 활성화합니다.
    assign ifmap_GLB_re = ~is_zero; // + state logic


    // ## 3. GLB 실제 주소 변환 로직 ##
    // 유효 좌표(Effective coordinate)를 계산합니다. (패딩 offset 제거)
    wire [7:0] eff_H;
    wire [7:0] eff_W;
    assign eff_H = cur_H - layer_PAD;
    assign eff_W = cur_W - layer_PAD;

    // C, H, W 좌표를 1D 주소로 변환합니다.
    // 중요: 주소 계산 시에는 패딩이 없는 원본 크기(layer_HW)를 사용합니다.
    // 주의: layer_C, layer_HW의 최대값에 따라 결과가 16bit를 초과할 수 있습니다.
    //      최종 주소 범위에 맞게 입력 파라미터가 제한되어야 합니다.
    assign ifmap_GLB_ra = (cur_C * layer_HW * layer_HW) + (eff_H * layer_HW) + eff_W;

endmodule