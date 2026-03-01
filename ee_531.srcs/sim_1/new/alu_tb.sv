`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/23/2026 07:32:06 PM
// Design Name: 
// Module Name: alu_tb
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

module alu_tb;
    // Signals
    logic signed [7:0] data_in;
    logic [4:0]        op_code;
    logic              clk = 0;
    logic              reset;
    logic signed [7:0] out_upper, out_lower;
    logic              sign_bit;

    // Instantiate ALU
    alu uut (.*);

    // Clock Generation
    always #5 clk = ~clk;

    // Helper Task: Load registers and wait for clock
    task load_vals(input [7:0] a, input [7:0] b);
        @(posedge clk); op_code = 5'b00001; data_in = a; // Load A0
        @(posedge clk); op_code = 5'b00010; data_in = b; // Load B0
    endtask

    // Helper Task: Run Op and Display Result
    task run_op(input [4:0] code, input string name);
        @(posedge clk); op_code = code;
        @(posedge clk); op_code = 5'b10000; // Default to Read A0
        #1; $display("%s Result: %d (Sign: %b)", name, out_lower, sign_bit);
    endtask

    initial begin
        // Reset System
        reset = 1; #20; reset = 0;

        // --- ARITHMETIC ---
        // Addition
        load_vals(8'd10, 8'd20);  run_op(5'b00011, "ADD (10+20)");
        load_vals(-8'd15, 8'd5);  run_op(5'b00011, "ADD (-15+5)");

        // Subtraction
        load_vals(8'd30, 8'd10);  run_op(5'b00100, "SUB (30-10)");
        load_vals(8'd5, 8'd15);   run_op(5'b00100, "SUB (5-15)");

        // Multiplication
        load_vals(8'd4, 8'd3);    
        @(posedge clk); op_code = 5'b00101; // Mult
        @(posedge clk); op_code = 5'b10010; // Read A0,B0
        #1; $display("MULT (4*3): Upper=%d, Lower=%d", out_upper, out_lower);
        
        load_vals(8'd120, 8'd2); 
        @(posedge clk); op_code = 5'b00101;
        @(posedge clk); op_code = 5'b10010;
        #1; $display("MULT (120*2): 16-bit Result=%d", {out_upper, out_lower});

        // --- LOGICAL ---
        // AND
        load_vals(8'b10101010, 8'b11110000); run_op(5'b00110, "AND");
        load_vals(8'hFF, 8'h00);             run_op(5'b00110, "AND");
        
        // OR
        load_vals(8'b10101010, 8'b01010101); run_op(5'b00111, "OR");
        load_vals(8'h0F, 8'hF0);             run_op(5'b00111, "OR");
        
        // XOR
        load_vals(8'hAA, 8'hAA);             run_op(5'b01000, "XOR");
        load_vals(8'hFF, 8'h00);             run_op(5'b01000, "XOR");
        
        // NOT
        load_vals(8'b11110000, 8'b0);        run_op(5'b01001, "NOT");
        load_vals(8'b01010101, 8'b0);        run_op(5'b01001, "NOT");

        // --- SHIFTS (B0 is shift amount) ---
        // LSL
        load_vals(8'b00000001, 8'd1);        run_op(5'b01010, "LSL 1");
        load_vals(8'b00001111, 8'd4);        run_op(5'b01010, "LSL 4");
        
        // LSR
        load_vals(8'b10000000, 8'd1);        run_op(5'b01011, "LSR 1");
        load_vals(8'b11110000, 8'd4);        run_op(5'b01011, "LSR 4");
        
        // ASR
        load_vals(-8'd16, 8'd2);             run_op(5'b01100, "ASR -16>>2");
        load_vals(8'd16, 8'd2);              run_op(5'b01100, "ASR 16>>2");

        // --- ROTATES ---
        // RSL
        load_vals(8'b10000001, 8'd1);        run_op(5'b01101, "RSL 1");
        load_vals(8'b11000000, 8'd2);        run_op(5'b01101, "RSL 2");
        
        // RSR
        load_vals(8'b00000011, 8'd1);        run_op(5'b01110, "RSR 1");
        load_vals(8'b00000011, 8'd2);        run_op(5'b01110, "RSR 2");

        // --- LOAD/READ REGS ---
        load_vals(8'd55, 8'd0);
        @(posedge clk); op_code = 5'b10000; #1; // Read A0
        $display("Read A0: %d, Sign Bit: %b", out_lower, sign_bit);
        
        load_vals(8'd0, -8'd1);
        @(posedge clk); op_code = 5'b10001; #1; // Read B0
        $display("Read B0: %d, Sign Bit: %b", out_lower, sign_bit);

        #100;
        $finish;
    end
endmodule
