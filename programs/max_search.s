# Maximum of 16 words a[i] = (5*i + 3) mod 16 stored from address 64.
# The "new maximum?" branch is data dependent.
        li   t3, 64         # base address
        li   t0, 0          # i
        li   t1, 16         # n
init:   slli t2, t0, 2      # 4i
        add  t2, t2, t0     # 5i
        addi t2, t2, 3
        andi t2, t2, 15     # a[i] = (5i + 3) mod 16
        slli t4, t0, 2
        add  t4, t4, t3
        sw   t2, 0(t4)
        addi t0, t0, 1
        bne  t0, t1, init
        lw   s0, 0(t3)      # max = a[0]
        li   t0, 1
find:   slli t4, t0, 2
        add  t4, t4, t3
        lw   t2, 0(t4)      # a[i]
        slt  t5, s0, t2     # max < a[i] ?
        beq  t5, zero, keep
        mv   s0, t2         # new maximum
keep:   addi t0, t0, 1
        bne  t0, t1, find
        sw   s0, 0(zero)    # mem[0] = 15
        ecall
