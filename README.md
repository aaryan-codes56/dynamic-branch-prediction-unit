# Dynamic Branch Prediction Unit

**Design and Verification of a Dynamic Branch Prediction Unit Using 1-Bit and 2-Bit Saturating Predictors**
Modern Computer Architecture, Project 5

A synthesizable Verilog branch prediction unit with a static always-not-taken baseline, a dynamic
1-bit predictor and a dynamic 2-bit saturating-counter predictor, a Branch History Table, a Branch
Target Buffer and a pipeline flush interface. The three predictors are verified with
self-checking testbenches and compared on identical branch traces.

IEEE report: [`reports/IEEE_Project_Report.pdf`](reports/IEEE_Project_Report.pdf)

## Overview

In a pipelined processor a conditional branch (`BEQ`, `BNE`) is resolved only in the EX stage,
while the fetch stage needs the next address immediately. This **control hazard** forces the
processor to guess; a wrong guess flushes the wrong-path instructions and costs cycles (the
**misprediction penalty**). The DBPU makes that guess in hardware at fetch time, learns from
each resolved branch, and raises a flush with the correct next PC when a guess was wrong.

The unit is standalone with a pipeline-style interface (IF lookup, EX resolution); the
testbenches act as the IF and EX stages of a five-stage pipeline.

## Features

* Static always-not-taken predictor (baseline)
* Dynamic 1-bit predictor and 2-bit saturating-counter predictor (00/01/10/11, no wrap-around)
* Parameterized, untagged Branch History Table (entries, state width, reset value)
* Direct-mapped, tagged Branch Target Buffer (valid, tag, target)
* Next-PC prediction, misprediction detection, pipeline flush and corrected PC
* Seven self-checking testbenches and a pipelined integration testbench
* Six loop-oriented BEQ/BNE branch traces; accuracy, misprediction rate and estimated CPI
* RTL results cross-checked against an independent Python reference model
* Mutation testing, BHT-size sweep and Yosys synthesis

## Architecture

![DBPU architecture](docs/diagrams/dbpu_architecture.png)

| Module | Role |
|---|---|
| `branch_prediction_top` | Selects the predictor via `PREDICTOR_TYPE` (0 static, 1 one-bit, 2 two-bit) and integrates all blocks |
| `static_predictor` | Always predicts not taken |
| `one_bit_predictor` / `two_bit_predictor` | Branch History Table + update logic |
| `branch_history_table` | Untagged table, index `PC[5:2]` (16 entries), 2 read ports + 1 write port |
| `update_logic` | N-bit saturating counter (1-bit = last outcome) |
| `branch_target_buffer` | Direct-mapped, tagged; written by taken branches |
| `prediction_control` | IF: `pred_next_pc = (taken && btb_hit) ? target : PC + 4` |
| `misprediction_unit` | EX: `flush = (pred_next_pc != actual_next_pc)`, provides `ex_correct_pc` |

Interface, design decisions and all diagrams: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## How the predictors work

* **Static:** fetch always continues at PC + 4; no storage, no learning.
* **1-bit:** each BHT entry stores the last outcome. A loop `T T T T T N` is mispredicted twice
  per execution: at the exit and again at the next loop entry.
* **2-bit saturating counter:** taken `00->01->10->11->11`, not taken `11->10->01->00->00`;
  predict taken when the MSB is 1. A single loop exit moves `11` only to `10`, which still
  predicts taken, so the loop is mispredicted only once per execution.

![2-bit saturating counter](docs/diagrams/two_bit_fsm.png)

## Results

Same trace fed to all three predictors, 16-entry BHT (RTL simulation). Estimated
`CPI = 1.0 + 0.20 x misprediction rate x 2` (base CPI 1.0, 20 % branches, 2-cycle penalty).

| Workload | Branches | Static acc. | 1-bit acc. | 2-bit acc. | Static CPI | 1-bit CPI | 2-bit CPI |
|---|---:|---:|---:|---:|---:|---:|---:|
| Loop-heavy | 70 | 15.71 % | 68.57 % | **81.43 %** | 1.337 | 1.126 | **1.074** |
| Alternating | 60 | **50.00 %** | 0.00 % | 0.00 % | **1.200** | 1.400 | 1.400 |
| Mostly taken | 100 | 10.00 % | 83.00 % | **87.00 %** | 1.360 | 1.068 | **1.052** |
| Mostly not taken | 100 | **90.00 %** | 82.00 % | 89.00 % | **1.040** | 1.072 | 1.044 |
| Mixed | 160 | 39.38 % | 56.25 % | **74.38 %** | 1.242 | 1.175 | **1.103** |
| Aliasing | 80 | **50.00 %** | 0.00 % | 0.00 % | **1.200** | 1.400 | 1.400 |

![Accuracy comparison](analysis/plots/accuracy_comparison.png)

