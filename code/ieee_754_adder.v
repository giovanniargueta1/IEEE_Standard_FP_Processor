module ieee_754_adder(
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [31:0] result
);

    // Extract components from IEEE 754 values
    wire a_sign = a[31];
    wire b_sign = b[31];
    wire [7:0] a_exp = a[30:23];
    wire [7:0] b_exp = b[30:23];
    wire [22:0] a_mantissa = a[22:0];
    wire [22:0] b_mantissa = b[22:0];
    
    // Check for special cases
    wire a_is_zero = (a_exp == 8'b0) && (a_mantissa == 23'b0);
    wire b_is_zero = (b_exp == 8'b0) && (b_mantissa == 23'b0);
    wire a_is_inf = (a_exp == 8'hFF) && (a_mantissa == 23'b0);
    wire b_is_inf = (b_exp == 8'hFF) && (b_mantissa == 23'b0);
    wire a_is_nan = (a_exp == 8'hFF) && (a_mantissa != 23'b0);
    wire b_is_nan = (b_exp == 8'hFF) && (b_mantissa != 23'b0);
    
    // Internal signals for calculation
    reg a_gt_b;               // Is A > B in magnitude
    reg [7:0] exp_diff;       // Exponent difference
    reg [7:0] result_exp;     // Result exponent
    reg result_sign;          // Result sign
    ///reg [24:0] a_mant, b_mant; // Mantissas with implicit bit (24 bit)
    reg [24:0] aligned_a, aligned_b; // Aligned mantissas
    reg [24:0] add_result;    // Result of mantissa addition
    reg [24:0] norm_result;   // Normalized mantissa result
    reg [4:0] norm_shift;     // Normalization shift amount
    
    // Handle special cases
    reg is_special_case;
    reg [31:0] special_result;
    
    always @(*) begin
        is_special_case = 0;
        special_result = 32'b0;
        
        if (a_is_nan || b_is_nan) begin
            is_special_case = 1;
            special_result = 32'h7FC00000; // NaN
        end
        else if (a_is_inf && b_is_inf) begin
            is_special_case = 1;
            if (a_sign == b_sign)
                special_result = {a_sign, 8'hFF, 23'b0}; // Infinity with same sign
            else
                special_result = 32'h7FC00000; // NaN (inf - inf)
        end
        else if (a_is_inf) begin
            is_special_case = 1;
            special_result = {a_sign, 8'hFF, 23'b0}; // a is Inf
        end
        else if (b_is_inf) begin
            is_special_case = 1;
            special_result = {b_sign, 8'hFF, 23'b0}; // b is Inf
        end
        else if (a_is_zero && b_is_zero) begin
            is_special_case = 1;
            // For RTN, return -0 if either input is -0
            special_result = (a_sign || b_sign) ? 32'h80000000 : 32'h00000000;
        end
        else if (a_is_zero) begin
            is_special_case = 1;
            special_result = b; // If a is zero, return b
        end
        else if (b_is_zero) begin
            is_special_case = 1;
            special_result = a; // If b is zero, return a
        end
    end
    
    // Step 1: Calculate effective operation (addition or subtraction)
    wire effective_subtraction = a_sign ^ b_sign;
    
    // Step 2: Prepare mantissas with implicit bit
    reg [23:0] a_mant24, b_mant24;
    always @(*) begin
        // Get mantissa with implicit bit
        a_mant24 = (a_exp == 0) ? {1'b0, a_mantissa} : {1'b1, a_mantissa};
        b_mant24 = (b_exp == 0) ? {1'b0, b_mantissa} : {1'b1, b_mantissa};
    end
    
    // Step 3: Compare magnitudes and determine larger operand
    always @(*) begin
        if (a_exp > b_exp) begin
            a_gt_b = 1;
            exp_diff = a_exp - b_exp;
        end else if (a_exp < b_exp) begin
            a_gt_b = 0;
            exp_diff = b_exp - a_exp;
        end else begin
            // Equal exponents, compare mantissas
            a_gt_b = (a_mant24 >= b_mant24);
            exp_diff = 0;
        end
    end
    
    // Step 4: Align mantissas (shift smaller number right)
      
    
    reg [7:0] aligned_exp;
    // Extend each 24-bit significand to 25 bits by prepending a 0 instead of appending.
    always @(*) begin
        if (a_gt_b) begin
            aligned_a = {1'b0, a_mant24};
            aligned_b = (exp_diff >= 25 ? 25'b0 : ({1'b0, b_mant24} >> exp_diff));
            aligned_exp = a_exp;
        end else begin
            aligned_a = {1'b0, b_mant24};
            aligned_b = (exp_diff >= 25 ? 25'b0 : ({1'b0, a_mant24} >> exp_diff));
            aligned_exp = b_exp;
        end
    end
    
    // Step 5: Perform addition or subtraction
    wire [24:0] add_a, add_b;
    wire add_cin;
    wire [24:0] add_sum;
    wire add_cout;
    
    // Prepare inputs for adder
    assign add_a = aligned_a;
    assign add_b = effective_subtraction ? ~aligned_b : aligned_b;
    assign add_cin = effective_subtraction ? 1'b1 : 1'b0;
    
    // Instantiate adder
    tree_adder_25bit adder (
        .a(add_a),
        .b(add_b),
        .cin(add_cin),
        .sum(add_sum),
        .cout(add_cout)
    );
    
    // Step 6: Determine sign of the result and compute absolute result
    always @(*) begin
        if (!effective_subtraction) begin
            // Addition - result has the sign of inputs
            result_sign = a_gt_b ? a_sign : b_sign;
            add_result = add_sum;
        end else begin
            // Subtraction
            if (a_gt_b) begin
                // |A| > |B|, sign is A's sign
                result_sign = a_sign;
                add_result = add_sum;
            end else begin
                // |A| < |B|, sign is opposite of B's sign
                result_sign = b_sign;
                if (add_sum[24] == 1'b1) 
                    // Result is negative, get two's complement
                    add_result = ~add_sum + 1'b1;
                else
                    add_result = add_sum;
                end
            end
        end
    
    
    // Step 7: Check for zero result
    wire is_zero_result = (add_result == 25'b0);
    reg [7:0] norm_exp;
    // Step 8: Normalize the result
    always @(*) begin
        norm_exp = aligned_exp;
        if (!is_zero_result) begin
            if (add_result[24]) begin
                // Leading 1 is in bit 24, shift right
                norm_result = add_result >> 1;
                norm_exp = norm_exp + 8'd1;
            end else begin
                // Find leading 1 and shift left
                casex (add_result)
                    25'b01xxxxxxxxxxxxxxxxxxxxxxx: norm_shift = 5'd0;
                    25'b001xxxxxxxxxxxxxxxxxxxxxx: norm_shift = 5'd1; 
                    25'b0001xxxxxxxxxxxxxxxxxxxxx: norm_shift = 5'd2; 
                    25'b00001xxxxxxxxxxxxxxxxxxxx: norm_shift = 5'd3; 
                    25'b000001xxxxxxxxxxxxxxxxxxx: norm_shift = 5'd4; 
                    25'b0000001xxxxxxxxxxxxxxxxxx: norm_shift = 5'd5; 
                    25'b00000001xxxxxxxxxxxxxxxxx: norm_shift = 5'd6; 
                    25'b000000001xxxxxxxxxxxxxxxx: norm_shift = 5'd7; 
                    25'b0000000001xxxxxxxxxxxxxxx: norm_shift = 5'd8; 
                    25'b00000000001xxxxxxxxxxxxxx: norm_shift = 5'd9; 
                    25'b000000000001xxxxxxxxxxxxx: norm_shift = 5'd10; 
                    25'b0000000000001xxxxxxxxxxxx: norm_shift = 5'd11; 
                    25'b00000000000001xxxxxxxxxxx: norm_shift = 5'd12; 
                    25'b000000000000001xxxxxxxxxx: norm_shift = 5'd13; 
                    25'b0000000000000001xxxxxxxxx: norm_shift = 5'd14; 
                    25'b00000000000000001xxxxxxxx: norm_shift = 5'd15; 
                    25'b000000000000000001xxxxxxx: norm_shift = 5'd16; 
                    25'b0000000000000000001xxxxxx: norm_shift = 5'd17; 
                    25'b00000000000000000001xxxxx: norm_shift = 5'd18; 
                    25'b000000000000000000001xxxx: norm_shift = 5'd19; 
                    25'b0000000000000000000001xxx: norm_shift = 5'd20; 
                    25'b00000000000000000000001xx: norm_shift = 5'd21; 
                    25'b000000000000000000000001x: norm_shift = 5'd22; 
                    25'b0000000000000000000000001: norm_shift = 5'd23; 
                    default:                       norm_shift = 5'd24; 
                endcase
                
                // If normalization would underflow exponent, cap the shift
                if (norm_shift >= norm_exp && norm_exp != 0) begin
                    norm_shift = norm_exp - 8'd1;
                    norm_exp = 8'd0;
                end else begin
                    norm_exp = norm_exp - norm_shift;
                end
                
                // Perform the shift
                norm_result = add_result << norm_shift;
            end
        end else begin
            // Result is zero
            norm_result = 25'd0;
            norm_exp = 8'd0;
            // For RTN, if either input is negative, result is -0
            result_sign = 1'b0;
        end
        result_exp = norm_exp;
    end
    
    // Step 9: Handle overflow
    wire overflow = (result_exp >= 8'd255);
    
    // Step 10: Round to negative infinity
    reg [22:0] result_mantissa;
    
    always @(*) begin
        // Default: truncate
        result_mantissa = norm_result[22:0];
        // if negative and if low-order bit was 1, bump mantissa
        if (result_sign && norm_result[0]) begin
            result_mantissa = norm_result[22:0] + 1'b1;
        end
    end
    
    // Step 11: Compose final result
    assign result = is_special_case ? special_result :
                   is_zero_result ? {result_sign, 31'b0} :
                   overflow ? {result_sign, 8'hFF, 23'b0} : // Infinity
                   {result_sign, result_exp, result_mantissa};

endmodule

