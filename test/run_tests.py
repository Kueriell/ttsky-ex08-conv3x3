#!/usr/bin/env python3
"""
Randomized verification for the 1‑channel 3×3 Gaussian convolution engine.

Protocol:
  - uio_in = 0x01 while loading 9 pixels
  - uio_in = 0x00 to start MAC
  - uio_out = 0x01 when result is ready on uo_out
"""

import sys
import os
import subprocess
import re
import random

# Import golden model
sys.path.append(os.path.dirname(__file__))
from golden_model import conv3x3_single_channel


def build_and_run(tb_path: str) -> str:
    """Compile DUT + generated testbench with Icarus and run the simulation."""
    subprocess.run(
        [
            "iverilog",
            "-g2012",
            "-o",
            "sim_rand.out",
            tb_path,
            "src/tt_um_ex08_conv3x3.v",
            "src/convtop.v",
            "src/convcomp.v",
        ],
        check=True,
    )

    out = subprocess.check_output(["vvp", "sim_rand.out"]).decode()
    return out


NUM_RANDOM = 1
ok = 0
fail = 0

for t in range(NUM_RANDOM):

    # Generate 9 random 8‑bit pixels
    img = [random.randint(0, 255) for _ in range(9)]

    # Golden model output
    gold = conv3x3_single_channel(img)

    # Path for temporary testbench
    tb_path = os.path.join(os.path.dirname(__file__), "tb_rand_tmp.v")

    # Generate Verilog testbench matching the uio protocol
    tb = "`timescale 1ns/1ps\n"
    tb += "module tb_rand;\n"
    tb += "    logic clk = 0;\n"
    tb += "    logic rst_n = 0;\n"
    tb += "    logic [7:0] ui_in;\n"
    tb += "    wire  [7:0] uo_out;\n"
    tb += "    logic [7:0] uio_in = 0;\n"
    tb += "    wire  [7:0] uio_out;\n"
    tb += "    wire  [7:0] uio_oe;\n"
    tb += "    logic ena = 1;\n"
    tb += "    logic [7:0] rtl;\n\n"

    tb += "    always #10 clk = ~clk;\n\n"

    tb += "    tt_um_ex08_conv3x3 dut (\n"
    tb += "        .ui_in(ui_in), .uo_out(uo_out),\n"
    tb += "        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),\n"
    tb += "        .ena(ena), .clk(clk), .rst_n(rst_n)\n"
    tb += "    );\n\n"

    tb += "    initial begin\n"
    tb += "        rst_n = 0;\n"
    tb += "        ui_in = 0;\n"
    tb += "        uio_in = 0;\n"
    tb += "        repeat (5) @(posedge clk);\n"
    tb += "        rst_n = 1;\n\n"

    # Load window: uio_in = 0x01 while loading 9 pixels
    for i in range(9):
        tb += "        uio_in = 8'h01;\n"
        tb += f"        ui_in = 8'd{img[i]};\n"
        tb += "        @(posedge clk);\n"

    # Close window and start MAC
    tb += "        ui_in = 0;\n"
    tb += "        uio_in = 8'h00;\n"
    tb += "        @(posedge clk);\n\n"

    # Wait for done and print result
    tb += "        wait (uio_out == 8'h01);\n"
    tb += "        rtl = uo_out;\n"
    tb += "        $display(\"RESULT %0d\", rtl);\n"
    tb += "        $finish;\n"
    tb += "    end\n"
    tb += "endmodule\n"

    # Write testbench file
    with open(tb_path, "w") as f:
        f.write(tb)

    # Compile + run
    out = build_and_run(tb_path)

    # Extract RTL result
    m = re.search(r"RESULT\\s+(\\d+)", out)
    if not m:
        print("No result found!")
        fail += 1
        continue

    rtl = int(m.group(1))

    # Compare RTL vs. golden
    if rtl == gold:
        ok += 1
    else:
        fail += 1
        print("\n--- RANDOM MISMATCH ---")
        print("Image:", img)
        print(f"RTL:  {rtl}")
        print(f"GOLD: {gold}")
        print("------------------------")

# Summary
print(f"\nRandom Tests OK:   {ok}")
print(f"Random Tests FAIL: {fail}")
