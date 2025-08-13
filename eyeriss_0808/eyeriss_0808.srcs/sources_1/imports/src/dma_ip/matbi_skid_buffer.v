//////////////////////////////////////////////////////////////////////////////////
// Company: Personal
// Engineer: Matbi / Austin
//
// Create Date: 2022.10.04
// License : https://github.com/matbi86/matbi_fpga_season_1/blob/master/LICENSE
// Design Name: 
// Module Name: matbi_skid_buffer
// Project Name:
// Target Devices:
// Tool Versions:
// Description: skid buffer for timing closure. FPGA / ASIC Ver.
// Reference : https://github.com/iammituraj/skid_buffer/blob/main/pipe_skid_buffer.sv
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
module matbi_skid_buffer #
(
    parameter DATA_WIDTH = 8
)
(
    input  wire                   clk,
    input  wire                   rst,

    input  wire                   s_valid,
    output wire                   s_ready,
    input  wire [DATA_WIDTH-1:0]  s_data,

    output wire                   m_valid,
    input  wire                   m_ready,
    output wire [DATA_WIDTH-1:0]  m_data
);

// State 
localparam PIPE  = 1'b0 ; /* Stage where data is piped out or stored to temp buffer */
localparam SKID  = 1'b1 ; /* Stage to wait after data skid happened */

reg                		state_reg                                  	;        // State register
reg [DATA_WIDTH-1 : 0] 	m_data_reg, m_data_temp_reg                 ;        // Data buffer, Spare buffer
reg                		m_valid_reg, m_valid_temp_reg, s_ready_reg  ;        // Valid and Ready signals 
wire                	ready                                     	;        // Pipeline ready signal

assign ready   = m_ready || ~m_valid ;
assign s_ready = s_ready_reg         ;
assign m_data  = m_data_reg          ;
assign m_valid = m_valid_reg         ;

always @(posedge clk) begin
   if (rst) begin
      state_reg           	<= PIPE ;
      m_data_reg            <= 'd0  ;     
      m_data_temp_reg       <= 'd0  ;
      m_valid_reg           <= 1'b0 ;
      m_valid_temp_reg 		<= 1'b0 ;
      s_ready_reg           <= 1'b0 ;
   end
   else begin
      case (state_reg)   
         PIPE : begin
            // Pipe data out             
            if (ready) begin
               m_data_reg           <= s_data  	;  
               m_valid_reg          <= s_valid 	;
               s_ready_reg          <= 1'b1    	;
			   state_reg			<= PIPE		;
            end
            // Pipeline stall, store input data to temp buffer (skid happened)
            else begin
               m_data_temp_reg      <= s_data  	;
               m_valid_temp_reg 	<= s_valid 	;
               s_ready_reg          <= 1'b0    	;
               state_reg           	<= SKID    	;
            end
         end
         SKID : begin
            // Copy data from temp buffer to data buffer, resume pipeline           
            if (ready) begin
               m_data_reg  			<= m_data_temp_reg	;
               m_valid_reg 			<= m_valid_temp_reg ;               
               s_ready_reg 			<= 1'b1             ;
               state_reg 			<= PIPE             ;               
            end
         end
      endcase
   end
end
  
endmodule
