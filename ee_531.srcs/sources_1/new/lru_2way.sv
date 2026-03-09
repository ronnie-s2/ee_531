`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: lru_2way
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

module lru_2way #(
    parameter NUM_SETS = 256
)(
    input  logic clk,
    input  logic rst_n,

    input  logic access_valid,
    input  logic [$clog2(NUM_SETS)-1:0] set_index,
    input  logic access_way,

    output logic victim_way
);

    // One LRU bit per set
    logic lru_bit [NUM_SETS-1:0];

    // Victim selection
    assign victim_way = lru_bit[set_index];

    // Update on access
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                lru_bit[i] <= 0;
            end
        end
        else if (access_valid) begin
            lru_bit[set_index] <= ~access_way;
        end
    end

endmodule