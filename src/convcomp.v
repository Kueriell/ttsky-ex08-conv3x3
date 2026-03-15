`default_nettype none

// 3x3 Gaussian convolution MAC block.
// - Takes 9 pixels (flattened) and a run pulse.
// - Applies fixed 3x3 Gaussian kernel (sum = 16).
// - Accumulates products, divides by 16 (>> 4), clamps to [0,255].
// - Asserts done for one cycle when filt is valid.

module convcomp (
    input  wire        clock_i,
    input  wire        reset_i,
    input  wire        run,
    input  wire [71:0] pix_flat,
    output logic [7:0] filt,
    output logic       done
);

    // 1) Extract 9 pixels from flattened bus
    wire [7:0] pix [0:8];

    genvar i;
    generate
        for (i = 0; i < 9; i++) begin
            assign pix[i] = pix_flat[71 - 8*i -: 8];
        end
    endgenerate

    // 2) Gaussian kernel weights
    function automatic [7:0] kernel(input int idx);
        case (idx)
            0: kernel = 8'd1;
            1: kernel = 8'd2;
            2: kernel = 8'd1;
            3: kernel = 8'd2;
            4: kernel = 8'd4;
            5: kernel = 8'd2;
            6: kernel = 8'd1;
            7: kernel = 8'd2;
            8: kernel = 8'd1;
            default: kernel = 8'd0;
        endcase
    endfunction

    // 3) MAC engine
    logic [19:0] acc;   // accumulator for sum of products
    logic [3:0]  idx;   // tap index 0..8
    logic        busy;  // MAC is active

    // Current product term
    wire [19:0] term_w =
        ({12'd0, pix[idx]} * {12'd0, kernel(idx)});

    // Next accumulator value
    wire [19:0] acc_next_w = acc + term_w;

    // Value to be divided after last tap
    wire [19:0] acc_div_in_w =
        (idx == 4'd8) ? acc_next_w : acc;

    // Divide by 16 (kernel sum) via right shift
    wire [19:0] acc_shift_raw_w = acc_div_in_w >> 4;

    // Clamp to 8-bit range
    wire [7:0] acc_shift_clamped_w =
        (acc_shift_raw_w > 20'd255) ? 8'd255 :
                                      acc_shift_raw_w[7:0];

    // 4) Simple run/busy/done FSM
    always_ff @(posedge clock_i) begin
        if (reset_i) begin
            acc  <= 20'd0;
            idx  <= 4'd0;
            busy <= 1'b0;
            done <= 1'b0;
            filt <= 8'd0;

        end else begin
            done <= 1'b0;  // default: done is a one-cycle pulse

            if (run && !busy) begin
                // Start a new MAC sequence
                busy <= 1'b1;
                acc  <= 20'd0;
                idx  <= 4'd0;

            end else if (busy) begin
                // Accumulate current tap
                acc <= acc_next_w;

                if (idx == 4'd8) begin
                    // Last tap: produce output and finish
                    filt <= acc_shift_clamped_w;
                    done <= 1'b1;
                    busy <= 1'b0;
                end else begin
                    // Move to next tap
                    idx <= idx + 4'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
