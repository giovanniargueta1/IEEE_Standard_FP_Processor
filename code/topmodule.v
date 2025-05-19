`timescale 1ns / 1ps

module topmodule (
    input wire clk_100MHz, 
    input wire reset, 
    input wire rx, 
    input wire rx_irq, 
    input wire tx_irq,
    output wire tx,
    output wire [3:0] write_pointer, read_pointer,
    output wire full_flag, empty_flag, clock_1hz,
    output wire SDA, SCL,
    inout wire m_sda,
    output wire m_scl
);

    // Signals
    wire rx_done_tick, tx_done_tick;
    wire [7:0] rec_data, fifo_data_out;
    wire fifo_full, fifo_empty;
    wire clk_1Hz;
    reg fifo_read;
    reg [7:0] fifo_byte;
    reg [7:0] memblock [0:8];
    reg [3:0] counter;
    reg [2:0] read_index;
    reg [31:0] input_A, input_B;
    reg [1:0]  opcode;
    reg i2c_en;
    reg [4:0] state;

    // IEEE 754 calculation signals
    wire [31:0] add_result, sub_result;
    reg [31:0] result;

    localparam IDLE = 0, WAIT_LOAD = 1, LOAD_A = 2, LOAD_A1 = 3, LOAD_A2 = 4, LOAD_A3 = 5, LOAD_A4 = 6,
                     LOAD_B = 7, LOAD_B1 = 8, LOAD_B2 = 9, LOAD_B3 = 10, LOAD_B4 = 11,
                     LOAD_OP = 12, LOAD_OP1 = 13, SEND_PACKET = 14, WAIT_PACKET = 15;

    assign write_pointer = FIFO_UNIT.WR_ptr[3:0];
    assign read_pointer = FIFO_UNIT.RD_ptr[3:0];
    assign full_flag = fifo_full;
    assign empty_flag = fifo_empty;
    assign SDA = m_sda;
    assign SCL = m_scl;
    assign clock_1hz = clk_1Hz;

    
    reg [97:0] i2c_data;
    wire [31:0] master_data_out;
    wire ready;
    wire clk_10Hz;
    
    // Instantiate IEEE 754 adder and subtractor modules
    ieee_754_adder adder_inst (
        .a(input_A),
        .b(input_B),
        .result(add_result)
    );
    
    ieee_754_subtractor subtractor_inst (
        .a(input_A),
        .b(input_B),
        .result(sub_result)
    );
    
    // Clock divider
    clock_divider #(.DIVISOR(49999999)) CLOCK_DIV1 (
        .clk(clk_100MHz),
        .reset(reset),
        .clk_out(clk_1Hz)
    );
    clock_divider #(.DIVISOR(4999999)) CLOCK_DIV2 (
        .clk(clk_100MHz),
        .reset(reset),
        .clk_out(clk_10Hz)
    );

    always @(posedge clk_10Hz or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            fifo_read <= 0;
            i2c_en <= 0;
            counter <= 0;
            read_index <= 0;
            result <= 32'h0;
        end else begin
            fifo_read <= 0;

            case (state)
                IDLE: begin
                    i2c_en <= 0;
                    if (!fifo_empty && (FIFO_UNIT.filled_count >= 9)) begin
                        read_index <= 0;
                        state <= WAIT_LOAD;
                    end
                end
                
                WAIT_LOAD: begin
                    state <= LOAD_A;
                end
                
                // LOAD A
                LOAD_A: begin fifo_read <= 1; state <= LOAD_A1; i2c_en <= 0; end
                
                LOAD_A1: begin memblock[0] <= fifo_data_out; fifo_read <= 1; state <= LOAD_A2; end
                
                LOAD_A2: begin memblock[1] <= fifo_data_out; fifo_read <= 1; state <= LOAD_A3; end
                
                LOAD_A3: begin memblock[2] <= fifo_data_out; fifo_read <= 1; state <= LOAD_A4; end
                
                LOAD_A4: begin 
                    memblock[3] <= fifo_data_out;
                    state <= LOAD_B;
                    fifo_read <= 1;
                end

                // LOAD B
                LOAD_B: begin fifo_read <= 1; state <= LOAD_B1; input_A <= {memblock[1], memblock[2], memblock[3], fifo_data_out}; end
                LOAD_B1: begin memblock[4] <= fifo_data_out; fifo_read <= 1; state <= LOAD_B2; end
                LOAD_B2: begin memblock[5] <= fifo_data_out; fifo_read <= 1; state <= LOAD_B3; end
                LOAD_B3: begin memblock[6] <= fifo_data_out; fifo_read <= 1; state <= LOAD_B4; end
                LOAD_B4: begin
                    memblock[7] <= fifo_data_out;
                    input_B <= {memblock[4], memblock[5], memblock[6], fifo_data_out};
                    state <= LOAD_OP;
                    fifo_read <= 1;
                end

                // LOAD OPCODE
                LOAD_OP: begin fifo_read <= 1; state <= LOAD_OP1; end
                LOAD_OP1: begin
                    memblock[8] <= fifo_data_out;
                    opcode <= fifo_data_out[1:0];
                    
                    // Select result based on opcode
                    case (fifo_data_out[1:0])
                        2'b00: result <= add_result;      // Addition
                        2'b01: result <= sub_result;      // Subtraction
                        default: result <= 32'h0;         // For all other opcodes (including 10 for multiplication)
                    endcase
                    
                    state <= SEND_PACKET;
                end
                
                // Assemble and send full 98-bit packet
                SEND_PACKET: begin
                    i2c_data <= {input_A, input_B, opcode, result};  // 32+32+2+32 = 98 bits
                    i2c_en <= 1;
                    state <= WAIT_PACKET;
                end

                WAIT_PACKET: begin
                    i2c_en <= 0;
                    if (ready) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // UART
    uart_top #(.DBITS(8), .SB_TICK(16), .BR_LIMIT(651), .BR_BITS(10), .FIFO_EXP(2)) UART_UNIT (
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .read_uart(rx_irq),
        .write_uart(),
        .rx(rx),
        .write_data(fifo_data_out),
        .rx_done_tick(rx_done_tick),
        .tx_done_tick(tx_done_tick),
        .read_data(rec_data),
        .tx(tx)
    );

    // FIFO
    fifo #(.DEPTH(9), .WIDTH(8)) FIFO_UNIT (
        .wr_clk(clk_100MHz),
        .rd_clk(clk_10Hz),
        .reset(reset),
        .read(fifo_read),
        .write(rx_done_tick),
        .data_in(rec_data),
        .data_out(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    // I2C Master
    i2c_master #(.WIDTH(98)) i2c_Master (
        .clk(clk_10Hz),
        .rst(reset),
        .data_in(i2c_data),
        .enable(i2c_en),
        .rw(1'b0),
        .data_out(master_data_out),
        .ready(ready),
        .i2c_sda(m_sda),
        .i2c_scl(m_scl)
    );

endmodule