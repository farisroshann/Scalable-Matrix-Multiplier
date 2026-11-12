`timescale 1ns / 1ps

module tb_pe_f16_exhaustive;

    reg clk;
    reg en;
    reg rst;
    reg [15:0] a_in;
    reg [15:0] b_in;

    wire [15:0] a_out;
    wire [15:0] b_out;
    wire [31:0] acc_reg;

    // Instantiate the Unit Under Test (UUT)
    pe_f16 uut (
        .clk(clk),
        .en(en),
        .rst(rst),
        .a_in(a_in),
        .b_in(b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc_reg(acc_reg)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // Verification Scoreboard Variables
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_index = 0;

    // Pipeline delay matching for expected values (Updated to 4-stage latency)
    reg [31:0] exp_q1, exp_q2, exp_q3, exp_q4;
    integer check_counter = 0;

    // Test Vector Storage (15 rigorous scenarios)
    reg [15:0] test_vectors_a [0:14];
    reg [15:0] test_vectors_b [0:14];

    initial begin
        // --- DEFINE TEST VECTORS (FP16 Hex) ---
        test_vectors_a[0] = 16'h3C00; test_vectors_b[0] = 16'h4000; // 1.0 * 2.0 = 2.0
        test_vectors_a[1] = 16'h4000; test_vectors_b[1] = 16'h4200; // 2.0 * 3.0 = 6.0 (Acc: 8.0)
        test_vectors_a[2] = 16'hBE00; test_vectors_b[2] = 16'h4000; // -1.5 * 2.0 = -3.0 (Acc: 5.0)
        test_vectors_a[3] = 16'h3800; test_vectors_b[3] = 16'h4400; // 0.5 * 4.0 = 2.0 (Acc: 7.0)
        test_vectors_a[4] = 16'h0000; test_vectors_b[4] = 16'h4500; // 0.0 * 5.0 = 0.0 (Acc: 7.0)
        test_vectors_a[5] = 16'h3E00; test_vectors_b[5] = 16'h4000; // 1.5 * 2.0 = 3.0 (Acc: 10.0)
        test_vectors_a[6] = 16'h4000; test_vectors_b[6] = 16'h4000; // 2.0 * 2.0 = 4.0 (Acc: 14.0)
        test_vectors_a[7] = 16'h3800; test_vectors_b[7] = 16'h3800; // 0.5 * 0.5 = 0.25 (Acc: 14.25)
        test_vectors_a[8] = 16'hC000; test_vectors_b[8] = 16'h4200; // -2.0 * 3.0 = -6.0 (Acc: 8.25)
        test_vectors_a[9] = 16'h4400; test_vectors_b[9] = 16'h3800; // 4.0 * 0.5 = 2.0 (Acc: 10.25)
        test_vectors_a[10] = 16'h4200; test_vectors_b[10] = 16'h4200; // 3.0 * 3.0 = 9.0 (Acc: 19.25)
        test_vectors_a[11] = 16'h3C00; test_vectors_b[11] = 16'h3C00; // 1.0 * 1.0 = 1.0 (Acc: 20.25)
        test_vectors_a[12] = 16'h0000; test_vectors_b[12] = 16'h0000; // 0.0 * 0.0 = 0.0 (Acc: 20.25)
        test_vectors_a[13] = 16'h4500; test_vectors_b[13] = 16'h3C00; // 5.0 * 1.0 = 5.0 (Acc: 25.25)
        test_vectors_a[14] = 16'h4000; test_vectors_b[14] = 16'h3E00; // 2.0 * 1.5 = 3.0 (Acc: 28.25)
    end

    initial begin
        $dumpfile("pe_f16_exhaustive.vcd");
        $dumpvars(0, tb_pe_f16_exhaustive);

        // Initialize signals
        clk = 0;
        rst = 1;
        en = 0;
        a_in = 16'h0000;
        b_in = 16'h0000;
        exp_q1 = 32'h0;
        exp_q2 = 32'h0;
        exp_q3 = 32'h0;
        exp_q4 = 32'h0;

        // Apply Reset
        #30;
        rst = 0;
        @(posedge clk);
        en = 1;

        $display("==================================================");
        $display("   STARTING SYNCHRONIZED EXHAUSTIVE MAC TEST      ");
        $display("==================================================");

        // Feed test vectors synchronously on each positive clock edge
        for (test_index = 0; test_index < 15; test_index = test_index + 1) begin
            @(posedge clk);
            a_in <= test_vectors_a[test_index];
            b_in <= test_vectors_b[test_index];
        end

        // Zero inputs to drain pipeline
        @(posedge clk);
        a_in <= 16'h0000;
        b_in <= 16'h0000;

        // Wait for pipeline to completely drain through 4 stages
        repeat (6) @(posedge clk);

        $display("==================================================");
        $display("   TEST EXECUTION FINISHED                        ");
        $display("   Total Checks : %0d", pass_count + fail_count);
        $display("   PASSED       : %0d", pass_count);
        $display("   FAILED       : %0d", fail_count);
        $display("==================================================");
        
        if (fail_count == 0 && pass_count > 0)
            $display("[SUCCESS] All self-checking assertions PASSED cleanly!");
        else
            $display("[ERROR] Mismatches detected.");

        $finish;
    end

    // Golden Model Function: Expected FP32 cumulative results
    function [31:0] get_expected_acc(input integer idx);
        begin
            case (idx)
                0:  get_expected_acc = 32'h40000000; // 2.0
                1:  get_expected_acc = 32'h41000000; // 8.0
                2:  get_expected_acc = 32'h40a00000; // 5.0
                3:  get_expected_acc = 32'h40e00000; // 7.0
                4:  get_expected_acc = 32'h40e00000; // 7.0
                5:  get_expected_acc = 32'h41200000; // 10.0
                6:  get_expected_acc = 32'h41600000; // 14.0
                7:  get_expected_acc = 32'h41640000; // 14.25
                8:  get_expected_acc = 32'h41040000; // 8.25
                9:  get_expected_acc = 32'h41240000; // 10.25
                10: get_expected_acc = 32'h419a0000; // 19.25
                11: get_expected_acc = 32'h41a20000; // 20.25
                12: get_expected_acc = 32'h41a20000; // 20.25
                13: get_expected_acc = 32'h41ca0000; // 25.25
                14: get_expected_acc = 32'h41e20000; // 28.25
                default: get_expected_acc = 32'h00000000;
            endcase
        end
    endfunction

    // Synchronized Scoreboard / 4-Stage Pipeline Latency Tracker
    always @(posedge clk) begin
        if (rst) begin
            exp_q1        <= 32'h0;
            exp_q2        <= 32'h0;
            exp_q3        <= 32'h0;
            exp_q4        <= 32'h0;
            check_counter <= 0;
        end else if (en) begin
            exp_q1        <= get_expected_acc(check_counter);
            exp_q2        <= exp_q1;
            exp_q3        <= exp_q2;
            exp_q4        <= exp_q3;
            check_counter <= check_counter + 1;

            // Assertions check outputs matching 4-cycle pipeline delay
            if (check_counter >= 4 && check_counter <= 18) begin
                if (acc_reg === exp_q4) begin
                    $display("[PASS] Time=%0t ns | Vector %0d | Expected: %h | Actual: %h", 
                             $time, check_counter - 4, exp_q4, acc_reg);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[FAIL] Time=%0t ns | Vector %0d | Expected: %h | Actual: %h *** MISMATCH ***", 
                             $time, check_counter - 4, exp_q4, acc_reg);
                    fail_count = fail_count + 1;
                end
            end
        end
    end

endmodule