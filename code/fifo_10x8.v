`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2025 01:47:51 PM
// Design Name: 
// Module Name: fifo_10x8
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_10x8(
    input            clk,
    input            reset,
    input            wr_en,       // Write enable
    input            rd_en,       // Read enable
    input  [7:0]     data_in,     // Data to be written
    output reg [7:0] data_out,    // Data read out
    output           full,        // FIFO full flag
    output           empty,       // FIFO empty flag
    output reg [3:0] write_ptr,   // Write pointer (for LED mapping)
    output reg [3:0] read_ptr     // Read pointer (for LED mapping)
);
    // 10 slots
    reg [7:0] mem [0:9];
    // Count register
    reg [3:0] count;
    
    // Declare loop variable at the module level
    integer i;
    
    // Generate full and empty signals
    assign full  = (count == 10);
    assign empty = (count == 0);
    
    // operation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count     <= 0;
            write_ptr <= 0;
            read_ptr  <= 0;
            data_out  <= 8'b0;
            for (i = 0; i < 10; i = i + 1) begin
                mem[i] <= 8'b0;
            end
        end
        else begin
            
            if ((wr_en && !full) && (rd_en && !empty)) begin
                // Write new data output the current data 
                mem[write_ptr] <= data_in;
                data_out <= mem[read_ptr];
                // Increment both pointers 
                write_ptr <= (write_ptr == 9) ? 0 : write_ptr + 1;
                read_ptr  <= (read_ptr  == 9) ? 0 : read_ptr + 1;
                // Count remains the same in simultaneous operation
                count <= count;
            end
            // Write only
            else if (wr_en && !full) begin
                mem[write_ptr] <= data_in;
                write_ptr <= (write_ptr == 9) ? 0 : write_ptr + 1;
                count <= count + 1;
            end
            // Read only
            else if (rd_en && !empty) begin
                data_out <= mem[read_ptr];
                read_ptr <= (read_ptr == 9) ? 0 : read_ptr + 1;
                count <= count - 1;
            end
        end
    end
endmodule

