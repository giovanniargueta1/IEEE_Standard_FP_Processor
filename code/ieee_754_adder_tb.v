`timescale 1ns/1ps

module ieee_754_adder_tb;
    // Inputs
    reg [31:0] a, b;
    
    // Outputs
    wire [31:0] result;
    
    // For debugging
    reg [31:0] expected;
    
    // Instantiate  
    ieee_754_adder dut (
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
            exp = value[30:23];
            frac = value[22:0];
            
            $display("Value %0d: 0x%h - Sign: %b, Exp: %d (0x%h), Mantissa: 0x%h", 
                    id, value, sign, exp, exp, frac);
        end
    endtask
    
    // Task to check test result
    task check_result;
        input [3:0] test_num;
        
        // Variables used within the task
        integer int_exp_diff;
        real real_factor;
        
        begin
            a = test_a[test_num];
            b = test_b[test_num];
            expected = test_expected[test_num];
            
            #10; // Wait for computation
            
            $display("\n------------- Test %0d -------------", test_num);
            display_ieee754(a, 8'd1);
            display_ieee754(b, 8'd2);
            display_ieee754(expected, 8'd3);
            display_ieee754(result, 8'd4);
            
            // Additional debugging information
            $display("Bit-by-bit comparison:");
            $display("Expected: %b", expected);
            $display("Result:   %b", result);
            
            // Check exponents
            $display("Exponent comparison: Expected: %d, Result: %d, Difference: %d", 
                    expected[30:23], result[30:23], $signed(result[30:23] - expected[30:23]));
            
            // Check mantissas
            $display("Mantissa comparison: Expected: 0x%h, Result: 0x%h", 
                    expected[22:0], result[22:0]);
            
            if (result == expected)
                $display("*** TEST PASSED ***");
            else
                $display("*** TEST FAILED ***");
            
            // Additional analysis for failed tests
            if (result != expected) begin
                // Check for specific patterns of failure
                if (result[30:23] == expected[30:23] + 8'd1) begin
                    $display("Problem: Exponent is exactly 1 higher than expected!");
                end
                
                if (result[22:0] == {expected[21:0], 1'b0}) begin
                    $display("Problem: Mantissa appears to be shifted left by 1 bit!");
                end
                
                if (result[31] != expected[31]) begin
                    $display("Problem: Sign bit is incorrect!");
                end
                
                // Try to calculate the difference as a real number
                if (result[30:23] != 0 && expected[30:23] != 0 && 
                    !(&result[30:23]) && !(&expected[30:23])) begin
                    // Simple approximation of real value comparison
                    int_exp_diff = result[30:23] - expected[30:23];
                    real_factor = 1.0;
                    
                    // Calculate 2^int_exp_diff manually
                    if (int_exp_diff > 0) begin
                        repeat (int_exp_diff) real_factor = real_factor * 2.0;
                    end else if (int_exp_diff < 0) begin
                        repeat (-int_exp_diff) real_factor = real_factor / 2.0;
                    end
                    
                    $display("Approximate factor difference: 2^%0d = %f", 
                            int_exp_diff, real_factor);
                end
            end
            
            $display("----------------------------------\n");
        end
    endtask
    
    // Test vectors and simulation
    initial begin
        // Initialize test vectors
        // Test 1: 1.0 + 2.0 = 3.0
        test_a[0] = 32'h3F800000;        // 1.0
        test_b[0] = 32'h40000000;        // 2.0
        test_expected[0] = 32'h40400000; // 3.0
        
        // Test 2: 2.0 + 4.0 = 6.0
        test_a[1] = 32'h40000000;        // 2.0
        test_b[1] = 32'h40800000;        // 4.0
        test_expected[1] = 32'h40C00000; // 6.0
        
        // Test 3: 2.0 + (-2.0) = 0.0
        test_a[2] = 32'h40000000;        // 2.0
        test_b[2] = 32'hC0000000;        // -2.0
        test_expected[2] = 32'h00000000; // 0.0
        
        // Test 4: 3.0 + (-2.0) = 1.0
        test_a[3] = 32'h40400000;        // 3.0
        test_b[3] = 32'hC0000000;        // -2.0
        test_expected[3] = 32'h3F800000; // 1.0
        
        // Test 5: 2.0 + (-3.0) = -1.0
        test_a[4] = 32'h40000000;        // 2.0
        test_b[4] = 32'hC0400000;        // -3.0
        test_expected[4] = 32'hBF800000; // -1.0
        
        // Test 6: -1.0 + (-0.375) = -1.375
        test_a[5] = 32'hBF800000;        // -1.0
        test_b[5] = 32'hBEC00000;        // -0.375
        test_expected[5] = 32'hBFB00000; // -1.375
        
        // Test 7: 0.0 + (-0.0) = -0.0 (RTN)
        test_a[6] = 32'h00000000;        // 0.0
        test_b[6] = 32'h80000000;        // -0.0
        test_expected[6] = 32'h80000000; // -0.0
        
        // Test 8: Inf + 2.0 = Inf
        test_a[7] = 32'h7F800000;        // Inf
        test_b[7] = 32'h40000000;        // 2.0
        test_expected[7] = 32'h7F800000; // Inf
        
        // Test 9: Inf + (-Inf) = NaN
        test_a[8] = 32'h7F800000;        // Inf
        test_b[8] = 32'hFF800000;        // -Inf
        test_expected[8] = 32'h7FC00000; // NaN
        
        // Test 10: NaN + 2.0 = NaN
        test_a[9] = 32'h7FC00000;        // NaN
        test_b[9] = 32'h40000000;        // 2.0
        test_expected[9] = 32'h7FC00000; // NaN
        
        // Test 11: Large + Large = Inf
        test_a[10] = 32'h7F7FFFFF;       // Almost Inf
        test_b[10] = 32'h7F7FFFFF;       // Almost Inf
        test_expected[10] = 32'h7F800000; // Inf
        
        $display("Starting IEEE 754 Single Precision Adder tests with Round to Negative Infinity");
        
        // Run all tests
        check_result(0);  // Test 1
        check_result(1);  // Test 2
        check_result(2);  // Test 3
        check_result(3);  // Test 4
        check_result(4);  // Test 5
        check_result(5);  // Test 6
        check_result(6);  // Test 7
        check_result(7);  // Test 8
        check_result(8);  // Test 9
        check_result(9);  // Test 10
        check_result(10); // Test 11
        
        $display("\nAll tests completed");
        $finish;
    end
    
endmodule