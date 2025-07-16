`timescale 1ns / 1ps

module tb_GLB;

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

    // Parameters
    localparam DATA_BITWIDTH = 16;
    localparam BANK_NUM = 4;  // 테스트 간단히
    localparam BANK_DEPTH = 512;

    localparam BANK_SEL_WIDTH = clogb2(BANK_NUM);
    localparam ADDR_WIDTH = clogb2(BANK_DEPTH);

    // DUT inputs
    reg                     i_clk;
    reg                     i_rst;
    reg  [BANK_SEL_WIDTH-1:0] i_bank_sel;
    reg                     i_re;
    reg                     i_we;
    reg  [ADDR_WIDTH-1:0]   i_ra;
    reg  [ADDR_WIDTH-1:0]   i_wa;
    reg  [DATA_BITWIDTH-1:0] i_wd;

    // DUT output
    wire [DATA_BITWIDTH-1:0] o_rd;

    // Clock generation
    always #5 i_clk = ~i_clk;

    // Instantiate DUT
    GLB #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .BANK_NUM(BANK_NUM),
        .BANK_DEPTH(BANK_DEPTH)
    ) dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_bank_sel(i_bank_sel),
        .i_re(i_re),
        .i_we(i_we),
        .i_ra(i_ra),
        .i_wa(i_wa),
        .i_wd(i_wd),
        .o_rd(o_rd)
    );

    // Test sequence
    initial begin
        $readmemh("init_bank0.mem", glb.gen_GLB_BANKS[0].glb_bank_inst.BRAM);
        $readmemh("init_bank1.mem", glb.gen_GLB_BANKS[1].glb_bank_inst.BRAM);

        $display("Start GLB testbench");
        i_clk = 0;
        i_rst = 1;
        i_re  = 0;
        i_we  = 0;
        i_bank_sel = 0;
        i_ra = 0;
        i_wa = 0;
        i_wd = 0;

        repeat (5) @(posedge i_clk); #1;
        i_rst = 0;

        // --- Write to bank 0 ---
        @(posedge i_clk); #1;
        i_bank_sel = 0;
        i_wa = 5;
        i_wd = 32'hDEADBEEF;
        i_we = 1;

        @(posedge i_clk); #1;
        i_we = 0;

        // --- Write to bank 1 ---
        @(posedge i_clk); #1;
        i_bank_sel = 1;
        i_wa = 3;
        i_wd = 32'hCAFEBABE;
        i_we = 1;

        @(posedge i_clk); #1;
        i_we = 0;

        // --- Read from bank 0 ---
        @(posedge i_clk); #1;
        i_bank_sel = 0;
        i_ra = 5;
        i_re = 1;

        repeat (2) @(posedge i_clk); #1; // read latency 1-cycle
        i_re = 0;

        #1 $display("[Bank 0] Read value = 0x%08X (expect DEADBEEF)", o_rd);

        // --- Read from bank 1 ---
        @(posedge i_clk); #1;
        i_bank_sel = 1;
        i_ra = 3;
        i_re = 1;

        repeat (2) @(posedge i_clk); #1; // read latency 1-cycle
        i_re = 0;

        #1 $display("[Bank 1] Read value = 0x%08X (expect CAFEBABE)", o_rd);

        $display("End of test");
        $finish;
    end

endmodule