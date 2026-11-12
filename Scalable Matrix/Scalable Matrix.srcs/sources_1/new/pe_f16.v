`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.09.2026 16:08:07
// Design Name: 
// Module Name: pe_f16
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


module pe_f16(
        input clk,
        input en,
        input wire rst,
        input wire [15:0] a_in,
        input wire [15:0] b_in,
        output reg [15:0] a_out,
        output reg [15:0] b_out,
        output reg [31:0] acc_reg
    );    




    //==============================================
    //PIPELINE STAGE 1 : MULTIPLICATION fp16
    //============================================== 



    reg [31:0] accumulator = 32'd0;

        

        //UNPACK the fp16 number into mantissa , sign , exponent
    
    wire sign_a = a_in[15]; 
    wire sign_b = b_in[15];


    wire [4:0] exp_a = a_in[14:10];  // 5 bit exponent
    wire [4:0] exp_b = b_in[14:10];


    wire [10:0] mantissa_a = {1'b1 , a_in[9:0]};
    wire [10:0] mantissa_b = {1'b1 , b_in[9:0]};
    wire        a_is_zero = (a_in[14:0] == 15'd0);  // OPTIMIZE LATER
    wire        b_is_zero = (b_in[14:0] == 15'd0);
    wire        mul_zero  = a_is_zero || b_is_zero;

    // MULTIPLICATION

    wire [7:0]  exp_sum   = {3'b0, exp_a} + {3'b0, exp_b} + 8'd97;
    wire sign_out = sign_a ^ sign_b;
    wire [21:0] mantissa_out = mul_zero ? 22'd0 :  mantissa_a * mantissa_b;   // check Mul_zero

    reg [9:0] man_out;
    reg [7:0] exp_out;

    always @(*) begin
        if(mantissa_out[21]) begin
            man_out = mantissa_out[20:11];
            exp_out = exp_sum + 1'd1;
        end
        else begin
            man_out = mantissa_out[19:10];
            exp_out = exp_sum;
        end
    end


    reg         s1_valid;
    reg         s1_zero;
    reg         s1_sign;
    reg  [7:0]  s1_exp;
    reg  [22:0] s1_frac;
    

    always @(posedge clk) begin
        if (rst) begin
            s1_valid <= 1'b0;
            s1_zero  <= 1'b1;
            s1_sign  <= 1'b0;
            s1_exp   <= 8'd0;
            s1_frac  <= 23'd0;
        end else begin
            s1_valid <= en;
            if (en) begin
                s1_zero  <= mul_zero;
                s1_sign  <= sign_out;
                s1_exp   <= mul_zero ? 8'd0  : exp_out;
                s1_frac  <= mul_zero ? 23'd0 : {man_out, 13'b0};
            end
        end
    end





    // ADDITION With accumulator with FP32 conversion
    //==============================================
    //PIPELINE STAGE 2 : ADDITION AND NORMALIZATION
    //============================================== 

    // precombinational block
    
    
    


    wire [31:0] mul_result =  {s1_sign, s1_exp , s1_frac}; 

    wire mul_sign = s1_sign;
    wire [7:0] mul_exp = s1_exp;
    wire [22:0] mul_frac = s1_frac;

    reg [7:0] exp_max, exp_min;
    reg [23:0] mant_max, mant_min;
    
    reg sign_max, sign_min;

    wire acc_sign = accumulator[31];
    wire [7:0] acc_exp = accumulator[30:23];
    wire [22:0] acc_frac = accumulator[22:0];

    wire acc_is_zero = (accumulator == 32'd0);

    always @(*) begin
        if((acc_exp > mul_exp) || ((acc_exp == mul_exp) && (acc_frac >= mul_frac)) ) begin
            exp_max = acc_exp;
            exp_min = mul_exp;
            sign_max = acc_sign;
            sign_min = mul_sign;
            mant_max = acc_is_zero ? 24'd0 : {1'b1 , acc_frac};
            mant_min = s1_zero ? 24'd0 : {1'b1 , mul_frac} >> (exp_max - exp_min);
        end
        else begin
            exp_max = mul_exp;
            exp_min = acc_exp;
            sign_max = mul_sign;
            sign_min = acc_sign;
            mant_max =  s1_zero ? 24'd0 : {1'b1 , mul_frac};
            mant_min = acc_is_zero ? 24'd0 : ({1'b1, acc_frac} >> (exp_max  - exp_min));
        end
    end

    reg [24:0] mant_sum;
    reg sign_res;

    always @(*) begin
        sign_res = sign_max;                  
        if (sign_max == sign_min)
            mant_sum = mant_max + mant_min;   
        else
            mant_sum = mant_max - mant_min;   
    end


    

    
    integer i;
    reg [4:0] lzc;
    always @(*) begin
        lzc = 5'd24;

        for(i=23; i>=0; i=i-1)
            if(mant_sum[i] && lzc==24)
                lzc = 23-i;
    end

    reg [22:0] r_frac;
    reg [7:0]  r_exp;
    reg        r_sign;

    always @(*) begin
        r_sign   = sign_res;
        r_frac   = 23'd0;
        r_exp    = 8'd0;
        if (mant_sum == 25'd0) begin
            r_sign = 1'b0;                       
        end else if (mant_sum[24]) begin
            r_frac = mant_sum[23:1];             
            r_exp  = exp_max + 8'd1;             
        end else begin   
            r_frac   = mant_sum[22:0] << lzc;           
            r_exp    = exp_max - {3'd0, lzc};    
        end
    end
    wire [31:0] add_result = {r_sign, r_exp, r_frac};


    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 32'd0;
            acc_reg     <= 32'd0;
            a_out       <= 16'd0;
            b_out       <= 16'd0;
        end else begin
            if (en) begin
                a_out <= a_in;
                b_out <= b_in;
            end
            if (s1_valid) begin
                accumulator <= add_result;
                acc_reg     <= add_result;
            end
        end
    end



endmodule

