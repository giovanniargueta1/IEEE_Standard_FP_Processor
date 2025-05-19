`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2025 04:27:10 PM
// Design Name: 
// Module Name: ieee_754_subtractor_tb
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


`timescale 1ns/1ps 

module ieee_754_subtractor_tb;
    // Inputs
    reg [31:0] a, b;
    
    // Output from DUT
    wire [31:0] result;
    
    // For debugging and test verification
    reg [31:0] expected;
    
    // Instantiate 
    ieee_754_subtractor dut (
        .a(a),
        .b(b),
        .result(result)
    );
    
    
    reg [31:0] test_a [10:0];
    reg [31:0] test_b [10:0];
    reg [31:0] test_expected [10:0];
    
    // Task to display IEEE 754 components
    task display_ieee754;
        input [31:0] value;
        input [7:0] id;
        reg sign;
        reg [7:0] exp;
        reg [22:0] frac;
        begin
            sign = value[31];
            exp  = value[30:23];
            frac = value[22:0];
            $display("Value %0d: 0x%h - Sign: %b, Exp: %d (0x%h), Mantissa: 0x%h", 
                id, value, sign, exp, exp, frac);
        end
    endtask
    
    // Task to check test results
    task check_result;
        input [3:0] test_num;
        integer int_exp_diff;
        real real_factor;
        begin
            a = test_a[test_num];
            b = test_b[test_num];
            expected = test_expected[test_num];
            
            #10; 
            
            $display("\n------------- Test %0d -------------", test_num);
            display_ieee754(a, 8'd1);
            display_ieee754(b, 8'd2);
            display_ieee754(expected, 8'd3);
            display_ieee754(result, 8'd4);
            
            $display("Bit-by-bit comparison:");
            $display("Expected: %b", expected);
            $display("Result:   %b", result);
            $display("Exponent comparison: Expected: %d, Result: %d, Difference: %d", 
                expected[30:23], result[30:23], $signed(result[30:23] - expected[30:23]));
            $display("Mantissa comparison: Expected: 0x%h, Result: 0x%h", 
                expected[22:0], result[22:0]);
            
            if (result == expected)
                $display("*** TEST PASSED ***");
            else
                $display("*** TEST FAILED ***");
                
            if (result != expected) begin
                if (result[30:23] == expected[30:23] + 8'd1)
                    $display("Problem: Exponent is exactly 1 higher than expected!");
                if (result[22:0] == {expected[21:0], 1'b0})
                    $display("Problem: Mantissa appears to be shifted left by 1 bit!");
                if (result[31] != expected[31])
                    $display("Problem: Sign bit is incorrect!");
                    
                if (result[30:23] != 0 && expected[30:23] != 0 && 
                    !(&result[30:23]) && !(&expected[30:23])) begin
                    int_exp_diff = result[30:23] - expected[30:23];
                    real_factor = 1.0;
                    if (int_exp_diff > 0)
                        repeat (int_exp_diff) real_factor = real_factor * 2.0;
                    else if (int_exp_diff < 0)
                        repeat (-int_exp_diff) real_factor = real_factor / 2.0;
                    $display("Approximate factor difference: 2^%0d = %f", int_exp_diff, real_factor);
                end
            end
            
            $display("----------------------------------\n");
        end
    endtask
    
    // Test vectors for subtraction.
    // (All values are in IEEE 754 hex representation.)
    // Test 0: 3.0 - 2.0 = 1.0
    // 3.0 : 0x40400000, 2.0 : 0x40000000, 1.0 : 0x3F800000
    initial begin
        test_a[0] = 32'h40400000;        // 3.0
        test_b[0] = 32'h40000000;        // 2.0
        test_expected[0] = 32'h3F800000;   // 1.0
        
        // Test 1: 4.0 - 2.0 = 2.0
        test_a[1] = 32'h40800000;        // 4.0
        test_b[1] = 32'h40000000;        // 2.0
        test_expected[1] = 32'h40000000;   // 2.0
        
        // Test 2: 2.0 - 2.0 = 0.0
        test_a[2] = 32'h40000000;        // 2.0
        test_b[2] = 32'h40000000;        // 2.0
        test_expected[2] = 32'h00000000;   // 0.0
        
        // Test 3: -2.0 - 3.0 = -5.0
        // -2.0: 0xC0000000, 3.0: 0x40400000, -5.0: 0xC0A00000
        test_a[3] = 32'hC0000000;        // -2.0
        test_b[3] = 32'h40400000;        // 3.0
        test_expected[3] = 32'hC0A00000;   // -5.0
        
        // Test 4: (-3.0) - (-2.0) = -1.0
        // -3.0: 0xC0400000, -2.0: 0xC0000000, -1.0: 0xBF800000
        test_a[4] = 32'hC0400000;        
        test_b[4] = 32'hC0000000;
        test_expected[4] = 32'hBF800000;
        
        // Test 5: (-1.0) - 0.375 = -1.375
        // -1.0: 0xBF800000, 0.375: 0x3EA00000, -1.375: 0xBFA80000
        test_a[5] = 32'hBF800000;        
        test_b[5] = 32'h3EA00000;        
        test_expected[5] = 32'hBFA80000;
        
        // Test 6: 0.0 - (-0.0) = +0.0
        test_a[6] = 32'h00000000;        
        test_b[6] = 32'h80000000;        
        test_expected[6] = 32'h00000000;
        
        // Test 7: Inf - 2.0 = Inf
        test_a[7] = 32'h7F800000;        
        test_b[7] = 32'h40000000;        
        test_expected[7] = 32'h7F800000;
        
        // Test 8: Inf - Inf = NaN
        test_a[8] = 32'h7F800000;        
        test_b[8] = 32'h7F800000;        
        test_expected[8] = 32'h7FC00000;
        
        // Test 9: NaN - 2.0 = NaN
        test_a[9] = 32'h7FC00000;        
        test_b[9] = 32'h40000000;        
        test_expected[9] = 32'h7FC00000;
        
        // Test 10: (-Large) - (Large) = -Inf
        // For instance, use -Largest finite and Largest finite.
        test_a[10] = 32'hFF7FFFFF;   // -Largest finite
        test_b[10] = 32'h7F7FFFFF;   // Largest finite
        test_expected[10] = 32'hFF800000; // -Inf (underflow to -infinity)
        
        $display("Starting IEEE 754 Single Precision Subtractor tests with Round to Negative Infinity");
        
        // Run tests
        check_result(0);
        check_result(1);
        check_result(2);
        check_result(3);
        check_result(4);
        check_result(5);
        check_result(6);
        check_result(7);
        check_result(8);
        check_result(9);
        check_result(10);
        
        $display("\nAll tests completed");
        $finish;
    end
    
endmodule

