`default_nettype none

// -----------------------------------------------------------------------------
// convtop
// -----------------------------------------------------------------------------
// Thin wrapper around the convcomp MAC engine.
//
// Responsibilities:
//   - Forward the 9‑pixel flattened window and the run pulse to convcomp
//   - Latch the filtered result for one cycle when convcomp asserts done
//   - Re‑assert done upward as a clean one‑cycle pulse
//
// This module exists mainly to keep the top‑level neat and to allow future
// extensions (e.g., multi‑channel, pipelining, or streaming).
// -----------------------------------------------------------------------------

module convtop (
    input  wire        clock_i,
    input  wire        reset_i,
    input  wire [71:0] pix_flat,   // 9×8‑bit pixels, flattened
    input  wire        run,        // single‑cycle start pulse
    output logic [7:0] result,     // filtered output pixel
    output logic       done        // one‑cycle pulse when result is valid
);

    logic [7:0] conv_filt;
    logic       conv_done;

    // Core convolution MAC
    convcomp u_conv (
        .clock_i (clock_i),
        .reset_i (reset_i),
        .run     (run),
        .pix_flat(pix_flat),
        .filt    (conv_filt),
        .done    (conv_done)
    );

    // Output latch + done pulse
    always_ff @(posedge clock_i) begin
        if (reset_i) begin
            result <= 8'd0;
            done   <= 1'b0;

        end else begin
            done <= 1'b0;  // default: no pulse

            if (conv_done) begin
                // Latch filtered result and pulse done for one cycle
                result <= conv_filt;
                done   <= 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
