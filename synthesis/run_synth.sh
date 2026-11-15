#!/usr/bin/env bash
# =============================================================================
# run_synth.sh - Yosys synthesis of branch_prediction_top, one run per
# predictor type (0 = static, 1 = 1-bit, 2 = 2-bit), BHT = BTB = 16 entries.
#
# For each configuration two flows are run:
#   generic : `synth`        -> technology-independent gate/flip-flop count
#   xilinx  : `synth_xilinx` -> LUT / FF / carry / mux cell counts after
#                               mapping to Xilinx 7-series primitives
# Both are PRE-place-and-route estimates. No timing (Fmax) is produced: that
# requires a vendor place-and-route tool (e.g. Vivado) and a target device.
#
# The script also asserts that no latches were inferred.
# Reports: synthesis/reports/
# =============================================================================
set -eu
cd "$(dirname "$0")/.."
OUT=synthesis/reports
mkdir -p "$OUT"
RTL=$(ls rtl/*.v | tr '\n' ' ')
names=(static one_bit two_bit)

for t in 0 1 2; do
    n=${names[$t]}
    echo "== PREDICTOR_TYPE=$t ($n) =="
    yosys -q -l "$OUT/generic_$n.log" -p "
        read_verilog -sv $RTL
        chparam -set PREDICTOR_TYPE $t branch_prediction_top
        hierarchy -check -top branch_prediction_top
        proc
        select -assert-none t:\$dlatch t:\$adlatch t:\$dlatchsr
        synth -top branch_prediction_top -flatten
        select -assert-none t:\$_DLATCH_*
        tee -o $OUT/generic_${n}_stat.txt stat
    " > /dev/null
    yosys -q -l "$OUT/xilinx_$n.log" -p "
        read_verilog -sv $RTL
        chparam -set PREDICTOR_TYPE $t branch_prediction_top
        synth_xilinx -top branch_prediction_top -flatten
        select -assert-none t:LDCE t:LDPE
        tee -o $OUT/xilinx_${n}_stat.txt stat
    " > /dev/null
    echo "   no latches inferred; reports in $OUT/*_${n}_stat.txt"
done
# Direction predictors alone (no BTB), to compare 1-bit vs 2-bit cost
for m in one_bit_predictor two_bit_predictor; do
    yosys -q -l "$OUT/xilinx_$m.log" -p "
        read_verilog -sv $RTL
        synth_xilinx -top $m -flatten
        select -assert-none t:LDCE t:LDPE
        tee -o $OUT/xilinx_${m}_stat.txt stat
    " > /dev/null
    echo "== $m alone: reports in $OUT/xilinx_${m}_stat.txt"
done
python3 synthesis/summarize.py
echo "Synthesis completed for all configurations."
