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
    //INTIALIZING
    
    
    wire sign_a = a_in[15];
    wire sign_b = b_in[15];
    wire [4:0] exp_a = a_in[14:10];
    wire [4:0] exp_b = b_in[14:10];
    wire [13:0] mantissa_a = {1'b1 , a_in[9:0], 3'b000};
    wire [13:0] mantissa_b = {1'b1 , b_in[9:0], 3'b000};
    reg [31:0] mul_result;
    reg [21:0] mantissa_result;
    //NORMALIZATION
    
    reg [4:0] exp_max , exp_min;
    reg [13:0] mantissa_max, mantissa_min;
    
    always @(*) begin    // WHY NOT INITIAL
            if({exp_a, mantissa_a} > {exp_b, mantissa_b}) begin
                exp_max = exp_a;
                mantissa_max = mantissa_a;
                mantissa_min =  mantissa_b >> (exp_a - exp_b);
            end
            else begin
                exp_max = exp_b ;
                mantissa_max = mantissa_b;
                mantissa_min =  mantissa_a >> (exp_b - exp_a);     
            end 
    end 
    
   
        
    
   always @(posedge clk ) begin
        if(en) begin
            a_out <= a_in;
            b_out <= b_in;
            mul_result[31] = sign_a ^ sign_b;
            mul_result[30:22] = exp_a + exp_b + 4'b1111;
            mantissa_result = mantissa_a * mantissa_b;
            
            if(mantissa_result[21]) begin 
                mul_result[21:0] = mantissa_result[21:1];   
            end
            else begin 
                mul_result[21:0] = mantissa_result[20:0];
            end
            
            accumalator[31:0] <= accumalator + mul_result;
        end                  
   end
endmodule
