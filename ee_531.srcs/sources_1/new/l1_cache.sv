`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: l1_cache
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

module l1_cache(
  input  logic                  clk,
  input  logic                  rst_n,
  input  cache_req_t            cpu_req,
  output cache_resp_t           cpu_resp,
  
  // interface to L2
  output cache_req_t            l2_req,
  input  cache_resp_t           l2_resp
);

  // L1 Cache Geometry
  localparam WAYS       = 2;
  localparam NUM_SETS   = 256;
  localparam INDEX_BITS = $clog2(NUM_SETS);  // 8
  localparam TAG_BITS   = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;  // 18

  // Optional latency parameter
  localparam HIT_LAT    = 1;

  // Arrays: tags, data, valid, dirty
  logic [TAG_BITS-1:0] tag_array [WAYS-1:0][NUM_SETS-1:0];
  logic [DATA_WIDTH-1:0] data_array [WAYS-1:0][NUM_SETS-1:0];
  logic [WAYS-1:0][NUM_SETS-1:0] valid_array;
  logic [WAYS-1:0][NUM_SETS-1:0] dirty_array;

  // Controller FSM state
  cache_state_e state;
  
  // Address slicing
  logic [TAG_BITS-1:0]    addr_tag;
  logic [INDEX_BITS-1:0]  addr_index;
  logic [OFFSET_BITS-1:0] addr_offset;
  logic [$clog2(LINE_BYTES/(DATA_WIDTH/8))-1:0] word_index; // 4 bits for 16 words

  always_comb begin
    // tag = top TAG_BITS bits
    addr_tag    = cpu_req.addr[ADDR_WIDTH-1 -: TAG_BITS];

    // index = next INDEX_BITS above offset
    addr_index  = cpu_req.addr[OFFSET_BITS + INDEX_BITS-1 -: INDEX_BITS];

    // offset = lowest OFFSET_BITS bits
    addr_offset = cpu_req.addr[OFFSET_BITS-1:0];

    // word index = select which word in the line
    word_index  = addr_offset[OFFSET_BITS-1 : OFFSET_BITS-$clog2(LINE_BYTES/(DATA_WIDTH/8))];
  end

  // -------------------------
  // TODO:
  // - Address slicing: tag/index/offset (DONE)
  // - Hit/miss logic
  // - FIFO replacement logic
  // - FSM transitions: IDLE, LOOKUP, MISS, REFILL, WRITEBACK
  // -------------------------

endmodule