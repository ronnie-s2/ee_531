`timescale 1ns / 1ps

import cache_params_pkg::*;

module cache_hierarchy_top(
    input  logic        clk,
    input  logic        rst_n,

    // CPU interface
    input  cache_req_t  cpu_req,
    output cache_resp_t cpu_resp
);

    // Interconnect signals
    cache_req_t l1_to_l2_req;
    cache_resp_t l1_to_l2_resp;

    cache_req_t l2_to_l3_req;
    cache_resp_t l2_to_l3_resp;

    cache_req_t l3_to_dram_req;
    cache_resp_t l3_to_dram_resp;

    // Instantiate L1 cache
    l1_cache l1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(cpu_req),
        .cpu_resp(cpu_resp),
        .l2_req(l1_to_l2_req),
        .l2_resp(l1_to_l2_resp)
    );

    // Instantiate L2 cache
    l2_cache l2_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(l1_to_l2_req),
        .cpu_resp(l1_to_l2_resp),
        .l3_req(l2_to_l3_req),
        .l3_resp(l2_to_l3_resp)
    );

    // Instantiate L3 cache
    l3_cache l3_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(l2_to_l3_req),
        .cpu_resp(l2_to_l3_resp),
        .dram_req(l3_to_dram_req),
        .dram_resp(l3_to_dram_resp)
    );

    // Instantiate DRAM
    dram dram_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dram_req(l3_to_dram_req),
        .dram_resp(l3_to_dram_resp)
    );

endmodule