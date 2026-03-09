`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 05:13:06 PM
// Design Name: 
// Module Name: l1_tb
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

module l1_tb;

    logic clk;
    logic rst_n;

    // CPU interface
    cache_req_t  cpu_req;
    cache_resp_t cpu_resp;

    // Mock L2 interface
    cache_req_t  l2_req;
    cache_resp_t l2_resp;
    logic        l2_ready;

    // Instantiate L1
    l1_cache l1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(cpu_req),
        .cpu_resp(cpu_resp),
        .l2_req(l2_req),
        .l2_resp(l2_resp),
        .l2_ready(l2_ready)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; 

    // Mock L2 memory (word-indexed using OFFSET_BITS)
    logic [DATA_WIDTH-1:0] l2_mem [0:8191]; 
    initial for (int i=0; i<8192; i++) l2_mem[i] = i;

    // Mock L2 behavior
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_resp  <= '0;
            l2_ready <= 1;
        end else if (l2_req.valid) begin
            if (l2_req.we) begin
                l2_mem[l2_req.addr[ADDR_WIDTH-1:OFFSET_BITS]] <= l2_req.wdata;
                l2_resp.valid <= 0;
            end else begin
                l2_resp.valid <= 1;
                l2_resp.rdata <= l2_mem[l2_req.addr[ADDR_WIDTH-1:OFFSET_BITS]];
            end
        end else begin
            l2_resp.valid <= 0;
        end
    end

    // Helper task to deassert CPU request
    task deassert_request();
        @(posedge clk);
        cpu_req <= '0;
        @(posedge clk); // FSM settle
        @(posedge clk);
    endtask

    // Reset and Test Cases
    initial begin
        rst_n = 0;
        cpu_req = '0;
        #20;
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("--- Starting L1 Cache Tests ---");

        // 1. Read Miss
        $display("Test 1: Read Miss at 0x10");
        cpu_req.valid <= 1;
        cpu_req.we    <= 0;
        cpu_req.addr  <= 32'h0000_0010;
        wait(cpu_resp.valid === 1'b1);
        assert(cpu_resp.rdata == l2_mem[32'h10 >> OFFSET_BITS]) 
            else $fatal(1, "Read miss failed");
        deassert_request();

        // 2. Write Hit
        $display("Test 2: Write Hit at 0x10");
        cpu_req.valid <= 1;
        cpu_req.we    <= 1;
        cpu_req.addr  <= 32'h0000_0010;
        cpu_req.wdata <= 32'hDEADBEEF;
        wait(cpu_resp.valid === 1'b1);
        assert(l1_inst.dirty_array[l1_inst.hit_way][l1_inst.addr_index] === 1'b1)
            else $fatal(1, "Dirty bit not set on write hit");
        deassert_request();

        // 3. Read Hit (Verify Write)
        $display("Test 3: Read Hit at 0x10");
        cpu_req.valid <= 1;
        cpu_req.we    <= 0;
        cpu_req.addr  <= 32'h0000_0010;
        wait(cpu_resp.valid === 1'b1);
        assert(cpu_resp.rdata == 32'hDEADBEEF)
            else $fatal(1, "Read hit returned wrong data: %h", cpu_resp.rdata);
        deassert_request();

        // 4. Fill Set for Eviction
        $display("Test 4: Fill Set Way 1");
        cpu_req.valid <= 1;
        cpu_req.we    <= 0;
        cpu_req.addr  <= 32'h0001_0010; // same index, new tag
        wait(cpu_resp.valid === 1'b1);
        deassert_request();

        // 5. Evict Dirty Line -> WRITEBACK
        $display("Test 5: Evict Dirty Line");
        cpu_req.valid <= 1;
        cpu_req.we    <= 0;
        cpu_req.addr  <= 32'h0002_0010; // same index, different tag
        wait(cpu_resp.valid === 1'b1);

        // Check L2 memory
        assert(l2_mem[32'h10 >> OFFSET_BITS] == 32'hDEADBEEF)
            else $fatal(1, "WRITEBACK failed: L2 memory not updated");

        // Check that L1 dirty bit cleared
        assert(l1_inst.dirty_array[l1_inst.victim_way_reg][l1_inst.addr_index] === 1'b0)
            else $fatal(1, "Dirty bit not cleared after WRITEBACK");

        $display("WRITEBACK Verified");
        deassert_request();

        $display("--- All L1 tests passed ---");
        $finish;
    end

endmodule
