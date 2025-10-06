# Problem B: 3 inputs -> encode/decode -> compare with expected and summary
.text
.globl _start

_start:
    la   s1, v_list              # s1 = &v_list
    la   s2, e_list              # s2 = &e_list
    la   s3, d_list              # s3 = &d_list
    li   s0, 0                   # i = 0

# -------- generate e[i], d[i] --------
gen_loop:
    li   t0, 3                   # N = 3 筆
    bge  s0, t0, print_all       # i >= 3 -> 列印

    slli t1, s0, 2               # t1 = i*4 (word 位移)
    add  t2, s1, t1              # t2 = &v_list[i]
    lw   t4, 0(t2)               # t4 = v[i]

    mv   a0, t4                  # a0 = v
    jal  ra, uf8_encode          # a0 = e = encode(v)
    slli t1, s0, 2               # 重算位移
    add  t2, s2, t1              # t2 = &e_list[i]
    sw   a0, 0(t2)               # e_list[i] = e
    mv   t5, a0                  # t5 = e 暫存

    mv   a0, t5                  # a0 = e
    jal  ra, uf8_decode          # a0 = d = decode(e)
    slli t1, s0, 2               # 重算位移
    add  t2, s3, t1              # t2 = &d_list[i]
    sw   a0, 0(t2)               # d_list[i] = d

    addi s0, s0, 1               # i++
    j    gen_loop                # 下一筆

# -------- print v/e/d --------
print_all:
    li   s0, 0                   # i = 0
    la   s1, v_list              # 重新載入基址
    la   s2, e_list
    la   s3, d_list
p_loop:
    li   t0, 3                   # N = 3
    bge  s0, t0, compare_all     # i >= 3 -> 進入比對
    slli t1, s0, 2               # t1 = i*4

    la   a0, str_v               # print "v="
    li   a7, 4                   # RARS: print string
    ecall
    add  t2, s1, t1              # &v[i]
    lw   a0, 0(t2)               # a0 = v[i]
    li   a7, 1                   # RARS: print int
    ecall

    la   a0, str_e               # print " e="
    li   a7, 4
    ecall
    add  t2, s2, t1              # &e[i]
    lw   a0, 0(t2)               # a0 = e[i]
    li   a7, 1
    ecall

    la   a0, str_d               # print " d="
    li   a7, 4
    ecall
    add  t2, s3, t1              # &d[i]
    lw   a0, 0(t2)               # a0 = d[i]
    li   a7, 1
    ecall

    la   a0, nl                  # 換行
    li   a7, 4
    ecall

    addi s0, s0, 1               # i++
    j    p_loop

# -------- compare with expected and print summary --------
compare_all:
    li   s0, 0                   # i = 0
    la   s1, e_list              # s1 = &e_list
    la   s2, d_list              # s2 = &d_list
    la   s3, exp_e_list          # s3 = &exp_e_list
    la   s4, exp_d_list          # s4 = &exp_d_list
    li   s7, 0                   # ok = 0
    li   s8, 0                   # ng = 0
cmp_loop:
    li   t0, 3                   # N = 3
    bge  s0, t0, summary         # i >= 3 -> 統計
    slli t1, s0, 2               # t1 = i*4

    add  t2, s1, t1              # &e[i]
    lw   t3, 0(t2)               # t3 = e[i]
    add  t2, s3, t1              # &exp_e[i]
    lw   t4, 0(t2)               # t4 = exp_e[i]
    bne  t3, t4, mark_ng         # e 不相等 -> ng

    add  t2, s2, t1              # &d[i]
    lw   t3, 0(t2)               # t3 = d[i]
    add  t2, s4, t1              # &exp_d[i]
    lw   t4, 0(t2)               # t4 = exp_d[i]
    bne  t3, t4, mark_ng         # d 不相等 -> ng

    addi s7, s7, 1               # ok++
    j    next_i
mark_ng:
    addi s8, s8, 1               # ng++
next_i:
    addi s0, s0, 1               # i++
    j    cmp_loop

summary:
    la   a0, str_all             # "ALL:"
    li   a7, 4
    ecall
    li   a0, 3                   # 全部 3 筆
    li   a7, 1
    ecall
    la   a0, nl                  # 換行
    li   a7, 4
    ecall

    la   a0, str_ok              # "OK:"
    li   a7, 4
    ecall
    mv   a0, s7                  # 列印 ok
    li   a7, 1
    ecall
    la   a0, nl
    li   a7, 4
    ecall

    la   a0, str_ng              # "NG:"
    li   a7, 4
    ecall
    mv   a0, s8                  # 列印 ng
    li   a7, 1
    ecall
    la   a0, nl
    li   a7, 4
    ecall

    li a7, 10                    # RARS: exit
    ecall

# -------- uf8_encode: no CLZ --------
# 格式：若 v < 16 則直接回傳 v
# 否則找最小 2^(k+4)-1 >= v 的區段，輸出 (k<<4) | ((v - (2^k-1)) >> k) 之低 4 位
.globl uf8_encode
uf8_encode:
    mv   t4, a0                  # t4 = v
    li   t0, 16                  # 區段起點步階 = 16
    bltu t4, t0, SMALL           # v < 16 -> 直接回傳

    li   t1, 0                   # t1 = k (區段指數)
    li   t2, 0                   # t2 = 累積 (2^k - 1) 的近似界
LOOP:
    sub  t5, t4, t2              # t5 = v - base
    bltu t5, t0, DONE            # 若 v - base < step(=2^(k+4)) -> 命中
    add  t2, t2, t0              # base += step
    slli t0, t0, 1               # step <<= 1  (k++)
    addi t1, t1, 1               # k++
    li   t6, 15                  # k 上限 15
    blt  t1, t6, LOOP            # k < 15 繼續

DONE:
    sub  t3, t4, t2              # t3 = v - base
    srl  t3, t3, t1              # 右移 k
    andi t3, t3, 0x0F            # 取低 4 bits
    slli t1, t1, 4               # k << 4
    or   a0, t1, t3              # a0 = (k<<4) | frac
    andi a0, a0, 0xFF            # 取 8 bits
    ret
SMALL:
    andi a0, t4, 0xFF            # 直接回傳 v
    ret

# -------- uf8_decode --------
# 反解：k = hi4(e)，f = lo4(e)
# base = (1<<k) - 1，bias = ((1<<k)-1)<<4
# v = (f << k) + bias
.globl uf8_decode
uf8_decode:
    andi a0, a0, 0xFF            # e = e & 0xFF
    andi t0, a0, 0x0F            # t0 = f
    srli t1, a0, 4               # t1 = k
    li   t2, 1                   # t2 = 1
    sll  t2, t2, t1              # t2 = 1<<k
    addi t2, t2, -1              # t2 = (1<<k)-1 = base
    slli t2, t2, 4               # bias = base<<4
    sll  t3, t0, t1              # f<<k
    add  a0, t3, t2              # v = (f<<k) + bias
    ret

# -------- data --------
.data
.align 2
# 輸入
v_list:      .word 13, 47, 255   # 測試 3 筆
# 期望（對應目前 encode/decode 規則）
exp_e_list:  .word 13, 31, 64    # 期望的 e
exp_d_list:  .word 13, 46, 240   # 期望的 d
# 實際輸出緩衝
e_list:      .word 0, 0, 0
d_list:      .word 0, 0, 0

# 字串
str_v:   .string "input="
str_e:   .string " e="
str_d:   .string " d="
str_all: .string "ALL:"
str_ok:  .string "OK:"
str_ng:  .string "NG:"
nl:      .string "\n"
