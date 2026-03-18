`timescale 1ns / 1ps

import cache_params_pkg::*;

module l1_cache(
    input  logic        clk,
    input  logic        rst_n,
    input  cache_req_t  cpu_req,
    output cache_resp_t cpu_resp,

    // interface to L2
    output cache_req_t  l2_req,
    input  cache_resp_t l2_resp,
    input  logic        l2_ready 
);

    // Parameters
    localparam WAYS           = 2;
    localparam NUM_SETS       = 256;
    localparam INDEX_BITS     = $clog2(NUM_SETS);
    localparam TAG_BITS       = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE = LINE_BYTES / (DATA_WIDTH/8);

    // Cache arrays
    logic [TAG_BITS-1:0]   tag_array   [WAYS-1:0][NUM_SETS-1:0];
    logic [DATA_WIDTH-1:0] data_array  [WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    logic                  valid_array [WAYS-1:0][NUM_SETS-1:0];
    logic                  dirty_array [WAYS-1:0][NUM_SETS-1:0];

    // FSM
    cache_state_e curr_state, next_state;

    // Word counter and L2 registers
    logic [$clog2(WORDS_PER_LINE)-1:0] word_counter;
    cache_req_t l2_req_reg;
    logic       l2_req_valid;

    // CPU Tracking
    cache_req_t pending_req;
    logic       pending_req_valid;

    // Replacement Logic
    logic victim_way;
    logic victim_way_reg;

    // Address Decoding
    logic [TAG_BITS-1:0]   addr_tag;
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
        hit = 0;
        hit_way = '0;
        for (int w = 0; w < WAYS; w++) begin
            way_hit[w] = valid_array[w][addr_index] &&
                         (tag_array[w][addr_index] == addr_tag);
            if (way_hit[w]) begin
                hit = 1;
                hit_way = w;
            end
        end
    end

    // CPU response
    always_comb begin
        cpu_resp = '0;
        cpu_resp.hit = hit;

        if (pending_req_valid && hit) begin
            cpu_resp.valid = 1;
            cpu_resp.rdata = data_array[hit_way][addr_index][word_index];
        end
    end

    // LRU
    lru_2way #(.NUM_SETS(256)) lru_inst (
        .clk(clk),
        .rst_n(rst_n),
        .access_valid(hit && (curr_state == LOOKUP || curr_state == IDLE)),
        .set_index(addr_index),
        .access_way(hit_way),
        .victim_way(victim_way)
    );

    // Sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            pending_req_valid <= 0;
            word_counter <= 0;
            victim_way_reg <= 0;
            pending_req <= '0;

            for (int i = 0; i < WAYS; i++) begin
                for (int j = 0; j < NUM_SETS; j++) begin
                    valid_array[i][j] <= 0;
                    dirty_array[i][j] <= 0;
                end
            end
        end else begin
            curr_state <= next_state;

            if (curr_state == IDLE && cpu_req.valid) begin
                pending_req <= cpu_req;
                pending_req_valid <= 1;
            end else if (cpu_resp.valid) begin
                pending_req_valid <= 0;
            end

            if (curr_state == WRITEBACK && l2_ready)
                word_counter <= word_counter + 1;
            else if (curr_state == REFILL && l2_resp.valid)
                word_counter <= word_counter + 1;
            else if (next_state == IDLE || next_state == MISS)
                word_counter <= 0;

            if (curr_state == LOOKUP && !hit)
                victim_way_reg <= victim_way;
        end
    end

    // Data updates
    always_ff @(posedge clk) begin
        if (pending_req_valid && hit && pending_req.we && curr_state == LOOKUP) begin
            data_array[hit_way][addr_index][word_index] <= pending_req.wdata;
            dirty_array[hit_way][addr_index] <= 1'b1;
        end

        if (curr_state == REFILL && l2_resp.valid) begin
            if (pending_req.we && (word_counter == word_index))
                data_array[victim_way_reg][addr_index][word_counter] <= pending_req.wdata;
            else
                data_array[victim_way_reg][addr_index][word_counter] <= l2_resp.rdata;

            if (word_counter == WORDS_PER_LINE-1) begin
                tag_array[victim_way_reg][addr_index]   <= addr_tag;
                valid_array[victim_way_reg][addr_index] <= 1'b1;
                dirty_array[victim_way_reg][addr_index] <= pending_req.we;
            end
        end
    end

    // FSM
    always_comb begin
        next_state = curr_state;

        l2_req_valid = 0;
        l2_req_reg   = '0;
        l2_req_reg.valid = 0;   // default

        case (curr_state)

            IDLE: begin
                if (cpu_req.valid)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (hit)
                    next_state = IDLE;
                else if (dirty_array[victim_way_reg][addr_index] &&
                         valid_array[victim_way_reg][addr_index])
                    next_state = WRITEBACK;
                else
                    next_state = MISS;
            end

            WRITEBACK: begin
                l2_req_valid      = 1;
                l2_req_reg.valid  = 1;   
                l2_req_reg.we     = 1;

                l2_req_reg.addr = {
                    tag_array[victim_way_reg][addr_index],
                    addr_index,
                    {OFFSET_BITS{1'b0}}
                } + (word_counter * (DATA_WIDTH/8));

                l2_req_reg.wdata =
                    data_array[victim_way_reg][addr_index][word_counter];

                if (word_counter == WORDS_PER_LINE-1 && l2_ready)
                    next_state = MISS;
            end

            MISS: begin
                l2_req_valid      = 1;
                l2_req_reg.valid  = 1;   
                l2_req_reg.we     = 0;   // explicit read

                l2_req_reg.addr = {
                    addr_tag,
                    addr_index,
                    {OFFSET_BITS{1'b0}}
                };

                if (l2_ready)
                    next_state = REFILL;
            end

            REFILL: begin
                l2_req_valid     = 1;
                l2_req_reg.valid = 1;
                l2_req_reg.we    = 0;

                // Request each word sequentially
                l2_req_reg.addr = {
                    addr_tag,
                    addr_index,
                    {OFFSET_BITS{1'b0}}
                } + (word_counter * (DATA_WIDTH/8));

                if (l2_resp.valid && word_counter == WORDS_PER_LINE-1)
                    next_state = LOOKUP;
            end

            default: next_state = IDLE;
        endcase
    end

    assign l2_req = l2_req_reg;

endmodule