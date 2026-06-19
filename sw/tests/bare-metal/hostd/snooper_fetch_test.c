// Copyright 2024 ETH Zurich, University of Bologna and Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// snooper_fetch_test.c  –  CVA6 (hostd) side
//
// Mirror of snooper_stress_test.c adapted for the fetch test.
// Uses distinct sync constants (SYNC_ADDR_VALID_FETCH, etc.) so this binary
// cannot accidentally pair with the ibex snooper_stress_test firmware.
//
// Protocol (scratch registers, same mapping as stress test):
//   scratch  8  CVA6 → ibex: dummy_code_start address
//   scratch  9  CVA6 → ibex: dummy_code_end   address
//   scratch 10  CVA6 → ibex: sync state  (SYNC_ADDR_VALID_FETCH, SYNC_FETCH_DONE,
//                                          SYNC_FETCH_DONE_RUN2)
//   scratch 11  ibex → CVA6: sync state  (SYNC_IBEX_FETCH_READY, SYNC_IBEX_READY_RUN2)
//
// Two-run protocol:
//   Run 1 (halt enabled) : measures CVA6 cycles WITH ibex-induced halts.
//   Run 2 (halt disabled): measures CVA6 cycles WITHOUT halts (baseline).
//   Δcycles = run1 − run2 is the true halt overhead; mhpmcounter3 misses it.

#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"
#include "car_util.h"

#ifndef VERBOSE
#define VERBOSE 1
#endif
#define LOG(fmt, ...) do { if (VERBOSE) printf(fmt, ##__VA_ARGS__); } while (0)

// Sync constants – must match snooper_fetch_test.c on the ibex side
#define SYNC_ADDR_VALID_FETCH  0xdeadc0de   // addresses published, ibex can configure
#define SYNC_FETCH_DONE        0xcafe00fe   // run-1 dummy complete (halt enabled)
#define SYNC_IBEX_FETCH_READY  0x5a1e00fe   // run-1 snooper configured, start dummy
#define SYNC_IBEX_READY_RUN2   0x5a1e01fe   // run-2 snooper reconfigured (halt off)
#define SYNC_FETCH_DONE_RUN2   0xcafe01fe   // run-2 dummy complete (halt disabled)

// ---------------------------------------------------------------------------
// Workload selection
//   A (default) – multiple conditionals per iteration: ~5 branches/iter,
//                 low entry count, easy to verify CFI paths.
//   B           – state machine: data-dependent branches, 4 distinct pc_dst
//                 values, best path diversity for CFI verification.
//   C           – nested loop: highest branch rate, maximises snooper fill,
//                 best for finding the ibex drain bottleneck.
//   D           – original: tight store loop 2000 iters, 1 branch/iter,
//                 identical to the legacy workload; useful as a reference
//                 baseline when comparing against older runs.
//   E           – realistic: mixed instruction stream (loads/stores,
//                 function calls, data-dependent branches) with a
//                 moderate working set to exercise realistic fetch patterns.
// ---------------------------------------------------------------------------
#ifndef WORKLOAD
#define WORKLOAD H
#endif

// Macro helpers for token-pasting the workload selector
#define _WORKLOAD_IS(x) (defined WORKLOAD_##x)
#define WORKLOAD_A 1
#define WORKLOAD_B 2
#define WORKLOAD_C 3
#define WORKLOAD_D 4
#define WORKLOAD_E 5
#define WORKLOAD_F 6
#define WORKLOAD_G 7
#define WORKLOAD_H 8
#define _WORKLOAD_VAL2(x) WORKLOAD_##x
#define _WORKLOAD_VAL(x)  _WORKLOAD_VAL2(x)
#define WORKLOAD_VAL      _WORKLOAD_VAL(WORKLOAD)

// ---------------------------------------------------------------------------
// Helper routines for WORKLOAD_E (realistic mixed workload). Marked
// noinline so they produce distinct call sites and diverse PC traces.
// ---------------------------------------------------------------------------
static void realistic_step_a(volatile int *buf, int n, int it) __attribute__((noinline));
static void realistic_step_b(volatile int *buf, int n, int it) __attribute__((noinline));
static void realistic_step_c(volatile int *buf, int n, int it) __attribute__((noinline));

