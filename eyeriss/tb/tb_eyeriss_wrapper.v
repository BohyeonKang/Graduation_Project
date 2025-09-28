
`timescale 1ns / 1ps

module tb_eyeriss_wrapper();

    localparam BANK_NUM = 3;
    localparam BANK_DEPTH = 8192;
    localparam DATA_BITWIDTH = 32;
    localparam NUM_ROWS = 3;
    localparam NUM_COLS = 13;
    localparam IFMAP_ROW_ID_BITWIDTH = 4;
    localparam WGHT_ROW_ID_BITWIDTH = 4;
    localparam PSUM_ROW_ID_BITWIDTH = 4;
    localparam IFMAP_COL_ID_BITWIDTH = 5;
    localparam WGHT_COL_ID_BITWIDTH = 4;
    localparam PSUM_COL_ID_BITWIDTH = 4;
    localparam IFMAP_BUS_BITWIDTH = 32;
    localparam WGHT_BUS_BITWIDTH = 32;
    localparam PSUM_BUS_BITWIDTH = 32;

    localparam layer_e = 13; // Number of output channels
    localparam layer_p = 16; // Number of input channels

    reg i_clk;
    reg i_rst;

    reg i_core_start;
    wire o_core_done;

    // Global buffer
    reg [DATA_BITWIDTH-1:0] psum_answer [0:BANK_DEPTH-1];

    // PE_array → GLB
    wire [DATA_BITWIDTH-1:0] psum_out_data_arr2glb;

    // for file writing and comparison
    integer fd, i;
    integer base_addr, num_elem, mismatch;


    eyeriss_wrapper #(
    .BANK_NUM(BANK_NUM),
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
    // Port connections
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_core_start(i_core_start),
    .o_core_done(o_core_done)
    );

    // Clock generation
    always #5 i_clk = ~i_clk;

    initial begin
        /*
        $readmemh("./data/conv3/ifmap.mem", u_eyeriss_wrapper.glb_inst.gen_GLB_BANKS[0].glb_bank_inst.BRAM);
        $readmemh("./data/conv3/psum_init.mem", u_eyeriss_wrapper.glb_inst.gen_GLB_BANKS[1].glb_bank_inst.BRAM);
        $readmemh("./data/conv3/weight.mem", u_eyeriss_wrapper.glb_inst.gen_GLB_BANKS[2].glb_bank_inst.BRAM);
        */
        
        $readmemh("./data/conv3/psum_answer.mem", psum_answer);

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
        fd = $fopen("./data/conv3/psum_out.mem", "w");
        if (fd) begin
            for (i = 0; i < BANK_DEPTH; i = i + 1) begin
                $fdisplay(fd, "%h", eyeriss_wrapper.glb_inst.u_glb_bank_psum.BRAM[i]);
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
                if (psum_answer[i] == u_eyeriss_wrapper.glb_inst.u_glb_bank_psum.BRAM[base_addr + i]) begin
                    $display("Match at address %0d: answer=%h, out=%h", i, psum_answer[i], u_eyeriss_wrapper.glb_inst.u_glb_bank_psum.BRAM[base_addr + i]);
                end
                if (psum_answer[i] !== u_eyeriss_wrapper.glb_inst.u_glb_bank_psum.BRAM[base_addr + i]) begin
                $display("Mismatch at address %0d: answer=%h, out=%h", i, psum_answer[i], u_eyeriss_wrapper.glb_inst.u_glb_bank_psum.BRAM[base_addr + i]);
                mismatch = 1;
                end
            end
            if (!mismatch) $display("All compared psum values match.");

        $finish;
    end

endmodule