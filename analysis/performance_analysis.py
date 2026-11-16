#!/usr/bin/env python3
"""
performance_analysis.py - DBPU performance evaluation from RTL simulation logs.

Inputs (produced by `make sim-traces`, `make sweep` and `make pipeline`):
  traces/<name>.csv                         the branch traces
  analysis/results/sim_<name>.csv           per-branch RTL log (tb_trace_runner)
  analysis/results/sweep/sim_<name>_bht<N>.csv   BHT-size sweep logs (optional)
  analysis/results/pipeline_summary.txt     PIPE_SUMMARY lines (optional)

What it does:
  1. Cross-checks EVERY row of every RTL log against an independent Python
     reference model of the three predictors and the BTB. Any mismatch is
     reported and the script exits with status 1.
  2. Computes, per workload and predictor: total branches, correct and
     incorrect predictions, accuracy, misprediction rate, estimated CPI and
     speed-up over the static baseline.
  3. Writes summary.csv, summary.json and summary.md to analysis/results/ and
     plots to analysis/plots/ (plots need matplotlib; skipped if missing).

CPI model (assumptions are command-line options):
  CPI = base_CPI + branch_fraction * misprediction_rate * penalty
  defaults: base_CPI = 1.0, branch_fraction = 0.20, penalty = 2 cycles
  (penalty = 2 because a branch resolved in EX of a 5-stage pipeline has two
  younger wrong-path instructions, in IF and ID, to squash).
"""
import argparse
import csv
import json
import os
import re
import sys

WORKLOADS = [
    ("loop_trace", "Loop-heavy"),
    ("alternating_trace", "Alternating"),
    ("mostly_taken", "Mostly taken"),
    ("mostly_not_taken", "Mostly not taken"),
    ("mixed_trace", "Mixed"),
    ("aliasing_trace", "Aliasing"),
]
PREDICTORS = [("static", "Always not taken"), ("onebit", "1-bit dynamic"), ("twobit", "2-bit dynamic")]

# Palette: categorical slots 1-3 (validated for 3 series, all pairs)
COLORS = {"static": "#2a78d6", "onebit": "#eb6834", "twobit": "#1baf7a"}


# --------------------------------------------------------------------------
# Independent reference model (does not reuse any RTL code)
# --------------------------------------------------------------------------
def reference_model(trace, bht_entries=16, btb_entries=16):
    """Return per-branch predictions/states/flushes for all three predictors
    using the immediate-update model of tb_trace_runner."""
    one = [0] * bht_entries            # 1-bit: reset to 0 (not taken)
    two = [1] * bht_entries            # 2-bit: reset to 01 (weakly not taken)
    btb = [None] * btb_entries         # entries: (pc, target)
    out = []
    for pc, target, taken in trace:
        bi = (pc >> 2) % bht_entries
        ti = (pc >> 2) % btb_entries
        hit = btb[ti] is not None and btb[ti][0] == pc
        btb_tgt = btb[ti][1] if hit else None
        actual_npc = target if taken else pc + 4

        def flush_of(pred):
            npc = btb_tgt if (pred and hit) else pc + 4
            return int(npc != actual_npc)

        row = {
            "static_pred": 0, "static_flush": flush_of(0),
            "onebit_state": one[bi], "onebit_pred": one[bi], "onebit_flush": flush_of(one[bi]),
            "twobit_state": two[bi], "twobit_pred": two[bi] >> 1, "twobit_flush": flush_of(two[bi] >> 1),
            "btb_hit": int(hit),
        }
        out.append(row)
        # update (rising clock edge)
        one[bi] = taken
        two[bi] = min(two[bi] + 1, 3) if taken else max(two[bi] - 1, 0)
        if taken:
            btb[ti] = (pc, target)
    return out


