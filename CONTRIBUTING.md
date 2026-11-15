# Contributing and Git Workflow

This repository is reviewed by faculty, including its commit history and the GitHub contributor
list. The goal is an **authentic** history: each member commits their own reviewed work from
their own GitHub account.

## Rules

1. Use your own GitHub account and your own Git identity. Check before committing:
   ```bash
   git config user.name     # must be your name
   git config user.email    # must be an email linked to YOUR GitHub account
   ```
   Set it for this repository only:
   ```bash
   git config user.name  "Your Name"
   git config user.email "you@example.com"
   ```
2. Never commit as another member, never change commit dates, never force-push to `main`,
   never rewrite shared history.
3. Do not add an AI tool as a co-author or contributor. If you used AI help, say so in plain
   text in the commit body (example below) and in `docs/CONTRIBUTIONS.md`.
4. Before committing, run `make test` and make sure everything passes.
5. Only commit source files. Build products (`build/`, `*.vcd`, logs) are ignored by `.gitignore`.

## Branch plan

| Branch | Owner | Contents |
|---|---|---|
| `main` | Aaryan Krishna (maintainer) | Integrated, always passing `make test` |
| `feature/two-bit-predictor` | Raghvendra Singh | `rtl/branch_history_table.v`, `rtl/update_logic.v`, `rtl/two_bit_predictor.v`, `docs/diagrams/two_bit_fsm.tex` |
| `feature/static-1bit-predictor` | Pratik Agade | `rtl/static_predictor.v`, `rtl/one_bit_predictor.v`, `rtl/branch_target_buffer.v`, `docs/diagrams/one_bit_fsm.tex` |
| `feature/architecture` | Aaryan Krishna | `rtl/branch_prediction_top.v`, `rtl/prediction_control.v`, `rtl/misprediction_unit.v`, `Makefile`, `synthesis/`, `docs/ARCHITECTURE.md`, `docs/diagrams/dbpu_architecture.*` |
| `feature/testbench-verification` | Vedant Satbhai | `testbench/`, `simulation/`, `scripts/`, `docs/TESTING.md`, `docs/waveforms/` |
| `feature/performance-analysis` | Vivek Kumar Raj | `traces/`, `analysis/`, `requirements.txt`, `reports/`, `docs/REFERENCES.md`, `demo/` |

Suggested merge order (so that `make test` passes after each merge): skeleton on `main` ->
`feature/two-bit-predictor` (BHT and update logic are used by the 1-bit predictor) ->
`feature/static-1bit-predictor` -> `feature/architecture` -> `feature/testbench-verification` ->
`feature/performance-analysis`.

## Step by step

**Maintainer (Aaryan), once:** commit the skeleton (`README.md`, `LICENSE`, `.gitignore`,
`CONTRIBUTING.md`, `docs/PROJECT_STATUS.md`, `docs/CONTRIBUTIONS.md`) to `main`, push, and add
the four other members as collaborators on GitHub (Settings -> Collaborators). Share the
remaining files with the owners (for example, by giving them this working copy).

**Every member:**
```bash
git clone https://github.com/aaryan-codes56/dynamic-branch-prediction-unit.git
cd dynamic-branch-prediction-unit
git config user.name "Your Name"; git config user.email "you@example.com"
git checkout -b feature/<your-branch>
# copy in YOUR files, read them, run them, change/improve what you want
make test
git add <your files>
git commit        # message format below
git push -u origin feature/<your-branch>
```
Then open a pull request on GitHub into `main`, ask another member to review it, and merge after
approval.

## Commit message format

```
<area>: <short summary in imperative mood>

<what and why, 1-3 lines>
<how it was tested>
AI-assisted: initial version generated with an AI assistant; reviewed,
tested and understood by <your name>.
```

Examples:
```
rtl: add parameterized branch history table and saturating update logic
rtl: add 2-bit saturating-counter predictor with weakly-not-taken reset
rtl: add static and 1-bit predictors and direct-mapped BTB
rtl: integrate predictors, BTB and flush logic in branch_prediction_top
tb: add self-checking unit testbenches and pipelined integration test
analysis: add trace generator, RTL cross-check and accuracy/CPI plots
docs: add IEEE report, references and demo script
```

## Code style (Verilog)

* Verilog-2005, synthesizable RTL only in `rtl/` (no `#` delays, no `$display`).
* Non-blocking (`<=`) in clocked `always` blocks, blocking (`=`) in `always @(*)`.
* Synchronous active-high reset; every register has a defined reset value.
* Parameters instead of magic numbers; a header comment in every module.
* Every new module needs a self-checking testbench that prints `TEST_RESULT: PASS|FAIL`,
  added to `simulation/run_tests.sh`.
