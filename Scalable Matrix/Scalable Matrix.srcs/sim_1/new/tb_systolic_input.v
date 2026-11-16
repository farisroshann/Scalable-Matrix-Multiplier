`timescale 1ns / 1ps

module tb_systolic_input;

    reg          clk = 0;
    reg          rst;
    reg          en;
    reg  [63:0]  a_in;
    reg  [63:0]  b_col_in;
    wire [511:0] acc_out_grid;

    systolic_4 uut (
        .clk     (clk),
        .rst     (rst),
        .en      (en),
        .a_in    (a_in),
        .b_in    (b_col_in),
        .sys_out (acc_out_grid)
    );

    always #5 clk = ~clk;

    reg [15:0] mat_a [0:15];
    reg [15:0] mat_b [0:15];

    integer t, i, out_fd;

    initial begin
        $dumpfile("systolic_wave.vcd");
        $dumpvars(0, tb_systolic_input);

        $readmemh("input_a.txt", mat_a);
        $readmemh("input_b.txt", mat_b);

        if (mat_a[15] === 16'hx || mat_b[15] === 16'hx) begin
            $display("ERROR: input_a.txt or input_b.txt failed to load!");
            $finish;
        end

        rst      = 1'b1;
        en       = 1'b0;
        a_in     = 64'd0;
        b_col_in = 64'd0;

        repeat (3) @(negedge clk);
        rst = 1'b0;
        @(negedge clk);

        en = 1'b1;

        for (t = 0; t < 7; t = t + 1) begin
            a_in[15:0]  = (t >= 0 && t < 4) ? mat_a[0*4 + (t - 0)] : 16'd0;
            a_in[31:16] = (t >= 1 && t < 5) ? mat_a[1*4 + (t - 1)] : 16'd0;
            a_in[47:32] = (t >= 2 && t < 6) ? mat_a[2*4 + (t - 2)] : 16'd0;
            a_in[63:48] = (t >= 3 && t < 7) ? mat_a[3*4 + (t - 3)] : 16'd0;

            b_col_in[15:0]  = (t >= 0 && t < 4) ? mat_b[(t - 0)*4 + 0] : 16'd0;
            b_col_in[31:16] = (t >= 1 && t < 5) ? mat_b[(t - 1)*4 + 1] : 16'd0;
            b_col_in[47:32] = (t >= 2 && t < 6) ? mat_b[(t - 2)*4 + 2] : 16'd0;
            b_col_in[63:48] = (t >= 3 && t < 7) ? mat_b[(t - 3)*4 + 3] : 16'd0;

            @(negedge clk);
        end

        a_in     = 64'd0;
        b_col_in = 64'd0;

        repeat (10) @(negedge clk);
        en = 1'b0;

        out_fd = $fopen("output.txt", "w");
        if (out_fd == 0) begin
            $display("ERROR: Failed to open output.txt");
            $finish;
        end

        for (i = 0; i < 16; i = i + 1) begin
            $fdisplay(out_fd, "%h", acc_out_grid[i*32 +: 32]);
        end

        $fclose(out_fd);
        $finish;
    end

endmodule