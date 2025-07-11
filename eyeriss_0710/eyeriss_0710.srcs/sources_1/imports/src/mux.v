module mux #(
    parameter NUM_INPUTS = 4,
    parameter DATA_BITWIDTH = 8
)(
    input  [NUM_INPUTS * DATA_BITWIDTH-1:0] i_data,  // Concatenated inputs
    input  [$clog2(NUM_INPUTS)-1:0]         i_sel,   // Select line
    output [DATA_BITWIDTH-1:0]              o_data   // Selected output
);

    assign o_data = i_data[i_sel * DATA_BITWIDTH +: DATA_BITWIDTH];

endmodule