`timescale 1ns / 1ps
//  Xilinx True Dual Port RAM, No Change, Single Clock
//  This code implements a parameterizable true dual port memory (both ports can read and write).
//  This is a no change RAM which retains the last read value on the output during writes
//  which is the most power efficient mode.
//  If a reset or enable is not necessary, it may be tied off or removed from the code.

module true_dpbram_config #(
  parameter RAM_WIDTH = 32,                       // Specify RAM data width
  parameter RAM_DEPTH = 64,                     // Specify RAM depth (number of entries)
  parameter RAM_PERFORMANCE = "LOW_LATENCY", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  parameter INIT_FILE = "pe_set_config.mem"                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Port A address bus, width determined from RAM_DEPTH
  input [clogb2(RAM_DEPTH-1)-1:0] addrb,  // Port B address bus, width determined from RAM_DEPTH
  input [RAM_WIDTH-1:0] dina,           // Port A RAM input data
  input [RAM_WIDTH-1:0] dinb,           // Port B RAM input data
  input clka,                           // Clock
  input clkb,
  input wea,                            // Port A write enable
  input web,                            // Port B write enable
  input ena,                            // Port A RAM Enable, for additional power savings, disable port when not in use
  input enb,                            // Port B RAM Enable, for additional power savings, disable port when not in use
  input rsta,                           // Port A output reset (does not affect memory contents)
  input rstb,                           // Port B output reset (does not affect memory contents)
  input regcea,                         // Port A output register enable
  input regceb,                         // Port B output register enable
  output [RAM_WIDTH-1:0] douta,         // Port A RAM output data
  output [RAM_WIDTH-1:0] doutb,         // Port B RAM output data

  output [5:0] GLB_allocation,
  output [3:0] total_pass,
  output [7:0] layer_HW,
  output [1:0] layer_U,
  output [1:0] layer_PAD,
  output [6:0] layer_m,
  output [2:0] layer_n,
  output [4:0] layer_e,
  output [4:0] layer_p,
  output [2:0] layer_q,
  output [2:0] layer_r,
  output [3:0] layer_s,
  output [2:0] layer_t,
  output [11:0] ifmap_row_id,
  output [11:0] wght_row_id,
  output [11:0] psum_row_id,
  output [194:0] ifmap_col_id,
  output [155:0] wght_col_id,
  output [155:0] psum_col_id
);

  (* ram_style = "block" *) reg [RAM_WIDTH-1:0] BRAM [0:RAM_DEPTH-1];
  reg [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
  reg [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          BRAM[ram_index] = {RAM_WIDTH{1'b0}};
    end
  endgenerate

  always @(posedge clka)
    if (ena)
      if (wea)
        BRAM[addra] <= dina;
      else
        ram_data_a <= BRAM[addra];

  always @(posedge clkb)
    if (enb)
      if (web)
        BRAM[addrb] <= dinb;
      else
        ram_data_b <= BRAM[addrb];

  //  The following code generates HIGH_PERFORMANCE (use output register) or LOW_LATENCY (no output register)
  generate
    if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register

      // The following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
       assign douta = ram_data_a;
       assign doutb = ram_data_b;

    end else begin: output_register

      // The following is a 2 clock cycle read latency with improve clock-to-out timing

      reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};
      reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

      always @(posedge clka) begin
        if (rsta)
          douta_reg <= {RAM_WIDTH{1'b0}};
        else if (regcea)
          douta_reg <= ram_data_a;
      end

      always @(posedge clkb) begin
        if (rstb)
          doutb_reg <= {RAM_WIDTH{1'b0}};
        else if (regceb)
          doutb_reg <= ram_data_b;
      end

      assign douta = douta_reg;
      assign doutb = doutb_reg;

    end
  endgenerate


  wire [RAM_WIDTH-1:0] bram_out_0 = BRAM[0];
  wire [RAM_WIDTH-1:0] bram_out_1 = BRAM[1];
  wire [RAM_WIDTH-1:0] bram_out_2 = BRAM[2];
  wire [RAM_WIDTH-1:0] bram_out_3 = BRAM[3];
  wire [RAM_WIDTH-1:0] bram_out_4 = BRAM[4];
  wire [RAM_WIDTH-1:0] bram_out_5 = BRAM[5];
  wire [RAM_WIDTH-1:0] bram_out_6 = BRAM[6];
  wire [RAM_WIDTH-1:0] bram_out_7 = BRAM[7];
  wire [RAM_WIDTH-1:0] bram_out_8 = BRAM[8];
  wire [RAM_WIDTH-1:0] bram_out_9 = BRAM[9];
  wire [RAM_WIDTH-1:0] bram_out_10 = BRAM[10];
  wire [RAM_WIDTH-1:0] bram_out_11 = BRAM[11];
  wire [RAM_WIDTH-1:0] bram_out_12 = BRAM[12];
  wire [RAM_WIDTH-1:0] bram_out_13 = BRAM[13];
  wire [RAM_WIDTH-1:0] bram_out_14 = BRAM[14];
  wire [RAM_WIDTH-1:0] bram_out_15 = BRAM[15];

  wire [RAM_WIDTH-1:0] bram_out_16 = BRAM[16];
  wire [RAM_WIDTH-1:0] bram_out_17 = BRAM[17];
  wire [RAM_WIDTH-1:0] bram_out_18 = BRAM[18];
  wire [RAM_WIDTH-1:0] bram_out_19 = BRAM[19];
  wire [RAM_WIDTH-1:0] bram_out_20 = BRAM[20];
  wire [RAM_WIDTH-1:0] bram_out_21 = BRAM[21];
  wire [RAM_WIDTH-1:0] bram_out_22 = BRAM[22];

  wire [RAM_WIDTH-1:0] bram_out_23 = BRAM[23];
  wire [RAM_WIDTH-1:0] bram_out_24 = BRAM[24];
  wire [RAM_WIDTH-1:0] bram_out_25 = BRAM[25];
  wire [RAM_WIDTH-1:0] bram_out_26 = BRAM[26];
  wire [RAM_WIDTH-1:0] bram_out_27 = BRAM[27];

  wire [RAM_WIDTH-1:0] bram_out_28 = BRAM[28];
  wire [RAM_WIDTH-1:0] bram_out_29 = BRAM[29];
  wire [RAM_WIDTH-1:0] bram_out_30 = BRAM[30];
  wire [RAM_WIDTH-1:0] bram_out_31 = BRAM[31];
  wire [RAM_WIDTH-1:0] bram_out_32 = BRAM[32];


  assign GLB_allocation = bram_out_0[5:0];
  assign total_pass     = bram_out_1[3:0];
  assign layer_HW       = bram_out_2[7:0];
  assign layer_U        = bram_out_3[1:0];
  assign layer_PAD      = bram_out_4[1:0];
  assign layer_m        = bram_out_5[6:0];
  assign layer_n        = bram_out_6[2:0];
  assign layer_e        = bram_out_7[4:0];
  assign layer_p        = bram_out_8[4:0];
  assign layer_q        = bram_out_9[2:0];
  assign layer_r        = bram_out_10[2:0];
  assign layer_s        = bram_out_11[3:0];
  assign layer_t        = bram_out_12[2:0];
  assign ifmap_row_id = bram_out_13[11:0];
  assign wght_row_id  = bram_out_14[11:0];
  assign psum_row_id  = bram_out_15[11:0];
  assign ifmap_col_id = {bram_out_16[29:0], bram_out_17[29:0], bram_out_18[29:0], bram_out_19[29:0], bram_out_20[29:0], bram_out_21[29:0], bram_out_22[14:0]};
  assign wght_col_id = {bram_out_23, bram_out_24, bram_out_25, bram_out_26, bram_out_27[27:0]};
  assign psum_col_id = {bram_out_28, bram_out_29, bram_out_30, bram_out_31, bram_out_32[27:0]};

  //  The following function calculates the address width based on specified RAM depth
  function integer clogb2;
    input integer depth;
      for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
  endfunction

endmodule