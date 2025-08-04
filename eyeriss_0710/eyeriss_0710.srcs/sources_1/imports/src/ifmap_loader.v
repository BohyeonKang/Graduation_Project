`timescale 1ns / 1ps
//// Role of ifmap_loader ////
//// 1. Determine whether (C,H,W) is zero_padded region or not ////
//// 2. Convert (C,H,W) to Real Address of GLB ////
module ifmap_loader(
    input i_clk,
    input i_rst,

    input i_ready,

    //// Layer information : To convert Real Address from (C,H,W)
    input [9:0] i_layer_C, //3~512 : 10bit can be cut down
    input [7:0] i_layer_HW, //8bit is enough - not padded feature map size
    // input [1:0] layer_U, //U is stride, 2 or 1 : 2bit can be cut down to 1bit
    // input [2:0] layer_RS,
    // input [6:0] layer_EF,
    input [1:0] i_layer_PAD, //1~3, 2bit is enough

    input [8:0] cur_C,
    input [7:0] cur_H,
    input [7:0] cur_W,

    output ifmap_glb_re,
    output [15:0] ifmap_glb_ra, //can be optimized later
    output is_zero
);

    // zero padding 판별
    wire [7:0] upper_bound;
    assign upper_bound = i_layer_HW + i_layer_PAD;
    assign is_zero =  (cur_H < i_layer_PAD) || // Top padding
                      (cur_W < i_layer_PAD) || // Left padding
                      (cur_H >= upper_bound) || // Bottom padding
                      (cur_W >= upper_bound);   // Right padding

    // padding 영역이 아닐때만 GLB에서 읽어오기
    assign ifmap_glb_re = i_ready && ~is_zero;


    // ## 3. GLB 실제 주소 변환 로직 ##
    // 유효 좌표(Effective coordinate)를 계산합니다. (패딩 offset 제거)
    wire [7:0] eff_H;
    wire [7:0] eff_W;
    assign eff_H = cur_H - i_layer_PAD;
    assign eff_W = cur_W - i_layer_PAD;

    // C, H, W 좌표를 1D 주소로 변환합니다.
    // 중요: 주소 계산 시에는 패딩이 없는 원본 크기(i_layer_HW)를 사용합니다.
    // 주의: i_layer_C, i_layer_HW의 최대값에 따라 결과가 16bit를 초과할 수 있습니다.
    //      최종 주소 범위에 맞게 입력 파라미터가 제한되어야 합니다.
    assign ifmap_glb_ra = (cur_C * i_layer_HW * i_layer_HW) + (eff_H * i_layer_HW) + eff_W;

endmodule