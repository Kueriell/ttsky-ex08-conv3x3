# SPDX-License-Identifier: Apache-2.0
#
# Cocotb verification for the 1‑channel 3×3 Gaussian convolution engine.
# Protocol:
#   - uio_in = 0x01 while loading 9 pixels
#   - uio_in = 0x00 to start MAC
#   - uio_out = 0x01 when result is ready on uo_out

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import random

from golden_model import conv3x3_single_channel


@cocotb.test()
async def test_project(dut):
    """Single randomized 3×3 window test against the Python golden model."""

    # Start clock
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset DUT
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # Random 3×3 image
    img = [random.randint(0, 255) for _ in range(9)]
    gold = conv3x3_single_channel(img)
    dut._log.info(f"Image: {img}, GOLD={gold}")

    # Load window: uio_in = 0x01 while loading 9 pixels
    for px in img:
        dut.ui_in.value  = px & 0xFF
        dut.uio_in.value = 0x01
        await RisingEdge(dut.clk)

    # Close window: uio_in = 0x00 -> start MAC
    dut.ui_in.value  = 0
    dut.uio_in.value = 0x00
    await RisingEdge(dut.clk)

    # Wait for done: uio_out == 0x01
    while int(dut.uio_out.value) != 0x01:
        await RisingEdge(dut.clk)

    rtl = int(dut.uo_out.value)
    dut._log.info(f"RTL={rtl}, GOLD={gold}")
    assert rtl == gold, f"Mismatch! RTL={rtl} GOLD={gold}"
