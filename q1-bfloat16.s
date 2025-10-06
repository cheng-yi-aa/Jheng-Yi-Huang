# ===== bfloat16 demo：f32bits -> bf16bits -> f32bits，含三筆檢查 + 總結(ALL/OK/NG) =====
# 只做位元操作；RARS/venus 可跑；syscall：4=print_str, 1=print_int, 11=print_char, 10=exit
.text
.globl _start

_start:
    la   s1, in_f32_bits_arr     # s1 = &in[i] (3 筆 uint32)
    la   s2, exp_bf16_arr        # s2 = &期望 bf16（低 16 位有效）
    la   s3, exp_out_arr         # s3 = &期望 out f32 bits
    li   s0, 0                   # s0 = i

    li   s7, 0                   # s7 = ok_cnt
    li   s8, 0                   # s8 = ng_cnt

loop3:
    li   t6, 3                   # N = 3
    beq  s0, t6, summary         # i==3 -> 跳到總結

    # ---- 取 in[i] ----
    slli t0, s0, 2               # t0 = i*4 (word 位移)
    add  t1, s1, t0              # t1 = &in[i]
    lw   s4, 0(t1)               # s4 = in[i]（32 位整數視為位元）

    # ---- f32 -> bf16 -> f32 ----
    mv   a0, s4                  # a0 = in bits
    jal  ra, f32_to_bf16         # 取高 16 位（截斷）
    mv   s5, a0                  # s5 = bf16（低 16 位承載）
    jal  ra, bf16_to_f32         # 左移回 32 位
    mv   s6, a0                  # s6 = out f32 bits

    li   s9, 1                   # s9 = 本筆 OK 旗標，預設 1；任何失敗會清為 0

    # ===== 印 input =====
    la   a0, msg_in              # "input f32 bits: "
    li   a7, 4
    ecall
    mv   a0, s4                  # 十進位輸出 in
    li   a7, 1
    ecall
    la   a0, msg_spc_hex         # " (hex="
    li   a7, 4
    ecall
    mv   a0, s4                  # 十六進位輸出 in
    jal  ra, print_hex32_simple
    la   a0, msg_ok              # 視作展示行：input 自身無需比對
    li   a7, 4
    ecall

    # ===== 印 bf16 並比對 =====
    la   a0, msg_bf16            # "bf16 bits: "
    li   a7, 4
    ecall
    mv   a0, s5                  # 十進位輸出 bf16（實值在低 16 位）
    li   a7, 1
    ecall
    la   a0, msg_spc_hex
    li   a7, 4
    ecall
    mv   a0, s5                  # 十六進位輸出 bf16
    jal  ra, print_hex16_simple

    # 期望 bf16 取低 16 位後比對
    slli t0, s0, 2               # 重新計位移
    add  t2, s2, t0              # t2 = &exp_bf16[i]
    lw   t3, 0(t2)               # t3 = 期望（32 中只有低 16 有效）
    slli t3, t3, 16
    srli t3, t3, 16              # t3 = exp & 0xFFFF

    mv   t4, s5
    slli t4, t4, 16
    srli t4, t4, 16              # t4 = s5 & 0xFFFF

    bne  t4, t3, bf16_ng         # 不相等 -> NG
    la   a0, msg_ok              # 相等 -> OK
    li   a7, 4
    ecall
    j    after_bf16_chk
bf16_ng:
    la   a0, msg_ng
    li   a7, 4
    ecall
    li   s9, 0                   # 標記本筆 NG
after_bf16_chk:

    # ===== 印 out f32 並比對 =====
    la   a0, msg_out             # "out f32 bits: "
    li   a7, 4
    ecall
    mv   a0, s6                  # 十進位輸出 out
    li   a7, 1
    ecall
    la   a0, msg_spc_hex
    li   a7, 4
    ecall
    mv   a0, s6                  # 十六進位輸出 out
    jal  ra, print_hex32_simple

    # 比對 out
    slli t0, s0, 2
    add  t5, s3, t0              # t5 = &exp_out[i]
    lw   t6, 0(t5)               # t6 = 期望 out
    bne  s6, t6, out_ng
    la   a0, msg_ok
    li   a7, 4
    ecall
    j    after_out_chk
out_ng:
    la   a0, msg_ng
    li   a7, 4
    ecall
    li   s9, 0                   # 標記本筆 NG
after_out_chk:

    # ===== 本筆計入 OK/NG =====
    beqz s9, add_ng              # s9==0 -> NG++
    addi s7, s7, 1               # ok_cnt++
    j    print_newline
add_ng:
    addi s8, s8, 1               # ng_cnt++

print_newline:
    li   a7, 11
    li   a0, 10                  # '\n'
    ecall

    addi s0, s0, 1               # i++
    j    loop3

