module TOP_ctrl #(
    parameter INST_BRAM_DEPTH = 64,
    parameter INST_BRAM_ADDR_WIDTH = clogb2(INST_BRAM_DEPTH),
    parameter DATA_BITWIDTH = 32,
    parameter NUM_COLS = 3,
    parameter NUM_ROWS = 3,
    parameter BANK_NUM = 3,
    parameter BANK_DEPTH = 512,
	parameter IFMAP_ROW_ID_BITWIDTH = 4,
	parameter WGHT_ROW_ID_BITWIDTH = 4,
	parameter PSUM_ROW_ID_BITWIDTH = 4,
	parameter IFMAP_COL_ID_BITWIDTH = 5,
	parameter WGHT_COL_ID_BITWIDTH = 4,
	parameter PSUM_COL_ID_BITWIDTH = 4,
	parameter IFMAP_BUS_BITWIDTH = 32,
    parameter WGHT_BUS_BITWIDTH = 32,
    parameter PSUM_BUS_BITWIDTH = 32
)(
    input i_clk,
    input i_rst,

    input [0:3*clogb2(BANK_NUM)-1] i_GLB_allocation,

    //// Layer & Tiling/Mapping Parameters from scan_chain_decoder.v
    input [3:0] i_total_pass,
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
    input [0:NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1] i_ifmap_row_id,
    input [0:NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1] i_wght_row_id,
    input [0:NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1] i_psum_row_id,
    input [0:NUM_ROWS * NUM_COLS * IFMAP_COL_ID_BITWIDTH-1] i_ifmap_col_id,
    input [0:NUM_ROWS * NUM_COLS * WGHT_COL_ID_BITWIDTH-1] i_wght_col_id,
    input [0:NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1] i_psum_col_id,

    // instruction bram interface
    output reg  [INST_BRAM_ADDR_WIDTH-1:0]   o_inst_bram_ra,
    input       [DATA_BITWIDTH-1:0]             i_inst_bram_rd,
    output reg  [INST_BRAM_ADDR_WIDTH-1:0]   o_inst_bram_wa,
    output reg  [DATA_BITWIDTH-1:0]             o_inst_bram_wd,
    output reg                                  o_inst_bram_we,

    // PE array interface
    output reg [2:0] o_inst_data,
    output reg [10:0] o_conv_info,
    output reg o_inst_valid,
    input i_inst_ready,

    output reg [0:IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1] o_ifmap_row_id,
    output reg [0:WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1] o_wght_row_id,
    output reg [0:PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1] o_psum_row_id,
    output reg o_ifmap_row_id_valid,
    output reg o_wght_row_id_valid,
    output reg o_psum_row_id_valid,

    // col ID는 한번에 한 ROW씩 들어오는걸로 가정. valid 신호는 one-hot encoded
    output reg [0:IFMAP_COL_ID_BITWIDTH*NUM_COLS-1] o_ifmap_col_id,
    output reg [0:WGHT_COL_ID_BITWIDTH*NUM_COLS-1] o_wght_col_id,
    output reg [0:PSUM_COL_ID_BITWIDTH*NUM_COLS-1] o_psum_col_id,
    output reg [0:NUM_ROWS-1] o_ifmap_col_id_valid,
    output reg [0:NUM_ROWS-1] o_wght_col_id_valid,
    output reg [0:NUM_ROWS-1] o_psum_col_id_valid,

    // psum_selection ctrl
    output reg [0:NUM_ROWS*NUM_COLS-1] o_ctrl_psum_in_sel_LNorGIN,
    output reg [0:NUM_ROWS*NUM_COLS-1] o_ctrl_psum_out_sel_GON,

    // label combined with GLB data
    output reg [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1:0] o_ifmap_packet,
    output reg [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1:0] o_wght_packet,
    output reg [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1:0] o_psum_in_packet,

    output reg o_ifmap_valid,
    output reg o_wght_valid,
    output reg o_psum_in_valid,
    output reg o_psum_out_ready,

    input i_ifmap_ready,
    input i_wght_ready,
    input i_psum_in_ready,
    input i_psum_out_valid,

    // GLB interface
    input [DATA_BITWIDTH-1:0] i_glb_rd,
	output reg [clogb2(BANK_NUM-1)-1:0] o_glb_bank_sel,
    output reg o_glb_re,
    output reg o_glb_we,
    output reg [clogb2(BANK_DEPTH-1)-1:0] o_glb_ra,
    output reg [clogb2(BANK_DEPTH-1)-1:0] o_glb_wa
);

    localparam IDLE = 4'd0;
    localparam INIT = 4'd1; // i_layer configuration
    localparam WAIT = 4'd2; // pass progress check
    localparam LOAD_DRAM2GLB = 4'd3; // Load required ifmap and weight from DRAM to GLB
    localparam LOAD_IFMAP = 4'd4; // LOAD IFMAP from GLB to PE array
    localparam LOAD_WGHT = 4'd5; // LOAD WGHT from GLB to PE array
    localparam LOAD_PSUM = 4'd6; // LOAD PSUM from GLB to PE array psum fifo. if no PSUM needed, load zero.
    localparam CALC = 4'd7;
    localparam ACCRST = 4'd8;
    localparam PSUM2GLB = 4'd9;
    localparam DONE = 4'd10;

    // opcodes for PE array
    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
	localparam CMD_ACC          = 3'b101;

    reg [10:0] cnt, tar_cnt;
    reg [6:0] iter_cnt;
    reg [9:0] pass_cnt;

    reg [3:0] state;
    reg [3:0] n_state;

    reg [1:0] glb_data_type;
    reg [clogb2(BANK_NUM*BANK_DEPTH)-1:0] glb_logical_addr;

    wire [clogb2(BANK_DEPTH)-1:0] glb_physical_addr;
    wire [clogb2(BANK_NUM-1)-1:0] glb_bank_sel;

    wire ifmap_load_iter_done, psum_load_iter_done;
    wire ifmap_load_done, wght_load_done, psum_load_done;
    wire ifmap_glb_re, wght_glb_re, psum_glb_re;
    wire [8:0] ifmap_tag;
    wire [7:0] wght_tag, psum_tag;
    wire [13:0] ifmap_glb_ra, wght_glb_ra, psum_glb_ra;

    wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_in_sel_LNorGIN;
    wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_out_sel_GON;

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
        case(state)
            IDLE: begin
                if(i_inst_bram_rd == 1'b1)          n_state = INIT;
                else                                n_state = IDLE;
            end
            INIT: begin
                if(cnt == tar_cnt)                  n_state = WAIT;
                else                                n_state = INIT;
            end
            WAIT: begin
                if(pass_cnt == i_total_pass)        n_state = DONE;
                else if(cnt == tar_cnt)             n_state = LOAD_DRAM2GLB;
                else                                n_state = WAIT;
            end
            LOAD_DRAM2GLB: begin
                if(cnt == tar_cnt)                  n_state = LOAD_IFMAP;
                else                                n_state = LOAD_DRAM2GLB;
            end
            LOAD_IFMAP: begin
                if(i_inst_ready && !(cnt == 0))     n_state = (iter_cnt == 0) ? LOAD_WGHT : LOAD_PSUM;
                else                                n_state = LOAD_IFMAP;
            end
            LOAD_WGHT: begin
                if(i_inst_ready && !(cnt == 0))     n_state = LOAD_PSUM;
                else                                n_state = LOAD_WGHT;
            end
            LOAD_PSUM: begin
                if(cnt == tar_cnt)                  n_state = CALC;
                else                                n_state = LOAD_PSUM;
            end
            CALC: begin
                if(i_inst_ready && !(cnt == 0))     n_state = ACCRST;
                else                                n_state = CALC;
            end
            ACCRST: begin
                if(i_inst_ready && !(cnt == 0))     n_state = PSUM2GLB;
                else                                n_state = ACCRST;
            end
            PSUM2GLB: begin
                if(cnt == tar_cnt)                  n_state = WAIT;
                else                                n_state = PSUM2GLB;
            end
            DONE: begin
                n_state = IDLE;
            end
            default: n_state = IDLE;
        endcase
    end

    // counter logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            cnt <= 0;
            tar_cnt <= 0;
            iter_cnt <= 0;
            pass_cnt <= 0;
        end else begin
            if(state != n_state) begin
                case(n_state)
                    // Defines how long the system should stay in the current state
                    IDLE            : begin cnt <= 0; tar_cnt <= 0; end
                    INIT            : begin cnt <= 0; tar_cnt <= NUM_ROWS - 1; end
                    WAIT            : begin cnt <= 0; tar_cnt <= 0; end
                    LOAD_DRAM2GLB   : begin cnt <= 0; tar_cnt <= 0; end
                    LOAD_IFMAP      : begin cnt <= 0; tar_cnt <= 11'b11111111111; end
                    LOAD_WGHT       : begin cnt <= 0; tar_cnt <= 11'b11111111111; end
                    LOAD_PSUM       : begin cnt <= 0; tar_cnt <= (1 + i_layer_p * i_layer_EF + 2) - 1; end
                    CALC            : begin cnt <= 0; tar_cnt <= 11'b11111111111; end
                    ACCRST          : begin cnt <= 0; tar_cnt <= 11'b11111111111; end
                    PSUM2GLB        : begin 
                        cnt <= 0; tar_cnt <= i_layer_p - 1;
                        if(iter_cnt == i_layer_EF - 1) begin
                            iter_cnt <= 0;
                            if(pass_cnt == i_total_pass) pass_cnt <= 0;
                            else pass_cnt <= pass_cnt + 1;
                        end
                        else begin
                            iter_cnt <= iter_cnt + 1;
                        end
                    end
                    DONE            : begin cnt <= 0; tar_cnt <= 0; end
                    default         : begin cnt <= 0; tar_cnt <= 0; end
                endcase
            end
            else begin
                cnt <= cnt + 1;
            end
        end
    end

    always @(*) begin

        //INST BRAM interface
        o_inst_bram_ra = {INST_BRAM_ADDR_WIDTH{1'b0}};
        o_inst_bram_wa = {INST_BRAM_ADDR_WIDTH{1'b0}};
        o_inst_bram_wd = {DATA_BITWIDTH{1'b0}};
        o_inst_bram_we = 1'b0;

        //PE array interface
        o_inst_data = CMD_NOP;
        o_conv_info = {4'd0, 3'd0, 4'd0};
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

        o_ctrl_psum_in_sel_LNorGIN = {NUM_ROWS*NUM_COLS{1'b0}};
        o_ctrl_psum_out_sel_GON = {NUM_ROWS*NUM_COLS{1'b0}};
        
        o_ifmap_packet = {(IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH){1'b0}};
        o_wght_packet = {(WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH){1'b0}};
        o_psum_in_packet = {(PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH){1'b0}};
        o_ifmap_valid = 1'b0;
        o_wght_valid = 1'b0;
        o_psum_in_valid = 1'b0;
        o_psum_out_ready = 1'b0;
        
        // GLB addr decoder interface
        glb_data_type = 2'd0 ;
        glb_logical_addr = {clogb2(BANK_NUM*BANK_DEPTH){1'b0}};

        // GLB interface
        o_glb_bank_sel = {clogb2(BANK_NUM-1){1'b0}};
        o_glb_re = {1'b0};
        o_glb_we = {1'b0};
        o_glb_ra = {clogb2(BANK_DEPTH-1){1'b0}};
        o_glb_wa = {clogb2(BANK_DEPTH-1){1'b0}};
        case(state)
            IDLE: begin
            end
            INIT: begin
                o_inst_data = CMD_SET;
                o_conv_info = {i_layer_p, i_layer_q, i_layer_RS};
                o_inst_valid = (cnt == 0);

                o_ifmap_row_id = i_ifmap_row_id;
                o_wght_row_id = i_wght_row_id;
                o_psum_row_id = i_psum_row_id;
                o_ifmap_row_id_valid = (cnt == 0);
                o_wght_row_id_valid = (cnt == 0);
                o_psum_row_id_valid = (cnt == 0);
                o_ifmap_col_id = i_ifmap_col_id[cnt * (NUM_COLS * IFMAP_COL_ID_BITWIDTH) +: (NUM_COLS * IFMAP_COL_ID_BITWIDTH)];
                o_wght_col_id = i_wght_col_id[cnt * (NUM_COLS * WGHT_COL_ID_BITWIDTH) +: (NUM_COLS * WGHT_COL_ID_BITWIDTH)];
                o_psum_col_id = i_psum_col_id[cnt * (NUM_COLS * PSUM_COL_ID_BITWIDTH) +: (NUM_COLS * PSUM_COL_ID_BITWIDTH)];
                o_ifmap_col_id_valid = {1'b1, {(NUM_ROWS - 1){1'b0}}} >> cnt;
                o_wght_col_id_valid = {1'b1, {(NUM_ROWS - 1){1'b0}}} >> cnt;
                o_psum_col_id_valid = {1'b1, {(NUM_ROWS - 1){1'b0}}} >> cnt;
            end
            WAIT: begin
            end
            LOAD_DRAM2GLB: begin
            end
            LOAD_IFMAP: begin
                o_inst_data = CMD_LOAD_IFMAP;
                o_inst_valid = (cnt == 0);

                if(cnt > 2 && cnt <= i_layer_C * i_layer_RS * i_layer_q + 2) begin
                    o_ifmap_valid = 1'b1;
                    o_ifmap_packet = {ifmap_tag, i_glb_rd};
                end
                else begin
                    o_ifmap_valid = 1'b0;
                    o_ifmap_packet = {ifmap_tag, {IFMAP_BUS_BITWIDTH{1'b0}}};
                end

                glb_data_type = 2'd1;
                glb_logical_addr = ifmap_glb_ra;

                o_glb_re = ifmap_glb_re;
                o_glb_ra = glb_physical_addr;
                o_glb_bank_sel = glb_bank_sel;
            end
            LOAD_WGHT: begin
                o_inst_data = CMD_LOAD_WGHT;
                o_inst_valid = (cnt == 0);

                if(cnt > 2 && cnt <= i_layer_RS * i_layer_p * i_layer_q * i_layer_RS + 2) begin
                    o_wght_valid = 1'b1;
                    o_wght_packet = {wght_tag, i_glb_rd};
                end
                else begin
                    o_wght_valid = 1'b0;
                    o_wght_packet = {wght_tag, {WGHT_BUS_BITWIDTH{1'b0}}};
                end
                
                glb_data_type = 2'd3;
                glb_logical_addr = wght_glb_ra;

                o_glb_re = wght_glb_re;
                o_glb_ra = glb_physical_addr;
                o_glb_bank_sel = glb_bank_sel;
            end
            LOAD_PSUM: begin
                if(cnt > 2) begin
                    o_psum_in_valid = 1'b1;
                    o_psum_in_packet = {psum_tag, i_glb_rd};
                end
                else begin
                    o_psum_in_valid = 1'b0;
                    o_psum_in_packet = {psum_tag, {PSUM_BUS_BITWIDTH{1'b0}}};
                end
                
                glb_data_type = 2'd2;
                glb_logical_addr = psum_glb_ra;

                o_glb_re = psum_glb_re;
                o_glb_ra = glb_physical_addr;
                o_glb_bank_sel = glb_bank_sel;
                o_ctrl_psum_in_sel_LNorGIN = ctrl_psum_in_sel_LNorGIN;
            end
            CALC: begin
                o_inst_data = CMD_CONV;
                o_inst_valid = (cnt == 0);
            end
            ACCRST: begin
                o_ctrl_psum_out_sel_GON = ctrl_psum_out_sel_GON;
                o_inst_data = CMD_ACC;
                o_inst_valid = (cnt == 0);
            end
            PSUM2GLB: begin
            end
            DONE: begin
            end
        endcase
    end

    GLB_addr_decoder #(
        .DATA_BITWIDTH (DATA_BITWIDTH),
        .BANK_NUM      (BANK_NUM),
        .BANK_DEPTH    (BANK_DEPTH)
    ) u_glb_addr_decoder (
        .i_GLB_allocation (i_GLB_allocation),
        .i_data_type     (glb_data_type),  // [1:0]
        .i_addr          (glb_logical_addr),  // [clogb2(BANK_NUM*BANK_DEPTH)-1:0]
        .o_glb_bank_sel  (glb_bank_sel),  // [clogb2(BANK_NUM)-1:0]
        .o_glb_addr        (glb_physical_addr)   // [clogb2(BANK_DEPTH)-1:0]
    );

    // ifmap_load_ctrl instance
    ifmap_load_ctrl u_ifmap_load_ctrl (
        .i_clk           (i_clk),
        .i_rst           (i_rst),

        .i_load_start   ((state == LOAD_IFMAP) && (cnt == 0)),

        // Layer & Tiling/Mapping Parameters
        .i_layer_C         (i_layer_C),
        .i_layer_M         (i_layer_M),
        .i_layer_HW        (i_layer_HW),
        .i_layer_U         (i_layer_U),
        .i_layer_RS        (i_layer_RS),
        .i_layer_EF        (i_layer_EF),
        .i_layer_PAD       (i_layer_PAD),
        .i_layer_m         (i_layer_m),
        .i_layer_n         (i_layer_n),
        .i_layer_e         (i_layer_e),
        .i_layer_p         (i_layer_p),
        .i_layer_q         (i_layer_q),
        .i_layer_r         (i_layer_r),
        .i_layer_t         (i_layer_t),

        // Final Outputs to GLB
        .o_ifmap_glb_re    (ifmap_glb_re),
        .o_ifmap_glb_ra    (ifmap_glb_ra),
        .o_ifmap_tag       (ifmap_tag),
        .o_load_done       (ifmap_load_done)
    );

    // Instance of wght_load_ctrl
    wght_load_ctrl u_wght_load_ctrl (
        .i_clk         (i_clk),           // input clock
        .i_rst         (i_rst),           // input reset
        .i_load_start  ((state == LOAD_WGHT) && (cnt == 0)),    // start signal to begin loading

        // Layer & Tiling/Mapping Parameters
        .i_layer_HW      (i_layer_HW),        // ifmap height/width (assumed square)
        .i_layer_RS      (i_layer_RS),        // filter size
        .i_layer_EF      (i_layer_EF),        // output feature map size
        .i_layer_C       (i_layer_C),         // number of input channels
        .i_layer_M       (i_layer_M),         // number of output channels
        .i_layer_U       (i_layer_U),         // stride
        .i_layer_PAD     (i_layer_PAD),       // padding
        .i_layer_m       (i_layer_m),         // tile M
        .i_layer_n       (i_layer_n),         // tile N
        .i_layer_e       (i_layer_e),         // tile E
        .i_layer_p       (i_layer_p),         // tile P
        .i_layer_q       (i_layer_q),         // tile Q
        .i_layer_r       (i_layer_r),         // tile R
        .i_layer_t       (i_layer_t),         // tile T

        // Outputs to GLB
        .o_wght_glb_re   (wght_glb_re),     // weight GLB read enable
        .o_wght_glb_ra   (wght_glb_ra),     // weight GLB read address
        .o_wght_tag      (wght_tag),        // weight tag (used for routing or matching)
        .o_load_done     (wght_load_done)        // indicates all loading is finished
    );

    psum_load_ctrl u_psum_load_ctrl (
        .i_clk           (i_clk),
        .i_rst           (i_rst),

        .i_load_start    ((state == LOAD_PSUM) && (cnt == 0)),

        .i_layer_HW      (i_layer_HW),
        .i_layer_RS      (i_layer_RS),
        .i_layer_EF      (i_layer_EF),
        .i_layer_C       (i_layer_C),
        .i_layer_M       (i_layer_M),
        .i_layer_U       (i_layer_U),
        .i_layer_PAD     (i_layer_PAD),
        .i_layer_m       (i_layer_m),
        .i_layer_n       (i_layer_n),
        .i_layer_e       (i_layer_e),
        .i_layer_p       (i_layer_p),
        .i_layer_q       (i_layer_q),
        .i_layer_r       (i_layer_r),
        .i_layer_t       (i_layer_t),

        .o_psum_glb_re   (psum_glb_re),
        .o_psum_glb_ra   (psum_glb_ra),
        .o_psum_tag      (psum_tag),
        .o_load_done     (psum_load_done)
    );

    psum_selection_decoder #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) u_psum_selection_decoder (
        .i_layer_RS(i_layer_RS),
        .i_psum_row_id(i_psum_row_id),
        .i_psum_col_id(i_psum_col_id),
        .o_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN),
        .o_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON)
    );

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule