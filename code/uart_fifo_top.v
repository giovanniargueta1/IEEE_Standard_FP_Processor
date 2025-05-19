`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/26/2025 02:59:01 PM
// Design Name: 
// Module Name: uart_fifo_top
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

module uart_fifo_top(
    input           clk_100MHz,
    input           reset,
    input           rx,           // Serial data input from RS232
    input           removal_btn,  // Removal request button (tx_irq)
    output          tx,           // Serial data output to RS232
    output [15:0]   LED           // LED mapping for FIFO pointers and flags
);

   
    wire rx_done_tick;
    wire tx_done_tick;
    wire [7:0] uart_rx_data;
    wire uart_tx_start;   // Trigger for UART transmission
    wire [7:0] uart_tx_data; // Data to be transmitted

  
  
    uart_top UART_UNIT (
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .read_uart(1'b0),           // Not used in this design
        .write_uart(uart_tx_start), // Triggered by the removal button pulse
        .rx(rx),
        .write_data(uart_tx_data),  // Data from FIFO is sent out via UART
        .rx_done_tick(rx_done_tick),
        .tx_done_tick(tx_done_tick),
        .read_data(uart_rx_data),
        .tx(tx)
    );
    
    // FIFO signals
    wire fifo_full, fifo_empty;
    wire [7:0] fifo_data_out;
    wire [3:0] fifo_write_ptr, fifo_read_ptr;
    
    // FIFO write enable- when a byte is received and FIFO is not full
    wire fifo_wr_en = rx_done_tick && !fifo_full;
    
    // Debounce removal button 
    wire removal_btn_tick;
    debounce_explicit removal_debouncer (
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .btn(removal_btn),
        .db_level(),  
        .db_tick(removal_btn_tick)
    );
    
    // FIFO read enable- triggered by the removal button pulse if FIFO != empty
    wire fifo_rd_en = removal_btn_tick && !fifo_empty;
    
    // same pulse from the removal button to trigger UART transmission.
    assign uart_tx_start = removal_btn_tick && !fifo_empty;
    
    // FIFO (10-slot deep, 8-bit wide)
    fifo_10x8 fifo_inst (
        .clk(clk_100MHz),
        .reset(reset),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .data_in(uart_rx_data),
        .data_out(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty),
        .write_ptr(fifo_write_ptr),
        .read_ptr(fifo_read_ptr)
    );
    
    //  FIFO data output to the UART transmitter 
    assign uart_tx_data = fifo_data_out;
    

    assign LED[3:0] = fifo_write_ptr;
    assign LED[7:4] = fifo_read_ptr;
    assign LED[14] = fifo_full;
    assign LED[15] = fifo_empty;
    assign LED[13:8] = 6'b0;

endmodule
