#!/usr/bin/env python3
"""
rv32.py - tiny RV32I assembler and reference instruction-set simulator (ISS)
for the DBPU 5-stage pipeline.

Supported instructions (the subset implemented by rtl/rv32_pipeline_core.v):
  R-type : add sub and or xor slt sll srl            rd, rs1, rs2
  I-type : addi andi ori xori slti slli srli         rd, rs1, imm
  load   : lw                                        rd, imm(rs1)
  store  : sw                                        rs2, imm(rs1)
  branch : beq bne                                   rs1, rs2, label
  system : ecall                                     (halts the program)
  pseudo : nop | li rd, imm | mv rd, rs | j label    (j = beq x0, x0, label)

Registers: x0-x31 or ABI names (zero ra sp gp tp t0-t6 s0-s11 a0-a7 fp).
Comments start with '#'. Labels end with ':'.

The ISS executes the same program architecturally (one instruction at a time)
and is used as the golden reference for the pipeline testbench.
"""

MASK = 0xFFFFFFFF
DMEM_WORDS = 256          # 1 KiB data memory (byte addresses 0..1023)
IMEM_WORDS = 256

ABI = {"zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
       "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14,
       "a5": 15, "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22,
       "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30,
       "t6": 31}

R_OPS = {  # name: (funct3, funct7)
    "add": (0, 0x00), "sub": (0, 0x20), "sll": (1, 0x00), "slt": (2, 0x00),
    "xor": (4, 0x00), "srl": (5, 0x00), "or": (6, 0x00), "and": (7, 0x00)}
I_OPS = {"addi": 0, "slti": 2, "xori": 4, "ori": 6, "andi": 7}
SHIFT_I = {"slli": 1, "srli": 5}
B_OPS = {"beq": 0, "bne": 1}


class AsmError(Exception):
    pass


def reg(tok):
    t = tok.strip().lower()
    if t in ABI:
        return ABI[t]
    if t.startswith("x") and t[1:].isdigit() and 0 <= int(t[1:]) < 32:
        return int(t[1:])
    raise AsmError(f"bad register '{tok}'")


def imm_val(tok, lo, hi):
    v = int(tok.strip(), 0)
    if not lo <= v <= hi:
        raise AsmError(f"immediate {v} out of range [{lo}, {hi}]")
    return v


def mem_operand(tok):
    # "imm(rs1)"
    tok = tok.strip()
    if "(" not in tok or not tok.endswith(")"):
        raise AsmError(f"bad memory operand '{tok}'")
    off, base = tok[:-1].split("(")
    return imm_val(off or "0", -2048, 2047), reg(base)


def enc_r(f7, rs2, rs1, f3, rd, op=0x33):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op=0x13):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3=2, op=0x23):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(off, rs2, rs1, f3, op=0x63):
    if off % 2 or not -4096 <= off <= 4094:
        raise AsmError(f"branch offset {off} invalid")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | op


def parse(text):
    """Return list of (line_no, mnemonic, [operands]) and label map."""
    insts, labels = [], {}
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        while ":" in line:
            lab, line = line.split(":", 1)
            lab = lab.strip()
            if not lab.isidentifier():
                raise AsmError(f"line {n}: bad label '{lab}'")
            labels[lab] = 4 * len(insts)
            line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        ops = [o.strip() for o in parts[1].split(",")] if len(parts) > 1 else []
        insts.append((n, parts[0].lower(), ops))
    return insts, labels


