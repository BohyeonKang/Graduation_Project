`timescale 1ns / 1ps

module GLB #(
    parameter BANK_WIDTH = 32,
    parameter BANK_DEPTH = 8192
)(
    input i_clk,
    input i_rst,
    
	input [1:0] i_bank_sel,

    input                               i_we,      // Write enable for each bank
    input  [clogb2(BANK_DEPTH-1)-1:0]   i_addr, // Read addr
    input  [BANK_WIDTH-1:0]     i_wd,        // Write data
    output reg [BANK_WIDTH-1:0] o_rd         // Read data
);

    wire [BANK_WIDTH-1:0] ifmap_bank_rd, wght_bank_rd, psum_bank_rd;
    wire ifmap_bank_we, wght_bank_we, psum_bank_we;

    xilinx_true_dual_port_no_change_1_clock_ram #(
        .RAM_WIDTH(BANK_WIDTH),                       // Specify RAM data width
        .RAM_DEPTH(BANK_DEPTH),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE() // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) ifmap_bank (
        .addra(i_addr),   // Port A address bus, width determined from RAM_DEPTH
        .addrb({clogb2(BANK_DEPTH-1){1'b0}}),   // Port B address bus, width determined from RAM_DEPTH
        .dina(i_wd),     // Port A RAM input data, width determined from RAM_WIDTH
        .dinb({BANK_WIDTH{1'b0}}),     // Port B RAM input data, width determined from RAM_WIDTH
        .clka(i_clk),     // Clock
        .wea(ifmap_bank_we),       // Port A write enable
        .web(1'b0),       // Port B write enable
        .ena(1'b1),       // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(1'b0),       // Port B RAM Enable, for additional power savings, disable port when not in use
        .rsta(i_rst),     // Port A output reset (does not affect memory contents)
        .rstb(i_rst),     // Port B output reset (does not affect memory contents)
        .regcea(1'b1), // Port A output register enable
        .regceb(1'b1), // Port B output register enable
        .douta(ifmap_bank_rd),   // Port A RAM output data, width determined from RAM_WIDTH
        .doutb()    // Port B RAM output data, width determined from RAM_WIDTH
    );

    xilinx_true_dual_port_no_change_1_clock_ram #(
        .RAM_WIDTH(BANK_WIDTH),                       // Specify RAM data width
        .RAM_DEPTH(BANK_DEPTH),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE() // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) wght_bank (
        .addra(i_addr),   // Port A address bus, width determined from RAM_DEPTH
        .addrb({clogb2(BANK_DEPTH-1){1'b0}}),   // Port B address bus, width determined from RAM_DEPTH
        .dina(i_wd),     // Port A RAM input data, width determined from RAM_WIDTH
        .dinb({BANK_WIDTH{1'b0}}),     // Port B RAM input data, width determined from RAM_WIDTH
        .clka(i_clk),     // Clock
        .wea(wght_bank_we),       // Port A write enable
        .web(1'b0),       // Port B write enable
        .ena(1'b1),       // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(1'b0),       // Port B RAM Enable, for additional power savings, disable port when not in use
        .rsta(i_rst),     // Port A output reset (does not affect memory contents)
        .rstb(i_rst),     // Port B output reset (does not affect memory contents)
        .regcea(1'b1), // Port A output register enable
        .regceb(1'b1), // Port B output register enable
        .douta(wght_bank_rd),   // Port A RAM output data, width determined from RAM_WIDTH
        .doutb()    // Port B RAM output data, width determined from RAM_WIDTH
    );

    xilinx_true_dual_port_no_change_1_clock_ram #(
        .RAM_WIDTH(BANK_WIDTH),                       // Specify RAM data width
        .RAM_DEPTH(BANK_DEPTH),                     // Specify RAM depth (number of entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE() // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) psum_bank (
        .addra(i_addr),   // Port A address bus, width determined from RAM_DEPTH
        .addrb({clogb2(BANK_DEPTH-1){1'b0}}),   // Port B address bus, width determined from RAM_DEPTH
        .dina(i_wd),     // Port A RAM input data, width determined from RAM_WIDTH
        .dinb({BANK_WIDTH{1'b0}}),     // Port B RAM input data, width determined from RAM_WIDTH
        .clka(i_clk),     // Clock
        .wea(psum_bank_we),       // Port A write enable
        .web(1'b0),       // Port B write enable
        .ena(1'b1),       // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(1'b0),       // Port B RAM Enable, for additional power savings, disable port when not in use
        .rsta(i_rst),     // Port A output reset (does not affect memory contents)
        .rstb(i_rst),     // Port B output reset (does not affect memory contents)
        .regcea(1'b1), // Port A output register enable
        .regceb(1'b1), // Port B output register enable
        .douta(psum_bank_rd),   // Port A RAM output data, width determined from RAM_WIDTH
        .doutb()    // Port B RAM output data, width determined from RAM_WIDTH
    );

    always @(*) begin
        o_rd = {BANK_WIDTH{1'b0}};
        case(i_bank_sel)
            2'h1: o_rd = ifmap_bank_rd;
            2'h2: o_rd = wght_bank_rd;
            2'h3: o_rd = psum_bank_rd;
        endcase
    end

    assign ifmap_bank_we = i_we && (i_bank_sel == 2'h1);
    assign wght_bank_we = i_we && (i_bank_sel == 2'h2);
    assign psum_bank_we = i_we && (i_bank_sel == 2'h3);

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule