`timescale 1ns / 1ps

module tb_sftreg;

    reg i_clk;
    reg i_rst;
    reg i_we;
    wire o_we;

    // DUT
    sftreg uut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_we(i_we),
        .o_we(o_we)
    );

    // Clock generation (10ns period)
    always #5 i_clk = ~i_clk;

    initial begin
        i_clk = 0;
        i_rst = 1;
        i_we  = 0;
        repeat (5) @(posedge i_clk);
        
        i_rst = 0;
        repeat (5) @(posedge i_clk);
        
        @(posedge i_clk); i_we = 1;
        @(posedge i_clk); i_we = 0;

        // Wait and observe o_we
        repeat (10) @(posedge i_clk);

        $finish;
    end

endmodule