`timescale 1ns / 1ps

module tb_Spad;

    parameter DATA_BITWIDTH = 16;
    parameter ADDR_BITWIDTH = 7;
    parameter RAM_DEPTH = (1 << ADDR_BITWIDTH);

    // Inputs
    reg [ADDR_BITWIDTH-1:0] addra = 0;
    reg [ADDR_BITWIDTH-1:0] addrb = 0;
    reg [DATA_BITWIDTH-1:0] dina = 0;
    reg [DATA_BITWIDTH-1:0] dinb = 0;
    reg clka = 0;
    reg wea = 0;
    reg web = 0;
    reg ena = 0;
    reg enb = 0;
    reg rsta = 0;
    reg rstb = 0;
    reg regcea = 0;
    reg regceb = 0;

    // Outputs
    wire [DATA_BITWIDTH-1:0] douta;
    wire [DATA_BITWIDTH-1:0] doutb;

    // DUT 인스턴스
    true_dpbram #(
        .DATA_BITWIDTH(DATA_BITWIDTH),
        .ADDR_BITWIDTH(ADDR_BITWIDTH),
        .RAM_DEPTH(RAM_DEPTH),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("")
    ) dut (
        .addra(addra), .addrb(addrb),
        .dina(dina), .dinb(dinb),
        .clka(clka), .clkb(clka),
        .wea(wea), .web(web),
        .ena(ena), .enb(enb),
        .rsta(rsta), .rstb(rstb),
        .regcea(regcea), .regceb(regceb),
        .douta(douta), .doutb(doutb)
    );

    // Clock generation
    always #5 clka = ~clka;

    initial begin
        $display("=== Test Start: True Dual Port RAM ===");

        // Reset
        ena = 1; enb = 1;
        rsta = 1; rstb = 1;
        regcea = 1; regceb = 1;
        repeat (10) @(posedge clka);
        rsta = 0; rstb = 0;

        // Write to address 5 via Port B
        addrb = 9'd5;
        dinb = 16'h1234;
        web = 1;
        @(posedge clka);
        web = 0;

        // Read from address 5 via Port A (should see result 2 cycles later)
        @(posedge clka);
        addra = 9'd5;
        wea = 0;
        regcea = 1;

        // Read latency 2 cycle → 기대: douta = 0x1234 around t + 20ns
        repeat (4) @(posedge clka);

        if (doutb === 16'h1234)
            $display("PASS: doutb = 0x%h (expected 0x1234)", doutb);
        else
            $display("FAIL: doutb = 0x%h (expected 0x1234)", doutb);

        $finish;
    end

endmodule
