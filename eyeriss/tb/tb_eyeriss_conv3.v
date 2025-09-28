
`timescale 1ns / 1ps

module tb_eyeriss_conv3();

    parameter BANK_NUM = 3;
    parameter BANK_DEPTH = 8192;
    parameter DATA_BITWIDTH = 32;
    parameter NUM_ROWS = 3;
    parameter NUM_COLS = 13;
    parameter IFMAP_ROW_ID_BITWIDTH = 4;
    parameter WGHT_ROW_ID_BITWIDTH = 4;
    parameter PSUM_ROW_ID_BITWIDTH = 4;
    parameter IFMAP_COL_ID_BITWIDTH = 5;
    parameter WGHT_COL_ID_BITWIDTH = 4;
    parameter PSUM_COL_ID_BITWIDTH = 4;
    parameter IFMAP_BUS_BITWIDTH = 32;
    parameter WGHT_BUS_BITWIDTH = 32;
    parameter PSUM_BUS_BITWIDTH = 32;

    reg i_clk;
    reg i_rst;

    reg i_ap_start;
    wire o_ap_done;

    // Global buffer
    reg [DATA_BITWIDTH-1:0] psum_answer [0:BANK_DEPTH-1];

    //// hypothetical signals from scan chain configuration ////
    reg [0:3*clogb2(BANK_NUM)-1] i_GLB_allocation;
    reg [3:0] i_total_pass;
    reg [7:0] i_layer_HW;
    reg [1:0] i_layer_U;
    reg [1:0] i_layer_PAD;
    
    reg [6:0] i_layer_m;
    reg [2:0] i_layer_n;
    reg [4:0] i_layer_e;
    reg [4:0] i_layer_p;
    reg [2:0] i_layer_q;
    reg [2:0] i_layer_r;
    reg [3:0] i_layer_s;
    reg [2:0] i_layer_t;
    reg [0:NUM_ROWS * IFMAP_ROW_ID_BITWIDTH-1] i_ifmap_row_id;
    reg [0:NUM_ROWS * WGHT_ROW_ID_BITWIDTH-1] i_wght_row_id;
    reg [0:NUM_ROWS * PSUM_ROW_ID_BITWIDTH-1] i_psum_row_id;
    reg [0:NUM_ROWS * NUM_COLS * IFMAP_COL_ID_BITWIDTH-1] i_ifmap_col_id;
    reg [0:NUM_ROWS * NUM_COLS * WGHT_COL_ID_BITWIDTH-1] i_wght_col_id;
    reg [0:NUM_ROWS * NUM_COLS * PSUM_COL_ID_BITWIDTH-1] i_psum_col_id;

    //// Interconnects ////

    // TOP_ctrl → PE_array
    wire [2:0] inst_data_ctrl2arr;
    wire       inst_valid_ctrl2arr;

    wire [0:IFMAP_ROW_ID_BITWIDTH * NUM_ROWS-1] ifmap_row_id_ctrl2arr;
    wire [0:WGHT_ROW_ID_BITWIDTH * NUM_ROWS-1]  wght_row_id_ctrl2arr;
    wire [0:PSUM_ROW_ID_BITWIDTH * NUM_ROWS-1]  psum_row_id_ctrl2arr;

    wire ifmap_row_id_valid_ctrl2arr;
    wire wght_row_id_valid_ctrl2arr;
    wire psum_row_id_valid_ctrl2arr;

    wire [0:IFMAP_COL_ID_BITWIDTH * NUM_COLS-1] ifmap_col_id_ctrl2arr;
    wire [0:WGHT_COL_ID_BITWIDTH * NUM_COLS-1]  wght_col_id_ctrl2arr;
    wire [0:PSUM_COL_ID_BITWIDTH * NUM_COLS-1]  psum_col_id_ctrl2arr;

    wire [0:NUM_ROWS-1] ifmap_col_id_valid_ctrl2arr;
    wire [0:NUM_ROWS-1] wght_col_id_valid_ctrl2arr;
    wire [0:NUM_ROWS-1] psum_col_id_valid_ctrl2arr;

    wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_in_sel_LNorGIN_ctrl2arr;
    wire [0:NUM_ROWS*NUM_COLS-1] ctrl_psum_out_sel_GON_ctrl2arr;

    wire [IFMAP_ROW_ID_BITWIDTH + IFMAP_COL_ID_BITWIDTH + IFMAP_BUS_BITWIDTH - 1:0] ifmap_packet_ctrl2arr;
    wire [WGHT_ROW_ID_BITWIDTH + WGHT_COL_ID_BITWIDTH + WGHT_BUS_BITWIDTH - 1:0] wght_packet_ctrl2arr;
    wire [PSUM_ROW_ID_BITWIDTH + PSUM_COL_ID_BITWIDTH + PSUM_BUS_BITWIDTH - 1:0] psum_in_packet_ctrl2arr;

    wire ifmap_valid_ctrl2arr;
    wire wght_valid_ctrl2arr;
    wire psum_in_valid_ctrl2arr;
    wire psum_out_ready_ctrl2arr;

    // PE_array → TOP_ctrl
    wire inst_ready_arr2ctrl;
    wire ifmap_ready_arr2ctrl;
    wire wght_ready_arr2ctrl;
    wire psum_in_ready_arr2ctrl;
    wire psum_out_valid_arr2ctrl;

    // GLB → TOP_ctrl
    wire [DATA_BITWIDTH-1:0] glb_rd_glb2ctrl;

    // TOP_ctrl → GLB
    wire [clogb2(BANK_NUM-1)-1:0] glb_bank_sel_ctrl2glb;
    wire glb_re_ctrl2glb;
    wire glb_we_ctrl2glb;
    wire [clogb2(BANK_DEPTH-1)-1:0] glb_ra_ctrl2glb;
    wire [clogb2(BANK_DEPTH-1)-1:0] glb_wa_ctrl2glb;

    // PE_array → GLB
    wire [DATA_BITWIDTH-1:0] psum_out_data_arr2glb;

    // for file writing and comparison
    integer fd, i;
    integer base_addr, num_elem, mismatch;

    GLB #(
        .DATA_BITWIDTH (DATA_BITWIDTH),
        .BANK_NUM      (BANK_NUM),
        .BANK_DEPTH    (BANK_DEPTH)
    ) u_GLB (
        .i_clk      (i_clk),  // clock
        .i_rst      (i_rst),  // reset
        .i_bank_sel (glb_bank_sel_ctrl2glb),  // [clogb2(BANK_NUM-1)-1:0]
        .i_re       (glb_re_ctrl2glb),  // read enable
        .i_we       (glb_we_ctrl2glb),  // write enable
        .i_ra       (glb_ra_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] read addr
        .i_wa       (glb_wa_ctrl2glb),  // [clogb2(BANK_DEPTH-1)-1:0] write addr
        .i_wd       (psum_out_data_arr2glb),  // [DATA_BITWIDTH-1:0] write data
        .o_rd       (glb_rd_glb2ctrl)   // [DATA_BITWIDTH-1:0] read data
    );

    TOP_ctrl #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .BANK_NUM(BANK_NUM),
        .BANK_DEPTH(BANK_DEPTH),
        .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
        .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
        .IFMAP_BUS_BITWIDTH(IFMAP_BUS_BITWIDTH),
        .WGHT_BUS_BITWIDTH(WGHT_BUS_BITWIDTH),
        .PSUM_BUS_BITWIDTH(PSUM_BUS_BITWIDTH)
    ) u_top_ctrl (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_ap_start(i_ap_start),
        .o_ap_done(o_ap_done),
        .i_GLB_allocation(i_GLB_allocation),
        .i_total_pass(i_total_pass),
        .i_layer_HW(i_layer_HW),
        .i_layer_U(i_layer_U),
        .i_layer_PAD(i_layer_PAD),
        .i_layer_n(i_layer_n),
        .i_layer_m(i_layer_m),
        .i_layer_e(i_layer_e),
        .i_layer_p(i_layer_p),
        .i_layer_q(i_layer_q),
        .i_layer_r(i_layer_r),
        .i_layer_s(i_layer_s),
        .i_layer_t(i_layer_t),
        .i_ifmap_row_id(i_ifmap_row_id),
        .i_wght_row_id(i_wght_row_id),
        .i_psum_row_id(i_psum_row_id),
        .i_ifmap_col_id(i_ifmap_col_id),
        .i_wght_col_id(i_wght_col_id),
        .i_psum_col_id(i_psum_col_id),
        .o_inst_data(inst_data_ctrl2arr),
        .o_inst_valid(inst_valid_ctrl2arr),
        .i_inst_ready(inst_ready_arr2ctrl),
        .o_ifmap_row_id(ifmap_row_id_ctrl2arr),
        .o_wght_row_id(wght_row_id_ctrl2arr),
        .o_psum_row_id(psum_row_id_ctrl2arr),
        .o_ifmap_row_id_valid(ifmap_row_id_valid_ctrl2arr),
        .o_wght_row_id_valid(wght_row_id_valid_ctrl2arr),
        .o_psum_row_id_valid(psum_row_id_valid_ctrl2arr),
        .o_ifmap_col_id(ifmap_col_id_ctrl2arr),
        .o_wght_col_id(wght_col_id_ctrl2arr),
        .o_psum_col_id(psum_col_id_ctrl2arr),
        .o_ifmap_col_id_valid(ifmap_col_id_valid_ctrl2arr),
        .o_wght_col_id_valid(wght_col_id_valid_ctrl2arr),
        .o_psum_col_id_valid(psum_col_id_valid_ctrl2arr),
        .o_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN_ctrl2arr),
        .o_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON_ctrl2arr),
        .o_ifmap_packet(ifmap_packet_ctrl2arr),
        .o_wght_packet(wght_packet_ctrl2arr),
        .o_psum_in_packet(psum_in_packet_ctrl2arr),
        .o_ifmap_valid(ifmap_valid_ctrl2arr),
        .o_wght_valid(wght_valid_ctrl2arr),
        .o_psum_in_valid(psum_in_valid_ctrl2arr),
        .o_psum_out_ready(psum_out_ready_ctrl2arr),
        .i_ifmap_ready(ifmap_ready_arr2ctrl),
        .i_wght_ready(wght_ready_arr2ctrl),
        .i_psum_in_ready(psum_in_ready_arr2ctrl),
        .i_psum_out_valid(psum_out_valid_arr2ctrl),
        .i_glb_rd(glb_rd_glb2ctrl),
        .o_glb_bank_sel(glb_bank_sel_ctrl2glb),
        .o_glb_re(glb_re_ctrl2glb),
        .o_glb_we(glb_we_ctrl2glb),
        .o_glb_ra(glb_ra_ctrl2glb),
        .o_glb_wa(glb_wa_ctrl2glb)
    );

    PE_array #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .DATA_BITWIDTH(DATA_BITWIDTH),

        .IFMAP_BUS_BITWIDTH(IFMAP_BUS_BITWIDTH),
        .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),

        .WGHT_BUS_BITWIDTH(WGHT_BUS_BITWIDTH),
        .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),

        .PSUM_BUS_BITWIDTH(PSUM_BUS_BITWIDTH),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH)
    ) u_PE_array (
        .i_clk(i_clk),
        .i_rst(i_rst),

        // TOP CTRL interface
        .i_inst_data(inst_data_ctrl2arr),
        .i_inst_valid(inst_valid_ctrl2arr),
        .o_inst_ready(inst_ready_arr2ctrl),
        .i_layer_p(i_layer_p),
        .i_layer_q(i_layer_q),
        .i_layer_s(i_layer_s),

        .i_ifmap_row_id(ifmap_row_id_ctrl2arr),
        .i_wght_row_id(wght_row_id_ctrl2arr),
        .i_psum_row_id(psum_row_id_ctrl2arr),

        .i_ifmap_row_id_valid(ifmap_row_id_valid_ctrl2arr),
        .i_wght_row_id_valid(wght_row_id_valid_ctrl2arr),
        .i_psum_row_id_valid(psum_row_id_valid_ctrl2arr),

        .i_ifmap_col_id(ifmap_col_id_ctrl2arr),
        .i_wght_col_id(wght_col_id_ctrl2arr),
        .i_psum_col_id(psum_col_id_ctrl2arr),

        .i_ifmap_col_id_valid(ifmap_col_id_valid_ctrl2arr),
        .i_wght_col_id_valid(wght_col_id_valid_ctrl2arr),
        .i_psum_col_id_valid(psum_col_id_valid_ctrl2arr),

        .i_ctrl_psum_in_sel_LNorGIN(ctrl_psum_in_sel_LNorGIN_ctrl2arr),
        .i_ctrl_psum_out_sel_GON(ctrl_psum_out_sel_GON_ctrl2arr),

        // GLB interface
        .i_ifmap_packet(ifmap_packet_ctrl2arr),
        .i_wght_packet(wght_packet_ctrl2arr),
        .i_psum_in_packet(psum_in_packet_ctrl2arr),
        .o_psum_out_data(psum_out_data_arr2glb),

        .i_ifmap_valid(ifmap_valid_ctrl2arr),
        .i_wght_valid(wght_valid_ctrl2arr),
        .i_psum_in_valid(psum_in_valid_ctrl2arr),
        .i_psum_out_ready(psum_out_ready_ctrl2arr),

        .o_ifmap_ready(ifmap_ready_arr2ctrl),
        .o_wght_ready(wght_ready_arr2ctrl),
        .o_psum_in_ready(psum_in_ready_arr2ctrl),
        .o_psum_out_valid(psum_out_valid_arr2ctrl)
    );

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

    // Clock generation
    always #5 i_clk = ~i_clk;

    initial begin
        $readmemh("./data/conv3/ifmap.mem", u_GLB.gen_GLB_BANKS[0].glb_bank_inst.BRAM);
        $readmemh("./data/conv3/psum_init.mem", u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM);
        $readmemh("./data/conv3/weight.mem", u_GLB.gen_GLB_BANKS[2].glb_bank_inst.BRAM);
        $readmemh("./data/conv3/psum_answer.mem", psum_answer);

        // Initialize Inputs
        i_clk = 0;
        i_rst = 1;

        i_GLB_allocation = {2'd1,2'b1,2'b1};
        i_total_pass = 4'd1;

        i_layer_HW = 8'd15;
        i_layer_U = 2'd1;
        i_layer_PAD = 2'd0;

        i_layer_m = 7'd16;
        i_layer_n = 3'd1;
        i_layer_e = 5'd13;
        i_layer_p = 5'd16;
        i_layer_q = 3'd4;
        i_layer_r = 3'd1;
        i_layer_s = 4'd3;
        i_layer_t = 3'd1;
        i_ifmap_row_id = {4'd1, 4'd1, 4'd1};
        i_wght_row_id = {4'd1, 4'd2, 4'd3};
        i_psum_row_id = {4'd1, 4'd2, 4'd3};

        i_ifmap_col_id = {{5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13},
                          {5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13, 5'd14},
                          {5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15}};

        i_wght_col_id = {NUM_ROWS{{NUM_COLS{4'd1}}}};
        i_psum_col_id = {NUM_ROWS{4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13}};

        repeat (10) @(posedge i_clk); #1;
        i_rst = 0;
        i_ap_start = 32'd1;

        @(posedge i_clk); #1;
        i_ap_start = 32'd0;

        wait(o_ap_done);

        // Save psum_out to file
        fd = $fopen("./data/conv3/psum_out.mem", "w");
        if (fd) begin
            for (i = 0; i < BANK_DEPTH; i = i + 1) begin
                $fdisplay(fd, "%h", u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM[i]);
            end
            $fclose(fd);
        end else begin
            $display("Error: Could not open psum_out.mem for writing.");
        end

        // Compare psum_answer and psum_out
            base_addr = i_layer_e * i_layer_e * i_layer_p;
            num_elem = i_layer_e * i_layer_e * i_layer_p;
            mismatch = 0;
            for (i = 0; i < num_elem; i = i + 1) begin
                if (psum_answer[i] == u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM[base_addr + i]) begin
                    $display("Match at address %0d: answer=%h, out=%h", i, psum_answer[i], u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM[base_addr + i]);
                end
                if (psum_answer[i] !== u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM[base_addr + i]) begin
                $display("Mismatch at address %0d: answer=%h, out=%h", i, psum_answer[i], u_GLB.gen_GLB_BANKS[1].glb_bank_inst.BRAM[base_addr + i]);
                mismatch = 1;
                end
            end
            if (!mismatch) $display("All compared psum values match.");

        $finish;
    end

endmodule