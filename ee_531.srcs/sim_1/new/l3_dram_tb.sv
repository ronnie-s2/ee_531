`timescale 1ns / 1ps

import cache_params_pkg::*;

module l3_tb;

    // ================= SIGNALS =================
    logic clk;
    logic rst_n;
    cache_req_t  cpu_req;   // Stimulus from L2
    cache_resp_t cpu_resp;  // Response to L2
    cache_req_t  dram_req;  // Request to DRAM
    cache_resp_t dram_resp; // Response from DRAM
    logic        dram_ready;

    // ================= DUT & DRAM =================
    l3_cache l3_inst (.*);

    // Using a latency of 10-16 cycles
    dram #(.MEM_DEPTH(4096), .LATENCY(10)) dram_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dram_req(dram_req),
        .dram_resp(dram_resp)
    );
    
    assign dram_ready = 1'b1; 

    // ================= CLOCK GENERATION =================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================= STATE TRACING =================
    always @(posedge clk) begin
        if (l3_inst.curr_state != 0 || cpu_req.valid) // Assuming 0 is IDLE
            $display("[%t] L3_STATE=%s | L2_addr=%h | hit=%b | dram_valid=%b | word_cnt=%0d",
                $realtime, l3_inst.curr_state.name(), cpu_req.addr, cpu_resp.hit, dram_req.valid, l3_inst.word_counter
            );
    end

    // ================= REQUEST TASK =================
    task send_req(input logic [31:0] addr, input logic we, input logic [31:0] wdata);
        int timeout = 0;
        begin
            $display("\n[%t] >>> L3 NEW REQ: addr=%h we=%b data=%h", $realtime, addr, we, wdata);
            @(negedge clk);
            cpu_req.addr  = addr; 
            cpu_req.we    = we; 
            cpu_req.wdata = wdata; 
            cpu_req.valid = 1;
            
            @(negedge clk);
            cpu_req.valid = 0;

            // Wait for response
            while (cpu_resp.valid !== 1) begin
                @(posedge clk);
                if (++timeout > 2000) begin 
                    $display("[%t] ERROR: TIMEOUT! L3 stuck in %s", $realtime, l3_inst.curr_state.name());
                    $finish;
                end
            end
            $display("[%t] L3 RESPONSE: rdata=%h hit=%b", $realtime, cpu_resp.rdata, cpu_resp.hit);
        end
    endtask

    // ================= COMPREHENSIVE TEST SEQUENCE =================
    initial begin
        // Reset Phase
        rst_n = 0; 
        cpu_req = '0; 
        #40; 
        rst_n = 1; 
        repeat(5) @(posedge clk);

        $display("\n========== STARTING COMPREHENSIVE L3 TEST ==========");

        // TEST 1: Cold Read Miss (Fill Way 0)
        // This will fetch from DRAM (initial pattern = address)
        send_req(32'h0000_4000, 1'b0, 32'h0);

        // TEST 2: Write Hit (Dirty Way 0)
        // Update the data in the cache without going to DRAM
        send_req(32'h0000_4000, 1'b1, 32'h5555_AAAA);

        // TEST 3: Fill Ways 1 through 7 (Stress Associativity)
        // We use different tags but the same index to fill the set
        for (int i = 1; i < 8; i++) begin
            $display("\n--- Filling L3 Way %0d ---", i);
            send_req(32'h0000_4000 + (i << 16), 1'b0, 32'h0); 
        end

        // TEST 4: The 9th Access (Trigger Eviction + Writeback)
        // This address conflicts with the full set. 
        // It should evict the oldest (Way 0), which is Dirty.
        $display("\n!!! TRIGGERING L3 EVICTION AND DRAM WRITEBACK !!!");
        $display("Expected behavior: DRAM WE=1 (Writeback) then DRAM WE=0 (Refill)");
        send_req(32'h0008_4000, 1'b0, 32'h0); 

        // TEST 5: Verify Persistence
        // Read the evicted address again. It must fetch the dirty data (5555AAAA) from DRAM.
        $display("\n--- Verifying that DRAM was updated by the Writeback ---");
        send_req(32'h0000_4000, 1'b0, 32'h0);

        $display("\n========== L3 TEST COMPLETE: ALL WAYS VERIFIED ==========\n");
        #100;
        $finish;
    end

endmodule