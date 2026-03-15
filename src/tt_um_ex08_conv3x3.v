/*
 * Copyright (c) 2026 Cyrill Rüttimann
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Top-level TinyTapeout user module wrapping a 3x3 Gaussian convolution core.
// Protocol on uio:
//   - While loading pixels:  uio_in  = 8'h01
//   - After 9 pixels:        uio_in  = 8'h00  (closes load window, starts MAC)
//   - When MAC is done:      uio_out = 8'h01  (result valid on uo_out)

module tt_um_ex08_conv3x3 (
    input  wire [7:0] ui_in,    // pixel input during load window
    output wire [7:0] uo_out,   // filtered output pixel
    input  wire [7:0] uio_in,   // control from host (load window)
    output wire [7:0] uio_out,  // status to host (done flag)
    output wire [7:0] uio_oe,   // uio output enable
    input  wire       ena,      // unused (TinyTapeout enable)
    input  wire       clk,
    input  wire       rst_n
);

    // Done flag from convtop drives uio_out[0]
    logic done;
    assign uio_out = done ? 8'h01 : 8'h00;
    assign uio_oe  = 8'hFF;  // always drive all uio_out bits

    wire reset_i = ~rst_n;

    // Load window: high while host is streaming 9 pixels
    wire       load_window = (uio_in == 8'h01);
    wire [7:0] pixel_bits  = ui_in;

    // 9-pixel buffer for a single 3x3 window
    logic [7:0] pix [0:8];

    // Simple FSM for load / run control
    typedef enum logic [1:0] {S_IDLE, S_LOAD, S_RUN} state_t;
    state_t state_q, state_d;

    logic [3:0] pix_idx_q, pix_idx_d;
    logic       run_pulse_q, run_pulse_d;

    logic [7:0] result;

    // FSM next-state logic
    always_comb begin
        state_d     = state_q;
        pix_idx_d   = pix_idx_q;
        run_pulse_d = 1'b0;

        case (state_q)

            // Wait for host to open load window
            S_IDLE: begin
                if (load_window) begin
                    pix_idx_d = 4'd0;   // first pixel index
                    state_d   = S_LOAD;
                end
            end

            // Load exactly 9 pixels while load_window is high
            S_LOAD: begin
                if (load_window) begin
                    // Count up to index 8 while window is high
                    if (pix_idx_q < 4'd8)
                        pix_idx_d = pix_idx_q + 4'd1;
                    // Stay in S_LOAD until window closes
                end else begin
                    // Window closed: if we saw 9 pixels, start MAC
                    if (pix_idx_q == 4'd8)
                        run_pulse_d = 1'b1;
                    state_d = S_RUN;
                end
            end

            // Wait for MAC to assert done
            S_RUN: begin
                if (done)
                    state_d = S_IDLE;
            end

        endcase
    end

    // State registers and pixel writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q     <= S_IDLE;
            pix_idx_q   <= 4'd0;
            run_pulse_q <= 1'b0;
            for (int i = 0; i < 9; i++)
                pix[i] <= 8'd0;
        end else begin
            state_q     <= state_d;
            pix_idx_q   <= pix_idx_d;
            run_pulse_q <= run_pulse_d;

            // Use next state/index so the first load cycle writes pix[0]
            if (state_d == S_LOAD && load_window)
                pix[pix_idx_d] <= pixel_bits;
        end
    end

    // Flatten pixel buffer into 72-bit bus for conv core
    wire [71:0] pix_flat = {
        pix[0], pix[1], pix[2],
        pix[3], pix[4], pix[5],
        pix[6], pix[7], pix[8]
    };

    // Convolution core wrapper
    convtop u_convtop (
        .clock_i (clk),
        .reset_i (reset_i),
        .pix_flat(pix_flat),
        .run     (run_pulse_q),
        .result  (result),
        .done    (done)
    );

    assign uo_out = result;

    // Silence unused ena
    wire _unused = &{ena, 1'b0};

endmodule

`default_nettype wire
