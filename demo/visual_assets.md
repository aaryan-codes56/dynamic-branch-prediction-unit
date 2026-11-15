# Visual Assets for the Video

All assets are generated from the repository. Regenerate with `make all` before recording.

| ID | Used in | Asset | Source |
|---|---|---|---|
| V1 | 0:00 | Title slide: project title, "Project 5, Modern Computer Architecture, Phase I" | create in slides |
| V2 | 0:20 | Team slide: 5 names and roles (from `docs/CONTRIBUTIONS.md`) | create in slides |
| V3 | 0:30 | Pipeline flush diagram (Diagram 9) | `docs/ARCHITECTURE.md` section 10 (Mermaid renders on GitHub) |
| V4 | 1:15 | Architecture block diagram | `docs/diagrams/dbpu_architecture.png` |
| V5 | 1:35 | 1-bit FSM | `docs/diagrams/one_bit_fsm.png` |
| V6 | 1:45 | 2-bit saturating counter FSM | `docs/diagrams/two_bit_fsm.png` |
| V7 | 2:15 | Code: `rtl/update_logic.v` (saturation lines) and `rtl/branch_prediction_top.v` (generate block) | editor |
| V8 | 2:35 | Terminal: `make test` (live) | terminal |
| V9 | 3:05 | Predictor comparison waveform | `docs/waveforms/wave_predictor_comparison.png` or `make wave TB=...` in GTKWave |
| V10 | 3:30 | Pipeline flush waveform | `docs/waveforms/wave_pipeline_flush.png` |
| V11 | 3:45 | Accuracy bar chart | `analysis/plots/accuracy_comparison.png` |
| V12 | 4:05 | Results table (accuracy + CPI) | `analysis/results/summary.md` or README section 12 |
| V13 | 4:30 | Summary slide: implemented / verified / limitations / Phase II | create in slides |

Optional extra visuals if time allows: `analysis/plots/bht_size_sweep.png` (aliasing vs BHT
size), `docs/waveforms/wave_two_bit_transitions.png` (saturation), `synthesis/SYNTHESIS_RESULTS.md`.

Rules: show only real outputs; do not edit numbers into screenshots; if you show GTKWave, open
the VCD produced by a run you just did.

Screenshots taken for the video should be saved in `demo/screenshots/`.
