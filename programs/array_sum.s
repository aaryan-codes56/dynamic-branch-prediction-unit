# Fill a[i] = 3*i for 32 words at address 64, then sum the array with lw.
# The add right after each lw causes a load-use stall.
        li   t0, 0          # i
        li   t1, 32         # n
        li   t2, 0          # value
        li   t3, 64         # base address
fill:   slli t4, t0, 2
        add  t4, t4, t3
        sw   t2, 0(t4)
        addi t2, t2, 3
        addi t0, t0, 1
        bne  t0, t1, fill
        li   t0, 0
        li   s0, 0          # sum
sum:    slli t4, t0, 2
        add  t4, t4, t3
        lw   t5, 0(t4)
        add  s0, s0, t5     # load-use hazard
        addi t0, t0, 1
        bne  t0, t1, sum
        sw   s0, 0(zero)    # mem[0] = 1488
        ecall
