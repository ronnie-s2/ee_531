`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/17/2026 12:51:33 PM
// Design Name: 
// Module Name: fsm
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


module fsm_controller (
    input  logic clk,
    input  logic rst,
    input  logic start,

    output logic load_sum,
    output logic load_product,
    output logic valid_out,
    output logic busy
);

    typedef enum logic [1:0] {
        IDLE,
        ADD,
        MULT,
        DONE
    } state_t;

    state_t state, next_state;

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: if (start) next_state = ADD;
            ADD:  next_state = MULT;
            MULT: next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end

    // Output logic
    assign load_sum     = (state == ADD);
    assign load_product = (state == MULT);
    assign valid_out    = (state == DONE);
    assign busy         = (state != IDLE);

endmodule

