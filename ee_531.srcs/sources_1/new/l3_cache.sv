`timescale 1ns / 1ps

import cache_params_pkg::*;

module l3_cache(
    input  logic        clk,
    input  logic        rst_n,
    input  cache_req_t  cpu_req,  // From L2
    output cache_resp_t cpu_resp, // To L2
    output cache_req_t  dram_req, // To DRAM
    input  cache_resp_t dram_resp,// From DRAM
    input  logic        dram_ready
);

    // Parameters
    localparam WAYS           = 8;
    localparam NUM_SETS       = 4096;
    localparam INDEX_BITS     = $clog2(NUM_SETS);
    localparam TAG_BITS       = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam WORDS_PER_LINE = LINE_BYTES / (DATA_WIDTH/8);

    logic [TAG_BITS-1:0]   tag_array   [WAYS-1:0][NUM_SETS-1:0];
    logic [DATA_WIDTH-1:0] data_array  [WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    logic                  valid_array [WAYS-1:0][NUM_SETS-1:0];
    logic                  dirty_array [WAYS-1:0][NUM_SETS-1:0];

    cache_state_e curr_state, next_state;
    logic [$clog2(WORDS_PER_LINE)-1:0] word_counter;
    cache_req_t pending_req;
    logic       pending_req_valid;

    // FIFO Replacement
    logic [2:0] victim_way, victim_way_reg;

    // Address Decoding (Stable Version)
    logic [TAG_BITS-1:0]   addr_tag;
    logic [INDEX_BITS-1:0] addr_index;
    logic [$clog2(WORDS_PER_LINE)-1:0] word_index;

    // Internal combinational dram request signal
    cache_req_t dram_req_comb;

    // Always use pending_req for internal logic once a request is accepted
    assign addr_tag   = pending_req.addr[ADDR_WIDTH-1 -: TAG_BITS];
    assign addr_index = pending_req.addr[OFFSET_BITS + INDEX_BITS-1 -: INDEX_BITS];
    assign word_index = pending_req.addr[OFFSET_BITS-1 -: $clog2(WORDS_PER_LINE)];

    // Hit Logic
    logic hit;
    logic [2:0] hit_way;
    always_comb begin
        hit = 0; hit_way = '0;
        for (int w = 0; w < WAYS; w++) begin
            if (valid_array[w][addr_index] && (tag_array[w][addr_index] == addr_tag)) begin
                hit = 1; hit_way = w;
            end
        end
    end

    always_comb begin
        cpu_resp = '0;
        cpu_resp.hit = hit;
        // Respond when we have a hit or when a refill is complete and we are back in LOOKUP
        if (pending_req_valid && hit && (curr_state == LOOKUP || curr_state == IDLE)) begin
            cpu_resp.valid = 1;
            cpu_resp.rdata = data_array[hit_way][addr_index][word_index];
        end
    end

    fifo_repl #(.NUM_SETS(NUM_SETS), .WAYS(WAYS)) fifo_inst (
        .clk(clk), .rst_n(rst_n),
        .access_valid(hit && (curr_state == LOOKUP || curr_state == IDLE)),
        .set_index(addr_index), .victim_way(victim_way)
    );

    // Sequential Control Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE; 
            pending_req_valid <= 0; 
            word_counter <= 0;
            pending_req <= '0;
            victim_way_reg <= '0;
            for (int i=0; i<WAYS; i++) for (int j=0; j<NUM_SETS; j++) begin
                valid_array[i][j] <= 0; dirty_array[i][j] <= 0;
            end
        end else begin
            curr_state <= next_state;
            
            // Accept Request
            if (curr_state == IDLE && cpu_req.valid) begin
                pending_req <= cpu_req; 
                pending_req_valid <= 1;
            end else if (cpu_resp.valid) begin
                pending_req_valid <= 0;
            end

            // Victim Locking: Lock the way immediately when a miss is detected
            if (curr_state == LOOKUP && !hit) begin
                victim_way_reg <= victim_way;
            end

            // Word Counter Logic
            if ((curr_state == WRITEBACK && dram_ready) || (curr_state == REFILL && dram_resp.valid))
                word_counter <= word_counter + 1;
            else if (next_state == IDLE || next_state == MISS || next_state == LOOKUP)
                word_counter <= 0;
        end
    end

    // Memory Array Updates
    always_ff @(posedge clk) begin
        if (pending_req_valid && hit && pending_req.we && curr_state == LOOKUP) begin
            data_array[hit_way][addr_index][word_index] <= pending_req.wdata;
            dirty_array[hit_way][addr_index] <= 1'b1;
        end
        
        if (curr_state == REFILL && dram_resp.valid) begin
            data_array[victim_way_reg][addr_index][word_counter] <= (pending_req.we && (word_counter == word_index)) ? pending_req.wdata : dram_resp.rdata;
            if (word_counter == WORDS_PER_LINE-1) begin
                tag_array[victim_way_reg][addr_index] <= addr_tag;
                valid_array[victim_way_reg][addr_index] <= 1'b1;
                dirty_array[victim_way_reg][addr_index] <= pending_req.we;
            end
        end
    end

    // Next State & DRAM Request Logic (combinational)
    always_comb begin
        next_state = curr_state; 
        dram_req_comb = '0; // Default all zeros

        case (curr_state)
            IDLE: if (cpu_req.valid) next_state = LOOKUP;
            
            LOOKUP: begin
                if (hit) next_state = IDLE;
                else if (valid_array[victim_way_reg][addr_index] && dirty_array[victim_way_reg][addr_index]) 
                    next_state = WRITEBACK;
                else 
                    next_state = MISS;
            end
            
            WRITEBACK: begin
                dram_req_comb.valid = 1; 
                dram_req_comb.we = 1;
                // Construct address using the TAG currently in the victim way
                dram_req_comb.addr = {tag_array[victim_way_reg][addr_index], addr_index, {OFFSET_BITS{1'b0}}} + (word_counter * (DATA_WIDTH/8));
                dram_req_comb.wdata = data_array[victim_way_reg][addr_index][word_counter];
                if (word_counter == WORDS_PER_LINE-1 && dram_ready) next_state = MISS;
            end
            
            MISS: begin
                dram_req_comb.valid = 1; 
                dram_req_comb.we = 0;
                dram_req_comb.addr = {addr_tag, addr_index, {OFFSET_BITS{1'b0}}};
                if (dram_ready) next_state = REFILL;
            end
            
            REFILL: begin
                dram_req_comb.valid = 1; 
                dram_req_comb.we = 0;
                // Stable refill address
                dram_req_comb.addr = {addr_tag, addr_index, {OFFSET_BITS{1'b0}}} + (word_counter * (DATA_WIDTH/8));
                if (dram_resp.valid && word_counter == WORDS_PER_LINE-1) next_state = LOOKUP;
            end
            
            default: next_state = IDLE;
        endcase
    end

    assign dram_req = dram_req_comb;

endmodule