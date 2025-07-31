module TOP_ctrl #(
    parameter DATA_BITWIDTH = 32,
    parameter ROW_LEN = 12,
    parameter COL_LEN = 14,
    parameter BANK_NUM = 27,
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

    /*
    // scan chain configuration
    input [24:0] i_GLB_allocation,

    input [7:0] i_HW, //ifmap size
    input [3:0] i_RS, //wght size
    input [5:0] i_EF, //ofmap size
    input [7:0] i_C, //input channel
    input [7:0] i_M, //output channel
    input [1:0] i_U, //stride

    input [6:0] i_m,
    input [2:0] i_n,
    input [4:0] i_e,
    input [3:0] i_p, // 1~16
    input [1:0] i_q, // 1~4
    input i_r,
    input [1:0] i_t,
    */



    // instruction bram interface
    output reg o_inst_bram_ra,
    input [3:0] i_inst_bram_rd,
    output reg o_inst_bram_wa,
    output reg o_inst_bram_wd,
    output reg o_inst_bram_we,

    // PE array interface
    output reg [2:0] o_inst_data,
    output reg [8:0] o_conv_info,
    output reg o_inst_valid,
    input i_inst_ready,

    output reg [IFMAP_ROW_ID_BITWIDTH * COL_LEN-1:0] o_ifmap_row_id,
    output reg [WGHT_ROW_ID_BITWIDTH * COL_LEN-1:0] o_wght_row_id,
    output reg [PSUM_ROW_ID_BITWIDTH * COL_LEN-1:0] o_psum_row_id,
    output reg o_ifmap_row_id_valid,
    output reg o_wght_row_id_valid,
    output reg o_psum_row_id_valid,

    // col ID는 한번에 한 ROW씩 들어오는걸로 가정. valid 신호는 one-hot encoded
    output reg [IFMAP_COL_ID_BITWIDTH * ROW_LEN - 1 :0] o_ifmap_col_id,
    output reg [WGHT_COL_ID_BITWIDTH * ROW_LEN - 1 :0] o_wght_col_id,
    output reg [PSUM_COL_ID_BITWIDTH * ROW_LEN - 1 :0] o_psum_col_id,
    output reg [COL_LEN-1:0] o_ifmap_col_id_valid,
    output reg [COL_LEN-1:0] o_wght_col_id_valid,
    output reg [COL_LEN-1:0] o_psum_col_id_valid,

    // psum_selection ctrl
    output reg [COL_LEN * ROW_LEN - 1:0] o_ctrl_psum_in_sel_LNorGIN,
    output reg [COL_LEN * ROW_LEN - 1:0] o_ctrl_psum_out_sel_GON,

    // label combined with GLB data
    output reg [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH - 1:0] o_ifmap_tag,
    output reg [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH - 1:0] o_wght_tag,
    output reg [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH - 1:0] o_psum_in_tag,

    output reg o_ifmap_valid,
    output reg o_wght_valid,
    output reg o_psum_in_valid,
    output reg o_psum_out_ready,

    input i_ifmap_ready,
    input i_wght_ready,
    input i_psum_in_ready,
    input i_psum_out_valid,

    // GLB interface
	output reg [clogb2(BANK_NUM-1)-1:0] o_glb_bank_sel,
    output reg o_glb_re,
    output reg o_glb_we,
    output reg [clogb2(BANK_DEPTH-1)-1:0] o_glb_ra,
    output reg [clogb2(BANK_DEPTH-1)-1:0] o_glb_wa
);
    // scan chain configuration
    localparam [24:0] i_GLB_allocation = 25'b0000011111111111111111111;
    localparam [7:0] i_HW = 227; //ifmap size
    localparam [3:0] i_RS, //wght size
    localparam [5:0] i_EF, //ofmap size
    localparam [7:0] i_C, //localparam channel
    localparam [7:0] i_M, //output channel
    localparam [1:0] i_U, //stride

    //localparam [6:0] i_m
    //localparam [2:0] i_n
    localparam [4:0] i_e,
    localparam [3:0] i_p, // 1~16
    localparam [1:0] i_q, // 1~4
    localparam i_r,
    localparam [1:0] i_t,

    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam WAIT = 4'd2;
    localparam LOAD_GLB = 4'd3;
    localparam LOAD_IFMAP = 4'd4;
    localparam LOAD_WEIGHT = 4'd5;
    localparam LOAD_PSUM = 4'd6;
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
	localparam CMD_ACC          = 3'b101; // includes LOAD_PSUM from GLB PSUM BANK

    reg [9:0] conv_info_reg;
    wire [3:0] p; 
    wire [1:0] q;
    wire [3:0] s;
    assign {p, q, s} = conv_info_reg;

    reg [9:0] cnt_pass;
    reg [2:0] cnt_n;
    reg [7:0] cnt_q;
    reg [3:0] cnt_h;
    reg [3:0] cnt_w;

    reg [3:0] state;
    reg [3:0] n_state;

    //FSM : state register update
    always @(posedge i_clk) begin
        if(i_rst) begin
            state <= 0;
        end
        else begin
            state <= n_state;
        end
    end

    // counter logic
    always @(posedge i_clk) begin
        if(i_rst) begin
            cnt_pass <= 0;
            cnt_n <= 0;
            cnt_q <= 0;
            cnt_h <= 0;
            cnt_w <= 0;
        end
        else begin
            if(n_state != state) begin
                cnt_pass <= 0; 
                cnt_n <= 0; 
                cnt_q <= 0;
                cnt_h <= 0;
                cnt_w <= 0;
            end
            else if(state == LOAD_IFMAP) begin
                if(cnt_w == s - 1) begin
                    cnt_w <= 0;
                    if(cnt_q == q - 1) begin
                        cnt_q <= 0;
                        if(cnt_h == h - 1) begin
                            cnt_h <= 0;
                            if(cnt_n == n - 1) cnt_n <= 0;
                            else cnt_n <= cnt_n + 1;
                        end
                        else cnt_h <= cnt_h + 1;
                    end
                    else cnt_q <= cnt_q + 1;
                end
                else cnt_w <= cnt_w + 1;

                
            end
        end
    end

    always @(*) begin
        o_inst_bram_ra = {1'b0};
        o_inst_bram_wa = {1'b0};
        o_inst_bram_wd = {1'b0};
        o_inst_bram_we = {1'b0};
        o_inst_data = CMD_NOP;
        o_conv_info = {1'b0};
        o_inst_valid = {1'b0};
        o_ifmap_row_id = {1'b0};
        o_wght_row_id = {1'b0};
        o_psum_row_id = {1'b0};
        o_ifmap_row_id_valid = {1'b0};
        o_wght_row_id_valid = {1'b0};
        o_psum_row_id_valid = {1'b0};
        o_ifmap_col_id = {1'b0};
        o_wght_col_id = {1'b0};
        o_psum_col_id = {1'b0};
        o_ifmap_col_id_valid = {1'b0};
        o_wght_col_id_valid = {1'b0};
        o_psum_col_id_valid = {1'b0};
        o_ctrl_psum_in_sel_LNorGIN = {1'b0};
        o_ctrl_psum_out_sel_GON = {1'b0};
        o_ifmap_tag = {1'b0};
        o_wght_tag = {1'b0};
        o_psum_in_tag = {1'b0};
        o_ifmap_valid = {1'b0};
        o_wght_valid = {1'b0};
        o_psum_in_valid = {1'b0};
        o_psum_out_ready = {1'b0};
        o_glb_bank_sel = {clogb2(BANK_NUM-1){1'b0}};
        o_glb_re = {1'b0};
        o_glb_we = {1'b0};
        o_glb_ra = {1'b0};
        o_glb_wa = {clogb2(BANK_DEPTH-1){1'b0}};
        case(state)
            IDLE:
            INIT: begin
            end
            WAIT:
            LOAD_GLB: begin

            end
            LOAD_IFMAP: begin
                o_inst_data = CMD_LOAD_IFMAP;
                o_inst_valid = 1;
                o_glb_bank_sel = 0;
                o_glb_re = 1;
                o_glb_ra = cnt_h
            end
            LOAD_WEIGHT:
            LOAD_PSUM:
            CALC:
            ACCRST:
            PSUM2GLB:
            DONE:
        endcase
    end

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule