`timescale 1ns / 1ps

module ifmap_sequencer(
    input i_clk,
    input i_rst,

    input i_load, // FSM control signal from outside (e.g., IDLE, LOAD_PE)

    //// Layer information
    input [9:0] i_layer_C,
    input [7:0] i_layer_HW,   // Ifmap Size (original)
    input [1:0] i_layer_U,    // Stride
    input [2:0] i_layer_RS,   // Filter Size
    input [6:0] i_layer_EF,   // Ofmap Size
    input [1:0] i_layer_PAD,

    // Tiling/Mapping Parameters
    input [3:0] i_layer_m,
    input [4:0] i_layer_e,
    input [2:0] i_layer_p,
    input [2:0] i_layer_q,    // # of channels processed by a PE set
    input       i_layer_r,
    input       i_layer_t,

    //
    input [8:0] c_base_cnt,
    input [7:0] h_base_cnt,
    input [7:0] w_base_cnt,

    //// Outputs
    output [8:0] cur_C,
    output [7:0] cur_H,
    output [7:0] cur_W,
    output [8:0] tag,
    output seq_done
);

    // 
    wire [7:0] ifmap_end_idx = (i_layer_EF - 1) * i_layer_U + i_layer_RS - 1;

    // counters
    reg [2:0] cnt_c;
    reg [7:0] cnt_h;
    reg [2:0] cnt_w;

    wire [3:0] X_tag;
    wire [4:0] Y_tag;

    always @(posedge i_clk)
    begin
        if (i_rst) begin
            cnt_c <= 0;
            cnt_h <= 0;
            cnt_w <= 0;
        end
        else if (i_load) begin
            if (cnt_w == i_layer_RS - 1) begin
                cnt_w <= 0;
                if (cnt_c == i_layer_q - 1) begin
                    cnt_c <= 0;
                    if (cnt_h == ifmap_end_idx) begin
                        cnt_h <= 0; // 여기서 리셋!
                    end else begin
                        cnt_h <= cnt_h + 1;
                    end
                end else begin
                    cnt_c <= cnt_c + 1;
                end
            end 
            else begin
                cnt_w <= cnt_w + 1;
            end
        end
    end

    assign tag = {X_tag,Y_tag};
    assign X_tag = (i_layer_U==2) ? ({2'b00,cur_H[0]}) : 0;
    assign Y_tag = (i_layer_U==2) ? (cur_H >> 1) : (i_layer_U==1) ? cur_H : 0;

    assign cur_C = c_base_cnt + cnt_c;
    assign cur_H = h_base_cnt + cnt_h;
    assign cur_W = w_base_cnt + cnt_w;

    assign seq_done = (cnt_w == i_layer_RS - 1) && (cnt_c == i_layer_q - 1) && (cnt_h == ifmap_end_idx);

endmodule
