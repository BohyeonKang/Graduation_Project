module fifo#(
    parameter QUEUE_PTR_BANDWIDTH = 3,
    parameter ELE_BANDWIDTH       = 8
)(
    input i_clk,
    input i_rst,

    //FIFO interface as rx
    input [ELE_BANDWIDTH-1:0] i_push_data,
    input i_valid,
    output o_ready,

    //FIFO interface as tx
    input i_ready,         
    output o_valid,
    output [ELE_BANDWIDTH-1:0] o_pop_data
);

    localparam QUEUE_SIZE = (1<<QUEUE_PTR_BANDWIDTH);

    reg [ELE_BANDWIDTH-1:0] queue_mem [QUEUE_SIZE-1:0];
    reg [QUEUE_PTR_BANDWIDTH:0] head;
    reg [QUEUE_PTR_BANDWIDTH:0] tail;

    wire full, empty;
    wire head_MSB, tail_MSB;
    wire [QUEUE_PTR_BANDWIDTH-1:0] head_fifo_ptr, tail_fifo_ptr;

    assign {head_MSB, head_fifo_ptr} = head;
    assign {tail_MSB, tail_fifo_ptr} = tail;

    assign full  = (head_MSB      != tail_MSB) &
                   (head_fifo_ptr == tail_fifo_ptr);
    assign empty = (head_MSB      == tail_MSB) &
                   (head_fifo_ptr == tail_fifo_ptr);

    wire push_flag, pop_flag, shift_flag, bypass_flag;

    assign shift_flag  = (i_ready & i_valid) & full;
    assign bypass_flag = (i_ready & i_valid) & empty;
    
    assign o_valid = bypass_flag ? 1'b1 : ~empty;
    assign o_ready = shift_flag  ? 1'b1 : ~full;
    assign o_pop_data = bypass_flag ? i_push_data : queue_mem[head_fifo_ptr];

    assign pop_flag    = o_valid & i_ready;
    assign push_flag   = i_valid & o_ready;
    
    always @(posedge i_clk or negedge i_rst) begin
        if (i_rst) begin
            tail <= 0;
            head <= 0;
        end else begin
            if(shift_flag) begin
                queue_mem[tail_fifo_ptr] <= i_push_data;
                tail                     <= tail+1;
                head                     <= head+1;
            end
            else if(bypass_flag) begin
                queue_mem[tail_fifo_ptr] <= queue_mem[tail_fifo_ptr];
                tail                     <= tail;
                head                     <= head;
            end 
            else if(push_flag && pop_flag) begin
                queue_mem[tail_fifo_ptr] <= i_push_data;
                tail                     <= tail+1;
                head                     <= head+1;
            end 
            else if(push_flag) begin 
                queue_mem[tail_fifo_ptr] <= i_push_data;
                tail                     <= tail+1;
                head                     <= head;
            end else if(pop_flag) begin 
                queue_mem[tail_fifo_ptr] <= queue_mem[tail_fifo_ptr];
                tail                     <= tail;
                head                     <= head+1;
            end else begin 
                queue_mem[tail_fifo_ptr] <= queue_mem[tail_fifo_ptr];
                tail                     <= tail;
                head                     <= head;
            end
        end
    end

endmodule

/*
    fifo #(
        QUEUE_PTR_BANDWIDTH(),
        ELE_BANDWIDTH()
    ) your_instance_name (
        .i_clk(),
        .i_rst(),

        //FIFO interface as rx
        .i_push_data(),
        .i_valid(),
        .o_ready(),

        //FIFO interface as tx
        .i_ready(),         
        .o_valid(),
        .o_pop_data()
    );
*/