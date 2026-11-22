# if (i & 1) odd++; else even++;  for i = 0..39  (branch alternates N,T,N,T,...)
        li   t0, 0          # i
        li   t1, 40
        li   s0, 0          # even count
        li   s1, 0          # odd count
loop:   andi t2, t0, 1
        bne  t2, zero, odd  # alternating branch
        addi s0, s0, 1
        j    next
odd:    addi s1, s1, 1
next:   addi t0, t0, 1
        bne  t0, t1, loop
        sw   s0, 0(zero)
        sw   s1, 4(zero)
        ecall
