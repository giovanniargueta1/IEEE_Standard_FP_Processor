`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2025 08:20:35 PM
// Design Name: 
// Module Name: tree_adder_25bit
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
module tree_adder_25bit( 
input wire [24:0] a, 
input wire [24:0] b, 
input wire cin,
output wire [24:0] sum, 
output wire cout 
); 
    localparam N = 25;
     genvar i;



// Stage 0: Preprocessing - compute the individual propagate and generate signals.
    wire [N-1:0] p0, g0;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage0
            assign p0[i] = a[i] ^ b[i];
            assign g0[i] = a[i] & b[i];
        end
    endgenerate

// Stage 1: Combine pairs (distance = 1)
    wire [N-1:0] p1, g1;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage1
            if (i >= 1) begin
                assign p1[i] = p0[i] & p0[i-1];
                assign g1[i] = g0[i] | (p0[i] & g0[i-1]);
            end else begin
                assign p1[i] = p0[i];
                assign g1[i] = g0[i];
            end
        end 
    endgenerate

// Stage 2: Distance = 2
    wire [N-1:0] p2, g2;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage2
            if (i >= 2) begin
                assign p2[i] = p1[i] & p1[i-2];
                assign g2[i] = g1[i] | (p1[i] & g1[i-2]);
            end else begin
                assign p2[i] = p1[i];
                assign g2[i] = g1[i];
            end
        end
    endgenerate

// Stage 3: Distance = 4
    wire [N-1:0] p3, g3;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage3
            if (i >= 4) begin
                assign p3[i] = p2[i] & p2[i-4];
                assign g3[i] = g2[i] | (p2[i] & g2[i-4]);
            end else begin
                assign p3[i] = p2[i];
                assign g3[i] = g2[i];
            end
        end
    endgenerate

// Stage 4: Distance = 8
    wire [N-1:0] p4, g4;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage4
            if (i >= 8) begin
                assign p4[i] = p3[i] & p3[i-8];
                assign g4[i] = g3[i] | (p3[i] & g3[i-8]);
            end else begin
                assign p4[i] = p3[i];
                assign g4[i] = g3[i];
            end
        end
    endgenerate

// Stage 5: Distance = 16
    wire [N-1:0] p5, g5;
    generate
        for (i = 0; i < N; i = i + 1) begin : stage5
            if (i >= 16) begin
                assign p5[i] = p4[i] & p4[i-16];
                assign g5[i] = g4[i] | (p4[i] & g4[i-16]);
            end else begin
                assign p5[i] = p4[i];
                assign g5[i] = g4[i];
            end
        end 
    endgenerate


// For bit 0, the carry in is just cin.
// For bit i (i>=1), the carry into that bit is given by the prefix output of bits 0..i-1.
// Since tree is built assuming an input carry of 0, add in cin at the final stage.
    wire [N-1:0] carry;
    assign carry[0] = cin;
    generate
        for (i = 1; i < N; i = i + 1) begin : final_carry
        // For each bit i, the carry-in is g5[i-1] OR (p5[i-1] AND cin)
            assign carry[i] = g5[i-1] | (p5[i-1] & cin);
        end
    endgenerate

// Compute the sum bits.
    generate
        for (i = 0; i < N; i = i + 1) begin : sum_generation
            assign sum[i] = p0[i] ^ carry[i];
        end
    endgenerate

// The final output carry.
    assign cout = g5[N-1] | (p5[N-1] & cin);

endmodule
