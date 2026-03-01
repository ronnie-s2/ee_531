`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: cache_params_pkg
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


package cache_params_pkg;

  // System-wide constants
  localparam ADDR_WIDTH   = 32;   // physical address width
  localparam DATA_WIDTH   = 32;   // CPU word width
  localparam LINE_BYTES   = 64;   // cache line size in bytes
  localparam OFFSET_BITS = $clog2(LINE_BYTES);  // offset bits (6)

  // Write policies
  localparam WRITE_BACK     = 1;  // 1 = write-back, 0 = write-through
  localparam WRITE_ALLOCATE = 1;  // 1 = write-allocate, 0 = no-write-allocate

  // Common cache FSM states
  typedef enum logic [2:0] {
    IDLE,
    LOOKUP,
    MISS,
    WRITEBACK,
    REFILL
  } cache_state_e;

  // Cache request interface struct
  typedef struct packed {
    logic                  valid;
    logic                  we;              // write enable
    logic [ADDR_WIDTH-1:0] addr;            // address
    logic [DATA_WIDTH-1:0] wdata;           // write data
  } cache_req_t;

  // Cache response interface struct
  typedef struct packed {
    logic                  valid;
    logic [DATA_WIDTH-1:0] rdata;           // read data
    logic                  hit;             // hit/miss flag
  } cache_resp_t;

endpackage