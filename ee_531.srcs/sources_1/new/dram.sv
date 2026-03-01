`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:48:34 PM
// Design Name: 
// Module Name: dram
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

module dram(
    input  logic            clk,
    input  logic            rst_n,
    input  cache_req_t      dram_req,
    output cache_resp_t     dram_resp
);

  // Simple combinational memory simulation (placeholder)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dram_resp.valid <= 0;
      dram_resp.rdata <= '0;
      dram_resp.hit   <= 1;
    end else if (dram_req.valid) begin
      dram_resp.valid <= 1;
      dram_resp.rdata <= dram_req.addr; // dummy: just echo address
      dram_resp.hit   <= 1;
    end else begin
      dram_resp.valid <= 0;
    end
  end

endmodule