`timescale 1ns / 1ps
module psum_load_ctrl(
    input i_clk,
    input i_rst,

    input i_load_start, // Start loading an entire pass
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
    output          o_psum_glb_en,
    output [15:0]   o_psum_glb_ra,
    output [7:0]    o_psum_tag,
    output          o_psum_valid
);

    localparam IDLE         = 2'h0;
    localparam LOAD         = 2'h1;
    localparam DONE         = 2'h2;

    reg [2:0] state, n_state;

    wire [7:0]    psum_tag;
    reg [7:0]     psum_tag_d1, psum_tag_d2;
    reg           psum_valid_d1, psum_valid_d2;

    // counter
    reg [4:0] cnt_p;
    reg [4:0] cnt_e;
    wire load_done;

    wire [3:0] row_tag = i_layer_s;
    wire [3:0] col_tag = cnt_e + 1;
    assign psum_tag = {row_tag, col_tag};

    always @(posedge i_clk) begin
        if(i_rst) begin
            psum_tag_d1 <= 0;
            psum_tag_d2 <= 0;
            psum_valid_d1 <= 0;
            psum_valid_d2 <= 0;
        end
        else begin
            psum_tag_d1 <= psum_tag;
            psum_tag_d2 <= psum_tag_d1;
            psum_valid_d1 <= (state == LOAD);
            psum_valid_d2 <= psum_valid_d1;
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
            IDLE:     n_state = (i_load_start) ? LOAD : IDLE;
            LOAD:     n_state = (load_done) ? DONE : LOAD;
            DONE:     n_state = IDLE;
            default:  n_state = IDLE;
        endcase
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            cnt_p <= 0;
            cnt_e <= 0;
        end
        else if (state == LOAD) begin
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

    assign load_done = (cnt_p == i_layer_p - 1) && (cnt_e == i_layer_e - 1);

    assign o_psum_glb_en = (state == LOAD);
    assign o_psum_glb_ra = (cnt_p * i_layer_e * i_layer_e) + (cnt_e * i_layer_e) + i_iter_cnt;
    assign o_psum_tag = psum_tag_d2;
    assign o_psum_valid = psum_valid_d2;

endmodule