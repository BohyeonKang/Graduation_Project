// Dual-Port Distributed RAM with Synchronous Read
module rams_dist # (
    parameter DATA_BITWIDTH = 8,
    parameter ADDR_BITWIDTH = 8
)(
    input         clk,
    input         we,
    input  [ADDR_BITWIDTH-1:0]  a,      // write + spo read address
    input  [ADDR_BITWIDTH-1:0]  dpra,   // dpo read address
    input  [DATA_BITWIDTH-1:0] di,      // write data
    output [DATA_BITWIDTH-1:0] spo, // spo read data
    output [DATA_BITWIDTH-1:0] dpo  // dpo read data
);

    localparam RAM_DEPTH = 1 << ADDR_BITWIDTH;

    (* ram_style = "distributed" *)
    reg [DATA_BITWIDTH-1:0] ram [RAM_DEPTH-1:0];

    always @(posedge clk) begin
        if (we)
            ram[a] <= di;
    end

    assign spo = ram[a];     // synchronous read for spo
    assign dpo = ram[dpra];  // synchronous read for dpo

endmodule