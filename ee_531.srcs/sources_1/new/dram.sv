`timescale 1ns / 1ps

import cache_params_pkg::*;

module dram #(
    parameter MEM_DEPTH = 65536,       // number of words in memory
    parameter LATENCY   = 16           // cycles for read/write
)(
    input  logic             clk,
    input  logic             rst_n,
    input  cache_req_t       dram_req,
    output cache_resp_t      dram_resp
);

    // Simple memory array
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Request queue to model latency
    typedef struct packed {
        logic                 valid;
        logic                 we;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] wdata;
    } dram_req_q_t;

    dram_req_q_t req_queue[LATENCY-1:0];

    // Response register
    cache_resp_t resp_reg;
    assign dram_resp = resp_reg;

    // ================= MEMORY INITIALIZATION =================
    initial begin
        $display("[%t] DRAM: Initializing memory array...", $realtime);
        for (int i = 0; i < MEM_DEPTH; i++) begin
            // Initialize with address pattern for easy verification
            mem[i] = i[DATA_WIDTH-1:0]; 
        end
    end

    // ================= SEQUENTIAL LOGIC =================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_reg.valid <= 0;
            resp_reg.rdata <= '0;
            resp_reg.hit   <= 1;
            for (int i = 0; i < LATENCY; i++) begin
                req_queue[i] <= '0;
            end
        end else begin
            // 1. Shift request queue (Moving requests through the "pipeline")
            for (int i = LATENCY-1; i > 0; i--) begin
                req_queue[i] <= req_queue[i-1];
            end

            // 2. Capture new request into queue[0]
            if (dram_req.valid) begin
                req_queue[0].valid <= 1;
                req_queue[0].we    <= dram_req.we;
                req_queue[0].addr  <= dram_req.addr;
                req_queue[0].wdata <= dram_req.wdata;
            end else begin
                // Wiping the entire struct prevents 'X' propagation from address/data
                req_queue[0] <= '0; 
            end

            // 3. Handle oldest request completing latency
            if (req_queue[LATENCY-1].valid) begin
                // Use bitwise AND for masking to be more resilient to 'X' bits in simulation
                if (req_queue[LATENCY-1].we) begin
                    mem[req_queue[LATENCY-1].addr & (MEM_DEPTH-1)] <= req_queue[LATENCY-1].wdata;
                    resp_reg.rdata <= req_queue[LATENCY-1].wdata;
                end else begin
                    resp_reg.rdata <= mem[req_queue[LATENCY-1].addr & (MEM_DEPTH-1)];
                end

                resp_reg.valid <= 1;
                resp_reg.hit   <= 1;

            end else begin
                resp_reg.valid <= 0;
            end
        end
    end

endmodule