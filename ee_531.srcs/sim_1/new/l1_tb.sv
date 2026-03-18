`timescale 1ns / 1ps

import cache_params_pkg::*;

module l1_tb;

    logic clk;
    logic rst_n;
    cache_req_t  cpu_req;
    cache_resp_t cpu_resp;
    cache_req_t  l2_req;
    cache_resp_t l2_resp;
    logic        l2_ready;

    l1_cache l1_inst (.*);

    // ================= CLOCK =================
    initial clk = 0;
    always #5 clk = ~clk;

    // ================= STATE TRACE =================
    always @(posedge clk) begin
        $display("[%t] STATE=%s | cpu_valid=%b we=%b | hit=%b | resp_valid=%b | l2_valid=%b l2_ready=%b",
            $realtime,
            l1_inst.curr_state.name(),
            cpu_req.valid,
            cpu_req.we,
            cpu_resp.hit,
            cpu_resp.valid,
            l2_req.valid,
            l2_ready
        );
    end

    // ================= L2 MODEL =================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_resp  <= '0;
            l2_ready <= 1;
        end else begin
            if (l2_req.valid) begin
                l2_resp.valid <= 1;
                l2_resp.rdata <= 32'hABCD0000 | l2_req.addr[7:0];
            end else begin
                l2_resp.valid <= 0;
            end
        end
    end

    // ================= REQUEST TASK =================
    task send_req(input logic [31:0] addr,
                  input logic        we,
                  input logic [31:0] wdata);
        int timeout;
    begin
        $display("\n[%t] >>> NEW REQUEST addr=%h we=%b wdata=%h",
                 $realtime, addr, we, wdata);

        // Drive request
        @(negedge clk);
        cpu_req.addr  = addr;
        cpu_req.we    = we;
        cpu_req.wdata = wdata;
        cpu_req.valid = 1;

        @(negedge clk);
        cpu_req.valid = 0;

        // Wait for response with timeout
        timeout = 0;
        while (cpu_resp.valid !== 1) begin
            @(posedge clk);
            timeout++;

            if (timeout % 10 == 0) begin
                $display("[%t] ...waiting (%0d cycles) state=%s word_cnt=%0d",
                    $realtime,
                    timeout,
                    l1_inst.curr_state.name(),
                    l1_inst.word_counter
                );
            end

            if (timeout > 200) begin
                $display("[%t] TIMEOUT waiting for response!", $realtime);
                $display("    state=%s hit=%b l2_valid=%b l2_ready=%b",
                    l1_inst.curr_state.name(),
                    cpu_resp.hit,
                    l2_req.valid,
                    l2_ready
                );
                $finish;
            end
        end

        $display("[%t] RESPONSE addr=%h we=%b rdata=%h hit=%b\n",
                 $realtime, addr, we, cpu_resp.rdata, cpu_resp.hit);
    end
    endtask

    // ================= TEST =================
    initial begin
        rst_n = 0;
        cpu_req = '0;

        #25;
        rst_n = 1;
        @(posedge clk);

        $display("\n========== STARTING CACHE TEST ==========\n");

        // 1. READ (expect MISS + REFILL)
        send_req(32'h0000_0010, 1'b0, 32'h0);

        // 2. WRITE (should be HIT)
        send_req(32'h0000_0010, 1'b1, 32'hDEADBEEF);

        // 3. READ BACK (should return written data)
        send_req(32'h0000_0010, 1'b0, 32'h0);

        // 4. WRITE new line (MISS + allocate)
        send_req(32'h0000_1010, 1'b1, 32'hCAFEBABE);

        // 5. READ BACK second line
        send_req(32'h0000_1010, 1'b0, 32'h0);

        $display("\n========== TEST COMPLETE ==========\n");
        #20;
        $finish;
    end

endmodule