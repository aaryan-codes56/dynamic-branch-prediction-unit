# Project Status

Last updated: 15 Nov 2026. Phase I deadline: 16 Nov 2026, 11:59 PM IST.

## Initial state (Milestone 0, recorded 15 Nov 2026)

| Item | Finding |
|---|---|
| Local folder | `MCA project/dynamic-branch-prediction-unit/` containing only `.git/` |
| Git | Initialized, branch `main`, **no commits**, working tree empty |
| Remote | `origin` = https://github.com/aaryan-codes56/dynamic-branch-prediction-unit.git (remote has no branches yet) |
| Git identity (local machine) | `user.name = Aaryan Krishna`; e-mail configured |
| OS | macOS 27.0 (Apple Silicon, arm64) |
| Icarus Verilog | 13.0 (stable), installed |
| Yosys | 0.71+post, installed |
| Python | 3.14.2, installed; Matplotlib **not** installed system-wide (used from a virtual environment; `pip install -r requirements.txt`) |
| Git | 2.47.0 |
| Tectonic (LaTeX) | installed (used to build the IEEE PDF) |
| GTKWave | **not installed** (`brew install --cask gtkwave`); waveform PNGs rendered from VCD with `scripts/vcd_to_png.py` instead |
| Verilator | not installed (not required) |
| nextpnr / Vivado | not installed, so no place-and-route timing (Fmax) |

## Milestones

| # | Milestone | Status | Evidence |
|---|---|---|---|
| 0 | Repository and environment inspection | COMPLETE | this file |
| 1 | Architecture and design | COMPLETE | `docs/ARCHITECTURE.md`, `docs/diagrams/` |
| 2 | RTL implementation (9 modules) | COMPLETE | `rtl/`; compiles with `iverilog -g2005 -Wall`, no warnings |
| 3 | Verification | COMPLETE | `make test`: 7/7 PASS (3279 checks); integration PASS on 6 traces; mutation test 7/7 detected |
| 4 | Performance evaluation | COMPLETE | `analysis/results/summary.{md,csv,json}`, `analysis/plots/`; RTL vs reference: 0 mismatches |
| 5 | Synthesis and design review | COMPLETE (limited) | `synthesis/SYNTHESIS_RESULTS.md`; no latches; no Fmax (no P&R tool) |
| 6 | Documentation and IEEE report | COMPLETE | `README.md`, `docs/`, `reports/IEEE_Project_Report.pdf` |
| 7 | Video preparation | IN PROGRESS | script, checklist, assets ready in `demo/`; video not yet recorded |
| 8 | Final submission | IN PROGRESS | repository pushed; video pending; see `PHASE1_SUBMISSION_CHECKLIST.md` |

## Open items (need the team)

1. Record and upload the video; add the link to `README.md`.
2. The complete project was committed and pushed from Aaryan Krishna's account (15 Nov 2026).
   Other members should review their files and contribute from their own GitHub accounts
   (`CONTRIBUTING.md`), then update `docs/CONTRIBUTIONS.md`.

## Key decisions

* Standalone predictor with a pipeline-style interface (no full CPU), as allowed by the scope.
* Predictor chosen with the `PREDICTOR_TYPE` parameter; one `update_logic` module serves 1-bit
  and 2-bit predictors.
* BHT 16 entries (index `PC[5:2]`), BTB 16 entries direct mapped, tagged.
* 2-bit reset state 01 (weakly not taken).
* CPI model: base 1.0, branch fraction 0.20, penalty 2 cycles (documented assumptions).
