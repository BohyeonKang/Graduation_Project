`timescale 1ns / 1ps
module psum_store_ctrl(
    input i_clk,
    input i_rst,

    input i_start, // Start loading an entire pass

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
    output          o_psum_glb_we,
    output [15:0]   o_psum_glb_wa,
    output          o_iter_done,
    output          o_load_done
);

    localparam IDLE         = 3'd0;
    localparam STORE        = 3'd1;
    localparam UPDATE_BASE  = 3'd2;
    localparam UPDATE_BATCH = 3'd3;
    localparam DONE         = 3'd4;

    reg [2:0] state, n_state;

    // counter
    reg [2:0] batch_cnt;
    reg [6:0] iter_cnt;
    reg [4:0] cnt_p;
    reg [4:0] cnt_e;

    reg [3:0] pe_set_sel;

    wire iter_done = (cnt_p == i_layer_p - 1) && (cnt_e == i_layer_e - 1);
    wire pass_done = (cnt_p == i_layer_p - 1) && (cnt_e == i_layer_e - 1) && (iter_cnt == i_layer_e - 1) && (batch_cnt == i_layer_n - 1);

    wire [15:0] wa_offset;

    always @(posedge i_clk) begin
        if (i_rst)
            state <= IDLE;
        else
            state <= n_state;
    end

    always @(*) begin
        case(state)
            IDLE:     n_state = (i_start) ? STORE : IDLE;
            STORE:    n_state = (iter_done) ? UPDATE_BASE : STORE;
            UPDATE_BASE: n_state = (iter_cnt == i_layer_e - 1) ? UPDATE_BATCH : IDLE;
            UPDATE_BATCH: n_state = (batch_cnt == i_layer_n - 1) ? DONE : IDLE;
            DONE:     n_state = IDLE;
            default:  n_state = IDLE;
        endcase
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            batch_cnt <= 0;
            iter_cnt <= 0;
            cnt_p <= 0;
            cnt_e <= 0;
        end
        else if (n_state == STORE) begin
            if (cnt_p == i_layer_p - 1) begin
                cnt_p <= 0;
                if (cnt_e == i_layer_e - 1) begin
                    cnt_e <= 0;
                end
                else cnt_e <= cnt_e + 1;
            end 
            else cnt_p <= cnt_p + 1;
        end
        else if(n_state == UPDATE_BASE)
            iter_cnt <= (iter_cnt == i_layer_e - 1) ? 0 : iter_cnt + 1;
        else if(n_state == UPDATE_BATCH) 
            batch_cnt <= (batch_cnt == i_layer_n - 1) ? 0 : batch_cnt + 1;
        else begin
            cnt_p <= 0;
            cnt_e <= 0;
        end
    end

    assign wa_offset = i_layer_e * i_layer_e * i_layer_p;
    assign o_psum_glb_we = (n_state == STORE || n_state == UPDATE_BASE);
    assign o_psum_glb_wa = wa_offset + (cnt_p * i_layer_e * i_layer_e) + (cnt_e * i_layer_e) + iter_cnt;
    assign o_iter_done = iter_done;
    assign o_load_done   = (n_state == DONE);

endmodule