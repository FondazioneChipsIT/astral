// Copyright 2026 ETH Zurich, University of Bologna and Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
 * OT clock-divider functional test — CVA6 (hostd) side
 * =====================================================
 * Companion to sw/tests/scarv/ot_clk_div_test/ot_clk_div_test.c running on ibex.
 *
 * Protocol (CVA6 side, repeated once per divider value under test):
 *   1. Poll SCRATCH_12 until ibex writes SYNC_IBEX_START.
 *   2. Snapshot get_mcycle() (start).
 *   3. Busy-wait for MEASURE_CHESHIRE_CYCLES Cheshire cycles.
 *   4. Snapshot get_mcycle() (end).
 *   5. Write elapsed cycles [63:32] to SCRATCH_15, [31:0] to SCRATCH_14.
 *   6. Write SYNC_CVA6_DONE to SCRATCH_13.
 *   7. Poll SCRATCH_12 until ibex clears it back to SYNC_IBEX_IDLE (consumed).
 *
 * Frequency relationship assumed by ibex verifier:
 *   f_OT = f_cheshire / (2 * ot_div)
 *   => cheshire_cycles / ot_cycles  ≈  2 * ot_div
 *
 * The measurement window is large enough (>= 1 M Cheshire cycles ~10 ms @100 MHz)
 * that polling/fence latency is negligible in the ratio computation.
 */

#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"
#include "car_util.h"

#ifndef VERBOSE
#define VERBOSE 1
#endif
#define LOG(fmt, ...) do { if (VERBOSE) printf(fmt, ##__VA_ARGS__); } while (0)

// Synchronisation tokens — must match ot_clk_div_test.c on the ibex side.
#define SYNC_IBEX_IDLE        0x00000000u  // ibex idle / slot cleared
#define SYNC_IBEX_BOOT_READY  0xAB000000u  // ibex signals it has booted and is ready
#define SYNC_IBEX_START       0xAB000001u  // ibex requests a measurement
#define SYNC_CVA6_BOOT_READY  0xCD000000u  // CVA6 signals it has booted and is ready
#define SYNC_CVA6_DONE        0xCD000001u  // CVA6 has written the elapsed cycle count

// Number of rounds: must match the number of measure_clk_div() calls in ibex test.
#define NUM_ROUNDS  8u

// Fixed measurement window in Cheshire cycles.
// 2 000 000 cycles @ ~100 MHz = ~20 ms; large enough to dwarf polling overhead.
#define MEASURE_CHESHIRE_CYCLES  2000000ULL

int main(void) {
    car_init_start();
    LOG("[hostd] ot_clk_div_test: start\n\r");

    // Release the security island so ibex starts executing.
    car_enable_domain(CAR_SECURITY_RST);

    // Boot-time barrier: announce CVA6 is ready, then wait for ibex.
    // Either side can reach this point first; both proceed only after
    // seeing each other's token.
    *reg32(&__base_regs, CHESHIRE_SCRATCH_13_REG_OFFSET) = (uint32_t)SYNC_CVA6_BOOT_READY;
    fence();
    while ((uint32_t)*reg32(&__base_regs, CHESHIRE_SCRATCH_12_REG_OFFSET) != SYNC_IBEX_BOOT_READY)
        ;
    // Clear own slot; ibex will clear its own slot independently.
    *reg32(&__base_regs, CHESHIRE_SCRATCH_13_REG_OFFSET) = (uint32_t)SYNC_IBEX_IDLE;
    fence();
    LOG("[hostd] ot_clk_div_test: sync done, starting measurement\n\r");

    for (unsigned round = 0; round < NUM_ROUNDS; round++) {
        LOG("[hostd] ot_clk_div_test: waiting for round %u\n\r", round);

        // Step 1 — wait for ibex to signal start.
        while ((uint32_t)*reg32(&__base_regs, CHESHIRE_SCRATCH_12_REG_OFFSET) != SYNC_IBEX_START)
            ;

        // Step 2 — latch start cycle as close as possible to the ibex signal.
        uint64_t t_start = get_mcycle();

        // Step 3 — busy-wait for the fixed measurement window.
        while ((get_mcycle() - t_start) < MEASURE_CHESHIRE_CYCLES)
            ;

        // Step 4 — latch end cycle.
        uint64_t t_end = get_mcycle();
        uint64_t elapsed = t_end - t_start;

        // Step 5 — publish elapsed cycles (lo word first so ibex sees consistent hi/lo).
        *reg32(&__base_regs, CHESHIRE_SCRATCH_14_REG_OFFSET) = (uint32_t)(elapsed & 0xFFFFFFFFu);
        fence();
        *reg32(&__base_regs, CHESHIRE_SCRATCH_15_REG_OFFSET) = (uint32_t)(elapsed >> 32);
        fence();

        LOG("[hostd] round %u: elapsed Cheshire cycles = %lu\n\r",
            round, (unsigned long)elapsed);

        // Step 6 — signal ibex that the result is ready.
        *reg32(&__base_regs, CHESHIRE_SCRATCH_13_REG_OFFSET) = (uint32_t)SYNC_CVA6_DONE;
        fence();

        // Step 7 — wait for ibex to acknowledge consumption before the next round.
        while ((uint32_t)*reg32(&__base_regs, CHESHIRE_SCRATCH_12_REG_OFFSET) != SYNC_IBEX_IDLE)
            ;
    }

    LOG("[hostd] ot_clk_div_test: done\n\r");
    return 0;
}