def read_trace(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append((int(r["pc"], 16), int(r["target"], 16), int(r["taken"])))
    return rows


def read_sim(path):
    with open(path) as f:
        return list(csv.DictReader(f))


def cross_check(name, trace, sim, bht_entries):
    """Compare RTL log with reference model; return number of mismatching fields."""
    ref = reference_model(trace, bht_entries)
    errors = 0
    if len(sim) != len(trace):
        print(f"  MISMATCH {name}: RTL logged {len(sim)} branches, trace has {len(trace)}")
        return 1
    for i, (t, s, r) in enumerate(zip(trace, sim, ref)):
        if int(s["pc"], 16) != t[0] or int(s["target"], 16) != t[1] or int(s["actual_taken"]) != t[2]:
            errors += 1
            print(f"  MISMATCH {name} row {i}: RTL input differs from trace")
        for key, val in r.items():
            if int(s[key]) != val:
                errors += 1
                if errors <= 10:
                    print(f"  MISMATCH {name} bht={bht_entries} row {i} {key}: RTL={s[key]} ref={val}")
    return errors


def metrics(trace, sim, args):
    n = len(trace)
    res = {}
    for key, _ in PREDICTORS:
        correct = sum(1 for t, s in zip(trace, sim) if int(s[f"{key}_pred"]) == t[2])
        wrong = n - correct
        flushes = sum(int(s[f"{key}_flush"]) for s in sim)
        mr = wrong / n
        cpi = args.base_cpi + args.branch_fraction * mr * args.penalty
        res[key] = {
            "total": n, "correct": correct, "incorrect": wrong,
            "accuracy_pct": 100.0 * correct / n, "mispred_rate_pct": 100.0 * mr,
            "est_cpi": cpi, "flushes_with_btb": flushes,
        }
    base = res["static"]["est_cpi"]
    for key, _ in PREDICTORS:
        res[key]["speedup_vs_static"] = base / res[key]["est_cpi"]
    return res


def parse_pipeline(path):
    """Parse 'TRACE <name>' + PIPE_SUMMARY lines from tb_branch_prediction_top."""
    out = {}
    if not os.path.exists(path):
        return out
    cur = None
    pat = re.compile(r"PIPE_SUMMARY type=(\w+) branches=(\d+) cycles=(\d+) dir_mispredicts=(\d+) flushes=(\d+)")
    keymap = {"static": "static", "one_bit": "onebit", "two_bit": "twobit"}
    with open(path) as f:
        for line in f:
            if line.startswith("TRACE "):
                cur = line.split()[1].strip()
                out[cur] = {}
            m = pat.search(line)
            if m and cur:
                out[cur][keymap[m.group(1)]] = {
                    "branches": int(m.group(2)), "cycles": int(m.group(3)),
                    "dir_mispredicts": int(m.group(4)), "flushes": int(m.group(5)),
                }
    return out


# --------------------------------------------------------------------------
# Plots
# --------------------------------------------------------------------------
def make_plots(summary, sweep, plot_dir):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed - skipping plots (pip install matplotlib)")
        return []
    os.makedirs(plot_dir, exist_ok=True)
    plt.rcParams.update({
        "font.size": 9, "axes.spines.top": False, "axes.spines.right": False,
        "axes.edgecolor": "#52514e", "axes.labelcolor": "#0b0b0b",
        "xtick.color": "#52514e", "ytick.color": "#52514e",
        "axes.grid": True, "grid.color": "#e4e3df", "grid.linewidth": 0.6,
        "axes.axisbelow": True, "figure.facecolor": "#ffffff", "axes.facecolor": "#ffffff",
    })
    files = []
    names = [w for w, _ in WORKLOADS if w in summary]
    labels = [dict(WORKLOADS)[w].replace("Mostly ", "Mostly\n") for w in names]

    def grouped_bar(metric, ylabel, fname, ylim=None, fmt="{:.0f}"):
        fig, ax = plt.subplots(figsize=(7.0, 2.9))
        width = 0.26
        xs = range(len(names))
        for j, (key, label) in enumerate(PREDICTORS):
            vals = [summary[w][key][metric] for w in names]
            pos = [x + (j - 1) * (width + 0.01) for x in xs]
            bars = ax.bar(pos, vals, width, color=COLORS[key], label=label,
                          edgecolor="#ffffff", linewidth=1.0)
            for b, v in zip(bars, vals):
                ax.text(b.get_x() + b.get_width() / 2, b.get_height(), fmt.format(v),
                        ha="center", va="bottom", fontsize=6.5, color="#52514e")
        ax.set_xticks(list(xs))
        ax.set_xticklabels(labels)
        ax.set_ylabel(ylabel)
        if ylim:
            ax.set_ylim(*ylim)
        ax.grid(axis="x", visible=False)
        ax.legend(frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.5, 1.18))
        fig.tight_layout()
        for ext in ("png", "pdf"):
            p = os.path.join(plot_dir, f"{fname}.{ext}")
            fig.savefig(p, dpi=200, metadata={"CreationDate": None} if ext == "pdf" else None)
            files.append(p)
        plt.close(fig)

    grouped_bar("accuracy_pct", "Prediction accuracy (%)", "accuracy_comparison", (0, 112))

    if sweep:
        ws = [w for w, _ in WORKLOADS if w in sweep]
        fig, axes = plt.subplots(1, len(ws), figsize=(7.0, 2.6), sharey=True)
        if len(ws) == 1:
            axes = [axes]
        for ax, w in zip(axes, ws):
            sizes = sorted(sweep[w])
            for key, label in PREDICTORS:
                acc = [sweep[w][s][key]["accuracy_pct"] for s in sizes]
                hollow = key == "onebit"   # hollow + larger so coincident lines stay visible
                ax.plot(sizes, acc, "-", color=COLORS[key], linewidth=2,
                        marker="o", markersize=7 if hollow else 4,
                        markerfacecolor="#ffffff" if hollow else COLORS[key],
                        markeredgewidth=1.5, label=label, zorder=2 if hollow else 3)
            ax.set_xscale("log", base=2)
            ax.set_xticks(sizes)
            ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
            ax.minorticks_off()
            ax.set_xlabel("BHT entries")
            ax.set_title(dict(WORKLOADS)[w] + " trace", fontsize=9)
            ax.set_ylim(-3, 105)
        axes[0].set_ylabel("Accuracy (%)")
        handles, labels_ = axes[0].get_legend_handles_labels()
        fig.legend(handles, labels_, frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.5, 1.0))
        fig.tight_layout(rect=(0, 0, 1, 0.9))
        for ext in ("png", "pdf"):
            p = os.path.join(plot_dir, f"bht_size_sweep.{ext}")
            fig.savefig(p, dpi=200, metadata={"CreationDate": None} if ext == "pdf" else None)
            files.append(p)
        plt.close(fig)
    return files


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--base-cpi", type=float, default=1.0)
    ap.add_argument("--branch-fraction", type=float, default=0.20)
    ap.add_argument("--penalty", type=float, default=2.0)
    ap.add_argument("--bht-entries", type=int, default=16)
    args = ap.parse_args()

    res_dir = os.path.join(args.root, "analysis", "results")
    plot_dir = os.path.join(args.root, "analysis", "plots")
    trace_dir = os.path.join(args.root, "traces")
    total_mismatch = 0
    summary = {}

    print("== Cross-checking RTL logs against the Python reference model ==")
    for name, _ in WORKLOADS:
        sim_path = os.path.join(res_dir, f"sim_{name}.csv")
        if not os.path.exists(sim_path):
            print(f"  missing {sim_path} (run `make sim-traces`)")
            total_mismatch += 1
            continue
        trace = read_trace(os.path.join(trace_dir, f"{name}.csv"))
        sim = read_sim(sim_path)
        mm = cross_check(name, trace, sim, args.bht_entries)
        total_mismatch += mm
        print(f"  {name:18s} {len(trace):4d} branches  mismatches={mm}")
        summary[name] = metrics(trace, sim, args)

    # BHT size sweep
    sweep = {}
    sweep_dir = os.path.join(res_dir, "sweep")
    if os.path.isdir(sweep_dir):
        print("== Cross-checking BHT-size sweep logs ==")
        pat = re.compile(r"sim_(\w+?)_bht(\d+)\.csv")
        for fname in sorted(os.listdir(sweep_dir)):
            m = pat.fullmatch(fname)
            if not m:
                continue
            name, size = m.group(1), int(m.group(2))
            trace = read_trace(os.path.join(trace_dir, f"{name}.csv"))
            sim = read_sim(os.path.join(sweep_dir, fname))
            mm = cross_check(f"{name}", trace, sim, size)
            total_mismatch += mm
            sweep.setdefault(name, {})[size] = metrics(trace, sim, args)
            print(f"  {name:18s} bht={size:3d} mismatches={mm}")

    pipeline = parse_pipeline(os.path.join(res_dir, "pipeline_summary.txt"))

    # ---------------- outputs ----------------
    out = {
        "assumptions": {"base_cpi": args.base_cpi, "branch_fraction": args.branch_fraction,
                        "misprediction_penalty_cycles": args.penalty, "bht_entries": args.bht_entries,
                        "btb_entries": 16, "update_model": "immediate (tb_trace_runner)"},
        "workloads": summary, "bht_sweep": {w: {str(k): v for k, v in d.items()} for w, d in sweep.items()},
        "pipelined_rtl": pipeline,
        "rtl_vs_reference_mismatches": total_mismatch,
    }
    with open(os.path.join(res_dir, "summary.json"), "w") as f:
        json.dump(out, f, indent=2)

    with open(os.path.join(res_dir, "summary.csv"), "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["workload", "predictor", "total", "correct", "incorrect", "accuracy_pct",
                    "mispred_rate_pct", "est_cpi", "speedup_vs_static", "flushes_with_btb"])
        for name, label in WORKLOADS:
            if name not in summary:
                continue
            for key, plabel in PREDICTORS:
                m = summary[name][key]
                w.writerow([label, plabel, m["total"], m["correct"], m["incorrect"],
                            f"{m['accuracy_pct']:.2f}", f"{m['mispred_rate_pct']:.2f}",
                            f"{m['est_cpi']:.4f}", f"{m['speedup_vs_static']:.4f}", m["flushes_with_btb"]])

    md = ["# DBPU Simulation Results (auto-generated)", "",
          "Generated by `analysis/performance_analysis.py` from RTL simulation logs. Do not edit by hand.", "",
          f"Assumptions: base CPI = {args.base_cpi}, branch fraction = {args.branch_fraction}, "
          f"misprediction penalty = {args.penalty:g} cycles, BHT = {args.bht_entries} entries, BTB = 16 entries, "
          "immediate-update trace model.", "",
          f"RTL vs. Python reference model mismatches: **{total_mismatch}**", "",
          "## Accuracy and estimated CPI", "",
          "| Workload | Predictor | Branches | Correct | Incorrect | Accuracy (%) | Mispred. rate (%) | Est. CPI | Speed-up vs static | Flushes (with BTB) |",
          "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for name, label in WORKLOADS:
        if name not in summary:
            continue
        for key, plabel in PREDICTORS:
            m = summary[name][key]
            md.append(f"| {label} | {plabel} | {m['total']} | {m['correct']} | {m['incorrect']} | "
                      f"{m['accuracy_pct']:.2f} | {m['mispred_rate_pct']:.2f} | {m['est_cpi']:.3f} | "
                      f"{m['speedup_vs_static']:.3f} | {m['flushes_with_btb']} |")
    if sweep:
        md += ["", "## BHT size sweep (accuracy %, RTL re-compiled per size)", ""]
        for name in sweep:
            sizes = sorted(sweep[name])
            md.append(f"**{dict(WORKLOADS)[name]}**")
            md.append("")
            md.append("| Predictor | " + " | ".join(f"{s} entries" for s in sizes) + " |")
            md.append("|---|" + "---:|" * len(sizes))
            for key, plabel in PREDICTORS:
                md.append(f"| {plabel} | " + " | ".join(f"{sweep[name][s][key]['accuracy_pct']:.2f}" for s in sizes) + " |")
            md.append("")
    if pipeline:
        md += ["", "## Pipelined RTL run (tb_branch_prediction_top, delayed update + squash)", "",
               "Every instruction in these streams is a branch; each flush costs 2 bubble cycles.", "",
               "| Workload | Predictor | Branches | Cycles | Cycles/branch | Dir. mispredicts | Flushes |",
               "|---|---|---:|---:|---:|---:|---:|"]
        for name, label in WORKLOADS:
            if name not in pipeline:
                continue
            for key, plabel in PREDICTORS:
                p = pipeline[name].get(key)
                if p:
                    md.append(f"| {label} | {plabel} | {p['branches']} | {p['cycles']} | "
                              f"{p['cycles'] / p['branches']:.3f} | {p['dir_mispredicts']} | {p['flushes']} |")
    with open(os.path.join(res_dir, "summary.md"), "w") as f:
        f.write("\n".join(md) + "\n")

    files = make_plots(summary, sweep, plot_dir)

    print("\n== Accuracy (%) ==")
    print(f"  {'workload':18s} {'static':>8s} {'1-bit':>8s} {'2-bit':>8s}")
    for name, _ in WORKLOADS:
        if name in summary:
            s = summary[name]
            print(f"  {name:18s} {s['static']['accuracy_pct']:8.2f} {s['onebit']['accuracy_pct']:8.2f} {s['twobit']['accuracy_pct']:8.2f}")
    print(f"\nWrote {res_dir}/summary.csv, summary.json, summary.md")
    for p in files:
        print(f"Wrote {p}")
    if total_mismatch:
        print(f"\nRESULT: FAIL - {total_mismatch} RTL/reference mismatches")
        sys.exit(1)
    print("\nRESULT: PASS - RTL logs match the reference model exactly")


if __name__ == "__main__":
    main()
