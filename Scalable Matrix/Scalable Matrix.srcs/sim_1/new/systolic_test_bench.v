`timescale 1ns / 1ps

module systolic_test_bench;

    reg         clk = 0;
    reg         rst;
    reg         en;
    reg  [63:0] a_in;
    reg  [63:0] b_col_in;
    wire [511:0] acc_out_grid;

    // Instantiate the 4x4 Systolic Array
    systolic_array_4x4 uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_col_in(b_col_in),
        .acc_out_grid(acc_out_grid)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Real-number conversion helper (FP16 -> real)
    // ------------------------------------------------------------------
    function real h2r;
        input [15:0] x;
        integer ex;
        real    m;
        begin
            ex = x[14:10];
            if (ex == 0) h2r = 0.0;
            else begin
                ex = ex - 15;
                m  = 1.0 + x[9:0] / 1024.0;
                h2r = m * (2.0 ** ex);
                if (x[15]) h2r = -h2r;
            end
        end
    endfunction

    // Helper function to extract FP32/accumulated value from grid and convert to real
    function real f32_to_real;
        input [31:0] x;
        integer ex;
        real    m;
        begin
            ex = x[30:23];
            if (ex == 0) f32_to_real = 0.0;
            else begin
                ex = ex - 127;
                m  = 1.0 + x[22:0] / 8388608.0;
                f32_to_real = m * (2.0 ** ex);
                if (x[31]) f32_to_real = -f32_to_real;
            end
        end
    endfunction

    integer errors, checks;
    integer r, c;
    real expected_acc [0:3][0:3];
    real actual_val;
    real diff;

    initial begin
        // Initialize signals
        rst = 1;
        en = 0;
        a_in = 64'd0;
        b_col_in = 64'd0;
        errors = 0;
        checks = 0;

        // Initialize software reference matrix accumulator to 0.0
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                expected_acc[r][c] = 0.0;
            end
        end

        // Apply Reset
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        $display("==================================================");
        $display("   STARTING ADVANCED 4x4 SYSTOLIC ARRAY TEST      ");
        $display("==================================================");

        en = 1;

        // --- Pattern Wave 1 ---
        // Using non-zero FP16 values: 
        // 16'h3C00 = 1.0, 16'h4000 = 2.0, 16'h4200 = 3.0, 16'h4400 = 4.0
        
        // Drive Row Inputs (A)
        a_in = {16'h4400, 16'h4200, 16'h4000, 16'h3C00}; // [4.0, 3.0, 2.0, 1.0]
        // Drive Column Inputs (B)
        b_col_in = {16'h3C00, 16'h4000, 16'h4200, 16'h4400}; // [1.0, 2.0, 3.0, 4.0]
        
        // Update software expected accumulator model for Wave 1
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                expected_acc[r][c] = expected_acc[r][c] + (h2r(a_in[r*16 +: 16]) * h2r(b_col_in[c*16 +: 16]));
            end
        end
        @(negedge clk);

        // --- Pattern Wave 2 ---
        a_in = {16'h4000, 16'h3C00, 16'h4400, 16'h4200}; // [2.0, 1.0, 4.0, 3.0]
        b_col_in = {16'h4200, 16'h3C00, 16'h4400, 16'h4000}; // [3.0, 1.0, 4.0, 2.0]

        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                expected_acc[r][c] = expected_acc[r][c] + (h2r(a_in[r*16 +: 16]) * h2r(b_col_in[c*16 +: 16]));
            end
        end
        @(negedge clk);

        // Turn off input stream and let pipeline flush through the 4x4 grid
        a_in     = 64'd0;
        b_col_in = 64'd0;
        en       = 0;

        // Allow sufficient cycles for 2-stage pipeline and propagation across grid
        repeat (8) @(negedge clk);

        // --- Final Verification Phase ---
        $display("\n--- Verifying Hardware Accumulators vs Golden Model ---");
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                checks = checks + 1;
                actual_val = f32_to_real(acc_out_grid[(r*4 + c)*32 +: 32]);
                diff = actual_val - expected_acc[r][c];
                if (diff < 0.0) diff = -diff;

                // Allow small floating-point tolerance
                if (diff > 0.05) begin
                    errors = errors + 1;
                    $display("[FAIL] PE[%0d][%0d]: Expected = %f, Actual = %f", r, c, expected_acc[r][c], actual_val);
                end else begin
                    $display("[PASS] PE[%0d][%0d]: Expected = %f, Actual = %f", r, c, expected_acc[r][c], actual_val);
                end
            end
        end

        $display("==================================================");
        $display("   TEST SUMMARY: Checks = %0d | Errors = %0d", checks, errors);
        if (errors == 0)
            $display("   RESULT: ALL TESTS PASSED SUCCESSFULLY!         ");
        else
            $display("   RESULT: TESTS FAILED WITH ERRORS.              ");
        $display("==================================================");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("TIMEOUT: Simulation took too long.");
        $finish;
    end

endmodule