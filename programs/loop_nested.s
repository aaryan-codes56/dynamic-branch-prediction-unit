# Nested loop: for (o = 0; o < 10; o++) for (i = 0; i < 6; i++) sum += i;
# Inner back-edge pattern T T T T T N (same as traces/loop_trace.csv).
        li   s0, 0          # sum
        li   t0, 0          # o
        li   t2, 10         # outer bound
outer:  li   t1, 0          # i
        li   t3, 6          # inner bound
inner:  add  s0, s0, t1
        addi t1, t1, 1
        bne  t1, t3, inner  # inner back-edge
        addi t0, t0, 1
        bne  t0, t2, outer  # outer back-edge
        sw   s0, 0(zero)    # mem[0] = 150
        ecall
