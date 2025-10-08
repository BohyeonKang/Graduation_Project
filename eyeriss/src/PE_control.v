`timescale 1ns / 1ps

module PE_control #(
	parameter IFMAP_SPAD_AWIDTH = 4,
	parameter WGHT_SPAD_AWIDTH = 8,
	parameter PSUM_SPAD_AWIDTH = 5
)(
    input i_clk,
    input i_rst,

    //// Interface to TOP CTRL ////  
    input [4:0] i_layer_p,
    input [2:0] i_layer_q,
    input [3:0] i_layer_s,
    input [2:0] i_opcode, // SET, LOAD_IFMAP, LOAD_WGHT, CONV, ACC
    input       i_opcode_valid, // TOP CTRL에서 opcode와 함께 보내주는 start 신호
    output reg  o_opcode_ready, // (state == IDLE)일 때 활성화

    //// Interface to FIFO ////
    input       i_ifmap_fifo_valid,
    input       i_wght_fifo_valid,
    input       i_psum_in_fifo_valid,
    input       i_psum_out_fifo_ready,
    output reg  o_ifmap_fifo_ready,
    output reg  o_wght_fifo_ready,
    output reg  o_psum_in_fifo_ready,
    output      o_psum_out_fifo_valid,

    //// Interface to PE_datapath.v ////
    input i_psum_out_valid,

	output reg [IFMAP_SPAD_AWIDTH-1:0]    o_ifmap_spad_addr,
	output reg [WGHT_SPAD_AWIDTH-1:0]     o_wght_spad_addr,
	output reg [PSUM_SPAD_AWIDTH-1:0]     o_psum_spad_addr,

	output reg o_ifmap_spad_we,
	output reg o_wght_spad_we,
	output reg o_psum_spad_we,

    output reg o_acc_sel,
    output reg o_rst_psum
);

    //ISA
    localparam CMD_SET          = 3'b000;
    localparam CMD_LOAD_IFMAP   = 3'b001;
    localparam CMD_LOAD_WGHT    = 3'b010;
    localparam CMD_CONV         = 3'b011;
    localparam CMD_ACC          = 3'b100;

    //States
    localparam IDLE             = 4'h0;
    localparam DEC              = 4'h1;
    localparam SET              = 4'h2;    //scan configuration bit and adjust setting
    localparam LOAD_IFMAP       = 4'h3;
    localparam LOAD_WGHT        = 4'h4;
    localparam CONV             = 4'h5;
    localparam ACC              = 4'h6;
    localparam RSTPSUM          = 4'h7;
    localparam DONE            = 4'h8;

    reg [3:0] state;
    reg [3:0] n_state;

    reg [4:0] r_layer_p;
    reg [2:0] r_layer_q;
    reg [3:0] r_layer_s;
    reg [2:0] r_opcode;

    //counter
    reg [4:0] cnt_p;
    reg [2:0] cnt_q;
    reg [3:0] cnt_s;
    reg [7:0] counter;

    reg psum_in_fifo_ready;
    reg psum_in_fifo_ready_d1;
    reg psum_in_fifo_ready_d2;

    reg psum_in_fifo_hs_d1;
    reg psum_in_fifo_hs_d2;

    wire opcode_hs = i_opcode_valid && o_opcode_ready;
    wire ifmap_fifo_hs = i_ifmap_fifo_valid && o_ifmap_fifo_ready;
    wire wght_fifo_hs = i_wght_fifo_valid && o_wght_fifo_ready;
    wire psum_in_fifo_hs = i_psum_in_fifo_valid && o_psum_in_fifo_ready;


    // capture opcode if opcode_hs
    always@(posedge i_clk) begin 
        if(i_rst)
            r_opcode <= 0;
        else if(opcode_hs)
            r_opcode <= i_opcode;
        else
            r_opcode <= r_opcode;
    end

    //capture configuration bit if state == SET
    always @(posedge i_clk) begin
        if(i_rst) begin
            r_layer_p <= 0;
            r_layer_q <= 0;
            r_layer_s <= 0;
        end 
        else if(state == SET) begin
            r_layer_p <= i_layer_p;
            r_layer_q <= i_layer_q;
            r_layer_s <= i_layer_s;
        end
    end

    always @(posedge i_clk) begin
        if(i_rst) begin
            psum_in_fifo_ready_d1 <= 0;
            psum_in_fifo_ready_d2 <= 0;
            psum_in_fifo_hs_d1 <= 0;
            psum_in_fifo_hs_d2 <= 0;
        end
        else begin
            psum_in_fifo_ready_d1 <= psum_in_fifo_ready;
            psum_in_fifo_ready_d2 <= psum_in_fifo_ready_d1;
            psum_in_fifo_hs_d1 <= psum_in_fifo_hs;
            psum_in_fifo_hs_d2 <= psum_in_fifo_hs_d1;
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

    //FSM : next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if(opcode_hs)
                    n_state = DEC;
                else
                    n_state = IDLE;
            end
            DEC : begin 
                case(r_opcode)
                    CMD_SET         : n_state = SET;
                    CMD_LOAD_IFMAP  : n_state = LOAD_IFMAP;
                    CMD_LOAD_WGHT   : n_state = LOAD_WGHT;
                    CMD_CONV        : n_state = CONV;
                    CMD_ACC         : n_state = ACC;
                    default         : n_state = DONE;
                endcase
            end
            SET: begin
                n_state = DONE;
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
            ACC: begin
                if(counter == 0)
                    n_state = RSTPSUM;
                else
                    n_state = ACC;
            end
            RSTPSUM: begin
                if(counter == 0)
                    n_state = DONE;
                else
                    n_state = RSTPSUM;
            end
            DONE: begin
                n_state = IDLE;
            end
            default: begin
                n_state = IDLE;
            end
        endcase
    end
    
    //counter for state duration
    always @(posedge i_clk) begin
        if (i_rst) begin
            counter <= 0;
        end else begin
            if (counter > 0) begin
                case(state)
                    LOAD_IFMAP      : counter <= (ifmap_fifo_hs) ? counter - 1 : counter;
                    LOAD_WGHT       : counter <= (wght_fifo_hs) ? counter - 1 : counter;
                    ACC             : counter <= (psum_in_fifo_hs) ? counter - 1 : counter;
                    default         : counter <= counter - 1;
                endcase
            end 
            else begin
                case (n_state)
                    // Defines how long the system should stay in the current state
                    IDLE            : counter <= 0;
                    DEC             : counter <= 0;
                    SET             : counter <= 0;
                    LOAD_IFMAP      : counter <= r_layer_q * r_layer_s - 1;
                    LOAD_WGHT       : counter <= r_layer_p * r_layer_q * r_layer_s - 1;
                    CONV            : counter <= (r_layer_p < 3) ? (3 * r_layer_q * r_layer_s - 1) : r_layer_p * r_layer_q * r_layer_s - 1;
                    ACC             : counter <= r_layer_p - 1;
                    RSTPSUM         : counter <= r_layer_p - 1;
                    DONE            : counter <= 0;
                    default         : counter <= 0;
                endcase
            end
        end
    end

    //counter for convolution
    always @(posedge i_clk) begin
        if(i_rst) begin
            cnt_p <= 0; 
            cnt_q <= 0; 
            cnt_s <= 0;
        end
        else begin
            if(n_state != state) begin
                cnt_p <= 0; 
                cnt_s <= 0; 
                cnt_q <= 0;
            end
            else if(state == LOAD_IFMAP) begin
                if(ifmap_fifo_hs) begin
                    cnt_s <= (cnt_s == r_layer_s - 1) ? 0 : cnt_s + 1;
                    cnt_q <= (cnt_s == r_layer_s - 1) ? ((cnt_q == r_layer_q - 1) ? 0 : cnt_q + 1) : cnt_q;
                end
            end
            else if(state == LOAD_WGHT) begin
                if(wght_fifo_hs) begin
                    cnt_p <= (cnt_p == r_layer_p - 1) ? 0 : cnt_p + 1;
                    cnt_s <= (cnt_p == r_layer_p - 1) ? ((cnt_s == r_layer_s - 1) ? 0 : cnt_s + 1) : cnt_s;
                    cnt_q <= (cnt_p == r_layer_p - 1) ? ((cnt_s == r_layer_s - 1) ? ((cnt_q == r_layer_q - 1) ? 0 : cnt_q + 1) : cnt_q) : cnt_q;
                end
            end
            else if(state == CONV) begin
                if(r_layer_p < 3) begin // PSUM SPAD에 write한 partial sum을 곧바로 read하는 데 3 cycle 소요
                    cnt_p <= (cnt_p == 2) ? 0 : cnt_p + 1; 
                    cnt_s <= (cnt_p == 2) ? ((cnt_s == r_layer_s - 1) ? 0 : cnt_s + 1) : cnt_s;
                    cnt_q <= (cnt_p == 2) ? ((cnt_s == r_layer_s - 1) ? ((cnt_q == r_layer_q - 1) ? 0 : cnt_q + 1) : cnt_q) : cnt_q;
                end
                else begin
                    cnt_p <= (cnt_p == r_layer_p - 1) ? 0 : cnt_p + 1; 
                    cnt_s <= (cnt_p == r_layer_p - 1) ? ((cnt_s == r_layer_s - 1) ? 0 : cnt_s + 1) : cnt_s;
                    cnt_q <= (cnt_p == r_layer_p - 1) ? ((cnt_s == r_layer_s - 1) ? ((cnt_q == r_layer_q - 1) ? 0 : cnt_q + 1) : cnt_q) : cnt_q;
                end
            end
            else if(state == ACC) begin
                if(psum_in_fifo_hs)
                    cnt_p <= (cnt_p == r_layer_p - 1) ? 0 : cnt_p + 1; 
            end

            else if(state == RSTPSUM) begin
                if(cnt_p == r_layer_p - 1)
                    cnt_p <= 0; 
                else begin
                    cnt_p <= cnt_p + 1;
                end
            end
            else begin
                cnt_p <= 0; 
                cnt_s <= 0; 
                cnt_q <= 0;
            end
        end
    end

    always @(*) begin
        psum_in_fifo_ready = 0;
        o_opcode_ready = 0;
        o_ifmap_fifo_ready = 0;
        o_wght_fifo_ready = 0;
        o_psum_in_fifo_ready = 0;
        o_ifmap_spad_addr = 0;
        o_wght_spad_addr = 0;
        o_psum_spad_addr = 0;
        o_ifmap_spad_we = 0;
        o_wght_spad_we = 0;
        o_psum_spad_we = 0;
        o_acc_sel = 0;
        o_rst_psum = 0;
        case(state)
            IDLE: begin
                o_opcode_ready = 1;
            end
            DEC: begin
            end
            LOAD_IFMAP: begin
                o_ifmap_fifo_ready = 1;
                o_ifmap_spad_addr = cnt_s + (r_layer_s * cnt_q);
                o_ifmap_spad_we = i_ifmap_fifo_valid;
            end
            LOAD_WGHT: begin
                o_wght_fifo_ready = 1;
                o_wght_spad_addr = (cnt_p * r_layer_q * r_layer_s) + (cnt_q * r_layer_s) + cnt_s;
                o_wght_spad_we = i_wght_fifo_valid;
            end
            CONV: begin
                o_ifmap_spad_addr = cnt_s + (r_layer_s * cnt_q);
                o_wght_spad_addr = (cnt_p * r_layer_q * r_layer_s) + (cnt_q * r_layer_s) + cnt_s;
                o_psum_spad_addr = cnt_p;
                if(r_layer_p == 1)
                    o_psum_spad_we = (cnt_p % 3 == 0) ? 1'b1 : 1'b0; // activated every 3 cycles
                else if(r_layer_p == 2)
                    o_psum_spad_we = (cnt_p % 3 == 2) ? 1'b0 : 1'b1; // deactivated every 3 cycles
                else
                    o_psum_spad_we = 1'b1;
            end
            ACC: begin
                psum_in_fifo_ready = 1'b1;
                o_psum_in_fifo_ready = 1'b1;
                o_psum_spad_addr = cnt_p;
                o_acc_sel = psum_in_fifo_hs;
            end
            RSTPSUM: begin
                o_psum_spad_addr = cnt_p;
                o_psum_spad_we = 1'b1;
                o_rst_psum = 1'b1;
            end
            DONE: begin
            end
        endcase
    end

    assign o_psum_out_fifo_valid = i_psum_out_valid;

endmodule