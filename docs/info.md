<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
This project implements a compact 1‑channel 3×3 Gaussian convolution engine.
It receives 9 pixels serially over an 8‑bit input bus, performs a Gaussian blur on the 3×3 window, and outputs a single 8‑bit filtered result.
The design is optimized for Tiny Tapeout’s limited I/O:
- 8 input pins (ui_in)
- 8 output pins (uo_out)
- 8 bidirectional pins used only for control (uio_in, uio_out)
- No external memory or streaming interface
The convolution uses a fixed 3×3 Gaussian kernel

1 2 1
2 4 2
1 2 1

TheThe kernel sum is 16, so the output is normalized by a right‑shift of 4.

### Data loading protocol
Pixels are loaded through 'ui_in[7:0]'.
The load window is controlled via 'uio_in':
- 'uio_in = 0x01' → load window open
- 'uio_in = 0x00' → load window closed, start convolution
The user must send exactly 9 pixels, one per clock cycle, in raster order:

pix[0] pix[1] pix[2]
pix[3] pix[4] pix[5]
pix[6] pix[7] pix[8]

The hardware automatically detects the falling edge of the load window and begins the MAC operation.

### Convolution engine
TheThe computation is performed by two modules:

#### convcomp
A single‑cycle‑per‑tap MAC engine:
1. Multiply pixel × kernel weight
2. Accumulate over 9 taps
3. Divide by 16 (right shift by 4)
4. Clamp to 0–255
5. Assert 'done' for one cycle

#### convtop
A thin wrapper that:
- forwards the flattened pixel window to 'convcomp'
- latches the filtered result
- re‑pulses 'done' upward
The entire convolution completes in 9 clock cycles after the load window closes.

### Output behavior
- The filtered result is driven on 'uo_out[7:0]'.
- Completion is signaled via 'uio_out = 0x01' for one cycle.
- The result is valid in the same cycle that 'uio_out' asserts.

## How to test
Two verification paths are provided:

1. Cocotb testbench ('test.py')
    - generates random 9‑pixel windows
    - loads them into the DUT
    - waits for 'uio_out == 0x01'
    - compares the RTL output to the Python golden model

2. Python randomized test harness ('run_tests.py')
    - generates random 9‑pixel inputs
    - dynamically builds a Verilog testbench
    - compiles with Icarus Verilog
    - extracts the RTL result
    - compares against the golden model

Both tests must pass for the design to be considered correct.

## External hardware
No external hardware is required.
All computation is performed on‑chip using the Tiny Tapeout digital fabric.