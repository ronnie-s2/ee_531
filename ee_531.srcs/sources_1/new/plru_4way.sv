`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: plru_4way
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

import cache_params_pkg::*;

module plru_4way #(
    parameter NUM_SETS = 256
)(
    input  logic clk,
    input  logic rst_n,

    input  logic access_valid,
    input  logic [$clog2(NUM_SETS)-1:0] set_index,
    input  logic [1:0] access_way,  // 2 bits for 4 ways

    output logic [1:0] victim_way
);

    // 3 PLRU bits per set: b0 (root), b1 (left), b2 (right)
    logic [2:0] plru_bits [NUM_SETS-1:0];

    // Victim selection (combinational)
    always_comb begin
        logic [2:0] b = plru_bits[set_index];
        case (b)
            3'b000: victim_way = 2'd0;
            3'b001: victim_way = 2'd1;
            3'b010: victim_way = 2'd2;
            3'b011: victim_way = 2'd3;
            // Not all combinations needed; defaults for safety
            default: victim_way = 2'd0;
        endcase
    end

    // PLRU update on access
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++)
                plru_bits[i] = 3'b000;  // default all root left
        end
        else if (access_valid) begin
            case (access_way)
                2'd0: plru_bits[set_index] <= 3'b111; // mark w0 as most recently used
                2'd1: plru_bits[set_index] <= 3'b101; // mark w1 as most recently used
                2'd2: plru_bits[set_index] <= 3'b010; // mark w2 as most recently used
                2'd3: plru_bits[set_index] <= 3'b000; // mark w3 as most recently used
            endcase
        end
    end

endmodule