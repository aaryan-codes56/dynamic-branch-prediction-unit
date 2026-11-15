# Recording Checklist

## Before recording
- [ ] Pull the latest `main`; run `make clean && make all` and confirm `Summary: 7 passed, 0 failed`.
- [ ] Run `make results`; confirm the analysis ends with `RESULT: PASS`.
- [ ] Check that numbers in `demo/demo_script.md` still match `analysis/results/summary.md`.
- [ ] Prepare slides V1, V2, V13 (see `demo/visual_assets.md`).
- [ ] Open in tabs: `rtl/update_logic.v`, `rtl/branch_prediction_top.v`, the architecture and FSM
      PNGs, the two waveform PNGs, the accuracy chart, the results table.
- [ ] Terminal: large font (at least 16 pt), repository root as the working directory, clear screen.
- [ ] (Optional) Install GTKWave and test `make wave TB=tb_two_bit_predictor`.
- [ ] Close notifications, chat apps and unrelated windows; hide personal information.
- [ ] Each speaker has read their segment aloud at least twice and timed it.

## During recording
- [ ] Say the project title and **all five names** in the first 30 seconds.
- [ ] Show the Verilog code, the block diagrams, a live `make test` run, a waveform and the
      performance comparison.
- [ ] Speak slowly; pause briefly when switching screens.
- [ ] Do not claim anything that is not implemented (no full processor, no FPGA run, no Fmax).

## After recording
- [ ] Total length is **5:00 or less**.
- [ ] Audio is clear for every speaker; text on screen is readable at 1080p.
- [ ] Upload (YouTube unlisted or Google Drive with "anyone with the link can view").
- [ ] Open the link in a private/incognito window to confirm it plays.
- [ ] Replace **[VIDEO LINK: to be added after upload]** in `README.md` and update
      `PHASE1_SUBMISSION_CHECKLIST.md`.
