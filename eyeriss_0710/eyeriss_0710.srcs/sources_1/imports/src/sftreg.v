module sftreg(
    input i_clk,
    input i_rst,
    input i_we,
    output o_we
);

    reg [2:0] we_sftreg;
    
    always @(posedge i_clk) begin
        if(i_rst) begin
            we_sftreg <= 3'b0;
        end
        else begin
            we_sftreg <= {we_sftreg[1:0], i_we};
        end
    end

    assign o_we = we_sftreg[2];

endmodule