def assemble(text):
    insts, labels = parse(text)
    words = []
    for idx, (n, m, ops) in enumerate(insts):
        pc = 4 * idx
        try:
            if m == "nop":
                w = enc_i(0, 0, 0, 0)
            elif m == "li":
                w = enc_i(imm_val(ops[1], -2048, 2047), 0, 0, reg(ops[0]))
            elif m == "mv":
                w = enc_i(0, reg(ops[1]), 0, reg(ops[0]))
            elif m == "j":
                w = enc_b(labels[ops[0]] - pc, 0, 0, 0)
            elif m in R_OPS:
                f3, f7 = R_OPS[m]
                w = enc_r(f7, reg(ops[2]), reg(ops[1]), f3, reg(ops[0]))
            elif m in I_OPS:
                w = enc_i(imm_val(ops[2], -2048, 2047), reg(ops[1]), I_OPS[m], reg(ops[0]))
            elif m in SHIFT_I:
                w = enc_i(imm_val(ops[2], 0, 31), reg(ops[1]), SHIFT_I[m], reg(ops[0]))
            elif m == "lw":
                off, base = mem_operand(ops[1])
                w = enc_i(off, base, 2, reg(ops[0]), op=0x03)
            elif m == "sw":
                off, base = mem_operand(ops[1])
                w = enc_s(off, reg(ops[0]), base)
            elif m in B_OPS:
                if ops[2] not in labels:
                    raise AsmError(f"unknown label '{ops[2]}'")
                w = enc_b(labels[ops[2]] - pc, reg(ops[1]), reg(ops[0]), B_OPS[m])
            elif m == "ecall":
                w = 0x00000073
            else:
                raise AsmError(f"unknown instruction '{m}'")
        except (AsmError, IndexError, KeyError, ValueError) as e:
            raise AsmError(f"line {n}: {m} {', '.join(ops)}: {e}")
        words.append(w)
    if len(words) > IMEM_WORDS:
        raise AsmError("program larger than instruction memory")
    return words


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def signed(v):
    return sext(v, 32)


class ISS:
    """Architectural reference model: executes one instruction per step."""

    def __init__(self, words):
        self.imem = list(words)
        self.regs = [0] * 32
        self.dmem = [0] * DMEM_WORDS
        self.pc = 0
        self.instret = 0
        self.branches = []          # (pc, target, taken)

    def _addr(self, a, pc):
        if a % 4 or not 0 <= a < 4 * DMEM_WORDS:
            raise RuntimeError(f"pc={pc:#x}: bad data address {a:#x}")
        return a // 4

    def run(self, max_steps=200000):
        while True:
            if self.instret >= max_steps:
                raise RuntimeError("program did not halt")
            pc = self.pc
            if pc // 4 >= len(self.imem):
                raise RuntimeError(f"pc {pc:#x} outside program")
            w = self.imem[pc // 4]
            self.instret += 1
            op, rd = w & 0x7F, (w >> 7) & 0x1F
            f3, rs1, rs2, f7 = (w >> 12) & 7, (w >> 15) & 0x1F, (w >> 20) & 0x1F, w >> 25
            a, b = self.regs[rs1], self.regs[rs2]
            nxt, res = pc + 4, None
            if w == 0x73:
                return self
            if op == 0x33:
                res = {0: (a - b) if f7 == 0x20 else (a + b), 1: a << (b & 31),
                       2: int(signed(a) < signed(b)), 4: a ^ b, 5: a >> (b & 31),
                       6: a | b, 7: a & b}[f3]
            elif op == 0x13:
                imm = sext(w >> 20, 12)
                sh = (w >> 20) & 31
                res = {0: a + imm, 1: a << sh, 2: int(signed(a) < imm), 4: a ^ (imm & MASK),
                       5: a >> sh, 6: a | (imm & MASK), 7: a & (imm & MASK)}[f3]
            elif op == 0x03:
                res = self.dmem[self._addr((a + sext(w >> 20, 12)) & MASK, pc)]
            elif op == 0x23:
                imm = sext(((w >> 25) << 5) | ((w >> 7) & 0x1F), 12)
                self.dmem[self._addr((a + imm) & MASK, pc)] = b
            elif op == 0x63:
                imm = sext((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) |
                           (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
                taken = (a == b) if f3 == 0 else (a != b)
                target = (pc + imm) & MASK
                self.branches.append((pc, target, int(taken)))
                if taken:
                    nxt = target
            else:
                raise RuntimeError(f"pc={pc:#x}: unsupported instruction {w:#010x}")
            if res is not None and rd != 0:
                self.regs[rd] = res & MASK
            self.pc = nxt
