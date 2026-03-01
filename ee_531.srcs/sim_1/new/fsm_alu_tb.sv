`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 12:55:57 PM
// Design Name: 
// Module Name: fsm_alu_tb
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

module fsm_alu_tb;

    // DUT Signals
    logic clk;
    logic rst;
    logic start;

    logic [3:0] A, B, C;
    logic [8:0] Y;
    logic valid_out;
    logic busy;

    // Instantiate DUT
    fsm_alu dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .A(A),
        .B(B),
        .C(C),
        .Y(Y),
        .valid_out(valid_out),
        .busy(busy)
    );


    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    // Test Task
    task run_test(input [3:0] a_in,
                  input [3:0] b_in,
                  input [3:0] c_in);

        logic [8:0] expected;

        begin
            expected = (a_in + b_in) * c_in;

            @(posedge clk);
            A = a_in;
            B = b_in;
            C = c_in;
            start = 1;

            @(posedge clk);
            start = 0;

            // Wait for valid_out
            wait (valid_out == 1);
            @(posedge clk);

            if (Y !== expected) begin
                $display("ERROR: A=%0d B=%0d C=%0d | Expected=%0d Got=%0d",
                          a_in, b_in, c_in, expected, Y);
            end
            else begin
                $display("PASS: A=%0d B=%0d C=%0d | Result=%0d",
                          a_in, b_in, c_in, Y);
            end
        end

    endtask

    // Test Sequence
    initial begin

        // Initialize
        rst = 1;
        start = 0;
        A = 0;
        B = 0;
        C = 0;

        repeat (2) @(posedge clk);
        rst = 0;

        run_test(4'd3, 4'd2, 4'd4);   // 20
        run_test(4'd7, 4'd1, 4'd3);   // 24
        run_test(4'd15,4'd15,4'd15);  // 450
        run_test(4'd0, 4'd8, 4'd5);   // 40
        run_test(4'd9, 4'd6, 4'd2);   // 30

        // Random tests
        repeat (10) begin
            run_test($urandom_range(0,15),
                     $urandom_range(0,15),
                     $urandom_range(0,15));
        end

        $display("All tests completed.");
        $finish;

    end

endmodule


