# Team Contributions

**Project:** Design and Verification of a Dynamic Branch Prediction Unit Using 1-Bit and 2-Bit
Saturating Predictors (Project 5, Modern Computer Architecture)

## Members and areas of responsibility

| Member | GitHub | Area of responsibility |
|---|---|---|
| Aaryan Krishna | [@aaryan-codes56](https://github.com/aaryan-codes56) | Project coordination, architecture, top-level integration, prediction control and misprediction unit, synthesis, final validation |
| Pratik Agade | [@PratikAgade](https://github.com/PratikAgade) | Static and 1-bit predictors, Branch Target Buffer |
| Raghvendra Singh | [@23raghvendra](https://github.com/23raghvendra) | 2-bit saturating predictor, Branch History Table, update logic |
| Vedant Satbhai | - | Testbenches and waveform verification |
| Vivek Kumar Raj | [@viveeeeek13](https://github.com/viveeeeek13) | Branch traces, performance analysis, documentation and report |

## Commit record

| Member | Commit | Contribution |
|---|---|---|
| Aaryan Krishna | [352cea3](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/352cea3) ... [6a855a2](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/6a855a2) (7 commits) | Initial implementation of the complete project: RTL (9 modules), testbenches, traces and analysis, synthesis flow, documentation and IEEE report |
| Raghvendra Singh | [ee36e1e](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/ee36e1e) | Second 2-bit predictor with reset state 00 in `tb_two_bit_predictor`; shows 6/12 mispredictions on alternating branches versus 12/12 for reset state 01 |
| Pratik Agade | [8a4557c](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/8a4557c) | BTB edge-case test for the highest PC (`0xFFFFFFFC`, index 7, all-ones tag) and a same-index tag-mismatch miss in `tb_branch_target_buffer` |
| Vivek Kumar Raj | [33d205e](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/33d205e) | Reproducible plot PDFs (creation timestamp removed) in `analysis/performance_analysis.py`; regenerated plots |
| Vedant Satbhai | pending | GTKWave waveform screenshots for `docs/TESTING.md` |
