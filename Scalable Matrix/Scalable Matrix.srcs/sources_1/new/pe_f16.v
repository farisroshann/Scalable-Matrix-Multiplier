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
        input wire [15:0] a_in,
        input wire [15:0] b_in,
        output reg [15:0] a_out,
        output reg [15:0] b_out,
        output reg [31:0] accumalator
    );    



    //UNPACK the fp16 number into mantissa , sign , exponent

    //follow normal fp16 multiplication IEEE754 style
    
    
    wire sign_a = a_in[15]; 
    wire sign_b = b_in[15];


    wire [4:0] exp_a = a_in[14:10];  // 5 bit exponent
    wire [4:0] exp_b = b_in[14:10];


    wire [10:0] mantissa_a = {1'b1 , a_in[9:0]};
    wire [10:0] mantissa_b = {1'b1 , b_in[9:0]};


    // MULTIPLICATION

    wire[6:0] exp_out = exp_a + exp_b - 5'd15;
    wire sign_out = sign_a ^ sign_b;
    wire [21:0] mantissa_out = mantissa_a * mantissa_b;

    reg [10:0] man_norm;
    reg [6:0] exp_norm;

    always @(*) begin
        if(mantissa_out[21]) begin
            man_norm = mantissa_out[21:11];
            exp_norm = exp_out + 1'd1;
        end
        else begin
            man_norm = mantissa_out[20:10];
            exp_norm = exp_out;
        end
    end



    // ADDITION With Accumalator with FP32 conversion
    

    wire [7:0] exp_out = exp_norm - 5'd15 + 8'd127;
    wire [21:0] mant_out = {man_norm[9:0] , 13'b0};


    wire [31:0] mul_result = {sign_out, exp32 , frac32};

    wire sign_acc = accumulator[31];
    wire [7:0] exp_acc = accumulator[30:23];
    wire [22:0] mant_acc = accumulator[22:0];

    reg [7:0] exp_max, exp_min;
    reg [23:0] mant_max, mant_min;
    reg sign_max, sign_min;

    always @(*) begin
        if(exp_acc > exp_out ) begin
            exp_max = exp_acc;
            exp_min = exp_out;
            mant_max = {1'b1 , mant_acc};
            mant_min = {1'b1 , mant_out} >> (exp_acc - exp_out);
            sign_max = sign_acc;
            sign_min = sign_out;
        end
        else{
            exp_max = exp_out;
            exp_min = exp_acc;
            sign_max = sign_out;
            sign_min = sign_acc;
            mant_max = {1'b1 , mant_out};
            mant_min = {1'b1 , mant_acc} >> (exp_out - exp_acc);
        }
    end

    reg [24:0] mant_sum;
    reg sign_res;

    always @(*) begin
        if (sign_max == sign_min) begin
            sign_res = sign_max;
            mant_sum = mant_max + mant_min;
        end
        else if(sign_max >= sign_min) begin
            sign_res = sign_max;
            mant_sum = mant_max - mant_min;
        end
        else begin
            sign_res = sign_min;
            mant_sum = mant_min - mant_max;
        end
    end




endmodule
