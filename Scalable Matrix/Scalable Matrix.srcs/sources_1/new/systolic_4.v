`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.11.2026 18:58:12
// Design Name: 
// Module Name: systolic_4
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


module systolic_4(
    input clk, 
    input rst,
    input[63:0] a_in,
    input [63:0] b_in,
    output[511:0]sys_out
    );

    wire [15:0] a_wire [0:3][0:4];
    wire [15:0] b_wire [0:4][0:3];

    genvar r , c;
    generate 
    for(r = 0; r < 4; r = r + 1) begin : a_split
        assign a_wire[r][0] = a_in[16*r +: 16];
    end

    for(c = 0; c < 4; c = c + 1) begin: b_split
        assign b_wire[0][c] = b_in[16*c +: 16];
    end

    for(r = 0; r < 4 ; r = r+ 1) begin: row_index
        for(c = 0; c < 4 ; c = c + 1) begin: coloumn_index
            wire [15:0] unused_a_out, unused_b_out;
                wire [31:0] pe_acc;

                pe_f16 u_pe (
                    .clk(clk),
                    .rst(rst),
                    .en(en),
                    .a_in(a_wire[r][c]),
                    .b_in(b_wire[r][c]),
                    .a_out(a_wire[r][c+1]), 
                    .b_out(b_wire[r+1][c]), 
                    .acc_reg(pe_acc)
                );

                assign sys_out[(r*4 + c)*32 +: 32] = pe_acc;
        end
    end
    endgenerate
endmodule
