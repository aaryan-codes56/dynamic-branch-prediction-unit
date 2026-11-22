# Team Contributions

**Project:** Design and Verification of a Dynamic Branch Prediction Unit Using 1-Bit and 2-Bit
Saturating Predictors (Project 5, Modern Computer Architecture)

## Members and areas of responsibility

| Member | GitHub | Area of responsibility |
|---|---|---|
| Aaryan Krishna | [@aaryan-codes56](https://github.com/aaryan-codes56) | Project coordination, architecture, top-level integration, prediction control and misprediction unit, synthesis, RV32I pipeline (Phase II), final validation |
| Pratik Agade | [@PratikAgade](https://github.com/PratikAgade) | Static and 1-bit predictors, Branch Target Buffer, Fibonacci benchmark |
| Raghvendra Singh | [@23raghvendra](https://github.com/23raghvendra) | 2-bit saturating predictor, Branch History Table, update logic, maximum-search benchmark |
| Vedant Satbhai | [@vedant21-ctr](https://github.com/vedant21-ctr) | Testbenches and waveform verification, RTL parameter validation and index bounds safety, parameter validation testbench, continuous integration |
| Vivek Kumar Raj | [@viveeeeek13](https://github.com/viveeeeek13) | Branch traces, performance analysis, processor CPI analysis, documentation and report |

## Phase I commit record

| Member | Commit | Contribution |
|---|---|---|
| Aaryan Krishna | [352cea3](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/352cea3) ... [6a855a2](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/6a855a2) (7 commits) | Initial implementation of the complete project: RTL (9 modules), testbenches, traces and analysis, synthesis flow, documentation and IEEE report |
| Raghvendra Singh | [ee36e1e](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/ee36e1e) | Second 2-bit predictor with reset state 00 in `tb_two_bit_predictor`; shows 6/12 mispredictions on alternating branches versus 12/12 for reset state 01 |
| Pratik Agade | [8a4557c](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/8a4557c) | BTB edge-case test for the highest PC (`0xFFFFFFFC`, index 7, all-ones tag) and a same-index tag-mismatch miss in `tb_branch_target_buffer` |
| Vivek Kumar Raj | [33d205e](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/33d205e) | Reproducible plot PDFs (creation timestamp removed) in `analysis/performance_analysis.py`; regenerated plots |
| Vedant Satbhai | [b4822bd](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/b4822bd) | RTL parameter validation and index bounds safety in BHT, BTB, and top-level modules; parameter validation testbench `tb_parameter_validation` (35 checks; full suite 3,317 checks, all passing) |
| Vedant Satbhai | [d55d8e6](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/d55d8e6) | README title edit |
| Vedant Satbhai | [12b3d92](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/12b3d92) | Waveform verification figures embedded in `docs/TESTING.md` |

## Phase II commit record (RV32I processor)

| Member | Commit | Contribution |
|---|---|---|
| Aaryan Krishna | [654ae4b](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/654ae4b) ... [a59a4f1](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/a59a4f1) (5 commits) | 5-stage RV32I pipeline with the DBPU, assembler and reference ISS, six benchmark programs, processor system test (`tb_rv32_pipeline`), CPU analysis and synthesis, documentation and report |
| Vedant Satbhai | [6cedbdf](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/6cedbdf) | GitHub Actions continuous integration: runs all testbenches, mutation tests and the results pipeline on every push |
| Raghvendra Singh | [18ebc19](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/18ebc19) | Maximum-search benchmark program (`programs/max_search.s`, data-dependent branch) |
| Pratik Agade | [5fa3fe8](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/5fa3fe8) | Fibonacci benchmark program (`programs/fibonacci.s`) |
| Vivek Kumar Raj | [0baeb6e](https://github.com/aaryan-codes56/dynamic-branch-prediction-unit/commit/0baeb6e) | Branch fraction and flush-penalty columns in the processor CPI analysis |
| Aaryan Krishna | (this update) | ALU unit testbench (`tb_rv32_alu`), final results with all eight programs |

