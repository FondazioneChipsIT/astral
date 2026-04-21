// Copyright 2024 ETH Zurich, University of Bologna and Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"
#include "car_util.h"

#ifndef VERBOSE
#define VERBOSE 1
#endif
#define LOG(fmt, ...) do { if (VERBOSE) printf(fmt, ##__VA_ARGS__); } while (0)

// CVA6 -> ibex: written to CHESHIRE_SCRATCH_10
#define SYNC_ADDR_VALID  0xdeadbeef  // addresses published, ibex can configure snooper
#define SYNC_DUMMY3_DONE 0xcafe0003  // dummy execution complete

// ibex -> CVA6: written to CHESHIRE_SCRATCH_11
#define SYNC_IBEX_READY3 0x5a1e0003  // snooper configured, start dummy

int main(void) {
    extern char dummy_code_start, dummy_code_end;

    car_init_start();
    LOG("[hostd] snooper_stress_test: start\n\r");

    // Publish dummy code region addresses via scratch registers
    // scratch 8-9: region addresses, scratch 10: CVA6->ibex sync, scratch 11: ibex->CVA6 sync
    *reg32(&__base_regs, CHESHIRE_SCRATCH_8_REG_OFFSET)  = (uintptr_t)&dummy_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_9_REG_OFFSET)  = (uintptr_t)&dummy_code_end;
    fence();
    // Sentinel: signal ibex that addresses are valid and snooper can be configured
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_ADDR_VALID;
    fence();

    // Enable security island
    car_enable_domain(CAR_SECURITY_RST);

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
    // Wait for ibex to finish configuring the snooper
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_11_REG_OFFSET) != SYNC_IBEX_READY3)
        ;
    // Configure mhpmevent3 = 22 (Pipeline Stall: cycles stalled in read-operands stage)
    asm volatile("csrwi mhpmevent3, 22" ::: "memory");
    // Reset mhpmcounter3 to zero before the measured region
    asm volatile("csrwi mhpmcounter3, 0" ::: "memory");
    uint64_t dummy_cycle_start = get_mcycle();


    asm volatile ("dummy_code_start:");
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
    asm volatile ("dummy_code_end:");

    uint64_t dummy_cycle_end = get_mcycle();
    uint64_t dummy_stall_cycles;
    asm volatile("csrr %0, mhpmcounter3" : "=r"(dummy_stall_cycles) :: "memory");

    LOG("[hostd] dummy perf: total_cycles=%lu pipeline_stall_cycles=%lu\n\r",
           (unsigned long)(dummy_cycle_end - dummy_cycle_start),
           (unsigned long)dummy_stall_cycles);
    LOG("[hostd] dummy perf: stall_ratio=%.2f%%\n\r",
           (double)dummy_stall_cycles / (dummy_cycle_end - dummy_cycle_start) * 100);

    fence();
    *reg32(&__base_regs, CHESHIRE_SCRATCH_10_REG_OFFSET) = SYNC_DUMMY3_DONE;
    fence();

    LOG("[hostd] snooper_stress_test: done\n\r");
    return 0;
}
