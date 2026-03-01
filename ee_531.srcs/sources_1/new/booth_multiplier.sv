`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 12:49:39 PM
// Design Name: 
// Module Name: booth_multiplier
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


module booth_multiplier (
    input  logic [4:0] multiplicand,  // CSA sum
    input  logic [3:0] multiplier,
    output logic [8:0] product
);

    logic [8:0] partial [3:0]; // 4 partial products

    integer i;

    always_comb begin
        // Generate partial products
        for (i = 0; i < 4; i++) begin
            if (multiplier[i])
                partial[i] = multiplicand << i; // shift for each multiplier bit
            else
                partial[i] = 9'd0;
        end

        // Sum partial products
        product = partial[0] + partial[1] + partial[2] + partial[3];
    end

endmodule


