`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 02:01:37 PM
// Design Name: 
// Module Name: l2_cache
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

module l2_cache(
    input  logic        clk,
    input  logic        rst_n,

    // L1 interface
    input  cache_req_t  cpu_req,
    output cache_resp_t cpu_resp,

    // L3 interface
    output cache_req_t  l3_req,
    input  cache_resp_t l3_resp,
    input  logic        l3_ready
);

    // L2 parameters
    localparam WAYS         = 4;
    localparam NUM_SETS     = 1024;
    localparam INDEX_BITS   = $clog2(NUM_SETS);                  
    localparam TAG_BITS     = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; 
    localparam WORDS_PER_LINE = LINE_BYTES / (DATA_WIDTH/8);

    // Cache arrays
    logic [TAG_BITS-1:0]         tag_array [WAYS-1:0][NUM_SETS-1:0];
    logic [DATA_WIDTH-1:0]       data_array [WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    logic [WAYS-1:0][NUM_SETS-1:0] valid_array;
    logic [WAYS-1:0][NUM_SETS-1:0] dirty_array;

    // FSM
    typedef enum logic [2:0] {IDLE, LOOKUP, WRITEBACK, MISS, REFILL} cache_state_e;
    cache_state_e curr_state, next_state;

    // Word counter
    logic [$clog2(WORDS_PER_LINE)-1:0] word_counter;

    // L3 request
    cache_req_t l3_req_reg;
    logic       l3_req_valid;

    // Victim way
    logic [1:0] victim_way;
    logic [1:0] victim_way_reg;

    // Pending CPU request
    cache_req_t pending_req;
    logic       pending_req_valid;

    // Address decoding
    logic [TAG_BITS-1:0] addr_tag;
    logic [INDEX_BITS-1:0] addr_index;
    logic [$clog2(WORDS_PER_LINE)-1:0] word_index;

    always_comb begin
        if (curr_state == IDLE && cpu_req.valid) begin
            addr_tag   = cpu_req.addr[ADDR_WIDTH-1 -: TAG_BITS];
            addr_index = cpu_req.addr[OFFSET_BITS + INDEX_BITS-1 -: INDEX_BITS];
            word_index = cpu_req.addr[OFFSET_BITS-1 -: $clog2(WORDS_PER_LINE)];
        end else begin
            addr_tag   = pending_req.addr[ADDR_WIDTH-1 -: TAG_BITS];
            addr_index = pending_req.addr[OFFSET_BITS + INDEX_BITS-1 -: INDEX_BITS];
            word_index = pending_req.addr[OFFSET_BITS-1 -: $clog2(WORDS_PER_LINE)];
        end
    end

    // Hit detection
    logic hit;
    logic [$clog2(WAYS)-1:0] hit_way;
    logic way_hit [WAYS-1:0];

    always_comb begin
        hit = 0; hit_way = '0;
        for (int w=0; w<WAYS; w++) begin
            way_hit[w] = valid_array[w][addr_index] && (tag_array[w][addr_index] == addr_tag);
            if (way_hit[w]) begin
                hit = 1;
                hit_way = w;
            end
        end
    end

    // CPU response logic
    always_comb begin
        cpu_resp = '0;
        cpu_resp.hit = hit;
        if (pending_req_valid && hit) begin
            cpu_resp.valid = 1;
            cpu_resp.rdata = data_array[hit_way][addr_index][word_index];
        end
    end

    // PLRU replacement
    plru_4way #(.NUM_SETS(NUM_SETS)) plru_inst (
        .clk(clk), .rst_n(rst_n),
        .access_valid(hit && (curr_state==LOOKUP || curr_state==IDLE)),
        .set_index(addr_index),
        .access_way(hit_way),
        .victim_way(victim_way)
    );

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state        <= IDLE;
            word_counter      <= 0;
            l3_req_reg        <= '0;
            victim_way_reg    <= 0;
            pending_req       <= '0;
            pending_req_valid <= 0;
            {tag_array, valid_array, dirty_array} <= '0;
        end else begin
            curr_state <= next_state;

            // Capture CPU request in IDLE
            if (curr_state == IDLE && cpu_req.valid) begin
                pending_req       <= cpu_req;
                pending_req_valid <= 1;
            end else if (cpu_resp.valid) begin
                pending_req_valid <= 0;
            end

            // Track victim for writeback/refill
            if (curr_state == LOOKUP && !hit) begin
                victim_way_reg <= victim_way;
            end

            // Word counter increment
            if ((curr_state == WRITEBACK || curr_state == REFILL) &&
                ((curr_state==WRITEBACK && l3_ready) || (curr_state==REFILL && l3_resp.valid)))
                word_counter <= word_counter + 1;
            else if (next_state == IDLE || next_state == MISS)
                word_counter <= 0;
        end
    end

    // Memory updates
    always_ff @(posedge clk) begin
        // Write hit
        if (pending_req_valid && hit && pending_req.we && curr_state==LOOKUP) begin
            data_array[hit_way][addr_index][word_index] <= pending_req.wdata;
            dirty_array[hit_way][addr_index] <= 1'b1;
        end

        // Refill from L3
        if (curr_state == REFILL && l3_resp.valid) begin
            data_array[victim_way_reg][addr_index][word_counter] <= l3_resp.rdata;
            if (word_counter == WORDS_PER_LINE-1) begin
                tag_array[victim_way_reg][addr_index] <= addr_tag;
                valid_array[victim_way_reg][addr_index] <= 1'b1;
                dirty_array[victim_way_reg][addr_index] <= 0;
            end
        end
    end

    // FSM
    always_comb begin
        next_state   = curr_state;
        l3_req_valid = 0;
        l3_req_reg   = '0;

        case (curr_state)
            IDLE: if (cpu_req.valid) next_state = LOOKUP;

            LOOKUP: begin
                if (hit) next_state = IDLE;
                else if (dirty_array[victim_way_reg][addr_index])
                    next_state = WRITEBACK;
                else
                    next_state = MISS;
            end

            WRITEBACK: begin
                l3_req_valid = 1;
                l3_req_reg.addr  = {tag_array[victim_way_reg][addr_index], addr_index, {OFFSET_BITS{1'b0}}} 
                                   + (word_counter * (DATA_WIDTH/8));
                l3_req_reg.we    = 1'b1;
                l3_req_reg.wdata = data_array[victim_way_reg][addr_index][word_counter];
                if (word_counter == WORDS_PER_LINE-1 && l3_ready)
                    next_state = MISS;
            end

            MISS: begin
                l3_req_valid    = 1;
                l3_req_reg.addr = pending_req.addr;
                l3_req_reg.we   = 1'b0;
                if (l3_ready)
                    next_state = REFILL;
            end

            REFILL: if (l3_resp.valid && word_counter == WORDS_PER_LINE-1)
                        next_state = LOOKUP;

            default: next_state = IDLE;
        endcase
    end

    assign l3_req = l3_req_valid ? l3_req_reg : '0;

endmodule