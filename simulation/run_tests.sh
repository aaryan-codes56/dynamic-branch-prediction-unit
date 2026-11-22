#!/usr/bin/env bash
# =============================================================================
# run_tests.sh - compile and run every self-checking DBPU testbench.
# Usage (from the repository root):  bash simulation/run_tests.sh
# Logs:      simulation/logs/<testbench>.log
# Waveforms: simulation/waveforms/<testbench>.vcd
# Exit status is non-zero if any testbench fails or does not report a result.
# =============================================================================
set -u
cd "$(dirname "$0")/.."

IVERILOG=${IVERILOG:-iverilog}
VVP=${VVP:-vvp}
TESTS="tb_static_predictor tb_one_bit_predictor tb_two_bit_predictor \
       tb_branch_history_table tb_branch_target_buffer tb_misprediction \
       tb_branch_prediction_top tb_parameter_validation tb_rv32_pipeline tb_rv32_alu"

mkdir -p build simulation/logs simulation/waveforms analysis/results
# assemble the RV32I programs used by tb_rv32_pipeline (needs python3)
if ! python3 scripts/build_programs.py > simulation/logs/build_programs.log 2>&1; then
    echo "ERROR: scripts/build_programs.py failed (see simulation/logs/build_programs.log)"; exit 1
fi
pass=0; fail=0
printf "%-28s %-6s %s\n" "TESTBENCH" "RESULT" "DETAILS"
printf "%-28s %-6s %s\n" "---------" "------" "-------"
for tb in $TESTS; do
    log="simulation/logs/$tb.log"
    if ! $IVERILOG -g2005 -Wall -o "build/$tb" "testbench/$tb.v" rtl/*.v > "$log" 2>&1; then
        printf "%-28s %-6s %s\n" "$tb" "FAIL" "compile error (see $log)"
        fail=$((fail + 1)); continue
    fi
    $VVP -n "build/$tb" >> "$log" 2>&1
    result=$(grep "TEST_RESULT:" "$log" | tail -1)
    if echo "$result" | grep -q "TEST_RESULT: PASS"; then
        pass=$((pass + 1))
        printf "%-28s %-6s %s\n" "$tb" "PASS" "$(echo "$result" | sed 's/.*(\(.*\))/\1/')"
    else
        fail=$((fail + 1))
        printf "%-28s %-6s %s\n" "$tb" "FAIL" "see $log"
    fi
done
echo
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
