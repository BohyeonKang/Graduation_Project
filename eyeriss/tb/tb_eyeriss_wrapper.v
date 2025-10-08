`timescale 1ns / 1ps
`define TESTCASE_CONV45
module tb_eyeriss_wrapper();

    localparam BANK_DEPTH = 8192;
    localparam DATA_BITWIDTH = 32;
    localparam IFMAP_ROW_ID_BITWIDTH = 4;
    localparam WGHT_ROW_ID_BITWIDTH = 4;
    localparam PSUM_ROW_ID_BITWIDTH = 4;
    localparam IFMAP_COL_ID_BITWIDTH = 5;
    localparam WGHT_COL_ID_BITWIDTH = 4;
    localparam PSUM_COL_ID_BITWIDTH = 4;
    localparam IFMAP_BUS_BITWIDTH = 32;
    localparam WGHT_BUS_BITWIDTH = 32;
    localparam PSUM_BUS_BITWIDTH = 32;

`ifdef TESTCASE_CONV3
    localparam CONFIG_FILE = "./data/conv3/config.mem";
    localparam NUM_ROWS = 3;
    localparam NUM_COLS = 13;
    localparam layer_e = 13;
    localparam layer_p = 16;
    localparam IFMAP_FILE   = "./data/conv3/ifmap.mem";
    localparam WEIGHT_FILE  = "./data/conv3/weight.mem";
    localparam PSUM_INIT_FILE = "./data/conv3/psum_init.mem";
    localparam PSUM_ANSWER_FILE = "./data/conv3/psum_answer.mem";
    localparam PSUM_OUT_FILE = "./data/conv3/psum_out.mem";
`elsif TESTCASE_CONV45
    localparam CONFIG_FILE = "./data/conv45/config.mem";
    localparam NUM_ROWS = 3;
    localparam NUM_COLS = 13;
    localparam layer_e = 13;
    localparam layer_p = 16;
    localparam IFMAP_FILE   = "./data/conv45/ifmap.mem";
    localparam WEIGHT_FILE  = "./data/conv45/weight.mem";
    localparam PSUM_INIT_FILE = "./data/conv45/psum_init.mem";
    localparam PSUM_ANSWER_FILE = "./data/conv45/psum_answer.mem";
    localparam PSUM_OUT_FILE = "./data/conv45/psum_out.mem";
`else // 기본값
    localparam CONFIG_FILE = "./data/testcase/config.mem";
    localparam NUM_ROWS = 3;
    localparam NUM_COLS = 3;
    localparam layer_e = 3;
    localparam layer_p = 4;
    localparam IFMAP_FILE   = "./data/testcase/ifmap.mem";
    localparam WEIGHT_FILE  = "./data/testcase/weight.mem";
    localparam PSUM_INIT_FILE = "./data/testcase/psum_init.mem";
    localparam PSUM_ANSWER_FILE = "./data/testcase/psum_answer.mem";
    localparam PSUM_OUT_FILE = "./data/testcase/psum_out.mem";
`endif

    reg i_clk;
    reg i_rst;

    reg i_core_start;
    wire o_core_done;

    // Global buffer
    reg [DATA_BITWIDTH-1:0] psum_answer [0:BANK_DEPTH-1];


    // for file writing and comparison
    integer fd, i;
    integer base_addr, num_elem, mismatch;

    eyeriss_wrapper #(
        .CONFIG_FILE(CONFIG_FILE),
        .BANK_DEPTH(BANK_DEPTH),
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS),
        .IFMAP_ROW_ID_BITWIDTH(IFMAP_ROW_ID_BITWIDTH),
        .WGHT_ROW_ID_BITWIDTH(WGHT_ROW_ID_BITWIDTH),
        .PSUM_ROW_ID_BITWIDTH(PSUM_ROW_ID_BITWIDTH),
        .IFMAP_COL_ID_BITWIDTH(IFMAP_COL_ID_BITWIDTH),
        .WGHT_COL_ID_BITWIDTH(WGHT_COL_ID_BITWIDTH),
        .PSUM_COL_ID_BITWIDTH(PSUM_COL_ID_BITWIDTH),
        .IFMAP_BUS_BITWIDTH(IFMAP_BUS_BITWIDTH),
        .WGHT_BUS_BITWIDTH(WGHT_BUS_BITWIDTH),
        .PSUM_BUS_BITWIDTH(PSUM_BUS_BITWIDTH)
    ) u_eyeriss_wrapper (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_core_start(i_core_start),
        .o_core_done(o_core_done)
    );

    // Clock generation
    always #5 i_clk = ~i_clk;

    initial begin
        
        $readmemh(IFMAP_FILE, u_eyeriss_wrapper.u_glb.ifmap_bank.BRAM);
        $readmemh(WEIGHT_FILE, u_eyeriss_wrapper.u_glb.wght_bank.BRAM);
        $readmemh(PSUM_INIT_FILE, u_eyeriss_wrapper.u_glb.psum_bank.BRAM);
        $readmemh(PSUM_ANSWER_FILE, psum_answer);

        // Initialize Inputs
        i_clk = 0;
        i_rst = 1;

        repeat (10) @(posedge i_clk); #1;
        i_rst = 0;
        i_core_start = 32'd1;

        @(posedge i_clk); #1;
        i_core_start = 32'd0;
        wait(o_core_done);

        // Save psum_out to file
        fd = $fopen(PSUM_OUT_FILE, "w");
        if (fd) begin
            for (i = 0; i < BANK_DEPTH; i = i + 1) begin
                $fdisplay(fd, "%h", u_eyeriss_wrapper.u_glb.psum_bank.BRAM[i]);
            end
            $fclose(fd);
        end else begin
            $display("Error: Could not open psum_out.mem for writing.");
        end

        // Compare psum_answer and psum_out
        base_addr = layer_e * layer_e * layer_p;
        num_elem = layer_e * layer_e * layer_p;
        mismatch = 0;
        for (i = 0; i < num_elem; i = i + 1) begin
            if (psum_answer[i] == u_eyeriss_wrapper.u_glb.psum_bank.BRAM[base_addr + i]) begin
                $display("Match at address %0d: answer=%h, out=%h", i, psum_answer[i], u_eyeriss_wrapper.u_glb.psum_bank.BRAM[base_addr + i]);
            end
            if (psum_answer[i] !== u_eyeriss_wrapper.u_glb.psum_bank.BRAM[base_addr + i]) begin
                $display("Mismatch at address %0d: answer=%h, out=%h", i, psum_answer[i], u_eyeriss_wrapper.u_glb.psum_bank.BRAM[base_addr + i]);
                mismatch = 1;
            end
        end
        if (!mismatch) $display("All compared psum values match.");

        $finish;
    end

endmodule