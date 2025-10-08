`timescale 1ns / 1ps
module psum_store_ctrl(
    input i_clk,
    input i_rst,

    input i_store_start, // Start loading an entire pass
    input [5:0] i_iter_cnt,

    //// Layer & Tiling/Mapping Parameters
    input [6:0] i_layer_m,
    input [2:0] i_layer_n,
    input [4:0] i_layer_e,
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [2:0] i_layer_r,
    input [3:0] i_layer_s,
    input [2:0] i_layer_t,

    //// Final Outputs to GLB
    output        o_psum_glb_we,
    output [15:0] o_psum_glb_wa
);

    localparam IDLE         = 2'h0;
    localparam STORE        = 2'h1;
    localparam DONE         = 2'h2;

    reg [2:0] state, n_state;

    reg [4:0] cnt_p;
    reg [4:0] cnt_e;
    wire store_done;

    wire [15:0] wa_offset;

    always @(posedge i_clk) begin
        if (i_rst)
            state <= IDLE;
        else
            state <= n_state;
    end

    always @(*) begin
        case(state)
            IDLE:     n_state = (i_store_start) ? STORE : IDLE;
            STORE:    n_state = (store_done) ? DONE : STORE;
            DONE:     n_state = IDLE;
            default:  n_state = IDLE;
        endcase
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            cnt_p <= 0;
            cnt_e <= 0;
        end
        else if (state == STORE) begin
            if (cnt_p == i_layer_p - 1) begin
                cnt_p <= 0;
                if (cnt_e == i_layer_e - 1) begin
                    cnt_e <= 0;
                end
                else cnt_e <= cnt_e + 1;
            end 
            else cnt_p <= cnt_p + 1;
        end
        else begin
            cnt_p <= 0;
            cnt_e <= 0;
        end
    end

    assign store_done = (cnt_p == i_layer_p - 1) && (cnt_e == i_layer_e - 1);
    assign wa_offset = i_layer_e * i_layer_e * i_layer_p;
    assign o_psum_glb_we = (state == STORE);
    assign o_psum_glb_wa = wa_offset + (cnt_p * i_layer_e * i_layer_e) + (cnt_e * i_layer_e) + i_iter_cnt;

endmodule