`timescale 1ns / 1ps

module axi_lite_wrapper #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 12
) (
    input wire  ACLK,
    input wire  ARESETN,
    // AXI-Lite Write Channels
    input wire  S_AXI_AWADDR,
    input wire  S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input wire  S_AXI_WDATA,
    input wire  S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire S_AXI_WREADY,
    output wire S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    // AXI-Lite Read Channels
    input wire  S_AXI_ARADDR,
    input wire  S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    output wire S_AXI_RDATA,
    output wire S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input wire  S_AXI_RREADY,
    // Output signals to TOP_ctrl and Instruction BRAM
    output wire [3:0]                     o_total_pass,
    output wire [7:0]                     o_layer_HW,
    output wire [3:0]                     o_layer_RS,
    output wire [6:0]                     o_layer_EF,
    output wire [9:0]                     o_layer_C,
    output wire [8:0]                     o_layer_M,
    output wire [1:0]                     o_layer_U,
    output wire [1:0]                     o_layer_PAD,
    output wire [3:0]                     o_layer_m,
    output wire [2:0]                     o_layer_n,
    output wire [4:0]                     o_layer_e,
    output wire [3:0]                     o_layer_p,
    output wire [2:0]                     o_layer_q,
    output wire [1:0]                     o_layer_r,
    output wire [1:0]                     o_layer_t,
    output wire [95:0]                    o_ifmap_row_id,
    output wire [95:0]                    o_wght_row_id,
    output wire [95:0]                    o_psum_row_id,
    output wire [479:0]                   o_ifmap_col_id,
    output wire [383:0]                   o_wght_col_id,
    output wire [383:0]                   o_psum_col_id,
    output wire [clogb2(64*32)-1:0] o_inst_bram_wa,
    output wire [31:0]                    o_inst_bram_wd,
    output wire                           o_inst_bram_we,
    output wire [3*clogb2(3)-1:0] o_GLB_allocation,
    output wire o_inst_start
);

    // BRAM Parameter definitions for TOP_ctrl
    localparam INST_BRAM_DEPTH = 64;
    localparam DATA_BITWIDTH = 32;

    // AXI-Lite State machine signals
    reg [1:0] axi_aw_state;
    reg [1:0] axi_ar_state;
    reg [1:0] axi_w_state;
    reg [1:0] axi_b_state;
    reg [1:0] axi_r_state;

    // AXI-Lite Registers
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr_reg;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_wdata_reg;
    reg S_AXI_AWREADY_reg;
    reg S_AXI_ARREADY_reg;
    reg S_AXI_WREADY_reg;
    reg S_AXI_BVALID_reg;
    reg S_AXI_RVALID_reg;
    reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA_reg;
    reg [1:0] S_AXI_BRESP_reg;
    reg [1:0] S_AXI_RRESP_reg;

    // Internal registers for TOP_ctrl configuration
    reg [3:0]                     r_total_pass;
    reg [7:0]                     r_layer_HW;
    reg [3:0]                     r_layer_RS;
    reg [6:0]                     r_layer_EF;
    reg [9:0]                     r_layer_C;
    reg [8:0]                     r_layer_M;
    reg [1:0]                     r_layer_U;
    reg [1:0]                     r_layer_PAD;
    reg [3:0]                     r_layer_m;
    reg [2:0]                     r_layer_n;
    reg [4:0]                     r_layer_e;
    reg [3:0]                     r_layer_p;
    reg [2:0]                     r_layer_q;
    reg [1:0]                     r_layer_r;
    reg [1:0]                     r_layer_t;
    reg [95:0]                    r_ifmap_row_id;
    reg [95:0]                    r_wght_row_id;
    reg [95:0]                    r_psum_row_id;
    reg [479:0]                   r_ifmap_col_id;
    reg [383:0]                   r_wght_col_id;
    reg [383:0]                   r_psum_col_id;
    reg [3*clogb2(3)-1:0] r_GLB_allocation;
    reg                           r_inst_start;

    // Registers for Instruction BRAM write interface
    reg [clogb2(INST_BRAM_DEPTH)-1:0] r_inst_bram_wa;
    reg [DATA_BITWIDTH-1:0]           r_inst_bram_wd;
    reg                               r_inst_bram_we;
    
    // AXI-Lite address map
    localparam ADDR_BASE = 12'h000;
    localparam ADDR_CTRL_0 = ADDR_BASE + 12'h000;  // r_total_pass, r_layer_HW
    localparam ADDR_CTRL_1 = ADDR_BASE + 12'h004;  // r_layer_RS, r_layer_EF
    localparam ADDR_CTRL_2 = ADDR_BASE + 12'h008;  // r_layer_C, r_layer_M
    localparam ADDR_CTRL_3 = ADDR_BASE + 12'h00C;  // r_layer_U, r_layer_PAD, r_layer_m, r_layer_n
    localparam ADDR_CTRL_4 = ADDR_BASE + 12'h010;  // r_layer_e, r_layer_p, r_layer_q, r_layer_r, r_layer_t
    localparam ADDR_GLB_ALLOC = ADDR_BASE + 12'h014; // r_GLB_allocation
    localparam ADDR_START = ADDR_BASE + 12'h018;  // r_inst_start
    localparam ADDR_BRAM_BASE = ADDR_BASE + 12'h100; // Instruction BRAM base address

    // AXI-Lite FSM for Write Channel
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_AWREADY_reg <= 1'b0;
            S_AXI_WREADY_reg  <= 1'b0;
            S_AXI_BVALID_reg  <= 1'b0;
            axi_aw_state <= 2'b00;
        end else begin
            case (axi_aw_state)
                2'b00: begin // IDLE
                    S_AXI_AWREADY_reg <= 1'b0;
                    S_AXI_WREADY_reg <= 1'b0;
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        S_AXI_AWREADY_reg <= 1'b1;
                        S_AXI_WREADY_reg <= 1'b1;
                        axi_awaddr_reg <= S_AXI_AWADDR;
                        axi_wdata_reg <= S_AXI_WDATA;
                        axi_aw_state <= 2'b01; // Write transaction received
                    end
                end
                2'b01: begin // Received AW and W, sending BVALID
                    S_AXI_AWREADY_reg <= 1'b0;
                    S_AXI_WREADY_reg <= 1'b0;
                    S_AXI_BVALID_reg <= 1'b1;
                    S_AXI_BRESP_reg <= 2'b00; // OKAY
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID_reg <= 1'b0;
                        axi_aw_state <= 2'b00; // Back to IDLE
                    end
                end
            endcase
        end
    end

    // AXI-Lite FSM for Read Channel
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_AXI_ARREADY_reg <= 1'b0;
            S_AXI_RVALID_reg <= 1'b0;
            axi_ar_state <= 2'b00;
        end else begin
            case (axi_ar_state)
                2'b00: begin // IDLE
                    S_AXI_ARREADY_reg <= 1'b0;
                    S_AXI_RVALID_reg <= 1'b0;
                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY_reg <= 1'b1;
                        axi_araddr_reg <= S_AXI_ARADDR;
                        axi_ar_state <= 2'b01; // Read transaction received
                    end
                end
                2'b01: begin // Sending RVALID
                    S_AXI_ARREADY_reg <= 1'b0;
                    S_AXI_RVALID_reg <= 1'b1;
                    S_AXI_RRESP_reg <= 2'b00; // OKAY
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID_reg <= 1'b0;
                        axi_ar_state <= 2'b00; // Back to IDLE
                    end
                end
            endcase
        end
    end

    // Register Write Logic
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            r_total_pass <= 0; r_layer_HW <= 0; r_layer_RS <= 0;
            r_layer_EF <= 0; r_layer_C <= 0; r_layer_M <= 0;
            r_layer_U <= 0; r_layer_PAD <= 0; r_layer_m <= 0;
            r_layer_n <= 0; r_layer_e <= 0; r_layer_p <= 0;
            r_layer_q <= 0; r_layer_r <= 0; r_layer_t <= 0;
            r_ifmap_row_id <= 0; r_wght_row_id <= 0; r_psum_row_id <= 0;
            r_ifmap_col_id <= 0; r_wght_col_id <= 0; r_psum_col_id <= 0;
            r_GLB_allocation <= 0; r_inst_start <= 0;
            r_inst_bram_we <= 0;
        end else begin
            r_inst_bram_we <= 1'b0;
            // Write to Configuration Registers
            if (S_AXI_AWVALID && S_AXI_WVALID && S_AXI_AWREADY_reg && S_AXI_WREADY_reg) begin
                case (axi_awaddr_reg)
                    ADDR_CTRL_0: begin
                        r_total_pass <= axi_wdata_reg[3:0];
                        r_layer_HW <= axi_wdata_reg[11:4];
                    end
                    ADDR_CTRL_1: begin
                        r_layer_RS <= axi_wdata_reg[3:0];
                        r_layer_EF <= axi_wdata_reg[10:4];
                    end
                    // ... other control registers ...
                    ADDR_GLB_ALLOC: begin
                        r_GLB_allocation <= axi_wdata_reg[clogb2(24)-1:0];
                    end
                    ADDR_START: begin
                        r_inst_start <= axi_wdata_reg[0];
                    end
                    default: begin // Write to Instruction BRAM
                        r_inst_bram_wa <= axi_awaddr_reg[clogb2(INST_BRAM_DEPTH)-1:0];
                        r_inst_bram_wd <= axi_wdata_reg;
                        r_inst_bram_we <= 1'b1;
                    end
                endcase
            end
        end
    end

    // Register Read Logic
    always @(*) begin
        S_AXI_RDATA_reg = 32'h0;
        case (axi_araddr_reg)
            ADDR_CTRL_0: begin
                S_AXI_RDATA_reg = {20'h0, r_layer_HW, r_total_pass};
            end
            ADDR_CTRL_1: begin
                S_AXI_RDATA_reg = {21'h0, r_layer_EF, r_layer_RS};
            end
            // ... other control registers ...
            default: begin
                S_AXI_RDATA_reg = 32'hdeadbeef; // Default value for unmapped addresses
            end
        endcase
    end

    // Assign outputs
    assign S_AXI_AWREADY = S_AXI_AWREADY_reg;
    assign S_AXI_ARREADY = S_AXI_ARREADY_reg;
    assign S_AXI_WREADY  = S_AXI_WREADY_reg;
    assign S_AXI_BVALID  = S_AXI_BVALID_reg;
    assign S_AXI_RVALID  = S_AXI_RVALID_reg;
    assign S_AXI_BRESP   = S_AXI_BRESP_reg;
    assign S_AXI_RRESP   = S_AXI_RRESP_reg;
    assign S_AXI_RDATA   = S_AXI_RDATA_reg;

    assign o_total_pass = r_total_pass;
    assign o_layer_HW = r_layer_HW;
    assign o_layer_RS = r_layer_RS;
    assign o_layer_EF = r_layer_EF;
    assign o_layer_C = r_layer_C;
    assign o_layer_M = r_layer_M;
    assign o_layer_U = r_layer_U;
    assign o_layer_PAD = r_layer_PAD;
    assign o_layer_m = r_layer_m;
    assign o_layer_n = r_layer_n;
    assign o_layer_e = r_layer_e;
    assign o_layer_p = r_layer_p;
    assign o_layer_q = r_layer_q;
    assign o_layer_r = r_layer_r;
    assign o_layer_t = r_layer_t;
    assign o_ifmap_row_id = r_ifmap_row_id;
    assign o_wght_row_id = r_wght_row_id;
    assign o_psum_row_id = r_psum_row_id;
    assign o_ifmap_col_id = r_ifmap_col_id;
    assign o_wght_col_id = r_wght_col_id;
    assign o_psum_col_id = r_psum_col_id;
    assign o_GLB_allocation = r_GLB_allocation;
    assign o_inst_start = r_inst_start;

    assign o_inst_bram_wa = r_inst_bram_wa;
    assign o_inst_bram_wd = r_inst_bram_wd;
    assign o_inst_bram_we = r_inst_bram_we;

    function integer clogb2;
        input integer depth;
        begin
            for (clogb2=0; depth>0; clogb2=clogb2+1)
                depth = depth >> 1;
        end
    endfunction

endmodule
