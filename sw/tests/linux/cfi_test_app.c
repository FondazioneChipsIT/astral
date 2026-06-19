// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// cfi_test_app.c — Simple application for cfi_launcher validation
//
// Designed to exercise every branch type the snooper can log:
//   - Direct calls            (add, fibonacci)
//   - Indirect calls          (dispatch table of function pointers)
//   - Conditional branches    (if/else chains, loop back-edges)
//   - Returns                 (every function return)
//
// When run under cfi_launcher the snooper should fill the ring with
// (PC_SRC, PC_DST, CTR_TYPE) records for every taken branch in this
// binary's .text pages.  Ibex fetches the instruction bytes and logs
// the count at the end.
//
// Build (on host, cross-compile):
//   riscv64-buildroot-linux-gnu-gcc -O1 -static -o cfi_test_app cfi_test_app.c
//
// Run (on target as root):
//   ./cfi_launcher ./cfi_test_app

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Verbose flag to control printing. Default: disabled. */
static int Verbose = 0;

/* Convenience macro to guard printf with the verbose flag. */
#define VPRINTF(...) do { if (Verbose) printf(__VA_ARGS__); } while (0)

// ---------------------------------------------------------------------------
// 1. Direct calls — simple arithmetic functions
// ---------------------------------------------------------------------------
static uint32_t add(uint32_t a, uint32_t b) { return a + b; }
static uint32_t mul(uint32_t a, uint32_t b) { return a * b; }
static uint32_t mod(uint32_t a, uint32_t b) { return b ? a % b : 0; }

// ---------------------------------------------------------------------------
// 2. Recursive function — many returns, back-edges via call stack
// ---------------------------------------------------------------------------
static uint32_t fibonacci(uint32_t n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// ---------------------------------------------------------------------------
// 3. Indirect dispatch — function pointer table
//    Generates indirect-call branches; CTR_TYPE should mark them as such.
// ---------------------------------------------------------------------------
typedef uint32_t (*op_fn)(uint32_t, uint32_t);

static const op_fn op_table[] = { add, mul, mod };
#define N_OPS (sizeof(op_table) / sizeof(op_table[0]))

static uint32_t dispatch(unsigned op_idx, uint32_t a, uint32_t b) {
    if (op_idx >= N_OPS) return 0;
    return op_table[op_idx](a, b);   // indirect call through table
}

// ---------------------------------------------------------------------------
// 4. State machine — data-dependent conditional branches
//    Models the kind of control flow a real interpreter or protocol
//    handler would produce.
// ---------------------------------------------------------------------------
typedef enum { ST_IDLE, ST_WORK, ST_WAIT, ST_DONE, ST_ERR } state_t;

static state_t next_state(state_t s, uint32_t token) {
    switch (s) {
    case ST_IDLE: return (token == 0xA5) ? ST_WORK : ST_ERR;
    case ST_WORK: return (token & 1)     ? ST_WAIT : ST_WORK;
    case ST_WAIT: return (token == 0)    ? ST_DONE : ST_WAIT;
    case ST_DONE: return ST_IDLE;
    default:      return ST_ERR;
    }
}

// ---------------------------------------------------------------------------
// 5. Tight loop — loop back-edge stress, exercised many times
// ---------------------------------------------------------------------------
static uint32_t checksum(const uint8_t *buf, size_t len) {
    uint32_t s = 0;
    for (size_t i = 0; i < len; i++) {
        s = add(s, buf[i]);
        if (s > 0x10000) s ^= 0xDEAD;  // extra conditional branch
    }
    return s;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-q") == 0 || strcmp(argv[i], "--quiet") == 0)
            Verbose = 0;
        else if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0)
            Verbose = 1;
    }

    VPRINTF("[app] cfi_test_app start\n");

    // ---- direct calls ----
    uint32_t r = 0;
    for (uint32_t i = 1; i <= 20; i++) {
        r = add(r, mul(i, i));
        if (mod(r, 7) == 0)
            r ^= 0x55;
    }
    VPRINTF("[app] direct: r=0x%08x\n", r);

    // ---- fibonacci (recursive) ----
    uint32_t fib = fibonacci(14);   // fib(14) = 377; generates ~1k calls
    VPRINTF("[app] fibonacci(14) = %u\n", fib);

    // ---- indirect dispatch ----
    uint32_t acc = 1;
    for (unsigned i = 0; i < 30; i++) {
        unsigned op  = i % N_OPS;
        uint32_t lhs = acc;
        uint32_t rhs = (i + 1) * 3;
        acc = dispatch(op, lhs, rhs);
        if (acc == 0) acc = 1;   // avoid zero in mul chain
    }
    VPRINTF("[app] dispatch: acc=0x%08x\n", acc);

    // ---- state machine ----
    static const uint32_t tokens[] = {
        0xA5, 0x01, 0x01, 0x00,  // IDLE→WORK→WAIT→WAIT→DONE
        0xA5, 0x00, 0xA5, 0x01, 0x00  // second run
    };
    state_t s = ST_IDLE;
    for (size_t i = 0; i < sizeof(tokens)/sizeof(tokens[0]); i++)
        s = next_state(s, tokens[i]);
        VPRINTF("[app] state machine final state = %d (expected %d)\n",
            (int)s, (int)ST_IDLE);

    // ---- tight loop ----
    uint8_t buf[256];
    for (int i = 0; i < 256; i++) buf[i] = (uint8_t)(i * 3 + 7);
    uint32_t cs = checksum(buf, 256);
    VPRINTF("[app] checksum = 0x%08x\n", cs);

    VPRINTF("[app] cfi_test_app done\n");
    return 0;
}