static void realistic_step_a(volatile int *buf, int n, int it) {
    for (int i = 0; i < 8; i++) {
        int idx = (i * 13 + it) & (n - 1);
        buf[idx] = buf[idx] ^ (it + i);
    }
}

static void realistic_step_b(volatile int *buf, int n, int it) {
    int sum = 0;
    for (int i = 0; i < 6; i++) {
        int idx = (it * 7 + i * 3) & (n - 1);
        sum += buf[idx];
    }
    buf[it & (n - 1)] = sum;
}

static void realistic_step_c(volatile int *buf, int n, int it) {
    if ((it & 3) == 0) {
        for (int i = 0; i < 4; i++)
            buf[(it + i) & (n - 1)] += i + (it & 0xff);
    } else {
        for (int i = 0; i < 2; i++)
            buf[(it * 3 + i) & (n - 1)] -= i;
    }
}

// ---------------------------------------------------------------------------
// RUN_WORKLOAD(label) — emits the chosen workload body between two asm labels
//   dummy_code_<label>_start / dummy_code_<label>_end so both runs share the
//   same region boundaries published to ibex.
// ---------------------------------------------------------------------------
#if WORKLOAD_VAL == WORKLOAD_A
// Option A: 4 data-dependent conditional swaps + loop back-edge (~5 entries/iter)
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int a = 3, b = 1, c = 4, d = 1;                              \
        asm volatile("dummy_code_" #label "_start:");                          \
        for (volatile int i = 0; i < 600; i++) {                              \
            if (a > b) { int t = a; a = b; b = t; }                           \
            if (b > c) { int t = b; b = c; c = t; }                           \
            if (c > d) { int t = c; c = d; d = t; }                           \
            if (d > a) { int t = d; d = a; a = t; }                           \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                            \
        (void)a; (void)b; (void)c; (void)d;                                   \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_B
// Option B: state machine with data-dependent switch dispatch (~4-5 entries/iter)
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int state = 0, acc = 1;                                       \
        asm volatile("dummy_code_" #label "_start:");                          \
        for (volatile int i = 1; i <= 800; i++) {                             \
            switch (state & 3) {                                               \
            case 0: acc += i;      break;                                      \
            case 1: acc ^= (i<<1); break;                                      \
            case 2: acc -= i;      break;                                      \
            default: acc |= i;     break;                                      \
            }                                                                  \
            if (acc & 1) state += 1;                                           \
            else         state += 3;                                           \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                            \
        (void)acc; (void)state;                                                \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_C
// Option C: nested loop (~3 entries/iter × 200×10 = ~6000 entries total)
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int mat[4] = {5, 3, 8, 1};                                   \
        asm volatile("dummy_code_" #label "_start:");                          \
        for (volatile int i = 0; i < 200; i++) {                              \
            for (volatile int j = 0; j < 10; j++) {                           \
                if (mat[j & 3] < mat[(j + 1) & 3])                            \
                    mat[j & 3] += mat[(j + 1) & 3] & 0xF;                     \
            }                                                                  \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                            \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_D
// Option D: original tight store loop — 2000 iterations, 1 branch/iter (~1999
// entries).  Identical to the legacy workload; use as a reference baseline.
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        asm volatile("dummy_code_" #label "_start:");                          \
        *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;              \
        for (volatile int i = 0; i < 2000; i++) {                             \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;          \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                            \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_E
// Option E: realistic mixed workload — calls small routines, does loads/
// stores across a moderate working set and a few conditional branches.
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int buf[256];                                                 \
        for (int _i = 0; _i < 256; _i++) buf[_i] = _i;                        \
        asm volatile("dummy_code_" #label "_start:");                       \
        for (volatile int it = 0; it < 1500; it++) {                           \
            realistic_step_a(buf, 256, it);                                    \
            realistic_step_b(buf, 256, it);                                    \
            realistic_step_c(buf, 256, it);                                    \
            if (it & 1) { volatile int x = buf[(it * 5) & 255]; (void)x; }      \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                         \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_F
// Option F: interpreter-style mixed workload — small bytecode VM with
// indirect-like dispatch, register file, and memory operations to create
// realistic fetch/CFI patterns and varied instruction sizes.
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile unsigned char code[64];                                       \
        volatile int mem[128];                                                 \
        volatile int regs[8];                                                  \
        for (int _i = 0; _i < 64; _i++) code[_i] = (unsigned char)(_i * 31 + 7); \
        for (int _i = 0; _i < 128; _i++) mem[_i] = _i * 3 + 1;                 \
        for (int _i = 0; _i < 8; _i++) regs[_i] = _i + 1;                       \
        asm volatile("dummy_code_" #label "_start:");                       \
        for (volatile int it = 0; it < 800; it++) {                             \
            int pc = (it * 5) & 63;                                            \
            for (int step = 0; step < 64; step++) {                           \
                unsigned char op = code[pc++ & 63];                            \
                switch (op & 7) {                                               \
                case 0: { int d = code[pc++ & 63] & 7; int s = code[pc++ & 63] & 7; regs[d] += regs[s]; break; } \
                case 1: { int d = code[pc++ & 63] & 7; int s = code[pc++ & 63] & 7; regs[d] *= regs[s]; break; } \
                case 2: { int d = code[pc++ & 63] & 7; int a = code[pc++ & 63] & 127; regs[d] += mem[a]; break; } \
                case 3: { int s = code[pc++ & 63] & 7; int a = code[pc++ & 63] & 127; mem[a] = regs[s]; break; } \
                case 4: { int a = code[pc++ & 63] & 127; mem[a] ^= regs[code[pc++ & 63] & 7]; break; } \
                default: pc++; break;                                               \
                }                                                                \
            }                                                                    \
            if (it & 3) { volatile int tmp = regs[(it >> 1) & 7]; (void)tmp; }     \
        }                                                                        \
        asm volatile("dummy_code_" #label "_end:");                         \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_G
// Option G: light workload — low instruction count, few branches, small
// working set to produce minimal fetch pressure and quick runs.
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int x = 1, y = 2, z = 3;                                      \
        asm volatile("dummy_code_" #label "_start:");                       \
        for (volatile int i = 0; i < 10000; i++) {                               \
            x += i;                                                            \
            if (x & 1) y ^= x; else y += z;                                    \  
            z = (y + x) & 0xFF;                                                \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                         \
        (void)x; (void)y; (void)z;                                             \
    } while (0)

#elif WORKLOAD_VAL == WORKLOAD_H
// Option H: low-CFI workload — many straight-line arithmetic and memory
// operations, with very rare conditional branches to minimize CFI edges.
#define RUN_WORKLOAD(label)                                                    \
    do {                                                                       \
        volatile int data[64];                                                 \
        for (int _i = 0; _i < 64; _i++) data[_i] = _i * 3 + 7;                 \
        asm volatile("dummy_code_" #label "_start:");                       \
        for (volatile int it = 0; it < 2000; it++) {                           \
            int base = it & 63;                                                 \
            /* unrolled straight-line work (no inner loop branches) */           \
            data[(base + 0) & 63] += ((it * 31) ^ (0 * 7)) + (data[(base + 5) & 63] & 0x1F); \
            data[(base + 1) & 63] += ((it * 31) ^ (1 * 7)) + (data[(base + 6) & 63] & 0x1F); \
            data[(base + 2) & 63] += ((it * 31) ^ (2 * 7)) + (data[(base + 7) & 63] & 0x1F); \
            data[(base + 3) & 63] += ((it * 31) ^ (3 * 7)) + (data[(base + 8) & 63] & 0x1F); \
            data[(base + 4) & 63] += ((it * 31) ^ (4 * 7)) + (data[(base + 9) & 63] & 0x1F); \
            data[(base + 5) & 63] ^= (data[(base + 0) & 63] >> 0);               \
            data[(base + 6) & 63] ^= (data[(base + 1) & 63] >> 1);               \
            data[(base + 7) & 63] ^= (data[(base + 2) & 63] >> 2);               \
            data[(base + 8) & 63] += (data[(base + 3) & 63] & 0xFF);            \
            data[(base + 9) & 63] += (data[(base + 4) & 63] & 0xFF);            \
            data[(base + 10) & 63] ^= (data[(base + 5) & 63] >> 1);             \
            data[(base + 11) & 63] += (data[(base + 6) & 63] & 0x3F);           \
            data[(base + 12) & 63] *= 3;                                        \
            data[(base + 13) & 63] -= data[(base + 7) & 63];                    \
            data[(base + 14) & 63] ^= data[(base + 8) & 63];                    \
            data[(base + 15) & 63] += (data[(base + 9) & 63] & 0x7F);           \
            /* extremely rare branch: once every 4096 iterations */             \
            if ((it & 4095) == 0) {                                             \
                data[it & 63] ^= 0x55;                                         \
            }                                                                  \
        }                                                                      \
        asm volatile("dummy_code_" #label "_end:");                         \
        (void)data;                                                            \
    } while (0)

#else
#error "Unknown WORKLOAD value — use A, B, C, D, E, F, or G"
#endif



int main(void) {
    extern char dummy_code_run1_start, dummy_code_run1_end;

    car_init_start();
    LOG("[hostd] snooper_fetch_test: start (workload=%d)\n\r", WORKLOAD_VAL);

    // Publish dummy code region addresses to ibex via scratch registers
    *reg32(&__base_regs, CHESHIRE_SCRATCH_8_REG_OFFSET)  = (uintptr_t)&dummy_code_run1_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_9_REG_OFFSET)  = (uintptr_t)&dummy_code_run1_end;
    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_ADDR_VALID_FETCH;
    fence();

    // Enable security island so ibex can come up and configure the snooper
    car_enable_domain(CAR_SECURITY_RST);
    car_select_clk(0, car_clkd_from_rstd(CAR_SECURITY_RST));


    // Wait for ibex to finish configuring the snooper
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_FETCH_READY)
        ;

    // -----------------------------------------------------------------------
    // RUN 1 — snooper halt ENABLED
    // mhpmcounter3 counts internal pipeline stalls only; it is blind to the
    // external halt signal ibex asserts.  The true halt overhead is the
    // difference in total_cycles between run 1 and run 2.
    // -----------------------------------------------------------------------
    asm volatile("csrwi mhpmevent3, 22"    ::: "memory");
    asm volatile("csrwi mhpmcounter3, 0"   ::: "memory");
    uint64_t cycle_start = get_mcycle();

    RUN_WORKLOAD(run1);

    uint64_t cycles_run1 = get_mcycle() - cycle_start;
    uint64_t stall_cycles_run1;
    asm volatile("csrr %0, mhpmcounter3" : "=r"(stall_cycles_run1) :: "memory");

    LOG("[hostd] run1 (halt ON ): total=%lu pipeline_stall=%lu (%.2f%%)\n\r",
        (unsigned long)cycles_run1, (unsigned long)stall_cycles_run1,
        (double)stall_cycles_run1 / cycles_run1 * 100);

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_FETCH_DONE;
    fence();

    // -----------------------------------------------------------------------
    // RUN 2 — snooper halt DISABLED (baseline)
    // Wait for ibex to reconfigure the snooper (halt bit cleared, ring reset)
    // then re-run the identical workload.
    // -----------------------------------------------------------------------
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_READY_RUN2)
        ;

    asm volatile("csrwi mhpmcounter3, 0" ::: "memory");
    uint64_t cycle_start2 = get_mcycle();

    RUN_WORKLOAD(run2);

    uint64_t cycles_run2 = get_mcycle() - cycle_start2;
    uint64_t stall_cycles_run2;
    asm volatile("csrr %0, mhpmcounter3" : "=r"(stall_cycles_run2) :: "memory");

    LOG("[hostd] run2 (halt OFF): total=%lu pipeline_stall=%lu (%.2f%%)\n\r",
        (unsigned long)cycles_run2, (unsigned long)stall_cycles_run2,
        (double)stall_cycles_run2 / cycles_run2 * 100);

    uint64_t halt_overhead = (cycles_run1 > cycles_run2) ? cycles_run1 - cycles_run2 : 0;
    LOG("[hostd] halt overhead: %lu cycles (%.2f%% of run2 baseline)\n\r",
        (unsigned long)halt_overhead,
        (double)halt_overhead / cycles_run2 * 100);

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_FETCH_DONE_RUN2;
    fence();

    LOG("[hostd] snooper_fetch_test: done (workload=%d)\n\r", WORKLOAD_VAL);
    return 0;
}
