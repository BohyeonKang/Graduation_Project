module GLB_addr_decoder #(
    parameter DATA_BITWIDTH = 32,
    parameter BANK_NUM      = 27,         // Total number of GLB banks
    parameter BANK_DEPTH    = 512        // Depth of each bank
)(
    input [3*clogb2(BANK_NUM)-1:0] i_GLB_allocation,
    input [1:0] i_data_type,
    input [clogb2(BANK_NUM*BANK_DEPTH)-1:0] i_addr, // Logical psum address

    output reg [clogb2(BANK_NUM)-1:0] o_glb_bank_sel,     // Physical bank number in GLB
    output reg [clogb2(BANK_DEPTH)-1:0] o_glb_addr   // Address within the selected bank
);

    localparam IFMAP = 2'd1;
    localparam PSUM  = 2'd2;
    localparam WGHT  = 2'd3;

    wire [clogb2(BANK_NUM)-1:0] ifmap_bank_count;
    wire [clogb2(BANK_NUM)-1:0] psum_bank_count;
    wire [clogb2(BANK_NUM)-1:0] wght_bank_count;
    assign {ifmap_bank_count, psum_bank_count, wght_bank_count} = i_GLB_allocation;

    // Intermediate wires
    wire [clogb2(BANK_NUM)-1:0] ifmap_bank_offset, psum_bank_offset, wght_bank_offset;
    wire [clogb2(BANK_NUM)-1:0] bank_idx;
    wire [clogb2(BANK_DEPTH)-1:0] bank_addr;

    // Calculate bank index within Psum section
    assign bank_idx = i_addr / BANK_DEPTH;
    assign bank_addr  = i_addr % BANK_DEPTH;

    // Add offset to determine physical bank index
    assign ifmap_bank_offset = 0;
    assign psum_bank_offset = ifmap_bank_count;
    assign wght_bank_offset = ifmap_bank_count + wght_bank_count;

    always @(*) begin
        o_glb_bank_sel = 0;
        o_glb_addr = 0;
        case(i_data_type)
            IFMAP: begin
                o_glb_bank_sel = ifmap_bank_offset + bank_idx;
                o_glb_addr = bank_addr;
            end
            PSUM: begin
                o_glb_bank_sel = psum_bank_offset + bank_idx;
                o_glb_addr = bank_addr;
            end
            WGHT: begin
                o_glb_bank_sel = wght_bank_offset + bank_idx;
                o_glb_addr = bank_addr;
            end
        endcase
    end

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction
endmodule