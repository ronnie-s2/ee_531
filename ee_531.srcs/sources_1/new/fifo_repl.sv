`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:48:34 PM
// Design Name: 
// Module Name: fifo_repl
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

module fifo_repl #(
    parameter NUM_SETS = 1024,       // number of sets in L3
    parameter WAYS    = 8           // 8-way cache
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  access_valid,
    input  logic [$clog2(NUM_SETS)-1:0] set_index,
    output logic [$clog2(WAYS)-1:0]     victim_way
);

    // FIFO pointer for each set
    logic [$clog2(WAYS)-1:0] fifo_ptr [NUM_SETS-1:0];

    // Combinational: current victim
    assign victim_way = fifo_ptr[set_index];

    // Sequential: update pointer on access (miss)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_SETS; i++) 
                fifo_ptr[i] <= '0;  // start from way 0
        end else if (access_valid) begin
            // Increment pointer modulo WAYS
            fifo_ptr[set_index] <= fifo_ptr[set_index] + 1;
        end
    end

endmodule