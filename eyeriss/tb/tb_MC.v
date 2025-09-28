`timescale 1ns/1ps

module tb_MC;

    reg         clk;
    reg         rst;

    reg  [2:0]  i_id;
    reg  [2:0]  i_tag;

    reg         i_data;
    reg         i_valid;
    wire        o_ready;

    reg         i_ready;
    wire        o_valid;
    wire        o_data;

    // DUT
    MC dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_id(i_id),
        .i_tag(i_tag),
        .i_data(i_data),
        .i_valid(i_valid),
        .o_ready(o_ready),
        .i_ready(i_ready),
        .o_valid(o_valid),
        .o_data(o_data)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period

    // Test sequence
    initial begin
        $display("Start MC testbench");
        rst = 1;
        i_id = 3'b000;
        i_tag = 3'b000;
        i_data = 0;
        i_valid = 0;
        i_ready = 0;

        repeat (3) @(posedge clk);
        rst = 0;
        i_id = 3'b101;  // Load id_reg = 101
        
        // Case 1: id == tag, valid & ready asserted
        @(posedge clk);
        i_tag = 3'b101;
        i_data = 1'b1;
        i_valid = 1'b1;
        i_ready = 1'b1;
        
        @(posedge clk);
        $display("Match Case - o_valid: %b, o_data: %b", o_valid, o_data);

        // Case 2: id != tag, should not send data
        @(posedge clk);
        i_tag = 3'b100;
        i_data = 1'b1;
        i_valid = 1'b1;
        i_ready = 1'b1;
        
        @(posedge clk);
        $display("Mismatch Case - o_valid: %b, o_data: %b", o_valid, o_data);

        // Case 3: id == tag, but ready is 0
        @(posedge clk);
        i_tag = 3'b101;
        i_valid = 1'b1;
        i_ready = 1'b0;

        @(posedge clk);
        $display("No Ready - o_valid: %b, o_data: %b", o_valid, o_data);

        // Case 4: id == tag, but valid is 0
        @(posedge clk);
        i_valid = 1'b0;
        i_ready = 1'b1;
        
        @(posedge clk);
        $display("No Valid - o_valid: %b, o_data: %b", o_valid, o_data);

        $finish;
    end

endmodule
