# Prototype Video Script (maximum 5:00)

Spoken at roughly 145 words per minute. Times are targets; the total is about 4:50.
Visuals are listed in `demo/visual_assets.md`. Every number below comes from actual simulation
output. Do not change a number unless you re-run `make results` and see a new value.

| Segment | Time | Speaker |
|---|---|---|
| 1. Introduction | 0:00-0:30 | Aaryan Krishna |
| 2. Problem statement | 0:30-1:15 | Vivek Kumar Raj |
| 3. Proposed architecture | 1:15-2:15 | Pratik Agade (1:15-1:45), Raghvendra Singh (1:45-2:15) |
| 4. Live prototype demonstration | 2:15-3:45 | Vedant Satbhai |
| 5. Performance comparison | 3:45-4:30 | Vivek Kumar Raj |
| 6. Conclusion | 4:30-5:00 | Aaryan Krishna |

---

## 1. Introduction (0:00-0:30), Aaryan Krishna
**Screen:** title slide (V1), then team slide (V2).

> "Hello. Our project is Project 5 of Modern Computer Architecture: *Design and Verification of a
> Dynamic Branch Prediction Unit Using 1-Bit and 2-Bit Saturating Predictors*. Our goal is to
> design and evaluate a hardware unit that reduces control-hazard penalties in a pipelined
> processor. Our team is: Aaryan Krishna, Pratik Agade, Raghvendra Singh, Vedant Satbhai and
> Vivek Kumar Raj."

## 2. Problem statement (0:30-1:15), Vivek Kumar Raj
**Screen:** pipeline flush diagram (V3).

> "A branch instruction, like BEQ or BNE, decides where the program goes next. In a five-stage
> pipeline the branch is only resolved in the Execute stage, but the Fetch stage needs the next
> address immediately. This is a control hazard. If the processor guesses wrong, the two
> instructions fetched on the wrong path must be flushed, and those cycles are wasted. That is
> the misprediction penalty, two cycles in our design. A branch predictor makes the guess in
> hardware, so most branches cost nothing."

## 3. Proposed architecture (1:15-2:15)
**Pratik Agade (1:15-1:45). Screen:** architecture diagram (V4), then 1-bit FSM (V5).

> "This is our architecture. On the fetch side, the branch PC goes to a direction predictor and a
> Branch Target Buffer. The prediction control block jumps to the stored target only when the
> predictor says taken and the BTB has the target. We implemented three predictors. The static
> baseline always predicts not taken. The 1-bit predictor remembers the last outcome of each
> branch in a Branch History Table."

**Raghvendra Singh (1:45-2:15). Screen:** 2-bit FSM (V6).

> "The 2-bit predictor stores a saturating counter: strongly not taken, weakly not taken, weakly
> taken, strongly taken. Taken adds one, not taken subtracts one, and it stops at the ends instead
> of wrapping around. Because one unusual outcome only moves it from strongly to weakly taken, a
> loop exit does not destroy the prediction. When the branch resolves in Execute, the
> misprediction unit compares the predicted and actual next PC and raises a flush with the
> correct address."

## 4. Live prototype demonstration (2:15-3:45), Vedant Satbhai
**Screen:** VS Code with `rtl/` open (V7), then the terminal (V8), then waveforms (V9, V10).

> "Here is the Verilog. There are nine modules in the rtl folder. This is update_logic: the
> counter only increments if it is not already at the maximum, which is the saturation. This is
> the top module, where a parameter selects the predictor."

**Action:** run `make test` live.

> "Now I run all seven self-checking testbenches. Each one compares the outputs with expected
> values and prints PASS or FAIL. All seven pass: 3279 checks, including the integration test,
> which runs all three predictors with pipeline timing and checks every output against a
> reference model."

**Action:** scroll the log to `tb_two_bit_predictor` (00 + T -> 01 ... 11 + T -> 11).

> "Here is the full 2-bit transition table, and here the saturation test: eleven plus taken stays
> eleven."

**Screen:** `docs/waveforms/wave_predictor_comparison.png` (or GTKWave).

> "This waveform is from the loop trace. The same branches go to all three predictors. At the
> loop exit both dynamic predictors mispredict. The 1-bit state drops to zero, but the 2-bit
> counter only drops to weakly taken. So when the loop starts again, only the 1-bit predictor is
> wrong a second time."

**Screen:** `docs/waveforms/wave_pipeline_flush.png`.

> "And this is the pipeline view: the branch is looked up in fetch, resolved two cycles later,
> flush goes high, the correct PC is supplied, and two bubble cycles follow."

## 5. Performance comparison (3:45-4:30), Vivek Kumar Raj
**Screen:** accuracy chart (V11), then results table (V12).

> "We fed the same six traces to all three predictors. On the loop-heavy trace accuracy goes from
> 15.7 percent for static, to 68.6 percent for 1-bit, to 81.4 percent for 2-bit. On the mixed
> workload the 2-bit predictor reaches 74.4 percent, and the estimated CPI falls from 1.242 to
> 1.103, assuming 20 percent branches and a two-cycle penalty. But the results are honest:
> strictly alternating branches, and two branches aliased into one table entry, defeat both
> dynamic predictors, and there the static predictor's 50 percent is better."

## 6. Conclusion (4:30-5:00), Aaryan Krishna
**Screen:** summary slide (V13).

> "To summarise: we implemented and verified static, 1-bit and 2-bit predictors, a Branch History
> Table, a Branch Target Buffer and a flush interface in synthesizable Verilog, with all tests
> passing and synthesis confirming no latches. The unit is currently standalone and uses
> synthetic traces, and we have no FPGA timing yet. In Phase Two we plan to connect it to a
> RISC-V pipeline, use real program traces and add a global-history predictor. Thank you."

---

## Word budget check
Spoken words per segment (counted): 1: 58, 2: 84, 3: 146, 4: 187, 5: 87, 6: 74 = 636 words,
about 4.4 minutes at 145 words per minute, leaving about 30 seconds for screen changes and the
live `make test` run. If a rehearsal runs long, shorten segment 4 first (skip the second waveform).
