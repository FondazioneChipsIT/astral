// Copyright 2024 ETH Zurich, University of Bologna and Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"
#include "car_util.h"

#ifndef VERBOSE
#define VERBOSE 0
#endif
#define LOG(fmt, ...) do { if (VERBOSE) printf(fmt, ##__VA_ARGS__); } while (0)

// CVA6 -> ibex: written to CHESHIRE_SCRATCH_10
#define SYNC_ADDR_VALID  0xdeadbeef  // addresses published, ibex can configure snooper
#define SYNC_DUMMY1_DONE 0xcafe0001  // dummy1 execution complete
#define SYNC_DUMMY2_DONE 0xcafe0002  // dummy2 execution complete
#define SYNC_DUMMY3_DONE 0xcafe0003  // dummy3 execution complete

// ibex -> CVA6: written to CHESHIRE_SCRATCH_11
#define SYNC_IBEX_READY1 0x5a1e0001  // snooper configured, start dummy1
#define SYNC_IBEX_READY2 0x5a1e0002  // buffer verified after dummy1, start dummy2
#define SYNC_IBEX_READY3 0x5a1e0003  // buffer verified after dummy2, start dummy3

int main(void) {
    extern char dummy1_code_start, dummy1_code_end;
    extern char dummy2_code_start, dummy2_code_end;
    extern char dummy3_code_start, dummy3_code_end;

    car_init_start();
    LOG("[hostd] snooper_stress_test: start\n\r");

    // Publish all dummy code region addresses via scratch registers
    // scratch 4-9: region addresses, scratch 10: CVA6->ibex sync, scratch 11: ibex->CVA6 sync
    *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET)  = (uintptr_t)&dummy1_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_5_REG_OFFSET)  = (uintptr_t)&dummy1_code_end;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_6_REG_OFFSET)  = (uintptr_t)&dummy2_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_7_REG_OFFSET)  = (uintptr_t)&dummy2_code_end;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_8_REG_OFFSET)  = (uintptr_t)&dummy3_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_9_REG_OFFSET)  = (uintptr_t)&dummy3_code_end;
    fence();
    // Sentinel: signal ibex that addresses are valid and snooper can be configured
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_ADDR_VALID;
    fence();

    // Enable security island
    car_enable_domain(CAR_SECURITY_RST);

    // Wait for ibex to finish configuring the snooper
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_READY1)
        ;

    //------------------------------------------------------------------------//
    //--------------------------- DUMMY1 CODE REGION -------------------------//
    // ibex monitors RANGE_0; ibex drains buffer and verifies after this block //
    //------------------------------------------------------------------------//
    asm volatile ("dummy1_code_start:");
    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (volatile int i = 0; i < 20; i++) {
        if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }
    asm volatile ("dummy1_code_end:");

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_DUMMY1_DONE;
    fence();

    // Wait for ibex to finish reading and verifying dummy1 buffer
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_READY2)
        ;

    //------------------------------------------------------------------------//
    //--------------------------- DUMMY2 CODE REGION -------------------------//
    // ibex monitors RANGE_1; ibex drains buffer and verifies after this block //
    //------------------------------------------------------------------------//
    asm volatile ("dummy2_code_start:");
    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (volatile int i = 0; i < 50; i++) {
        if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
            *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }
    asm volatile ("dummy2_code_end:");

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_DUMMY2_DONE;
    fence();

    // Wait for ibex to finish reading and verifying dummy2 buffer
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_READY3)
        ;

    //------------------------------------------------------------------------//
    //--------------------------- DUMMY3 CODE REGION -------------------------//
    // ibex monitors RANGE_2; CVA6 intentionally overflows the snooper buffer //
    // past HALT_LEVEL, causing repeated snooper-induced core halts.  ibex    //
    // concurrently drains the buffer to release each halt.                   //
    //                                                                         //
    // Performance counters:                                                   //
    //   mcycle          – total wall-clock cycles (includes snooper halts)   //
    //   mhpmcounter3    – pipeline stall cycles (CVA6 event 22)              //
    //------------------------------------------------------------------------//

    // Configure mhpmevent3 = 22 (Pipeline Stall: cycles stalled in read-operands stage)
    asm volatile("csrwi mhpmevent3, 22" ::: "memory");
    // Reset mhpmcounter3 to zero before the measured region
    asm volatile("csrwi mhpmcounter3, 0" ::: "memory");
    uint64_t dummy3_cycle_start = get_mcycle();

    asm volatile ("dummy3_code_start:");
    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    for (volatile int i = 0; i < 2000; i++) {
        //if (*reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) != 0)
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
        *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    }
    asm volatile ("dummy3_code_end:");

    uint64_t dummy3_cycle_end = get_mcycle();
    uint64_t dummy3_stall_cycles;
    asm volatile("csrr %0, mhpmcounter3" : "=r"(dummy3_stall_cycles) :: "memory");

    LOG("[hostd] dummy3 perf: total_cycles=%lu pipeline_stall_cycles=%lu\n\r",
           (unsigned long)(dummy3_cycle_end - dummy3_cycle_start),
           (unsigned long)dummy3_stall_cycles);
    LOG("[hostd] dummy3 perf: stall_ratio=%.2f%%\n\r",
           (double)dummy3_stall_cycles / (dummy3_cycle_end - dummy3_cycle_start) * 100);

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_DUMMY3_DONE;
    fence();

    LOG("[hostd] snooper_stress_test: done\n\r");
    return 0;
}
