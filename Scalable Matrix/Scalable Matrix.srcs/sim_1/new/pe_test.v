`timescale 1ns / 1ps
// Hard self-checking testbench for pe_f16 (2-stage pipeline).
//
// Two independent checks:
//  1. Bit-exact: DUT acc_reg must equal a golden model (g_prod / g_add) that
//     follows the same rules as the design (normal FP16 only, denormals flushed
//     to zero, truncation, no rounding).
//  2. Real-number sanity: the golden model itself is compared against exact
//     double-precision math with a tolerance. This catches mistakes that the
//     design and the golden model would share (e.g. a wrong exponent bias).

module tb_pe_f16_hard;

    localparam NMAX = 400;

    reg         clk = 0;
    reg         rst, en;
    reg  [15:0] a_in, b_in;
    wire [15:0] a_out, b_out;
    wire [31:0] acc_reg;

    reg [15:0] av [0:NMAX-130];
    reg [15:0] bv [0:NMAX-1];
    reg [31:0] ev [0:NMAX-1];

    integer N, k, i, errors, checks, seed;

    pe_f16 dut(.clk(clk), .rst(rst), .en(en), .a_in(a_in), .b_in(b_in),
               .a_out(a_out), .b_out(b_out), .acc_reg(acc_reg));

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Golden model
    // ------------------------------------------------------------------
    function [31:0] g_prod;
        input [15:0] a, b;
        reg [4:0]  ea, eb;
        reg [21:0] p;
        reg [7:0]  e;
        reg [9:0]  f;
        begin
            ea = a[14:10];
            eb = b[14:10];
            if (ea == 5'd0 || eb == 5'd0)
                g_prod = 32'd0;
            else begin
                p = {1'b1, a[9:0]} * {1'b1, b[9:0]};
                e = ea + eb + 8'd97;                 // -15 -15 +127
                if (p[21]) begin f = p[20:11]; e = e + 8'd1; end
                else       begin f = p[19:10]; end
                g_prod = {a[15] ^ b[15], e, f, 13'b0};
            end
        end
    endfunction

    function [31:0] g_add;
        input [31:0] acc, pr;
        reg [31:0] hi, lo;
        reg [7:0]  emax, emin;
        reg [24:0] mmax, mmin, s;
        integer    lz;
        reg [7:0]  lz8;
        begin
            if (acc[30:0] >= pr[30:0]) begin hi = acc; lo = pr;  end
            else                       begin hi = pr;  lo = acc; end
            emax = hi[30:23];
            emin = lo[30:23];
            mmax = (emax == 8'd0) ? 25'd0 : {2'b01, hi[22:0]};
            mmin = (emin == 8'd0) ? 25'd0 : ({2'b01, lo[22:0]} >> (emax - emin));
            s    = (hi[31] == lo[31]) ? (mmax + mmin) : (mmax - mmin);
            if (s == 25'd0)
                g_add = 32'd0;
            else if (s[24])
                g_add = {hi[31], emax + 8'd1, s[23:1]};
            else begin
                lz = 0;
                while (s[23 - lz] == 1'b0) lz = lz + 1;
                lz8 = lz;
                if (emax <= lz)
                    g_add = 32'd0;
                else
                    g_add = {hi[31], emax - lz8, s[22:0] << lz};
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Real-number helpers
    // ------------------------------------------------------------------
    function real h2r;                       // FP16 -> real
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

    function real f2r;                       // FP32 -> real
        input [31:0] x;
        integer ex;
        real    m;
        begin
            ex = x[30:23];
            if (ex == 0) f2r = 0.0;
            else begin
                ex = ex - 127;
                m  = 1.0 + x[22:0] / 8388608.0;
                f2r = m * (2.0 ** ex);
                if (x[31]) f2r = -f2r;
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Random FP16 generator (normal numbers and zeros only)
    // ------------------------------------------------------------------
    task gen_rand;
        output [15:0] v;
        integer r, e;
        reg [9:0] f;
        reg       sgn;
        begin
            r   = {$random(seed)} % 100;
            sgn = $random(seed);
            if (r < 8)
                v = {sgn, 15'd0};                          // +0 / -0
            else begin
                if      (r < 45) e = 12 + ({$random(seed)} % 7);   // ~1.0 range
                else if (r < 75) e = 1  + ({$random(seed)} % 30);  // full range
                else             e = 8  + ({$random(seed)} % 15);
                f = $random(seed);
                case ({$random(seed)} % 4)
                    0: f = 10'd0;
                    1: f = 10'h3FF;
                    default: ;
                endcase
                v = {sgn, e[4:0], f};
            end
        end
    endtask

    task add_vec;
        input [15:0] a, b;
        begin
            av[N] = a;
            bv[N] = b;
            N = N + 1;
        end
    endtask

    // ------------------------------------------------------------------
    // Checking helpers
    // ------------------------------------------------------------------
    task check;
        input integer idx;
        input [8*8-1:0] phase;
        begin
            checks = checks + 1;
            if (acc_reg !== ev[idx]) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL %0s #%0d  a=%h b=%h  expected=%h  actual=%h",
                             phase, idx, av[idx], bv[idx], ev[idx], acc_reg);
            end
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); rst = 1; en = 0; a_in = 0; b_in = 0;
            repeat (1) @(negedge clk);
            rst = 0;
        end
    endtask

    // ------------------------------------------------------------------
    // Build vectors and expected results
    // ------------------------------------------------------------------
    reg [15:0] ra, rb;
    reg [31:0] gacc;
    real       exact, mag, pr, d;

    task build;
        begin
            N = 0;
            // ----- directed, hard cases -----
            add_vec(16'h4200, 16'h4000);   // 3 * 2
            add_vec(16'h3C00, 16'h4400);   // 1 * 4          (carry out)
            add_vec(16'h0000, 16'h4200);   // 0 * 3          (zero product)
            add_vec(16'hC000, 16'h4000);   // -2 * 2         (subtract)
            add_vec(16'hC200, 16'h4000);   // -3 * 2         (cancel to 0)
            add_vec(16'h3800, 16'h3800);   // 0.5 * 0.5      (acc zero, small prod)
            add_vec(16'h7BFF, 16'h7BFF);   // 65504^2        (max magnitude)
            add_vec(16'hFBFF, 16'h7BFF);   // -65504^2       (exact cancel)
            add_vec(16'h3C01, 16'h3C00);   // 1.0009765625
            add_vec(16'hBC00, 16'h3C00);   // -1             (near cancel, lzc=10)
            add_vec(16'h0400, 16'h0400);   // (2^-14)^2      (tiny)
            add_vec(16'h7BFF, 16'h6400);   // 65504*1024     (huge)
            add_vec(16'h0400, 16'h0400);   // tiny added to huge -> vanishes
            add_vec(16'hFBFF, 16'h6400);   // -huge          (cancel, tiny remains)
            add_vec(16'h0400, 16'h0400);   // tiny + tiny
            add_vec(16'h3FFF, 16'h3FFF);   // 1.999^2        (carry in multiply)
            add_vec(16'hBFFF, 16'h3FFF);   // cancel
            add_vec(16'h3C01, 16'h3C01);   // truncated product
            add_vec(16'h3C00, 16'h3C00);   // 1*1
            add_vec(16'h3C00, 16'h3C00);   // 1*1
            add_vec(16'h3C00, 16'h3C00);   // 1*1
            add_vec(16'h0000, 16'h0000);   // 0*0
            add_vec(16'h8000, 16'h4500);   // -0 * 5
            add_vec(16'h3E00, 16'hBE00);   // 1.5 * -1.5
            add_vec(16'hBE00, 16'h3E00);   // -1.5 * 1.5
            add_vec(16'h4080, 16'h3C00);   // 2.25
            add_vec(16'h4700, 16'h1400);   // 7 * 2^-10
            add_vec(16'hC700, 16'h1400);   // -7 * 2^-10
            add_vec(16'h5640, 16'hD640);   // 100 * -100
            add_vec(16'h5640, 16'h5640);   // 100 * 100
            // ----- random, with forced exact cancellations -----
            for (i = 0; i < 300; i = i + 1) begin
                gen_rand(ra);
                gen_rand(rb);
                add_vec(ra, rb);
                if (i % 25 == 24)
                    add_vec(ra, {~rb[15], rb[14:0]});
            end
            // ----- expected values + real-number sanity -----
            gacc = 32'd0; exact = 0.0; mag = 0.0;
            for (i = 0; i < N; i = i + 1) begin
                gacc  = g_add(gacc, g_prod(av[i], bv[i]));
                ev[i] = gacc;
                pr    = h2r(av[i]) * h2r(bv[i]);
                exact = exact + pr;
                mag   = mag + ((pr < 0.0) ? -pr : pr);
                d     = f2r(gacc) - exact;
                if (d < 0.0) d = -d;
                if (d > mag / 256.0 + 1.0e-30) begin
                    errors = errors + 1;
                    $display("MODEL ERROR #%0d a=%h b=%h golden=%h (%e) exact=%e",
                             i, av[i], bv[i], gacc, f2r(gacc), exact);
                end
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------------
    initial begin
        seed = 32'h2026_0927;
        errors = 0; checks = 0;
        rst = 1; en = 0; a_in = 0; b_in = 0;
        build;

        // ---- Phase 1: back-to-back stream, check every cycle ----
        // vector k is driven at negedge k; acc includes it at negedge k+2
        do_reset;
        for (k = 0; k < N + 2; k = k + 1) begin
            @(negedge clk);
            if (k >= 2) check(k - 2, "stream");
            if (k < N) begin a_in = av[k]; b_in = bv[k]; en = 1; end
            else       begin en = 0; end
        end

        // ---- Phase 2: single inputs separated by idle cycles ----
        // Same first 60 vectors from reset, so ev[] is reused.
        do_reset;
        for (k = 0; k < 60; k = k + 1) begin
            @(negedge clk); a_in = av[k]; b_in = bv[k]; en = 1;
            @(negedge clk); en = 0;
            @(negedge clk);
            check(k, "gap");
            if (a_out !== av[k] || b_out !== bv[k]) begin
                errors = errors + 1;
                $display("FAIL pass-through #%0d a_out=%h b_out=%h", k, a_out, b_out);
            end
        end

        // ---- Phase 3: reset clears the accumulator ----
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        checks = checks + 1;
        if (acc_reg !== 32'd0) begin
            errors = errors + 1;
            $display("FAIL reset: acc_reg=%h", acc_reg);
        end

        $display("--------------------------------------------");
        $display("vectors = %0d   checks = %0d   errors = %0d", N, checks, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("TESTS FAILED");
        $finish;
    end

    initial begin
        #5000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule