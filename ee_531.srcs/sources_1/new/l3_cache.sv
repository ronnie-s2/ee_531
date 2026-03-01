`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: l3_cache
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

module l3_cache(
    input  logic        clk,
    input  logic        rst_n,

    // L2 interface
    input  cache_req_t  cpu_req,
    output cache_resp_t cpu_resp,

    // Interface to DRAM
    output cache_req_t  dram_req,
    input  cache_resp_t dram_resp
);

  // L3 Cache Geometry
  localparam WAYS       = 8;
  localparam NUM_SETS   = 4096;
  localparam INDEX_BITS = $clog2(NUM_SETS);                // 12
  localparam TAG_BITS   = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 14
  
  // Optional latency parameter
  localparam HIT_LAT    = 12;

  // Cache storage arrays
  logic [TAG_BITS-1:0]    tag_array [WAYS-1:0][NUM_SETS-1:0];
  logic [DATA_WIDTH-1:0]  data_array [WAYS-1:0][NUM_SETS-1:0];
  logic [WAYS-1:0][NUM_SETS-1:0] valid_array;
  logic [WAYS-1:0][NUM_SETS-1:0] dirty_array;

  // FSM state
  cache_state_e state;

  // -------------------------
  // TODO:
  // - Address slicing: tag/index/offset
  // - Hit/miss logic
  // - FIFO replacement logic
  // - FSM transitions: IDLE, LOOKUP, MISS, REFILL, WRITEBACK
  // -------------------------

endmodule