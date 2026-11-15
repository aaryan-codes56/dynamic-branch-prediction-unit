#!/usr/bin/env python3
"""
generate_traces.py - deterministic branch-trace generator for the DBPU project.

Each trace is a CSV file with one resolved conditional branch per line:

    pc,target,taken,instr
    0000010c,00000104,1,BNE

  pc      branch instruction address (8 hex digits, word aligned)
  target  branch target address if taken (8 hex digits)
  taken   actual outcome: 1 = taken, 0 = not taken
  instr   BEQ or BNE (informational)

The traces model the branch behaviour of small loop-oriented programs. They
are synthetic (generated from the program structure described in each
function's docstring), not captured from a real processor. Random choices
use a fixed seed, so running this script always produces identical files.

Usage:  python3 traces/generate_traces.py [output_dir]
"""
import csv
import os
import random
import sys

SEED = 2026


def write_trace(path, rows):
    with open(path, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["pc", "target", "taken", "instr"])
        for pc, target, taken, instr in rows:
            w.writerow([f"{pc:08x}", f"{target:08x}", int(taken), instr])


def loop_trace():
    """Nested loop:  for (o = 0; o < 10; o++) { for (i = 0; i < 6; i++) {...} }

    0x10c  BNE  inner back-edge -> 0x104 : T T T T T N   (6 iterations)
    0x114  BNE  outer back-edge -> 0x100 : T x9, then N   (10 iterations)
    Total = 10 * (6 + 1) = 70 branches.
    """
    rows = []
    outer_iters, inner_iters = 10, 6
    for o in range(outer_iters):
        for i in range(inner_iters):
            rows.append((0x10C, 0x104, i < inner_iters - 1, "BNE"))
        rows.append((0x114, 0x100, o < outer_iters - 1, "BNE"))
    return rows


def alternating_trace():
    """if ((i & 1) == 0) {...} inside a loop -> T N T N ... (60 branches).

    0x200  BEQ  forward branch -> 0x220
    """
    return [(0x200, 0x220, i % 2 == 0, "BEQ") for i in range(60)]


def biased_trace(pc, target, instr, n_total, n_taken, seed):
    outcomes = [1] * n_taken + [0] * (n_total - n_taken)
    random.Random(seed).shuffle(outcomes)
    return [(pc, target, t, instr) for t in outcomes]


def mostly_taken_trace():
    """Loop-like back-edge that is taken 90 % of the time.

    0x300  BNE -> 0x2e0 : exactly 90 taken / 10 not taken, shuffled (seeded).
    """
    return biased_trace(0x300, 0x2E0, "BNE", 100, 90, SEED + 1)


def mostly_not_taken_trace():
    """Error-check style forward branch that is rarely taken.

    0x400  BEQ -> 0x440 : exactly 10 taken / 90 not taken, shuffled (seeded).
    """
    return biased_trace(0x400, 0x440, "BEQ", 100, 10, SEED + 2)


def mixed_trace():
    """A small program with five different branch behaviours (160 branches).

    for (o = 0; o < 20; o++) {             // 0x1038 BNE outer back-edge
        for (i = 0; i < 4; i++) {...}       // 0x1008 BNE inner back-edge TTTN
        if (data[o] > threshold) {...}      // 0x1014 BEQ data dependent ~50 %
        if (error_flag) goto handler;       // 0x1020 BNE rarely taken (o==13)
        if (o & 1) {...}                    // 0x102c BEQ alternating
    }
    """
    rng = random.Random(SEED + 3)
    rows = []
    outer_iters, inner_iters = 20, 4
    for o in range(outer_iters):
        for i in range(inner_iters):
            rows.append((0x1008, 0x1004, i < inner_iters - 1, "BNE"))
        rows.append((0x1014, 0x101C, rng.random() < 0.5, "BEQ"))
        rows.append((0x1020, 0x2000, o == 13, "BNE"))
        rows.append((0x102C, 0x1034, o % 2 == 1, "BEQ"))
        rows.append((0x1038, 0x1000, o < outer_iters - 1, "BNE"))
    return rows


def aliasing_trace():
    """Two interleaved branches with opposite behaviour whose PCs share the
    same index in a 16-entry BHT (but not in a 32-entry BHT):

    0x100  BNE -> 0x0e0 : always taken      (index 0 for 16 entries, 0 for 32)
    0x140  BEQ -> 0x160 : always not taken  (index 0 for 16 entries, 16 for 32)
    Total = 2 * 40 = 80 branches.
    """
    rows = []
    for _ in range(40):
        rows.append((0x100, 0x0E0, 1, "BNE"))
        rows.append((0x140, 0x160, 0, "BEQ"))
    return rows


TRACES = {
    "loop_trace": loop_trace,
    "alternating_trace": alternating_trace,
    "mostly_taken": mostly_taken_trace,
    "mostly_not_taken": mostly_not_taken_trace,
    "mixed_trace": mixed_trace,
    "aliasing_trace": aliasing_trace,
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in TRACES.items():
        rows = fn()
        path = os.path.join(out_dir, f"{name}.csv")
        write_trace(path, rows)
        taken = sum(1 for r in rows if r[2])
        print(f"{name:18s} {len(rows):4d} branches  {taken:4d} taken  -> {path}")


if __name__ == "__main__":
    main()
