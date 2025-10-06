# ===== bfloat16 sqrt (RV32I, 1|8|7, bias=127) =====
# 一行一指令。Ripes ECALL：4=print_str, 11=putchar, 1=print_int, 10=exit

    .text
    .globl _start

_start:
    la    s5, tv_in
    la    s6, tv_exp
    li    s0, 3
    li    s1, 0
    li    s2, 0
    li    s3, 0

S_loop:
    beq   s1, s0, S_done

    slli  a1, s1, 1
    add   a2, s5, a1
    lhu   a0, 0(a2)
    mv    s7, a0
    jal   ra, bf16_sqrt
    mv    s9, a0

    slli  a1, s1, 1
    add   a3, s6, a1
    lhu   s8, 0(a3)

    la    a0, msg_case1
    li    a7, 4
    ecall
    mv    a0, s7
    jal   ra, print_hex16

    la    a0, msg_case2
    li    a7, 4
    ecall
    mv    a0, s8
    jal   ra, print_hex16

    la    a0, msg_case3
    li    a7, 4
    ecall
    mv    a0, s9
    jal   ra, print_hex16

    la    a0, msg_space
    li    a7, 4
    ecall

    bne   s9, s8, S_fail

S_pass:
    la    a0, msg_ok
    li    a7, 4
    ecall
    la    a0, msg_nl
    li    a7, 4
    ecall
    addi  s2, s2, 1
    j     S_next

S_fail:
    la    a0, msg_ng
    li    a7, 4
    ecall
    la    a0, msg_nl
    li    a7, 4
    ecall
    addi  s3, s3, 1

S_next:
    addi  s1, s1, 1
    j     S_loop

S_done:
    la    a0, msg_total
    li    a7, 4
    ecall
    mv    a0, s0
    li    a7, 1
    ecall
    la    a0, msg_nl
    li    a7, 4
    ecall

    la    a0, msg_pass
    li    a7, 4
    ecall
    mv    a0, s2
    li    a7, 1
    ecall
    la    a0, msg_nl
    li    a7, 4
    ecall

    la    a0, msg_fail
    li    a7, 4
    ecall
    mv    a0, s3
    li    a7, 1
    ecall
    la    a0, msg_nl
    li    a7, 4
    ecall

    li    a7, 10
    ecall

# ---------- bf16_sqrt: a0(in) -> a0(out) ----------
bf16_sqrt:
    srli  a1, a0, 15
    andi  a1, a1, 1
    srli  a2, a0, 7
    andi  a2, a2, 0xFF
    andi  a3, a0, 0x7F

    li    t0, 0xFF
    bne   a2, t0, SQ_ZCHK
    bnez  a3, SQ_RET_IN
    bnez  a1, SQ_QNAN
    j     SQ_POS_INF

SQ_ZCHK:
    beqz  a2, SQ_RET_ZERO
    bnez  a1, SQ_QNAN

    li    t1, 0x80
    or    t1, t1, a3
    li    t2, 127
    sub   t2, a2, t2

    andi  t3, t2, 1
    beqz  t3, SQ_E_OK
    slli  t1, t1, 1
    addi  t2, t2, -1

SQ_E_OK:
    srai  t2, t2, 1
    li    t4, 127
    add   t2, t2, t4

    slli  t1, t1, 7
    li    t3, 0
    li    t4, 16384

SQ_ISQ_LOOP:
    beqz  t4, SQ_ISQ_DONE
    add   t5, t3, t4
    blt   t1, t5, SQ_TRY_NO
    sub   t1, t1, t5
    srli  t3, t3, 1
    add   t3, t3, t4
    j     SQ_BIT_SHR

SQ_TRY_NO:
    srli  t3, t3, 1

SQ_BIT_SHR:
    srli  t4, t4, 2
    j     SQ_ISQ_LOOP

SQ_ISQ_DONE:
    andi  t3, t3, 0x7F

    li    t5, 255
    bge   t2, t5, SQ_POS_INF
    blez  t2, SQ_RET_ZERO

    slli  t2, t2, 7
    or    a0, t2, t3
    ret

SQ_POS_INF:
    li    a0, 0x7F80
    ret
SQ_QNAN:
    li    a0, 0x7FC0
    ret
SQ_RET_ZERO:
    li    a0, 0x0000
    ret
SQ_RET_IN:
    ret

# ---------- print 16-bit hex: a0 -> "0xHHHH" ----------
print_hex16:
    slli  a0, a0, 16
    srli  a0, a0, 16
    mv    t0, a0
    li    a7, 11
    li    a0, 48
    ecall
    li    a0, 120
    ecall
    li    t1, 4
    li    t2, 12
ph16_loop:
    srl   t3, t0, t2
    andi  t3, t3, 15
    li    t4, 10
    blt   t3, t4, ph16_dig
    addi  t3, t3, -10
    li    a0, 65
    add   a0, a0, t3
    ecall
    j     ph16_next
ph16_dig:
    li    a0, 48
    add   a0, a0, t3
    ecall
ph16_next:
    addi  t2, t2, -4
    addi  t1, t1, -1
    bne   t1, x0, ph16_loop
    ret

# ========================= Data =========================
    .data
    .align 2

# in->expected: 1.0, 16.0, 25.0
tv_in:
    .half 0x3F80
    .half 0x4180
    .half 0x41C8
tv_exp:
    .half 0x3F80
    .half 0x4080
    .half 0x40A0

msg_case1:
    .asciz "in bf16 bits: "
msg_case2:
    .asciz "  exp: "
msg_case3:
    .asciz "  out: "
msg_space:
    .asciz "  Check "
msg_ok:
    .asciz "OK"
msg_ng:
    .asciz "NG"
msg_total:
    .asciz "ALL: "
msg_pass:
    .asciz "OK: "
msg_fail:
    .asciz "NG: "
msg_nl:
    .asciz "\n"
