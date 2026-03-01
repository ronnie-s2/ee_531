`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 12:42:14 PM
// Design Name: 
// Module Name: csa
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

// 1-bit Full Adder
module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule

// 4-bit Carry-Save Adder (CSA)
module csa_4bit (
    input  logic [3:0] A,
    input  logic [3:0] B,
    output logic [4:0] SUM
);

    logic [3:0] sum_vec;     // sum outputs from CSA stage
    logic [3:0] carry_vec;   // carry outputs from CSA stage

    logic [4:0] ripple_sum;
    logic [4:0] ripple_carry;

    // Carry-Save Stage (no carry propagation)
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : csa_stage
            full_adder fa (
                .a   (A[i]),
                .b   (B[i]),
                .cin (1'b0),
                .sum (sum_vec[i]),
                .cout(carry_vec[i])
            );
        end
    endgenerate

    // Final Carry Propagate Stage
    // SUM = sum_vec + (carry_vec << 1)
    assign ripple_carry[0] = 1'b0;

    generate
        for (i = 0; i < 5; i++) begin : ripple_stage
            if (i == 0) begin
                full_adder fa_ripple (
                    .a   (sum_vec[0]),
                    .b   (1'b0),
                    .cin (ripple_carry[0]),
                    .sum (ripple_sum[0]),
                    .cout(ripple_carry[1])
                );
            end
            else if (i < 4) begin
                full_adder fa_ripple (
                    .a   (sum_vec[i]),
                    .b   (carry_vec[i-1]),
                    .cin (ripple_carry[i]),
                    .sum (ripple_sum[i]),
                    .cout(ripple_carry[i+1])
                );
            end
            else begin
                full_adder fa_ripple (
                    .a   (1'b0),
                    .b   (carry_vec[3]),
                    .cin (ripple_carry[4]),
                    .sum (ripple_sum[4]),
                    .cout()
                );
            end
        end
    endgenerate

    assign SUM = ripple_sum;

endmodule

