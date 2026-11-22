#!/usr/bin/env bash
# =============================================================================
# mutation_test.sh - "test the tests".
# Injects one deliberate bug at a time into a COPY of rtl/ (the real RTL is
# never modified) and checks that the testbenches detect it (report FAIL).
# Usage (from the repository root):  bash scripts/mutation_test.sh
# =============================================================================
set -u
cd "$(dirname "$0")/.."
WORK=build/mutation
# Mutant simulations run inside $WORK so their VCD dumps never overwrite
# the real waveforms in simulation/waveforms/.
mkdir -p "$WORK/simulation/waveforms" "$WORK/programs"
# the CPU testbench reads the assembled programs
python3 scripts/build_programs.py > /dev/null
rm -rf "$WORK/programs/build"; cp -r programs/build "$WORK/programs/build"
detected_all=1

mutate() {   # name file from to testbench...
    local name=$1 file=$2 from=$3 to=$4; shift 4
    rm -rf "$WORK/rtl"; cp -r rtl "$WORK/rtl"
    FROM="$from" TO="$to" python3 - "$WORK/rtl/$file" <<'EOF'
import os, sys
p = sys.argv[1]; s = open(p).read()
assert os.environ["FROM"] in s, "mutation anchor not found"
open(p, "w").write(s.replace(os.environ["FROM"], os.environ["TO"], 1))
EOF
    local caught=0
    for tb in "$@"; do
        iverilog -g2005 -o "$WORK/sim" "testbench/$tb.v" "$WORK"/rtl/*.v
        r=$(cd "$WORK" && vvp -n sim +OUT=/dev/null 2>&1 | grep TEST_RESULT)
        echo "  [$name] $tb -> ${r#TEST_RESULT: }"
        echo "$r" | grep -q FAIL && caught=1
    done
    if [ $caught -eq 1 ]; then echo "  => DETECTED"; else echo "  => NOT DETECTED"; detected_all=0; fi
}

echo "== Mutation testing =="
mutate "2-bit counter wraps 11->00" update_logic.v \
    "if (current_state != STATE_MAX)" "if (1'b1)" tb_two_bit_predictor tb_branch_prediction_top
mutate "BTB ignores tag" branch_target_buffer.v \
    "&& (tag_mem[lookup_idx] == lookup_tag)" "" tb_branch_target_buffer tb_branch_prediction_top
mutate "flush only on direction error" misprediction_unit.v \
    "assign flush          = mispredict;" "assign flush          = dir_mispredict;" tb_misprediction tb_branch_prediction_top
mutate "BHT index ignores word alignment" branch_history_table.v \
    "localparam ALIGN_BITS = 2;" "localparam ALIGN_BITS = 0;" tb_branch_history_table tb_one_bit_predictor
mutate "2-bit predicts from LSB" two_bit_predictor.v \
    "assign predict_taken = lookup_state[1];" "assign predict_taken = lookup_state[0];" tb_two_bit_predictor
mutate "BHT reset value ignored" branch_history_table.v \
    "table_mem[i] <= INIT_STATE;" "table_mem[i] <= {STATE_BITS{1'b0}};" tb_branch_history_table tb_two_bit_predictor
mutate "redirect without BTB hit" prediction_control.v \
    "assign pred_redirect = if_valid & predict_taken & btb_hit;" "assign pred_redirect = if_valid & predict_taken;" tb_misprediction tb_branch_prediction_top

# ---- Phase II CPU (rv32_pipeline_core) ----
mutate "CPU: no EX/MEM forwarding" rv32_pipeline_core.v \
    "wire fwd_a_mem = exmem_valid" "wire fwd_a_mem = 1'b0 && exmem_valid" tb_rv32_pipeline
mutate "CPU: no load-use stall" rv32_pipeline_core.v \
    "wire stall = load_use & ~flush;" "wire stall = 1'b0;" tb_rv32_pipeline
mutate "CPU: flush does not squash ID/EX" rv32_pipeline_core.v \
    "if (flush || stall || !ifid_valid) begin" "if (stall || !ifid_valid) begin" tb_rv32_pipeline
mutate "CPU: no register-file write-through" rv32_regfile.v \
    "(we && wa == ra1) ? wd : regs[ra1]" "regs[ra1]" tb_rv32_pipeline
mutate "CPU: branch compares unforwarded rs2" rv32_pipeline_core.v \
    "wire ex_equal = (ex_a == ex_b);" "wire ex_equal = (ex_a == idex_rs2_val);" tb_rv32_pipeline

rm -rf "$WORK"
if [ $detected_all -eq 1 ]; then echo "RESULT: all mutants detected"; else echo "RESULT: some mutants NOT detected"; exit 1; fi
