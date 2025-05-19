`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2025 04:23:32 PM
// Design Name: 
// Module Name: ieee_754_subtractor
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


module ieee_754_subtractor(
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [31:0] result
);
    // Invert the sign bit of b to get -b; the exponent and fraction are left unchanged.
    // This works because in IEEE 754, negation is simply the inversion of the sign bit.
    wire [31:0] neg_b;
    assign neg_b = {~b[31], b[30:0]};
    
    // reuse adder module to do a + (-b).
    ieee_754_adder adder_inst (
        .a(a),
        .b(neg_b),
        .result(result)
    );
    
endmodule



