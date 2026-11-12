`timescale 1ns / 1ps

module tb_pe_f16_advanced;

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

    initial begin
        // File dump for waveform viewing if using GTKWave
        $dumpfile("pe_f16_advanced.vcd");
        $dumpvars(0, tb_pe_f16_advanced);

        // Initialize signals
        clk  = 0;
        rst  = 1;
        en   = 0;
        a_in = 16'h0000;
        b_in = 16'h0000;

        // Hold reset active for 20ns
        #20;
        rst = 0;
        #10;
        
        en = 1;

        // -------------------------------------------------------------
        // Test 1: Positive * Positive with Accumulation
        // A = 2.0 (4000), B = 3.0 (4200) -> Product = 6.0
        // Acc = 0.0 + 6.0 = 6.0
        // -------------------------------------------------------------
        $display("--- Test 1: Positive Multiplication ---");
        a_in = 16'h4000; // 2.0
        b_in = 16'h4200; // 3.0
        #10;

        // -------------------------------------------------------------
        // Test 2: Negative Number Handling (Sign Bits & Subtraction path)
        // A = -1.5 (BE00), B = 2.0 (4000) -> Product = -3.0
        // Acc = 6.0 + (-3.0) = 3.0
        // -------------------------------------------------------------
        $display("--- Test 2: Negative Operand (Effective Subtraction) ---");
        a_in = 16'hBE00; // -1.5
        b_in = 16'h4000; // 2.0
        #10;

        // -------------------------------------------------------------
        // Test 3: Exponent Mismatch & Mantissa Right-Shifting
        // Multiplying a tiny number with a regular number
        // A = 0.5 (3800), B = 4.0 (4400) -> Product = 2.0
        // Acc = 3.0 + 2.0 = 5.0
        // -------------------------------------------------------------
        $display("--- Test 3: Exponent Alignment ---");
        a_in = 16'h3800; // 0.5
        b_in = 16'h4400; // 4.0
        #10;

        // -------------------------------------------------------------
        // Test 4: Back-to-Back Continuous Systolic Streaming
        // Keeping 'en' high and feeding data every single cycle without gaps
        // -------------------------------------------------------------
        $display("--- Test 4: Continuous Pipeline Streaming ---");
        a_in = 16'h3C00; b_in = 16'h3C00; // 1.0 * 1.0 = 1.0
        #10;
        a_in = 16'h4000; b_in = 16'h4000; // 2.0 * 2.0 = 4.0
        #10;
        a_in = 16'h3800; b_in = 16'h3800; // 0.5 * 0.5 = 0.25
        #30; // Wait for pipeline to drain

        $display("--- Simulation Complete ---");
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time=%0t ns | rst=%b en=%b | a_in=%h b_in=%h | a_out=%h b_out=%h | acc_reg=%h",
                 $time, rst, en, a_in, b_in, a_out, b_out, acc_reg);
    end

endmodule