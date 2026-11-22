# Directed hazard test: forwarding paths, load-use stalls, branch operands,
# store-data forwarding, x0 writes, every ALU operation.
        addi x1, x0, 5
        addi x2, x1, 3      # EX/MEM -> EX forward (x1)
        add  x3, x1, x2     # MEM/WB (x1) and EX/MEM (x2) forwards
        sub  x4, x3, x1
        sw   x4, 0(x0)      # store data forwarded
        lw   x5, 0(x0)
        add  x6, x5, x5     # load-use stall
        lw   x7, 0(x0)
        nop
        add  x8, x7, x1     # load with one gap -> MEM/WB forward
        addi x9, x0, 16
        beq  x6, x9, skip   # branch operands forwarded (taken)
        addi x10, x0, 99    # must be skipped
skip:   lw   x11, 0(x0)
        bne  x11, x4, bad   # load-use into a branch (not taken)
        addi x12, x0, 1
        and  x13, x6, x9
        or   x14, x1, x2
        xor  x15, x14, x1
        slt  x16, x1, x2
        slt  x17, x2, x1
        addi x18, x0, -7
        slti x19, x18, 0
        srli x20, x18, 28
        slli x21, x1, 4
        andi x25, x18, 15
        ori  x26, x1, 64
        xori x27, x1, -1
        sll  x28, x1, x1
        srl  x29, x18, x1
        add  x0, x1, x1     # write to x0 is ignored
        add  x22, x0, x1
        sw   x22, 4(x0)
        sw   x15, 8(x0)
        lw   x23, 8(x0)
        sw   x23, 12(x0)    # load -> store data
        ecall
bad:    addi x24, x0, 1
        ecall
