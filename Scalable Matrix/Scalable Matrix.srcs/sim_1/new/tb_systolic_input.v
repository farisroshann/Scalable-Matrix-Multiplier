`timescale 1ns / 1ps

module tb_systolic_input;

    reg          clk = 0;
    reg          rst;
    reg          en;
    reg  [63:0]  a_in;
    reg  [63:0]  b_col_in;
    wire [511:0] acc_out_grid;

    // Verify these port names match your systolic_4 module definition!
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

        if (mat_a[0] === 16'hx || mat_b[0] === 16'hx) begin
            $display("ERROR: matrix_a.txt or matrix_b.txt failed to load!");
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

        for (t = 0; t < 4; t = t + 1) begin
            a_in     = {mat_a[t*4 + 3], mat_a[t*4 + 2], mat_a[t*4 + 1], mat_a[t*4 + 0]};
            b_col_in = {mat_b[t*4 + 3], mat_b[t*4 + 2], mat_b[t*4 + 1], mat_b[t*4 + 0]};
            @(negedge clk);
        end

        a_in     = 64'd0;
        b_col_in = 64'd0;


        repeat (12) @(negedge clk);
        en = 1'b0;

        out_fd = $fopen("output_.txt", "w");
        if (out_fd == 0) begin
            $display("ERROR: Failed to open output_matrix_c.txt");
            $finish;
        end

        for (i = 0; i < 16; i = i + 1) begin
            $fdisplay(out_fd, "%h", acc_out_grid[i*32 +: 32]);
        end

        $fclose(out_fd);
        $finish;
    end

endmodule