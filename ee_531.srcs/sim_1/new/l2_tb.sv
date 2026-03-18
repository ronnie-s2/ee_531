`timescale 1ns / 1ps

import cache_params_pkg::*;

module l2_tb;

    logic clk;
    logic rst_n;
    cache_req_t  cpu_req;  // Stimulus from L1
    cache_resp_t cpu_resp; // Response to L1
    cache_req_t  l3_req;   // Request to L3
    cache_resp_t l3_resp;  // Response from L3
    logic        l3_ready;

    l2_cache l2_inst (.*);

    // ================= CLOCK =================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================= STATE TRACE =================
    always @(posedge clk) begin
        $display("[%t] L2_STATE=%s | L1_valid=%b we=%b | hit=%b | resp_valid=%b | l3_valid=%b l3_ready=%b",
            $realtime, l2_inst.curr_state.name(), cpu_req.valid, cpu_req.we,
            cpu_resp.hit, cpu_resp.valid, l3_req.valid, l3_ready
        );
    end

    // ================= L3 MOCK MODEL =================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l3_resp  <= '0;
            l3_ready <= 1;
        end else begin
            if (l3_req.valid) begin
                l3_resp.valid <= 1;
                l3_resp.rdata <= 32'hABCD0000 | l3_req.addr[7:0];
            end else begin
                l3_resp.valid <= 0;
            end
        end
    end

    // ================= REQUEST TASK =================
    task send_req(input logic [31:0] addr, input logic we, input logic [31:0] wdata);
        int timeout = 0;
        begin
            $display("\n[%t] >>> L2 NEW REQ addr=%h we=%b", $realtime, addr, we);
            @(negedge clk);
            cpu_req.addr = addr; cpu_req.we = we; cpu_req.wdata = wdata; cpu_req.valid = 1;
            @(negedge clk);
            cpu_req.valid = 0;
            while (cpu_resp.valid !== 1) begin
                @(posedge clk);
                if (++timeout > 300) begin
                    $display("[%t] TIMEOUT! L2 stuck in %s", $realtime, l2_inst.curr_state.name());
                    $finish;
                end
            end
            $display("[%t] L2 RESPONSE rdata=%h hit=%b\n", $realtime, cpu_resp.rdata, cpu_resp.hit);
        end
    endtask

    initial begin
        rst_n = 0; cpu_req = '0; #25; rst_n = 1; @(posedge clk);
        $display("\n========== COMPREHENSIVE L2 CACHE TEST ==========\n");

        // 1. COLD MISS + REFILL (Way 0)
        send_req(32'h0000_2000, 1'b0, 32'h0); 

        // 2. DIRTY THE LINE (Write Hit)
        send_req(32'h0000_2000, 1'b1, 32'hDEADC0DE);

        // 3. FILL THE REMAINING WAYS (Ways 1, 2, and 3)
        // Use addresses that have the same index but different tags
        send_req(32'h0001_2000, 1'b0, 32'h0); // Way 1
        send_req(32'h0002_2000, 1'b0, 32'h0); // Way 2
        send_req(32'h0003_2000, 1'b0, 32'h0); // Way 3

        // 4. FORCE EVICTION
        // This 5th address maps to the same set. 
        // It should force the 'Dirty' Way 0 (DEADC0DE) to be written back to L3.
        $display("!!! Triggering Eviction of Dirty Line !!!");
        send_req(32'h0004_2000, 1'b0, 32'h0); 

        $display("\n========== L2 TEST COMPLETE ==========\n");
        $finish;
    end
endmodule