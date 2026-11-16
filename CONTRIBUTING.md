# Contributing

## Workflow

1. Use your own GitHub account and Git identity:
   ```bash
   git config user.name  "Your Name"
   git config user.email "email-linked-to-your-github@example.com"
   ```
2. Create a branch, make your change, and run the tests:
   ```bash
   git checkout -b feature/<short-name>
   make test            # must end with: Summary: 7 passed, 0 failed
   ```
3. Commit only source files (build products, VCDs and logs are ignored by `.gitignore`), push,
   and open a pull request into `main`:
   ```bash
   git add <files>
   git commit -m "<area>: <short summary>" -m "<what and why; how it was tested>"
   git push -u origin feature/<short-name>
   ```

Never commit as another person, change commit dates or force-push to `main`. If you used an AI
tool, say so in the commit message.

## Commit message areas

`rtl:` hardware, `tb:` testbenches, `analysis:` traces and analysis, `synth:` synthesis,
`docs:` documentation, `report:` IEEE report, `build:` Makefile and scripts.

## Verilog style

* Verilog-2005; synthesizable RTL only in `rtl/` (no `#` delays, no `$display`).
* Non-blocking (`<=`) assignments in clocked `always` blocks, blocking (`=`) in `always @(*)`.
* Synchronous active-high reset; every register has a defined reset value.
* Parameters instead of magic numbers; a header comment in every module.
* Every new module needs a self-checking testbench that prints `TEST_RESULT: PASS|FAIL` and is
  added to `simulation/run_tests.sh`.
