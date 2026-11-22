# Generate 64 pseudo-random numbers (xorshift32) and count the odd ones.
# The parity branch is data dependent (hard to predict).
        li   s0, 677        # x (seed)
        li   s1, 0          # odd count
        li   t0, 0
        li   t1, 64
loop:   slli t2, s0, 13
        xor  s0, s0, t2
        srli t2, s0, 17
        xor  s0, s0, t2
        slli t2, s0, 5
        xor  s0, s0, t2
        andi t3, s0, 1
        beq  t3, zero, even # data-dependent branch
        addi s1, s1, 1
even:   addi t0, t0, 1
        bne  t0, t1, loop
        sw   s1, 0(zero)
        sw   s0, 4(zero)
        ecall