* Loops: 22 mispredictions with the 1-bit predictor, 13 with the 2-bit predictor.
* Biased branches: the 2-bit counter tolerates rare opposite outcomes; the 1-bit predictor pays
  twice for each.
* Alternating and aliased branches defeat both local counter predictors; enlarging the BHT
  from 16 to 32 entries removes the aliasing (0 % -> 98.75 %), see
  [`analysis/plots/bht_size_sweep.png`](analysis/plots/bht_size_sweep.png).

Full tables (including BHT sweep and pipelined cycle counts):
[`analysis/results/summary.md`](analysis/results/summary.md).

**Synthesis** (Yosys, Xilinx 7-series mapping, pre-place-and-route; no latches inferred):

| Configuration | LUTs | Flip-flops |
|---|---:|---:|
| Static + BTB | 510 | 944 |
| 1-bit BHT + BTB | 602 | 960 |
| 2-bit BHT + BTB | 634 | 976 |

Details: [`synthesis/SYNTHESIS_RESULTS.md`](synthesis/SYNTHESIS_RESULTS.md).

## Verification

```
tb_static_predictor          PASS   83/83 checks passed
tb_one_bit_predictor         PASS   49/49 checks passed
tb_two_bit_predictor         PASS   70/70 checks passed
tb_branch_history_table      PASS   33/33 checks passed
tb_branch_target_buffer      PASS   22/22 checks passed
tb_misprediction             PASS   12/12 checks passed
tb_branch_prediction_top     PASS   3013/3013 checks passed
Summary: 7 passed, 0 failed
```

* The integration testbench runs all three predictors with five-stage timing (lookup in IF,
  resolution in EX two cycles later, squash and refetch on flush) and compares every output
  with a reference model, on directed stimulus and on all six traces.
* Every prediction in the trace simulations matches an independent Python model (0 mismatches).
* Mutation testing: 7 of 7 deliberately injected bugs are detected.

Test descriptions and waveform figures: [`docs/TESTING.md`](docs/TESTING.md).

![Predictor comparison waveform](docs/waveforms/wave_predictor_comparison.png)

## Getting started

**Requirements:** Icarus Verilog, Python 3 with Matplotlib; optional: Yosys (synthesis),
GTKWave (waveforms), Tectonic or a LaTeX distribution (report).

```bash
# macOS
brew install icarus-verilog yosys
brew install --cask gtkwave
# Ubuntu / Debian
sudo apt install iverilog yosys gtkwave

python3 -m pip install -r requirements.txt
```

**Commands** (run from the repository root):

```bash
make test                            # run all self-checking testbenches
make sim  TB=tb_two_bit_predictor    # run one testbench
make wave TB=tb_two_bit_predictor    # run one testbench and open GTKWave
make traces                          # regenerate the branch traces (deterministic)
make results                         # trace simulations, BHT sweep, pipelined runs, analysis, plots
make waves                           # render waveform figures from the VCD files
make synth                           # Yosys synthesis of all three configurations
make report                          # build the IEEE report PDF
bash scripts/mutation_test.sh        # mutation testing
```

## Repository structure

```
rtl/          Verilog RTL (9 modules)
testbench/    self-checking testbenches and the trace runner
simulation/   test scripts and GTKWave save files (VCDs are generated here)
traces/       trace generator and six branch traces (CSV)
analysis/     performance analysis script, results and plots
synthesis/    Yosys flow, summary and raw statistics
scripts/      waveform renderer and mutation testing
docs/         architecture, testing, references, contributions, diagrams, waveforms
reports/      IEEE report (LaTeX source and PDF)
```

## Team

| Member | Area |
|---|---|
| Aaryan Krishna | Coordination, architecture, integration, final validation |
| Pratik Agade | Static and 1-bit predictors, Branch Target Buffer |
| Raghvendra Singh | 2-bit predictor, Branch History Table, update logic |
| Vedant Satbhai | Testbenches and waveform verification |
| Vivek Kumar Raj | Traces, performance analysis, documentation and report |


## References

Key sources: J. E. Smith, "A study of branch prediction strategies," ISCA 1981; J. K. F. Lee and
A. J. Smith, "Branch prediction strategies and branch target buffer design," *IEEE Computer*,
1984; J. L. Hennessy and D. A. Patterson, *Computer Architecture: A Quantitative Approach*,
6th ed. Full list: [`docs/REFERENCES.md`](docs/REFERENCES.md).

## Limitations and future work

Standalone unit (not integrated into a processor), synthetic traces, conditional direct branches
only, and synthesis without timing (no Fmax). Future work: integration into a five-stage RV32I
pipeline, benchmark traces, gshare/tournament predictors, a return-address stack, and
place-and-route timing on an FPGA.

## License

MIT, see [`LICENSE`](LICENSE).
