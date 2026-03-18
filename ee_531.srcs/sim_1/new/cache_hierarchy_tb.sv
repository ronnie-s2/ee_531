`timescale 1ns / 1ps

import cache_params_pkg::*;

module cache_hierarchy_tb;

    // Clock and reset
    logic clk;
    logic rst_n;

    // CPU interface signals
    cache_req_t  cpu_req;
    cache_resp_t cpu_resp;

    // Clock generation: 10 ns period (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate the cache hierarchy
    cache_hierarchy_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(cpu_req),
        .cpu_resp(cpu_resp)
    );

    // ================== Testbench variables ==================
    integer i;

    // Task to send a CPU request
    task automatic cpu_send(input logic we, input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] wdata);
        begin
            cpu_req.valid = 1;
            cpu_req.we    = we;
            cpu_req.addr  = addr;
            cpu_req.wdata = wdata;

            // Wait one clock cycle
            @(posedge clk);
            cpu_req.valid = 0;
        end
    endtask

    // Monitor CPU responses
    initial begin
        $display("[%t] Starting Cache Hierarchy Testbench", $realtime);
        forever @(posedge clk) begin
            if (cpu_resp.valid) begin
                $display("[%t] CPU Response: addr=%0h we=%0b rdata=%0h hit=%0b", 
                         $realtime, cpu_resp.addr, cpu_resp.we, cpu_resp.rdata, cpu_resp.hit);
            end
        end
    end

    // ================== Test Sequence ==================
    initial begin
        // Initialize signals
        rst_n = 0;
        cpu_req = '0;
        repeat (5) @(posedge clk);

        // Release reset
        rst_n = 1;
        @(posedge clk);

        // Test 1: Read address 0x10
        cpu_send(0, 16'h0010, '0);

        // Wait some cycles
        repeat (50) @(posedge clk);

        // Test 2: Write address 0x10
        cpu_send(1, 16'h0010, 32'hDEADBEEF);

        // Wait some cycles
        repeat (50) @(posedge clk);

        // Test 3: Read back address 0x10
        cpu_send(0, 16'h0010, '0);

        // Test 4: Write another address
        cpu_send(1, 16'h1010, 32'hCAFEBABE);

        // Test 5: Read it back
        cpu_send(0, 16'h1010, '0);

        // Wait for some time for refill/writeback to complete
        repeat (200) @(posedge clk);

        $display("[%t] Testbench finished", $realtime);
        $finish;
    end

endmodule