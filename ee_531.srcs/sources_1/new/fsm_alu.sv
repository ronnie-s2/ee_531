`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 12:53:01 PM
// Design Name: 
// Module Name: fsm_alu
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


module fsm_alu (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  logic [3:0] A,
    input  logic [3:0] B,
    input  logic [3:0] C,

    output logic [8:0] Y,
    output logic valid_out,
    output logic busy
);

    // Internal Signals
    logic load_sum;
    logic load_product;

    logic [4:0] sum_wire;
    logic [4:0] sum_reg;

    logic [8:0] product_wire;
    logic [8:0] product_reg;

    // Instantiate FSM Controller
    fsm_controller controller (
        .clk(clk),
        .rst(rst),
        .start(start),
        .load_sum(load_sum),
        .load_product(load_product),
        .valid_out(valid_out),
        .busy(busy)
    );

    // Instantiate CSA
    csa_4bit csa (
        .A(A),
        .B(B),
        .SUM(sum_wire)
    );

    // Instantiate Booth Multiplier
    booth_multiplier booth (
        .multiplicand(sum_reg),
        .multiplier(C),
        .product(product_wire)
    );

    // Pipeline Registers
    // Stage 1 Register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            sum_reg <= 5'd0;
        else if (load_sum)
            sum_reg <= sum_wire;
    end

    // Stage 2 Register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            product_reg <= 9'd0;
        else if (load_product)
            product_reg <= product_wire;
    end

    assign Y = product_reg;

endmodule

