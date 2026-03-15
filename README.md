![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

## 3×3 Convolution Engine (inspired by Exercise 08, VLSI 1)
A compact, fully synchronous 3×3 Gaussian convolution engine designed for Tiny Tapeout.
The module loads nine 8‑bit pixels serially via `ui_in`, performs a fixed‑coefficient Gaussian convolution, and outputs the filtered 8‑bit result on `uo_out`.

## Architecture Overview
- Pixel Loader:
  Serial acquisition of nine 8‑bit pixels into an internal buffer pix[0..8].
- Run‑Pulse Generator:
  Produces a single‑cycle run pulse when the host closes the load window.
- Convolution Core: 
  - Nine‑cycle multiply–accumulate pipeline
  - 8‑bit Gaussian kernel coefficients
  - 20‑bit accumulator
  - Saturated 8‑bit output
- Output Stage:
  The filtered pixel appears on `uo_out`.
  A one‑cycle "done" pulse is returned on `uio_out`.


## Verification
Verification is performed using Cocotb:
- Randomized 3×3 pixel blocks
- Python golden model
- RTL vs. golden comparison
- Deterministic PASS/FAIL
- FST waveform dump for GTKWave

### Example output:
Random image = [36, 25, 85, 20, 112, 118, 7, 115, 24]
Golden result = 72
RTL result    = 72
Cocotb test PASSED

## I/O Interface
| Signal       | Direction | Width | Description                                      |
|--------------|-----------|-------|--------------------------------------------------|
| clk          | in        | 1     | System clock                                     |
| rst_n        | in        | 1     | Asynchronous reset, active low                   |
| ui_in        | in        | [7:0] | Pixel data input during load window              |
| uo_out       | out       | [7:0] | 8‑bit convolution result                         |
| uio_in       | in        | [7:0] | Host control: 0x01=open load window, 0x00=close |
| uio_out      | out       | [7:0] | Status: 0x01=MAC done, 0x00=busy                 |
| uio_oe       | out       | [7:0] | Output enable for uio_out (always 0xFF)          |
| ena          | in        | 1     | Unused (Tiny Tapeout enable)                     |


## Simulation and Waveforms
Run the Cocotb testbench:
```sh
cd test
make -B
```
Open the waveform:
```sh
gtkwave tb.fst waves/tt_um_ex08_conv3x3.gtkw
```
The GTKWave layout highlights loader state, pixel registers, MAC pipeline, and output timing.

## Synthesis and Layout
The design was hardened using LibreLane:
- No setup or hold violations
- No slew or capacitance violations
- One non‑critical fanout warning in the clock tree
- Final GDS successfully generated

## Repository Structure
- src/ — RTL (top module, loader, convolution core)
- test/ — Cocotb testbench and golden model
- docs/ — Project documentation
- info.yaml — Tiny Tapeout metadata

## Submission
The project is fully verified and ready for submission to the Tiny Tapeout shuttle:
https://app.tinytapeout.com/

## Physical Signoff Summary

The design was hardened using OpenLane (Sky130 HD).  
All signoff checks passed:

- **Standard cells:** 543  
- **Core utilization:** 53%  
- **Die area:** 0.017 mm²  
- **Critical path:** 5.87 ns (meets 20 ns clock with large margin)  
- **Setup violations:** 0  
- **Hold violations:** 0  
- **DRC violations:** 0  
- **Antenna violations:** 0  
- **ERC:** clean  
- **Routing:** no shorts, no spacing errors  
- **Fanout:** one non‑critical warning on the clock net (expected for TT)  
- **Power (typical):** ~1.3 nW total  
- **Final GDS:** generated successfully

## Author
Cyrill Rüttimann