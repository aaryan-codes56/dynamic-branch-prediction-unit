# Bubble sort of 10 words at address 64 (data-dependent branches).
        li   t3, 64         # base address
        li   t0, 9
        sw   t0, 0(t3)
        li   t0, 3
        sw   t0, 4(t3)
        li   t0, 7
        sw   t0, 8(t3)
        li   t0, 1
        sw   t0, 12(t3)
        li   t0, 8
        sw   t0, 16(t3)
        li   t0, 2
        sw   t0, 20(t3)
        li   t0, 6
        sw   t0, 24(t3)
        li   t0, 0
        sw   t0, 28(t3)
        li   t0, 5
        sw   t0, 32(t3)
        li   t0, 4
        sw   t0, 36(t3)
        li   s1, 10         # n
        li   s2, 0          # i
outer:  li   s3, 0          # j
        sub  s4, s1, s2
        addi s4, s4, -1     # limit = n - i - 1
check:  beq  s3, s4, idone
        slli t4, s3, 2
        add  t4, t4, t3
        lw   t0, 0(t4)      # a[j]
        lw   t1, 4(t4)      # a[j+1]
        slt  t2, t1, t0     # a[j+1] < a[j] ?
        beq  t2, zero, noswap
        sw   t1, 0(t4)
        sw   t0, 4(t4)
noswap: addi s3, s3, 1
        j    check
idone:  addi s2, s2, 1
        addi t5, s1, -1
        bne  s2, t5, outer
        ecall
