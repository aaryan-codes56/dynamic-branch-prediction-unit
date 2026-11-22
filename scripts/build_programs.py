#!/usr/bin/env python3
"""
build_programs.py - assemble every programs/*.s and produce, in programs/build/:

  <name>.hex        machine code, one 32-bit word per line, padded with NOPs to
                    256 words (loaded into the CPU instruction memory)
  <name>.exp        expected final state from the reference ISS:
                    32 register values, 256 data-memory words, 1 instruction count
  <name>_trace.csv  dynamic branch trace (pc,target,taken,instr) of the program
  programs.list     names of all programs (read by testbench/tb_rv32_pipeline.v)

Usage: python3 scripts/build_programs.py
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rv32 import IMEM_WORDS, ISS, assemble  # noqa: E402

NOP = 0x00000013

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "programs")
OUT = os.path.join(SRC, "build")


def main():
    os.makedirs(OUT, exist_ok=True)
    names = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.s"))):
        name = os.path.splitext(os.path.basename(path))[0]
        words = assemble(open(path).read())
        iss = ISS(words).run()
        with open(os.path.join(OUT, f"{name}.hex"), "w") as f:
            # padded with NOPs to the full instruction-memory size
            f.writelines(f"{w:08x}\n" for w in words + [NOP] * (IMEM_WORDS - len(words)))
        with open(os.path.join(OUT, f"{name}.exp"), "w") as f:
            f.writelines(f"{v:08x}\n" for v in iss.regs + iss.dmem + [iss.instret])
        with open(os.path.join(OUT, f"{name}_trace.csv"), "w") as f:
            f.write("pc,target,taken,instr\n")
            for pc, tgt, tk in iss.branches:
                instr = "BEQ" if ((words[pc // 4] >> 12) & 7) == 0 else "BNE"
                f.write(f"{pc:08x},{tgt:08x},{tk},{instr}\n")
        taken = sum(t for _, _, t in iss.branches)
        print(f"{name:16s} {len(words):4d} words  {iss.instret:6d} instr  "
              f"{len(iss.branches):5d} branches ({taken} taken)")
        names.append(name)
    with open(os.path.join(OUT, "programs.list"), "w") as f:
        f.writelines(n + "\n" for n in names)


if __name__ == "__main__":
    main()
