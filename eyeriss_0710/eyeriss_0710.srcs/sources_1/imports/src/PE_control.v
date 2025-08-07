`timescale 1ns / 1ps

module PE_control #(
	parameter DATA_BITWIDTH = 8,
	parameter IFMAP_ADDR_BITWIDTH = 4,
	parameter WGHT_ADDR_BITWIDTH = 8,
	parameter PSUM_ADDR_BITWIDTH = 5
)(
    input i_clk,
    input i_rst,

    //// Interface to TOP CTRL instruction ////  
    input [2:0] i_opcode, //NOP, SET, LOAD_IFMAP, LOAD_WGHT, CONV
    input [10:0] i_conv_info, // TOP CTRL에서 SET opcode와 함께 보내주는 신호. p[3:0], q[2:0], s[3:0]
    input       i_inst_valid, // TOP CTRL에서 opcode와 함께 보내주는 start 신호
    output reg  o_inst_ready, // (state == IDLE)일 때 활성화

    //// Interface to IFMAP FIFO ////
    input i_ifmap_fifo_valid,
    output reg o_ifmap_fifo_ready,

    //// Interface to WGHT FIFO ////
    input i_wght_fifo_valid,
    output reg o_wght_fifo_ready,

    //// Interface to INPUT PSUM FIFO ////
    input i_psum_in_fifo_valid,
    output reg o_psum_in_fifo_ready,

    //// Interface to OUTPUT PSUM FIFO ////
    input i_psum_out_fifo_ready, //from FIFO

    //// Interface to PE_datapath.v ////
	output reg [IFMAP_ADDR_BITWIDTH-1:0] o_ifmap_ra,
	output reg [WGHT_ADDR_BITWIDTH-1:0] o_wght_ra,
	output reg [PSUM_ADDR_BITWIDTH-1:0] o_psum_ra,
	
	output reg [IFMAP_ADDR_BITWIDTH-1:0] o_ifmap_wa,
	output reg [WGHT_ADDR_BITWIDTH-1:0] o_wght_wa,
	output reg [PSUM_ADDR_BITWIDTH-1:0] o_psum_wa,

	output reg o_ifmap_we,
	output reg o_wght_we,
	output reg o_psum_we,

    output reg o_acc_sel,
    output reg o_rst_psum
);

    //ISA
    localparam CMD_NOP          = 3'b000;
    localparam CMD_SET          = 3'b001;
    localparam CMD_LOAD_IFMAP   = 3'b010;
    localparam CMD_LOAD_WGHT    = 3'b011;
    localparam CMD_CONV         = 3'b100;
    localparam CMD_ACC          = 3'b101;

    //States
    localparam  IDLE             = 4'h0;
    localparam  DEC              = 4'h1;
    localparam  NOP              = 4'h2;
    localparam  SET              = 4'h3;    //scan configuration bit and adjust setting
    localparam  LOAD_IFMAP       = 4'h4;
    localparam  LOAD_WGHT        = 4'h5;
    localparam  CONV             = 4'h6;
    localparam  ACCRST           = 4'h7;
    localparam  DONE             = 4'h8;

    reg [10:0] conv_info_reg;
    reg [3:0] state;
    reg [3:0] n_state;

    //counter
    reg [2:0] cnt_minimum_delay;
    reg [3:0] cnt_P;
    reg [2:0] cnt_Q;
    reg [3:0] cnt_S;
    reg [6:0] counter;
    
    wire [3:0] P;
    wire [2:0] Q;
    wire [3:0] S;
    assign {P, Q, S} = conv_info_reg;

    wire inst_hs = i_inst_valid && o_inst_ready;
    wire ifmap_fifo_hs = i_ifmap_fifo_valid && o_ifmap_fifo_ready;
    wire wght_fifo_hs = i_wght_fifo_valid && o_wght_fifo_ready;
    wire psum_in_fifo_hs = i_psum_in_fifo_valid && o_psum_in_fifo_ready;

    //FSM : state register update
    always @(posedge i_clk) begin
        if(i_rst) begin
            state <= 0;
        end
        else begin
            state <= n_state;
        end
    end

    //capture configuration bit
    always @(posedge i_clk) begin
        if(i_rst)
            conv_info_reg <= 0;
        else if(state == SET)
            conv_info_reg <= i_conv_info;
    end

    //capture opcode
    reg [2:0] opcode_reg;
    always@(posedge i_clk) begin 
        if(i_rst)
            opcode_reg <= 0;
        else if(inst_hs)
            opcode_reg <= i_opcode;
        else
            opcode_reg <= opcode_reg;
    end

    //FSM : next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if(inst_hs)
                    n_state = DEC;
                else
                    n_state = IDLE;
            end
            DEC : begin 
                case(opcode_reg) // transition state by captured opcode.
                    CMD_NOP         : n_state = NOP;
                    CMD_SET         : n_state = SET;
                    CMD_LOAD_IFMAP  : n_state = LOAD_IFMAP;
                    CMD_LOAD_WGHT   : n_state = LOAD_WGHT;
                    CMD_CONV        : n_state = CONV;
                    CMD_ACC         : n_state = ACCRST;
                    default         : n_state = DONE;
                endcase
            end
            NOP: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = NOP;
            end
            SET: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = SET;
            end
            LOAD_IFMAP: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = LOAD_IFMAP;
            end
            LOAD_WGHT: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = LOAD_WGHT;
            end
            CONV: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = CONV;
            end
            ACCRST: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = ACCRST;
            end
            DONE: begin
                n_state = IDLE;
            end
            default: begin
                n_state = IDLE;
            end
        endcase
    end
    
    //counter for general purpose
    always @(posedge i_clk) begin
        if (i_rst) begin
            counter <= 0;
        end else begin
            if (counter > 0) begin
                case(state)
                    LOAD_IFMAP      : counter <= (ifmap_fifo_hs) ? counter - 1 : counter;
                    LOAD_WGHT       : counter <= (wght_fifo_hs) ? counter - 1 : counter;
                    ACCRST          : begin
                        if(counter >= P)        counter <= (psum_in_fifo_hs) ? counter - 1 : counter;
                        else if(counter < P)    counter <= counter - 1;
                    end
                    default         : counter <= counter - 1;
                endcase
            end 
            else begin
                case (n_state)
                    // Defines how long the system should stay in the current state
                    IDLE            : counter <= 0;
                    DEC             : counter <= 0;
                    SET             : counter <= 0;
                    NOP             : counter <= 0;
                    LOAD_IFMAP      : counter <= Q * S - 1;
                    LOAD_WGHT       : counter <= P * Q * S - 1;
                    CONV            : counter <= (P < 3) ? (3 * Q * S - 1) : P * Q * S - 1;
                    ACCRST          : counter <= (2*P - 1);
                    DONE            : counter <= 0;
                    default         : counter <= 0;
                endcase
            end
        end
    end

    //counter for convolution
    always @(posedge i_clk) begin
        if(i_rst) begin
            cnt_minimum_delay <= 0;
            cnt_P <= 0; 
            cnt_Q <= 0; 
            cnt_S <= 0;
        end
        else begin
            if(n_state != state) begin
                cnt_P <= 0; 
                cnt_S <= 0; 
                cnt_Q <= 0;
            end
            else if(state == LOAD_IFMAP) begin
                if(ifmap_fifo_hs) begin
                    cnt_S <= (cnt_S == S - 1) ? 0 : cnt_S + 1;
                    cnt_Q <= (cnt_S == S - 1) ? ((cnt_Q == Q - 1) ? 0 : cnt_Q + 1) : cnt_Q;
                end
            end
            else if(state == LOAD_WGHT) begin
                if(wght_fifo_hs) begin
                    cnt_P <= (cnt_P == P - 1) ? 0 : cnt_P + 1;
                    cnt_S <= (cnt_P == P - 1) ? ((cnt_S == S - 1) ? 0 : cnt_S + 1) : cnt_S;
                    cnt_Q <= (cnt_P == P - 1) ? ((cnt_S == S - 1) ? ((cnt_Q == Q - 1) ? 0 : cnt_Q + 1) : cnt_Q) : cnt_Q;
                end
            end
            else if(state == CONV) begin
                if(P < 3) begin // PSUM SPAD에 write한 partial sum을 곧바로 read하는 데 3 cycle이 소요됨. logic 보완 필요
                    cnt_minimum_delay <= (cnt_minimum_delay == 2) ? 0 : cnt_minimum_delay + 1;
                    cnt_P <= (cnt_minimum_delay == 2) ? cnt_P : ((cnt_P == P - 1) ? 0 : cnt_P + 1); 
                    cnt_S <= (cnt_minimum_delay == 2) ? ((cnt_S == S - 1) ? 0 : cnt_S + 1) : cnt_S;
                    cnt_Q <= (cnt_P == P - 1) ? ((cnt_S == S - 1) ? ((cnt_Q == Q - 1) ? 0 : cnt_Q + 1) : cnt_Q) : cnt_Q;
                end
                else begin
                    cnt_P <= (cnt_P == P - 1) ? 0 : cnt_P + 1; 
                    cnt_S <= (cnt_P == P - 1) ? ((cnt_S == S - 1) ? 0 : cnt_S + 1) : cnt_S;
                    cnt_Q <= (cnt_P == P - 1) ? ((cnt_S == S - 1) ? ((cnt_Q == Q - 1) ? 0 : cnt_Q + 1) : cnt_Q) : cnt_Q;
                end
            end
            else if(state == ACCRST) begin
                if(counter >= P) begin
                    if(psum_in_fifo_hs) cnt_P <= (cnt_P == P - 1) ? 0 : cnt_P + 1; 
                end
                else begin
                    cnt_P <= (cnt_P == P - 1) ? 0 : cnt_P + 1;
                end
            end
            else begin
                cnt_P <= 0; 
                cnt_S <= 0; 
                cnt_Q <= 0;
            end
        end
    end

    always @(*) begin
        case(state)
            IDLE: begin
                o_inst_ready = 1;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_wght_wa = 0;
                o_psum_wa = 0;
                o_ifmap_we = 0;
                o_wght_we = 0;
                o_psum_we = 0;
                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            DEC: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_wght_wa = 0;
                o_psum_wa = 0;
                o_ifmap_we = 0;
                o_wght_we = 0;
                o_psum_we = 0;
                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            NOP: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_wght_wa = 0;
                o_psum_wa = 0;
                o_ifmap_we = 0;
                o_wght_we = 0;
                o_psum_we = 0;
                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            LOAD_IFMAP: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 1;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = cnt_S + (S * cnt_Q);
                o_ifmap_we = 1;

                o_wght_wa = 0;
                o_wght_we = 0;

                o_psum_wa = 0;
                o_psum_we = 0;

                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            LOAD_WGHT: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 1;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_ifmap_we = 0;

                o_wght_wa = (cnt_P * Q * S) + (cnt_Q * S) + cnt_S;
                o_wght_we = i_wght_fifo_valid;

                o_psum_wa = 0;
                o_psum_we = 0;

                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            CONV: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = 0;

                o_ifmap_ra = cnt_S + (S * cnt_Q);
                o_wght_ra = (cnt_P * Q * S) + (cnt_Q * S) + cnt_S;
                o_psum_ra = cnt_P;
            
                o_ifmap_wa = 0;
                o_ifmap_we = 0;

                o_wght_wa = 0;
                o_wght_we = 0;

                o_psum_wa = cnt_P;
                o_psum_we = 1; // logic 보완 필요

                o_acc_sel = 0;
                o_rst_psum = 0;
            end
            ACCRST: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;
                o_psum_in_fifo_ready = (counter >= P);

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = cnt_P;
            
                o_ifmap_wa = 0;
                o_ifmap_we = 0;

                o_wght_wa = 0;
                o_wght_we = 0;

                o_psum_wa = cnt_P;
                o_psum_we = (counter < P);

                o_acc_sel = psum_in_fifo_hs;
                o_rst_psum = (counter < P);
            end
            DONE: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_ifmap_we = 0;

                o_wght_wa = 0;
                o_wght_we = 0;

                o_psum_wa = 0;
                o_psum_we = 0;

                o_acc_sel = 0;
                o_rst_psum = 0;

                o_psum_in_fifo_ready = 0;
            end
            default: begin
                o_inst_ready = 0;
                o_ifmap_fifo_ready = 0;
                o_wght_fifo_ready = 0;

                o_ifmap_ra = 0;
                o_wght_ra = 0;
                o_psum_ra = 0;
            
                o_ifmap_wa = 0;
                o_ifmap_we = 0;

                o_wght_wa = 0;
                o_wght_we = 0;

                o_psum_wa = 0;
                o_psum_we = 0;

                o_acc_sel = 0;
                o_rst_psum = 0;

                o_psum_in_fifo_ready = 0;
            end
        endcase
    end
endmodule