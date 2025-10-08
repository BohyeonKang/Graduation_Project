`timescale 1ns / 1ps
module top_ctrl #(
    parameter DATA_BITWIDTH = 32,
    parameter NUM_ROWS = 3,
    parameter NUM_COLS = 3,
    parameter BANK_DEPTH = 512,
	parameter IFMAP_ROW_ID_BITWIDTH = 4,
	parameter WGHT_ROW_ID_BITWIDTH = 4,
	parameter PSUM_ROW_ID_BITWIDTH = 4,
	parameter IFMAP_COL_ID_BITWIDTH = 5,
	parameter WGHT_COL_ID_BITWIDTH = 4,
	parameter PSUM_COL_ID_BITWIDTH = 4
)(
    input i_clk,
    input i_rst,

    input i_start,
    output reg o_done,

    //// Layer & Tiling/Mapping Parameters from scan_chain_decoder.v
    input [7:0] i_layer_HW,
    input [2:0] i_layer_U,
    input [1:0] i_layer_PAD,
    
    input [6:0] i_layer_m,
    input [2:0] i_layer_n,
    input [4:0] i_layer_e,
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [2:0] i_layer_r,
    input [3:0] i_layer_s,
    input [2:0] i_layer_t,
    input [NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1:0] i_ifmap_row_id,
    input [NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1:0] i_wght_row_id,
    input [NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1:0] i_psum_row_id,
    input [NUM_ROWS * NUM_COLS * IFMAP_COL_ID_BITWIDTH-1:0] i_ifmap_col_id,
    input [NUM_ROWS * NUM_COLS * WGHT_COL_ID_BITWIDTH-1:0] i_wght_col_id,
    input [NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1:0] i_psum_col_id,

    // PE array interface
    output reg [2:0] o_inst_data,
    output reg       o_inst_valid,
    input            i_inst_ready,

    output reg [IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1:0] o_ifmap_row_id,
    output reg [WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1:0] o_wght_row_id,
    output reg [PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1:0] o_psum_row_id,
    output reg o_ifmap_row_id_valid,
    output reg o_wght_row_id_valid,
    output reg o_psum_row_id_valid,

    output reg [IFMAP_COL_ID_BITWIDTH*NUM_COLS-1:0] o_ifmap_col_id,
    output reg [WGHT_COL_ID_BITWIDTH*NUM_COLS-1:0] o_wght_col_id,
    output reg [PSUM_COL_ID_BITWIDTH*NUM_COLS-1:0] o_psum_col_id,
    output reg [NUM_ROWS-1:0] o_ifmap_col_id_valid,
    output reg [NUM_ROWS-1:0] o_wght_col_id_valid,
    output reg [NUM_ROWS-1:0] o_psum_col_id_valid,

    output reg [NUM_ROWS*NUM_COLS-1:0] o_psum_in_sel,
    output reg [NUM_ROWS*NUM_COLS-1:0] o_psum_out_sel,

    output reg [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] o_ifmap_packet,
    output reg [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] o_wght_packet,
    output reg [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH - 1:0] o_psum_in_packet,

    output reg o_ifmap_valid,
    output reg o_wght_valid,
    input i_psum_in_ready, // not used. 로직 보완 필요
    output reg o_psum_in_valid,
    output reg o_psum_out_ready,

    input i_psum_out_valid,
    input [DATA_BITWIDTH-1:0] i_psum_out_data,
    output [DATA_BITWIDTH-1:0] o_psum_out_data,

    // GLB interface
    input [DATA_BITWIDTH-1:0] i_glb_rd,
	output reg [1:0] o_glb_bank_sel,
    output reg o_glb_en,
    output reg o_glb_we,
    output reg [clogb2(BANK_DEPTH-1)-1:0] o_glb_addr
);

    localparam IDLE = 4'h0;
    localparam INIT = 4'h1;
    localparam LOAD_IFMAP_START = 4'h2;
    localparam LOAD_IFMAP_WAIT = 4'h3;
    localparam LOAD_IFMAP = 4'h4;
    localparam WAIT = 4'h5;
    localparam LOAD_WGHT_START = 4'h6;
    localparam LOAD_WGHT_WAIT = 4'h7;
    localparam LOAD_WGHT = 4'h8;
    localparam LOAD_PSUM_START = 4'h9;
    localparam LOAD_PSUM_WAIT = 4'ha;
    localparam LOAD_PSUM = 4'hb;
    localparam CALC = 4'hc;
    localparam ACC = 4'hd;
    localparam PSUM2GLB = 4'he;
    localparam DONE = 4'hf;

    // opcodes for PE array
    localparam CMD_SET          = 3'd0;
    localparam CMD_LOAD_IFMAP   = 3'd1;
    localparam CMD_LOAD_WGHT    = 3'd2;
    localparam CMD_CONV         = 3'd3;
	localparam CMD_ACC          = 3'd4;

    reg [10:0] counter;
    reg [5:0] iter_cnt;

    reg [4:0] state;
    reg [4:0] n_state;
    reg is_first_cycle;

    // ifmap_load_ctrl
    wire [15:0] ifmap_glb_ra;
    wire [8:0] ifmap_tag;
    wire       ifmap_glb_en;
    wire       ifmap_valid;

    // wght_load_ctrl
    wire [15:0] wght_glb_ra;
    wire [7:0] wght_tag;
    wire       wght_glb_en;
    wire       wght_valid;

    // psum_load_ctrl
    wire [15:0] psum_glb_ra;
    wire [7:0] psum_tag;
    wire       psum_glb_en;
    wire       psum_valid;

    // psum_store_ctrl
    wire [15:0] psum_glb_wa;
    wire psum_glb_we;

    // psum_sel_ctrl
    wire [NUM_ROWS*NUM_COLS-1:0] psum_in_sel;
    wire [NUM_ROWS*NUM_COLS-1:0] psum_out_sel;

    reg psum_out_valid;
    reg [DATA_BITWIDTH-1:0] psum_out_data;

    // ifmap_load_ctrl instance
    ifmap_load_ctrl u_ifmap_load_ctrl (
        .i_clk             (i_clk),
        .i_rst             (i_rst),

        .i_load_start      ((state == LOAD_IFMAP_START) && is_first_cycle),
        .i_iter_cnt        (iter_cnt),

        // Layer & Tiling/Mapping Parameters
        .i_layer_HW        (i_layer_HW),
        .i_layer_U         (i_layer_U),
        .i_layer_PAD       (i_layer_PAD),
        .i_layer_e         (i_layer_e),
        .i_layer_p         (i_layer_p),
        .i_layer_q         (i_layer_q),
        .i_layer_r         (i_layer_r),
        .i_layer_s         (i_layer_s),
        .i_layer_t         (i_layer_t),

        // Final Outputs to GLB
        .o_ifmap_glb_en    (ifmap_glb_en),
        .o_ifmap_glb_ra    (ifmap_glb_ra),
        .o_ifmap_tag       (ifmap_tag),
        .o_ifmap_valid     (ifmap_valid)
    );

    // Instance of wght_load_ctrl
    wght_load_ctrl u_wght_load_ctrl (
        .i_clk         (i_clk),           // input clock
        .i_rst         (i_rst),           // input reset

        .i_load_start  ((state == LOAD_WGHT_START) && is_first_cycle),    // start signal to begin loading

        .i_layer_p       (i_layer_p),
        .i_layer_q       (i_layer_q),
        .i_layer_s       (i_layer_s),

        .o_wght_glb_en   (wght_glb_en),     // weight GLB enable
        .o_wght_glb_ra   (wght_glb_ra),     // weight GLB read address
        .o_wght_tag      (wght_tag),        // weight tag (used for routing or matching)
        .o_wght_valid    (wght_valid)
    );

    psum_load_ctrl u_psum_load_ctrl (
        .i_clk           (i_clk),
        .i_rst           (i_rst),

        .i_load_start    ((state == LOAD_PSUM_START) && is_first_cycle),
        .i_iter_cnt      (iter_cnt),

        .i_layer_m       (i_layer_m),
        .i_layer_n       (i_layer_n),
        .i_layer_e       (i_layer_e),
        .i_layer_p       (i_layer_p),
        .i_layer_q       (i_layer_q),
        .i_layer_r       (i_layer_r),
        .i_layer_s       (i_layer_s),
        .i_layer_t       (i_layer_t),

        .o_psum_glb_en   (psum_glb_en),
        .o_psum_glb_ra   (psum_glb_ra),
        .o_psum_tag      (psum_tag),
        .o_psum_valid    (psum_valid)
    );

    psum_store_ctrl u_psum_store_ctrl (
        .i_clk         (i_clk),
        .i_rst         (i_rst),

        .i_store_start ((state == PSUM2GLB) && is_first_cycle),
        .i_iter_cnt    (iter_cnt),

        .i_layer_m     (i_layer_m),
        .i_layer_n     (i_layer_n),
        .i_layer_e     (i_layer_e),
        .i_layer_p     (i_layer_p),
        .i_layer_q     (i_layer_q),
        .i_layer_r     (i_layer_r),
        .i_layer_s     (i_layer_s),
        .i_layer_t     (i_layer_t),

        .o_psum_glb_we (psum_glb_we),
        .o_psum_glb_wa (psum_glb_wa)
    );

    psum_sel_ctrl #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) u_psum_sel_ctrl (
        .i_layer_s(i_layer_s),
        .i_psum_row_id(i_psum_row_id),
        .i_psum_col_id(i_psum_col_id),
        .o_psum_in_sel(psum_in_sel),
        .o_psum_out_sel(psum_out_sel)
    );

    always @(posedge i_clk) begin
        if (i_rst) begin
            psum_out_valid <= 0;
            psum_out_data <= 0;
        end
        else begin
            psum_out_valid <= i_psum_out_valid;
            psum_out_data <= i_psum_out_data;
        end
    end

    // counter logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            counter <= 0;
        end 
        else begin
            if(state != n_state) begin
                counter <= 0;                    
            end
            else begin
                counter <= counter + 1;
            end
        end
    end

    always @(posedge i_clk) begin
        if(i_rst) begin
            iter_cnt <= 0;
        end
        else begin
            if((state == PSUM2GLB) && (state != n_state)) begin
                iter_cnt <= (iter_cnt == i_layer_e - 1) ? 0 : iter_cnt + 1;
            end
        end
    end

    // signal activated every first cycle of each state
    always @(posedge i_clk) begin
        if(i_rst) begin
            is_first_cycle <= 0;
        end
        else begin
            is_first_cycle <= (state != n_state);
        end
    end

    //FSM : state register update
    always @(posedge i_clk) begin
        if(i_rst) begin
            state <= 0;
        end
        else begin
            state <= n_state;
        end
    end

    //FSM: next state logic
    always @(*) begin
        o_done = 1'b0;
        case(state)
            IDLE: begin
                if(i_start == 1'b1)                         n_state = INIT;
                else                                        n_state = IDLE;
            end
            INIT: begin
                if(i_inst_ready && !is_first_cycle)         n_state = LOAD_IFMAP_START;
                else                                        n_state = INIT;
            end
            LOAD_IFMAP_START:                               n_state = LOAD_IFMAP_WAIT;
            LOAD_IFMAP_WAIT: begin
                if(counter == 1)                            n_state = LOAD_IFMAP;
                else                                        n_state = LOAD_IFMAP_WAIT;
            end
            LOAD_IFMAP: begin
                if(i_inst_ready && !is_first_cycle)         n_state = WAIT;
                else                                        n_state = LOAD_IFMAP;
            end
            WAIT: begin
                if(iter_cnt == 0)                           n_state = LOAD_WGHT_START;
                else                                        n_state = LOAD_PSUM_START;
            end
            LOAD_WGHT_START:                                n_state = LOAD_WGHT_WAIT;
            LOAD_WGHT_WAIT: begin
                if(counter == 1)                            n_state = LOAD_WGHT;
                else                                        n_state = LOAD_WGHT_WAIT;
            end
            LOAD_WGHT: begin
                if(i_inst_ready && !is_first_cycle)         n_state = LOAD_PSUM_START;
                else                                        n_state = LOAD_WGHT;
            end
            LOAD_PSUM_START:                                n_state = LOAD_PSUM_WAIT;
            LOAD_PSUM_WAIT:  begin
                if(counter == 1)                            n_state = LOAD_PSUM;
                else                                        n_state = LOAD_PSUM_WAIT;
            end
            LOAD_PSUM: begin
                if(counter == i_layer_p * i_layer_e - 1)    n_state = CALC;
                else                                        n_state = LOAD_PSUM;
            end
            CALC: begin
                if(i_inst_ready && !is_first_cycle)         n_state = ACC;
                else                                        n_state = CALC;
            end
            ACC: begin
                if(i_inst_ready && !is_first_cycle)         n_state = PSUM2GLB;
                else                                        n_state = ACC;
            end
            PSUM2GLB: begin
                if(counter == NUM_ROWS * NUM_COLS * i_layer_p - 1)  n_state = (iter_cnt ==  i_layer_e - 1) ? DONE : LOAD_IFMAP_START;
                else                                                n_state = PSUM2GLB;
            end
            DONE: begin
                n_state = IDLE;
                o_done = 1'b1;
            end
            default: n_state = IDLE;
        endcase
    end

    always @(*) begin
        //PE array interface
        o_inst_data = CMD_SET;
        o_inst_valid = 1'b0;

        o_ifmap_row_id = {IFMAP_ROW_ID_BITWIDTH * NUM_ROWS{1'b0}};
        o_wght_row_id = {WGHT_ROW_ID_BITWIDTH * NUM_ROWS{1'b0}};
        o_psum_row_id = {PSUM_ROW_ID_BITWIDTH * NUM_ROWS{1'b0}};
        o_ifmap_row_id_valid = 1'b0;
        o_wght_row_id_valid = 1'b0;
        o_psum_row_id_valid = 1'b0;
        o_ifmap_col_id = {IFMAP_COL_ID_BITWIDTH*NUM_COLS{1'b0}};
        o_wght_col_id = {WGHT_COL_ID_BITWIDTH*NUM_COLS{1'b0}};
        o_psum_col_id = {PSUM_COL_ID_BITWIDTH*NUM_COLS{1'b0}};
        o_ifmap_col_id_valid = {NUM_ROWS{1'b0}};
        o_wght_col_id_valid = {NUM_ROWS{1'b0}};
        o_psum_col_id_valid = {NUM_ROWS{1'b0}};

        o_psum_in_sel = {NUM_ROWS*NUM_COLS{1'b0}};
        o_psum_out_sel = {NUM_ROWS*NUM_COLS{1'b0}};
        
        o_ifmap_packet = {(IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + DATA_BITWIDTH){1'b0}};
        o_wght_packet = {(WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + DATA_BITWIDTH){1'b0}};
        o_psum_in_packet = {(PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + DATA_BITWIDTH){1'b0}};
        o_ifmap_valid = 1'b0;
        o_wght_valid = 1'b0;
        o_psum_in_valid = 1'b0;
        o_psum_out_ready = 1'b0;

        // GLB interface
        o_glb_en = 1'b0;
        o_glb_we = 1'b0;
        o_glb_addr = {clogb2(BANK_DEPTH-1){1'b0}};
        o_glb_bank_sel = 2'h0;

        case(state)
            IDLE: begin
            end
            INIT: begin
                o_inst_data = CMD_SET;
                o_inst_valid = is_first_cycle;

                o_ifmap_row_id = i_ifmap_row_id;
                o_wght_row_id = i_wght_row_id;
                o_psum_row_id = i_psum_row_id;
                o_ifmap_row_id_valid = is_first_cycle;
                o_wght_row_id_valid = is_first_cycle;
                o_psum_row_id_valid = is_first_cycle;
                o_ifmap_col_id = i_ifmap_col_id[counter * (NUM_COLS * IFMAP_COL_ID_BITWIDTH) +: (NUM_COLS * IFMAP_COL_ID_BITWIDTH)];
                o_wght_col_id = i_wght_col_id[counter * (NUM_COLS * WGHT_COL_ID_BITWIDTH) +: (NUM_COLS * WGHT_COL_ID_BITWIDTH)];
                o_psum_col_id = i_psum_col_id[counter * (NUM_COLS * PSUM_COL_ID_BITWIDTH) +: (NUM_COLS * PSUM_COL_ID_BITWIDTH)];
                o_ifmap_col_id_valid = 1'b1 << counter;
                o_wght_col_id_valid = 1'b1 << counter;
                o_psum_col_id_valid = 1'b1 << counter;
            end
            LOAD_IFMAP_START: begin
                o_inst_data = CMD_LOAD_IFMAP;
                o_inst_valid = is_first_cycle;

                o_glb_addr = ifmap_glb_ra;
                o_glb_en = ifmap_glb_en;
                o_glb_bank_sel = 2'h1;
            end
            LOAD_IFMAP_WAIT: begin
                o_glb_addr = ifmap_glb_ra;
                o_glb_en = ifmap_glb_en;
                o_glb_bank_sel = 2'h1;
            end
            LOAD_IFMAP: begin
                o_ifmap_valid = ifmap_valid;
                o_ifmap_packet = {ifmap_tag, i_glb_rd};

                o_glb_addr = ifmap_glb_ra;
                o_glb_en = ifmap_glb_en;
                o_glb_bank_sel = 2'h1;
            end
            LOAD_WGHT_START: begin
                o_inst_data = CMD_LOAD_WGHT;
                o_inst_valid = is_first_cycle;

                o_glb_en = wght_glb_en;
                o_glb_addr = wght_glb_ra;
                o_glb_bank_sel = 2'h2;
            end
            LOAD_WGHT_WAIT: begin
                o_glb_en = wght_glb_en;
                o_glb_addr = wght_glb_ra;
                o_glb_bank_sel = 2'h2;
            end
            LOAD_WGHT: begin
                o_wght_valid = wght_valid;
                o_wght_packet = {wght_tag, i_glb_rd};

                o_glb_en = wght_glb_en;
                o_glb_addr = wght_glb_ra;
                o_glb_bank_sel = 2'h2;
            end
            LOAD_PSUM_START: begin
                o_glb_en = psum_glb_en;
                o_glb_addr = psum_glb_ra;
                o_glb_bank_sel = 2'h3;
                o_psum_in_sel = psum_in_sel;
            end
            LOAD_PSUM_WAIT: begin
                o_glb_en = psum_glb_en;
                o_glb_addr = psum_glb_ra;
                o_glb_bank_sel = 2'h3;
                o_psum_in_sel = psum_in_sel;
            end
            LOAD_PSUM: begin
                o_psum_in_valid = psum_valid;
                o_psum_in_packet = {psum_tag, i_glb_rd};

                o_glb_en = psum_glb_en;
                o_glb_addr = psum_glb_ra;
                o_glb_bank_sel = 2'h3;
                o_psum_in_sel = psum_in_sel;
            end
            CALC: begin
                o_inst_data = CMD_CONV;
                o_inst_valid = is_first_cycle;
            end
            ACC: begin
                o_inst_data = CMD_ACC;
                o_inst_valid = is_first_cycle;
            end
            PSUM2GLB: begin
                o_glb_bank_sel = 2'h3;
                o_glb_en = psum_glb_we;
                o_glb_we = psum_out_valid;
                o_glb_addr = psum_glb_wa;
                
                // p cycle for each top pe
                o_psum_out_sel = (psum_out_sel[counter / i_layer_p] << (counter / i_layer_p));
            end
            DONE: begin
            end
        endcase
    end

    assign o_psum_out_data = psum_out_data;

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule