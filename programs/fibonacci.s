# First 20 Fibonacci numbers F(0)..F(19) stored as words from address 64.
        li   t3, 64         # address of F(0)
        li   t0, 0          # F(n-2)
        li   t1, 1          # F(n-1)
        sw   t0, 0(t3)
        sw   t1, 4(t3)
        addi t3, t3, 8
        li   t4, 2          # n
        li   t5, 20
loop:   add  t2, t0, t1     # F(n) = F(n-1) + F(n-2)
        sw   t2, 0(t3)
        mv   t0, t1
        mv   t1, t2
        addi t3, t3, 4
        addi t4, t4, 1
        bne  t4, t5, loop   # loop back-edge
        sw   t1, 0(zero)    # mem[0] = F(19) = 4181
        ecall
