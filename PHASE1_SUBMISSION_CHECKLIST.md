# Phase I Submission Checklist (30 %)

Deadline: **16 Nov 2026, 11:59 PM IST**. Status values: COMPLETE, IN PROGRESS, NOT STARTED,
BLOCKED. An item is COMPLETE only with evidence.

## A. IEEE project report (10 marks)

| Requirement | Status | Evidence |
|---|---|---|
| IEEE two-column conference format, editable source | COMPLETE | `reports/IEEE_Project_Report.tex` (IEEEtran) |
| Submission-ready PDF | COMPLETE | `reports/IEEE_Project_Report.pdf` (6 pages), visually checked |
| Abstract | COMPLETE | report, Abstract |
| Literature Review | COMPLETE | report, Section II; 15 references checked against bibliographic records |
| Proposed Solution | COMPLETE | report, Section IV |
| Individual Contributions | COMPLETE | report, Section XI: responsibilities of all five members and AI-assistance disclosure |
| References (IEEE style, matching in-text citations) | COMPLETE | report reference list; `docs/REFERENCES.md` |
| Author details | COMPLETE | five member names and course; department/institution/contact intentionally omitted |

## B. Prototype video (15 marks)

| Requirement | Status | Evidence |
|---|---|---|
| Script within 5 minutes, all 5 members speak | COMPLETE | `demo/demo_script.md` (636 spoken words, about 4.4 min of speech) |
| Recording checklist and visual assets | COMPLETE | `demo/recording_checklist.md`, `demo/visual_assets.md` |
| Project idea and title explained | COMPLETE (script) | segments 1-2 |
| All five members introduced | COMPLETE (script) | segment 1 |
| Verilog implementation, block diagrams, working prototype shown | COMPLETE (script) | segments 3-4 |
| Video recorded | NOT STARTED | - |
| Video uploaded and link added to README | NOT STARTED | placeholder in `README.md` |

## C. GitHub repository (5 marks)

| Requirement | Status | Evidence |
|---|---|---|
| RTL files | COMPLETE | `rtl/` (9 modules) |
| Testbench files | COMPLETE | `testbench/` (7 self-checking + trace runner) |
| Project report in repo | COMPLETE | `reports/` |
| Architecture diagrams | COMPLETE | `docs/diagrams/`, `docs/ARCHITECTURE.md` |
| Simulation evidence | COMPLETE | `docs/waveforms/`, `analysis/results/`, `docs/TESTING.md` |
| README with build/run instructions | COMPLETE | `README.md` |
| Demo video link | NOT STARTED | waiting for upload |
| Files committed and pushed | COMPLETE | pushed to `origin/main` from Aaryan Krishna's account |
| Meaningful version history | COMPLETE | logical commits per area (RTL, testbenches, analysis, synthesis, docs, report) |
| Genuine individual contributions (5 GitHub accounts) | IN PROGRESS | initial import from Aaryan Krishna's account; other members' commits pending (`CONTRIBUTING.md`) |

## Technical deliverables (from the project specification)

| Deliverable | Status | Evidence |
|---|---|---|
| Always-not-taken baseline | COMPLETE | `rtl/static_predictor.v`, Test 1 PASS |
| 1-bit predictor | COMPLETE | `rtl/one_bit_predictor.v`, Test 2 PASS |
| 2-bit saturating predictor | COMPLETE | `rtl/two_bit_predictor.v`, `rtl/update_logic.v`, Test 3 PASS |
| Branch History Table | COMPLETE | `rtl/branch_history_table.v`, BHT test PASS |
| Branch Target Storage/Logic | COMPLETE | `rtl/branch_target_buffer.v`, Test 11 PASS |
| Pipeline flush/control interface | COMPLETE | `rtl/misprediction_unit.v`, `rtl/prediction_control.v`, Test 9 PASS |
| Branch traces (loop-oriented, BEQ/BNE) | COMPLETE | `traces/*.csv`, `traces/generate_traces.py` |
| Accuracy tables | COMPLETE | `analysis/results/summary.md` |
| CPI estimate | COMPLETE | same, assumptions stated |
| Waveform verification | COMPLETE | `docs/waveforms/*.png` (rendered from VCD) |
| Comparison of strategies | COMPLETE | report Section X, `analysis/plots/` |
| Synthesis (resource use) | COMPLETE | `synthesis/SYNTHESIS_RESULTS.md` |
| Maximum frequency | BLOCKED | needs Vivado/nextpnr (not available); stated in report |
| FPGA hardware demo | NOT STARTED | optional; no board used |

## Final steps before the deadline
1. Record, upload and link the video (replace the placeholder in `README.md`).
2. Other members review their files and contribute from their own accounts (`CONTRIBUTING.md`); update `docs/CONTRIBUTIONS.md`.
3. Submit the repository link.
