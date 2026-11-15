#!/usr/bin/env bash
# =============================================================================
# run_sim.sh - compile and run ONE testbench, optionally open GTKWave.
# Usage (from the repository root):
#   bash simulation/run_sim.sh tb_two_bit_predictor          # run
#   bash simulation/run_sim.sh tb_two_bit_predictor --wave   # run + GTKWave
# =============================================================================
set -eu
cd "$(dirname "$0")/.."

tb=${1:?usage: run_sim.sh <testbench_name> [--wave]}
mkdir -p build simulation/waveforms
iverilog -g2005 -Wall -o "build/$tb" "testbench/$tb.v" rtl/*.v
vvp -n "build/$tb"

if [ "${2:-}" = "--wave" ]; then
    vcd="simulation/waveforms/$tb.vcd"
    gtkw="simulation/waveforms/$tb.gtkw"
    if command -v gtkwave > /dev/null; then
        if [ -f "$gtkw" ]; then gtkwave "$vcd" "$gtkw" & else gtkwave "$vcd" & fi
    else
        echo "GTKWave not found. Install it (see README) or render a PNG with: make waves"
    fi
fi
