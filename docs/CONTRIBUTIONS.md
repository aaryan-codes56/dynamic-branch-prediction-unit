# Team Contributions

**Project:** Design and Verification of a Dynamic Branch Prediction Unit Using 1-Bit and 2-Bit
Saturating Predictors (Project 5, Modern Computer Architecture)

## Team

| Member | Proposed role | Feature branch |
|---|---|---|
| Aaryan Krishna | Project coordination, architecture, top-level integration, final validation | `feature/architecture` |
| Pratik Agade | Static and 1-bit predictor, Branch Target Buffer | `feature/static-1bit-predictor` |
| Raghvendra Singh | 2-bit predictor, Branch History Table, update logic | `feature/two-bit-predictor` |
| Vedant Satbhai | Testbench development, waveform verification, test automation | `feature/testbench-verification` |
| Vivek Kumar Raj | Branch traces, performance analysis, technical documentation, report integration | `feature/performance-analysis` |

## AI-assistance disclosure

The first complete version of the RTL, testbenches, scripts and documentation in this repository
was generated on 15 Nov 2026 in a session with **Claude, an AI assistant (Anthropic)**, directed
by Aaryan Krishna. Claude is a tool, not a team member, and does not appear as a contributor.
All simulation, analysis and synthesis results were produced by actually running the tools listed
in `docs/PROJECT_STATUS.md`; none were written by hand.

Each member is responsible for reviewing, understanding, testing and committing the files they
own (below), and must be able to explain them in the viva. Please keep this disclosure accurate:
if your institution requires a specific AI-use statement, add it here and in the report.

## Proposed file ownership

| Member | Files |
|---|---|
| Aaryan Krishna | `rtl/branch_prediction_top.v`, `rtl/prediction_control.v`, `rtl/misprediction_unit.v`, `Makefile`, `synthesis/`, `docs/ARCHITECTURE.md`, `docs/diagrams/dbpu_architecture.tex`, `README.md`, `docs/PROJECT_STATUS.md`, `PHASE1_SUBMISSION_CHECKLIST.md` |
| Pratik Agade | `rtl/static_predictor.v`, `rtl/one_bit_predictor.v`, `rtl/branch_target_buffer.v`, `docs/diagrams/one_bit_fsm.tex` |
| Raghvendra Singh | `rtl/branch_history_table.v`, `rtl/update_logic.v`, `rtl/two_bit_predictor.v`, `docs/diagrams/two_bit_fsm.tex` |
| Vedant Satbhai | `testbench/*.v`, `simulation/`, `scripts/mutation_test.sh`, `scripts/vcd_to_png.py`, `docs/waveforms/`, `docs/TESTING.md` |
| Vivek Kumar Raj | `traces/`, `analysis/`, `reports/`, `docs/REFERENCES.md`, `demo/` |

## Contribution status (update with real evidence only)

Status values: **Pending** (not yet reviewed/committed by the member), **Reviewed** (member has
read, run and understood the files), **Committed** (member committed from their own GitHub
account; add commit/PR links), **Extended** (member made their own changes; describe them).

| Member | Status | Evidence (commit / PR links) | Own changes made |
|---|---|---|---|
| Aaryan Krishna | Committed | Initial import of the complete Phase I project to `main` (15 Nov 2026) | - |
| Pratik Agade | Pending | - | - |
| Raghvendra Singh | Pending | - | - |
| Vedant Satbhai | Pending | - | - |
| Vivek Kumar Raj | Pending | - | - |

Do not mark a row as Committed or Extended until the commit or pull request exists on GitHub.
The "Individual Contributions" table in the IEEE report must match this table.
