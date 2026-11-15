#!/usr/bin/env python3
"""
vcd_to_png.py - render waveform figures directly from simulator VCD files.

GTKWave is the interactive viewer; this script exists so that the report,
README and demo can include waveform images that are produced automatically
from the REAL simulation dumps (no hand drawing). Each figure lists the VCD
file, the signals to show and the time window.

Usage (from the repository root, after `make test` and `make sim-traces`):
    python3 scripts/vcd_to_png.py
Output: docs/waveforms/*.png  (+ a .pdf of the figure used in the LaTeX report)
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAVE_DIR = os.path.join(ROOT, "simulation", "waveforms")
OUT_DIR = os.path.join(ROOT, "docs", "waveforms")


# ----------------------------------------------------------------------------
# Minimal VCD parser
# ----------------------------------------------------------------------------
def parse_vcd(path, wanted):
    """Return ({name: [(time_ps, value_str), ...]}, timescale_ps)."""
    id_to_names, scope = {}, []
    changes = {w: [] for w in wanted}
    ts_ps = 1
    t = 0
    with open(path) as f:
        tokens_mode = "header"
        buf = []
        for line in f:
            line = line.strip()
            if not line:
                continue
            if tokens_mode == "header":
                buf.append(line)
                if "$end" not in line:
                    continue
                stmt = " ".join(buf).split()
                buf = []
                kw = stmt[0]
                if kw == "$timescale":
                    val = "".join(stmt[1:-1])
                    num = int("".join(c for c in val if c.isdigit()))
                    unit = val.lstrip("0123456789")
                    ts_ps = num * {"s": 10**12, "ms": 10**9, "us": 10**6, "ns": 1000, "ps": 1, "fs": 1e-3}[unit]
                elif kw == "$scope":
                    scope.append(stmt[2])
                elif kw == "$upscope":
                    scope.pop()
                elif kw == "$var":
                    ident, name = stmt[3], stmt[4]
                    full = ".".join(scope + [name])
                    if full in changes:
                        id_to_names.setdefault(ident, []).append(full)
                elif kw == "$enddefinitions":
                    tokens_mode = "body"
                continue
            # body
            if line[0] == "#":
                t = int(line[1:]) * ts_ps
            elif line[0] in "01xzXZ":
                ident = line[1:]
                for n in id_to_names.get(ident, []):
                    changes[n].append((t, line[0].lower()))
            elif line[0] in "bB":
                val, ident = line[1:].split()
                for n in id_to_names.get(ident, []):
                    changes[n].append((t, val.lower()))
            elif line.startswith("$"):
                continue
    missing = [w for w in wanted if not changes[w]]
    if missing:
        raise SystemExit(f"{path}: signals not found or never set: {missing}")
    return changes, ts_ps


def value_at(ch, t):
    v = ch[0][1]
    for tt, vv in ch:
        if tt <= t:
            v = vv
        else:
            break
    return v


def fmt_value(v, fmt):
    if any(c in v for c in "xz"):
        return "x"
    n = int(v, 2)
    if fmt == "hex":
        return f"{n:x}"
    if fmt == "bin2":
        return f"{n:02b}"
    return str(n)


# ----------------------------------------------------------------------------
# Figure definitions (signal, label, format) ; format: bit | hex | dec | bin2
# ----------------------------------------------------------------------------
FIGURES = [
    {
        "name": "wave_predictor_comparison",
        "pdf": True,      # used in the IEEE report
        "vcd": "tb_trace_runner.vcd",
        "title": "Loop trace (inner loop TTTTTN): static vs 1-bit vs 2-bit, same branch stream",
        "window_ns": (15, 165),
        "signals": [
            ("tb_trace_runner.clk", "clk", "bit"),
            ("tb_trace_runner.rst", "rst", "bit"),
            ("tb_trace_runner.if_pc", "branch PC", "hex"),
            ("tb_trace_runner.ex_actual_taken", "actual taken", "bit"),
            ("tb_trace_runner.pt_s", "static pred", "bit"),
            ("tb_trace_runner.st_1", "1-bit state", "dec"),
            ("tb_trace_runner.pt_1", "1-bit pred", "bit"),
            ("tb_trace_runner.fl_1", "1-bit flush", "bit"),
            ("tb_trace_runner.st_2", "2-bit state", "bin2"),
            ("tb_trace_runner.pt_2", "2-bit pred", "bit"),
            ("tb_trace_runner.fl_2", "2-bit flush", "bit"),
            ("tb_trace_runner.hit_2", "BTB hit", "bit"),
        ],
    },
    {
        "name": "wave_pipeline_flush",
        "vcd": "tb_branch_prediction_top.vcd",
        "title": "Pipelined integration (2-bit unit): IF lookup, EX resolution 2 cycles later, flush",
        "window_ns": (15, 205),
        "signals": [
            ("tb_branch_prediction_top.clk", "clk", "bit"),
            ("tb_branch_prediction_top.h_two.if_valid", "if_valid", "bit"),
            ("tb_branch_prediction_top.h_two.if_pc", "if_pc", "hex"),
            ("tb_branch_prediction_top.h_two.pred_state", "pred_state", "bin2"),
            ("tb_branch_prediction_top.h_two.pred_taken", "pred_taken", "bit"),
            ("tb_branch_prediction_top.h_two.pred_target_valid", "BTB hit", "bit"),
            ("tb_branch_prediction_top.h_two.pred_next_pc", "pred_next_pc", "hex"),
            ("tb_branch_prediction_top.h_two.ex_valid", "ex_valid", "bit"),
            ("tb_branch_prediction_top.h_two.ex_pc", "ex_pc", "hex"),
            ("tb_branch_prediction_top.h_two.ex_actual_taken", "actual taken", "bit"),
            ("tb_branch_prediction_top.h_two.ex_dir_mispredict", "dir_mispredict", "bit"),
            ("tb_branch_prediction_top.h_two.flush", "flush", "bit"),
            ("tb_branch_prediction_top.h_two.ex_correct_pc", "correct_pc", "hex"),
        ],
    },
    {
        "name": "wave_two_bit_transitions",
        "vcd": "tb_two_bit_predictor.vcd",
        "title": "2-bit counter: saturation at 11 and 00 (tb_two_bit_predictor)",
        "window_ns": None,   # filled in automatically below
        "signals": [
            ("tb_two_bit_predictor.clk", "clk", "bit"),
            ("tb_two_bit_predictor.rst", "rst", "bit"),
            ("tb_two_bit_predictor.update_en", "update_en", "bit"),
            ("tb_two_bit_predictor.actual_taken", "actual taken", "bit"),
            ("tb_two_bit_predictor.lookup_state", "counter state", "bin2"),
            ("tb_two_bit_predictor.predict_taken", "predict taken", "bit"),
        ],
    },
    {
        "name": "wave_btb",
        "vcd": "tb_branch_target_buffer.vcd",
        "title": "Branch Target Buffer: miss, allocate, hit, tag conflict (tb_branch_target_buffer)",
        "window_ns": (15, 145),
        "signals": [
            ("tb_branch_target_buffer.clk", "clk", "bit"),
            ("tb_branch_target_buffer.rst", "rst", "bit"),
            ("tb_branch_target_buffer.lookup_pc", "lookup_pc", "hex"),
            ("tb_branch_target_buffer.lookup_hit", "hit", "bit"),
            ("tb_branch_target_buffer.lookup_target", "target", "hex"),
            ("tb_branch_target_buffer.update_en", "update_en", "bit"),
            ("tb_branch_target_buffer.update_pc", "update_pc", "hex"),
            ("tb_branch_target_buffer.update_target", "update_target", "hex"),
        ],
    },
]


def saturation_window(changes):
    """Locate the 'saturate high' test in tb_two_bit_predictor: the first run of
    >= 5 consecutive taken updates while the counter is already 11. The window
    also covers the following 'saturate low' test."""
    pre = "tb_two_bit_predictor."
    clk = changes[pre + "clk"]
    posedges = [t for t, v in clk if v == "1"]
    run = 0
    for t in posedges:
        probe = t - 1000   # 1 ns before the edge
        if (value_at(changes[pre + "lookup_state"], probe) == "11"
                and value_at(changes[pre + "actual_taken"], probe) == "1"
                and value_at(changes[pre + "update_en"], probe) == "1"):
            run += 1
            if run == 5:
                start = t - 4 * 10000
                return (start / 1000 - 45, start / 1000 + 230)
        else:
            run = 0
    raise SystemExit("saturation test not found in VCD")


def render(fig, plt):
    path = os.path.join(WAVE_DIR, fig["vcd"])
    if not os.path.exists(path):
        print(f"  skip {fig['name']}: {path} missing (run make test / make sim-traces)")
        return None
    names = [s[0] for s in fig["signals"]]
    changes, _ = parse_vcd(path, names)
    if fig["window_ns"] is None:
        fig["window_ns"] = saturation_window(changes)
    t0, t1 = (int(fig["window_ns"][0] * 1000), int(fig["window_ns"][1] * 1000))

    n = len(fig["signals"])
    h = 0.34 * n + 0.7
    f, ax = plt.subplots(figsize=(10, h))
    ink, muted, accent = "#0b0b0b", "#52514e", "#2a78d6"
    row_h, amp = 1.0, 0.36
    for i, (sig, label, fmt) in enumerate(fig["signals"]):
        y = (n - 1 - i) * row_h
        ch = changes[sig]
        pts = [(t0, value_at(ch, t0))] + [(t, v) for t, v in ch if t0 < t < t1] + [(t1, None)]
        ax.text(t0 - (t1 - t0) * 0.01, y, label, ha="right", va="center", fontsize=8, color=ink)
        for (ta, va), (tb, _) in zip(pts[:-1], pts[1:]):
            if fmt == "bit":
                level = {"1": amp, "0": -amp}.get(va, 0)
                color = accent if va == "1" else (muted if va == "0" else "#e34948")
                ax.plot([ta, tb], [y + level, y + level], color=color, lw=1.4)
                if tb < t1:
                    nxt = value_at(ch, tb)
                    nl = {"1": amp, "0": -amp}.get(nxt, 0)
                    ax.plot([tb, tb], [y + level, y + nl], color=muted, lw=0.8)
            else:
                d = min((tb - ta) * 0.15, (t1 - t0) * 0.004)
                xs = [ta, ta + d, tb - d, tb, tb - d, ta + d, ta]
                ys = [y, y + amp, y + amp, y, y - amp, y - amp, y]
                ax.plot(xs, ys, color=muted, lw=0.9)
                if tb - ta > (t1 - t0) * 0.018:
                    ax.text((ta + tb) / 2, y, fmt_value(va, fmt), ha="center", va="center",
                            fontsize=6.5, color=ink)
    ax.set_xlim(t0 - (t1 - t0) * 0.13, t1)
    ax.set_ylim(-0.7, n - 0.3)
    ax.set_yticks([])
    ticks = list(range(((t0 // 10000) + 1) * 10000, t1, 10000))
    ax.set_xticks(ticks)
    ax.set_xticklabels([f"{t // 1000}" for t in ticks], fontsize=6.5, color=muted)
    for t in ticks:
        ax.axvline(t, color="#e4e3df", lw=0.5, zorder=0)
    ax.set_xlabel("time (ns)", fontsize=8, color=muted)
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.set_title(fig["title"], fontsize=9, color=ink, loc="left")
    f.text(0.995, 0.01, f"rendered from simulation/waveforms/{fig['vcd']}", ha="right",
           fontsize=6, color=muted)
    f.tight_layout()
    os.makedirs(OUT_DIR, exist_ok=True)
    out = []
    for ext in ("png", "pdf") if fig.get("pdf") else ("png",):
        p = os.path.join(OUT_DIR, f"{fig['name']}.{ext}")
        f.savefig(p, dpi=200)
        out.append(p)
    plt.close(f)
    return out


def main():
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        sys.exit("matplotlib is required: pip install -r requirements.txt")
    for fig in FIGURES:
        files = render(fig, plt)
        if files:
            print("  wrote", ", ".join(os.path.relpath(p, ROOT) for p in files))


if __name__ == "__main__":
    main()