# ===== 總結輸出 =====
summary:
    la   a0, msg_all             # "ALL: "
    li   a7, 4
    ecall
    li   a0, 3                   # ALL = 3
    li   a7, 1
    ecall
    li   a7, 11                  # '\n'
    li   a0, 10
    ecall

    la   a0, msg_ok_only         # "OK: "
    li   a7, 4
    ecall
    mv   a0, s7                  # 列印 OK 數
    li   a7, 1
    ecall
    li   a7, 11
    li   a0, 10
    ecall

    la   a0, msg_ng_only         # "NG: "
    li   a7, 4
    ecall
    mv   a0, s8                  # 列印 NG 數
    li   a7, 1
    ecall
    li   a7, 11
    li   a0, 10
    ecall

    li   a7, 10                  # exit
    ecall

# ------------------------------------------------------------
# f32_to_bf16(a0=f32bits) -> a0=bf16bits（低 16 位；僅截斷不四捨五入）
# ------------------------------------------------------------
.globl f32_to_bf16
f32_to_bf16:
    srli a0, a0, 16              # 右移 16 取得高半字
    ret

# ------------------------------------------------------------
# bf16_to_f32(a0=bf16 低 16) -> a0=f32bits（回填高半字到高位）
# ------------------------------------------------------------
.globl bf16_to_f32
bf16_to_f32:
    slli a0, a0, 16              # 左移 16 放回高半字
    ret

# ------------------------------------------------------------
# print_hex32_simple(a0=value)：輸出 "0x" + 8 hex 字元
# ------------------------------------------------------------
.globl print_hex32_simple
print_hex32_simple:
    add  t0, a0, x0              # t0 = value
    li   a7, 11                  # print_char
    li   a0, 48                  # '0'
    ecall
    li   a0, 120                 # 'x'
    ecall
    li   t1, 8                   # 8 個 nibble
    li   t2, 28                  # 從最高位開始移（28,24,...,0）
ph32_loop:
    srl  t3, t0, t2              # 取出當前 nibble
    andi t3, t3, 0xF
    li   t4, 10
    blt  t3, t4, ph32_is_digit   # <10 -> '0'+n
    addi t3, t3, -10             # >=10 -> 'A'+(n-10)
    li   a0, 65                  # 'A'
    add  a0, a0, t3
    ecall
    j    ph32_next
ph32_is_digit:
    li   a0, 48                  # '0'
    add  a0, a0, t3
    ecall
ph32_next:
    addi t2, t2, -4              # 下一個 nibble
    addi t1, t1, -1
    bnez t1, ph32_loop
    ret

# ------------------------------------------------------------
# print_hex16_simple(a0=value 低 16)：輸出 "0x" + 4 hex 字元
# ------------------------------------------------------------
.globl print_hex16_simple
print_hex16_simple:
    slli a0, a0, 16              # 清除高噪聲
    srli a0, a0, 16
    add  t0, a0, x0
    li   a7, 11
    li   a0, 48                  # '0'
    ecall
    li   a0, 120                 # 'x'
    ecall
    li   t1, 4                   # 4 個 nibble
    li   t2, 12                  # 12,8,4,0
ph16_loop:
    srl  t3, t0, t2
    andi t3, t3, 0xF
    li   t4, 10
    blt  t3, t4, ph16_is_digit
    addi t3, t3, -10
    li   a0, 65                  # 'A'
    add  a0, a0, t3
    ecall
    j    ph16_next
ph16_is_digit:
    li   a0, 48                  # '0'
    add  a0, a0, t3
    ecall
ph16_next:
    addi t2, t2, -4
    addi t1, t1, -1
    bnez t1, ph16_loop
    ret

# ========================= Data =========================
.data
# 三筆輸入（僅以位元操作示範）
in_f32_bits_arr:
    .word 0x12345678             # 305419896
    .word 0x23456789             # 591751049
    .word 0x34567890             # 878082192

# 期望 bf16 與 out f32（對應簡單截斷）
exp_bf16_arr:
    .word 0x00001234             # 4660
    .word 0x00002345             # 9029
    .word 0x00003456             # 13398
exp_out_arr:
    .word 0x12340000             # 305397760
    .word 0x23450000             # 591724544
    .word 0x34560000             # 878051328

# 文案
msg_in:        .string "input f32 bits: "
msg_bf16:      .string "bf16 bits: "
msg_out:       .string "out f32 bits: "
msg_spc_hex:   .string " (hex="
msg_ok:        .string ")  Check OK\n"
msg_ng:        .string ")  Check NG\n"
msg_all:       .string "ALL: "
msg_ok_only:   .string "OK: "
msg_ng_only:   .string "NG: "
