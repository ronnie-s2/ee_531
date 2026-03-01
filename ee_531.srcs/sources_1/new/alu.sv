`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/23/2026 06:44:20 PM
// Design Name: 
// Module Name: alu
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


module alu (
    input  logic signed [7:0] data_in, // Input for Load operations
    input  logic [4:0]        op_code, // Operation selector
    input  logic              clk,
    input  logic              reset,
    output logic signed [7:0] out_upper, // For Read A0,B0
    output logic signed [7:0] out_lower, // For Read A0 or B0
    output logic              sign_bit   // Sign bit for read operations
);

    // Internal Registers
    logic signed [7:0] A0;
    logic signed [7:0] B0;

    // Logic for sign bit and outputs
    // Note: MSB of registers is the sign bit
    assign sign_bit = out_lower[7]; 

    always_ff @(posedge clk) begin
        if (reset) begin
            A0 <= 8'sb0;
            B0 <= 8'sb0;
        end else begin
            case (op_code)
                // --- Register Loads ---
                5'b00001: A0 <= data_in;
                5'b00010: B0 <= data_in;
    
                // --- Arithmetic ---
                5'b00011: A0 <= A0 + B0;      // Addition
                5'b00100: A0 <= A0 - B0;      // Subtraction
                5'b00101: {A0, B0} <= A0 * B0; // Multiplication: A0=MSB, B0=LSB
    
                // --- Logical ---
                5'b00110: A0 <= A0 & B0; // AND
                5'b00111: A0 <= A0 | B0; // OR
                5'b01000: A0 <= A0 ^ B0; // XOR
                5'b01001: A0 <= ~A0;     // NOT
    
                // --- Logical Shifts ---
                5'b01010: A0 <= A0 << B0;  // LSL: Logical Shift Left
                5'b01011: A0 <= A0 >> B0;  // LSR: Logical Shift Right
                
                // --- Arithmetic Shift ---
                5'b01100: A0 <= A0 >>> B0; // ASR: Arithmetic Shift Right (preserves sign)
    
                // --- Rotate Shifts ---
                // Rotate Left: bits shifted out of MSB enter at LSB
                5'b01101: A0 <= (A0 << B0[2:0]) | (A0 >> (8 - B0[2:0])); // RSL
                
                // Rotate Right: bits shifted out of LSB enter at MSB
                5'b01110: A0 <= (A0 >> B0[2:0]) | (A0 << (8 - B0[2:0])); // RSR
    
                default: ; // Maintain state
            endcase
        end
    end
    
    // --- Read Operations (Combinational) ---
    always_comb begin
        // Default values to avoid latches
        out_lower = 8'b0;
        out_upper = 8'b0;
        
        case (op_code)
            5'b10000: out_lower = A0; // Read A0
            5'b10001: out_lower = B0; // Read B0
            5'b10010: begin           // Read A0,B0
                out_upper = A0;
                out_lower = B0;
            end
            default: begin
                out_lower = 8'b0;
                out_upper = 8'b0;
            end
        endcase
    end

endmodule