module TOP_ctrl #(
    parameter INST_BRAM_DEPTH = 64,
    parameter INST_BRAM_ADDR_WIDTH = clogb2(INST_BRAM_DEPTH),
    parameter DATA_BITWIDTH = 32,
    parameter ROW_LEN = 3,
    parameter COL_LEN = 3,
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

    input [0:BANK_NUM-1] i_GLB_allocation,

    //// Layer & Tiling/Mapping Parameters from scan_chain_decoder.v
    input [9:0] layer_C,
    input [7:0] layer_HW,
    input [1:0] layer_U,
    input [3:0] layer_RS,
    input [6:0] layer_EF,
    input [1:0] layer_PAD,
    input [3:0] layer_m,
    input [4:0] layer_e,
    input [3:0] layer_p,
    input [1:0] layer_q,
    input       layer_r,
    input       layer_t,

    // instruction bram interface
    output reg  [INST_BRAM_ADDR_WIDTH-1:0]   o_inst_bram_ra,
    input       [DATA_BITWIDTH-1:0]             i_inst_bram_rd,
    output reg  [INST_BRAM_ADDR_WIDTH-1:0]   o_inst_bram_wa,
    output reg  [DATA_BITWIDTH-1:0]             o_inst_bram_wd,
    output reg                                  o_inst_bram_we,

    // PE array interface
    output reg [2:0] o_inst_data,
    output reg [8:0] o_conv_info,
    output reg o_inst_valid,
    input i_inst_ready,

    output reg [0:IFMAP_ROW_ID_BITWIDTH * COL_LEN-1] o_ifmap_row_id,
    output reg [0:WGHT_ROW_ID_BITWIDTH * COL_LEN-1] o_wght_row_id,
    output reg [0:PSUM_ROW_ID_BITWIDTH * COL_LEN-1] o_psum_row_id,
    output reg o_ifmap_row_id_valid,
    output reg o_wght_row_id_valid,
    output reg o_psum_row_id_valid,

    // col ID는 한번에 한 ROW씩 들어오는걸로 가정. valid 신호는 one-hot encoded
    output reg [0:IFMAP_COL_ID_BITWIDTH*ROW_LEN-1] o_ifmap_col_id,
    output reg [0:WGHT_COL_ID_BITWIDTH*ROW_LEN-1] o_wght_col_id,
    output reg [0:PSUM_COL_ID_BITWIDTH*ROW_LEN-1] o_psum_col_id,
    output reg [0:COL_LEN-1] o_ifmap_col_id_valid,
    output reg [0:COL_LEN-1] o_wght_col_id_valid,
    output reg [0:COL_LEN-1] o_psum_col_id_valid,

    // psum_selection ctrl
    output reg [0:COL_LEN*ROW_LEN-1] o_ctrl_psum_in_sel_LNorGIN,
    output reg [0:COL_LEN*ROW_LEN-1] o_ctrl_psum_out_sel_GON,

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

    localparam IDLE = 4'd0;
    localparam INIT = 4'd1; // layer configuration
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
	localparam CMD_ACC          = 3'b101; // includes LOAD_PSUM from GLB PSUM BANK

    reg [10:0] counter;

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

    //FSM: next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if(i_inst_bram_rd == 1'b1)  n_state = INIT;
                else                        n_state = IDLE;
            end
            INIT: begin
                if(counter == 0)            n_state = WAIT;
                else                        n_state = INIT;
            end
            WAIT: begin
                if(cnt_pass == 8)           n_state = DONE;
                else if(counter == 0)       n_state = LOAD_DRAM2GLB;
            end
            LOAD_DRAM2GLB: begin
                if(counter == 0)            n_state = LOAD_IFMAP;
                else                        n_state = LOAD_DRAM2GLB;
            end
            LOAD_IFMAP: begin
                if(counter == 0)            n_state = LOAD_WGHT;
                else                        n_state = LOAD_IFMAP;
            end
            LOAD_WGHT: begin
                if(counter == 0)            n_state = CALC;
                else                        n_state = LOAD_WGHT;
            end
            CALC: begin
                if(counter == 0)            n_state = ACCRST;
                else                        n_state = CALC;
            end
            ACCRST: begin
                if(counter == 0)            n_state = PSUM2GLB;
                else                        n_state = ACCRST;
            end
            PSUM2GLB: begin
                if(counter == 0)            n_state = WAIT;
                else                        n_state = PSUM2GLB;
            end
            DONE: begin
                n_state = IDLE;
            end
            default: n_state = IDLE;
        endcase
    end

    //counter for general purpose
    always @(posedge i_clk) begin
        if (i_rst) begin
            counter <= 0;
        end else begin
            case (n_state)
                // Defines how long the system should stay in the current state
                IDLE            : counter <= 0;
                INIT            : counter <= 0;
                WAIT            : counter <= 0;
                LOAD_DRAM2GLB   : counter <= 0;
                LOAD_IFMAP      : counter <= layer_HW * layer_q * layer_RS - 1;
                LOAD_WGHT       : counter <= layer_RS * (layer_p * layer_q * layer_RS) - 1;
                LOAD_PSUM       : counter <= layer_t * layer_p - 1;
                CALC            : counter <= (layer_p < 3) ? (3 * layer_q * layer_RS - 1) : layer_p * layer_q * layer_RS - 1;
                ACCRST          : counter <= 2 * layer_p - 1;
                PSUM2GLB        : counter <= layer_p - 1;
                DONE            : counter <= 0;
                default         : counter <= 0;
            endcase
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
        o_conv_info = {4'd0, 2'd0, 4'd0};
        o_inst_valid = 1'b0;

        o_ifmap_row_id = {IFMAP_ROW_ID_BITWIDTH * COL_LEN{1'b0}};
        o_wght_row_id = {WGHT_ROW_ID_BITWIDTH * COL_LEN{1'b0}};
        o_psum_row_id = {PSUM_ROW_ID_BITWIDTH * COL_LEN{1'b0}};
        o_ifmap_row_id_valid = 1'b0;
        o_wght_row_id_valid = 1'b0;
        o_psum_row_id_valid = 1'b0;
        o_ifmap_col_id = {IFMAP_COL_ID_BITWIDTH*ROW_LEN{1'b0}};
        o_wght_col_id = {WGHT_COL_ID_BITWIDTH*ROW_LEN{1'b0}};
        o_psum_col_id = {PSUM_COL_ID_BITWIDTH*ROW_LEN{1'b0}};
        o_ifmap_col_id_valid = {COL_LEN{1'b0}};
        o_wght_col_id_valid = {COL_LEN{1'b0}};
        o_psum_col_id_valid = {COL_LEN{1'b0}};

        o_ctrl_psum_in_sel_LNorGIN = {COL_LEN*ROW_LEN{1'b0}};
        o_ctrl_psum_out_sel_GON = {COL_LEN*ROW_LEN{1'b0}};
        
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
            IDLE: begin
            end
            INIT: begin

            end
            WAIT: begin
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
            end
            LOAD_DRAM2GLB: begin
            end
            LOAD_IFMAP: begin
            end
            LOAD_WGHT: begin
            end
            LOAD_PSUM: begin
            end
            CALC: begin
            end
            ACCRST: begin
            end
            PSUM2GLB: begin
            end
            DONE: begin
            end
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