// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
//

#include "car_memory_map.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "io.h"
#include "car_util.h"
#include "params.h"
#include "regs/cheshire.h"
#include "util.h"
#include "printf.h"

/* ============================================================
 * Test configuration
 * ============================================================ */

/* Address increment between consecutive test locations */
#define INCREASE_ADDR        0x100000
// alternative values (debug / long tests)
// #define INCREASE_ADDR     0x2000
// #define INCREASE_ADDR     0x1000
// #define INCREASE_ADDR     0x400
// #define INCREASE_ADDR     0x100   // ~4h32m test

/* Seed configuration */
#define DEFAULT_SEED         0xCACA5A5ADEADBEEF

/* LFSR feedback polynomial (64-bit) */
#define FEEDBACK             0x6C0000397F000032

/* ============================================================
 * Hyperbus register map
 * ============================================================ */

#define HYPERBUS_REG_BASE            CAR_HYPERBUS_CFG_BASE_ADDR

#define HYPERBUS_PHY_IN_USE_OFFSET   0x20
#define HYPERBUS_WHICH_PHY_OFFSET    0x24

#define HYPERBUS_CS0_BASE_OFFSET     0x38
#define HYPERBUS_CS0_END_OFFSET      0x3C
#define HYPERBUS_CS1_BASE_OFFSET     0x40
#define HYPERBUS_CS1_END_OFFSET      0x44

/* ============================================================
 * HyperRAM address map
 * ============================================================ */

#define CAR_HYPERRAM_BASE_ADDR       0x80000000
#define CAR_HYPERRAM_END_ADDR        0x82000000

#define CAR_HYPERRAM_0_BASE_ADDR     CAR_HYPERRAM_BASE_ADDR
#define CAR_HYPERRAM_0_END_ADDR      0x81000000

#define CAR_HYPERRAM_1_BASE_ADDR     CAR_HYPERRAM_0_END_ADDR
#define CAR_HYPERRAM_1_END_ADDR      CAR_HYPERRAM_END_ADDR



uint64_t get_runtime_seed(void)
{
#ifdef FORCE_SEED
    // Force seed at compile time
    uint64_t s = (uint64_t)FORCE_SEED;

    // xorshift preventing naive patterns
    s ^= (s << 13);
    s ^= (s >> 7);
    s ^= (s << 17);

    // Create 64-bit seed
    uint64_t result = (s << 32) | (s ^ 0xDEADBEEF);


    return result;
#else
    // Default seed
    uint64_t result = (uint64_t)DEFAULT_SEED;
    return result;
#endif
}

uint64_t lfsr_iter_bit(uint64_t lfsr) {
    return (lfsr & 1) ? ((lfsr >> 1) ^ (uint64_t)FEEDBACK) : (lfsr >> 1);
}

uint64_t lfsr_iter_byte(uint64_t lfsr) {
    for (int i = 0; i < 8; ++i) {
        lfsr = lfsr_iter_bit(lfsr);
    }
    return lfsr;
}

uint64_t lfsr_iter_word(uint64_t lfsr) {
    for (int i = 0; i < 4; ++i) {
        lfsr = lfsr_iter_byte(lfsr);
    }
    return lfsr;
}

uint64_t lfsr_64bits(uint64_t lfsr) {
    for (int i = 0; i < 8; ++i) {
        lfsr = lfsr_iter_byte(lfsr);
    }
    return lfsr;
}

int probe_range_lfsr_wrwr(volatile uintptr_t from, volatile uintptr_t to)
{
    // Preiminari checks
    if (to <= from)
        return 2;

    if (INCREASE_ADDR <= 0)
        return 2;

    uintptr_t addr = from;
    const uintptr_t incr = INCREASE_ADDR;
    uint64_t lfsr = get_runtime_seed();

    int i = 0;

    while (addr < to) {
        //  Compute and store next LFSR value
        lfsr = lfsr_64bits(lfsr);
        writed(lfsr, addr);
        fence();

        uint64_t r = readd(addr);
        if (r != lfsr) {
            printf("[ERROR] mismatch at i=%d addr=0x%lx wrote=0x%016llx read=0x%016llx\n", i, (unsigned long)addr, (unsigned long long)lfsr, (unsigned long long)r);
            return 1;
        }

        addr += incr;
        ++i;
    }

    return 0;
}

int probe_range_lfsr_wwrr(volatile uintptr_t from, volatile uintptr_t to)
{
    if (to <= from)
        return 2;

    if (INCREASE_ADDR <= 0)
        return 2;

    uintptr_t addr = from;
    const uintptr_t incr = INCREASE_ADDR;

    uint64_t seed = get_runtime_seed();
    uint64_t lfsr = seed;

    /* ---------------- WRITE PHASE ---------------- */
    int i = 0;

    while (addr < to) {

        lfsr = lfsr_64bits(lfsr);
        writed(lfsr, addr);

        addr += incr;
        ++i;
    }

    fence();

    /* ---------------- READ PHASE ---------------- */
    addr = from;
    lfsr = seed;
    int j = 0;

    while (addr < to) {

        lfsr = lfsr_64bits(lfsr);

        uint64_t r = readd(addr);

        if (r != lfsr) {
            printf("[WWRR][ERROR] i=%d j=%d addr=0x%lx exp=0x%016lx read=0x%016lx\n", i, j, addr, lfsr, r);
            return 1;
        }

        addr += incr;
        ++j;
    }

    return 0;
}


int configure_hyperbus_cs(bool phy_mode, bool which_phy)
{
    uintptr_t base = HYPERBUS_REG_BASE;

    uint32_t cs0_base;
    uint32_t cs0_end;
    uint32_t cs1_base;
    uint32_t cs1_end;

    if (phy_mode == 1) {
        // PHY_MODE == 1 => dual-PHY mode
        cs0_base = 0x80000000;
        cs0_end  = 0x81000000;
        cs1_base = cs0_end;
        cs1_end  = 0x82000000;

    }else if (phy_mode == 0) {

        if (which_phy == 0) {
            // PHY 0 -> CS0: 0x8000_0000 - 0x807F_FFFF
            cs0_base = 0x80000000;
            cs0_end  = 0x80800000;
            cs1_base = cs0_end;
            cs1_end  = 0x81000000;
        }
        else if (which_phy == 1) {
            // PHY 1 -> CS0: 0x8100_0000 - 0x817F_FFFF
            cs0_base = 0x81000000;
            cs0_end  = 0x81800000;
            cs1_base = cs0_end;
            cs1_end  = 0x82000000;
        }else{
            printf("[ERROR] Invalid WHICH_PHY: must be 0 or 1 when PHY_MODE == 0\n");
            return 1;
        }

    }else{
        printf("[ERROR] Invalid PHY_MODE: must be 0 or 1\n");
        return 1;
    }

    if (phy_mode == 1) {
        writew(0x1, base + HYPERBUS_PHY_IN_USE_OFFSET);
    }else if (phy_mode == 0) {
        writew(0x0, base + HYPERBUS_PHY_IN_USE_OFFSET);

        if (which_phy == 0) {
            writew(0x0, base + HYPERBUS_WHICH_PHY_OFFSET);
        }else if (which_phy == 1) {
            writew(0x1, base + HYPERBUS_WHICH_PHY_OFFSET);
        }else{
            printf("[ERROR] Invalid WHICH_PHY: must be 0 or 1 when PHY_MODE == 0\n");
            return 1;
        }  
    }else{
        printf("[ERROR] Invalid PHY_MODE: must be 0 or 1\n");
        return 1;
    }   

    fence();

    #ifdef DEBUG
        uint32_t phy_in_use_reg  = readw(base + HYPERBUS_PHY_IN_USE_OFFSET);
        uint32_t which_phy_reg    = readw(base + HYPERBUS_WHICH_PHY_OFFSET);

        printf("[DBG] phys_in_use @0x%lx = 0x%08x\n", (unsigned long)(base + HYPERBUS_PHY_IN_USE_OFFSET), phy_in_use_reg);
        printf("[DBG] which_phy   @0x%lx = 0x%08x\n", (unsigned long)(base + HYPERBUS_WHICH_PHY_OFFSET), which_phy_reg);
    #endif

    writew(0x0, base + HYPERBUS_CS0_BASE_OFFSET);           // Reset CS0 base to 0 to prevent the "start > end" failed assertion
    writew(cs0_end,  base + HYPERBUS_CS0_END_OFFSET);
    writew(cs0_base, base + HYPERBUS_CS0_BASE_OFFSET);
    

    writew(0x0, base + HYPERBUS_CS1_BASE_OFFSET);           // Reset CS1 base to 0 to prevent the "start > end" failed assertion
    writew(cs1_end,  base + HYPERBUS_CS1_END_OFFSET);
    writew(cs1_base, base + HYPERBUS_CS1_BASE_OFFSET);
    

    fence();

    uint32_t r0 = readw(base + HYPERBUS_CS0_BASE_OFFSET);
    uint32_t r1 = readw(base + HYPERBUS_CS0_END_OFFSET );
    uint32_t r2 = readw(base + HYPERBUS_CS1_BASE_OFFSET);
    uint32_t r3 = readw(base + HYPERBUS_CS1_END_OFFSET );

    #ifdef DEBUG
        printf("[DBG] CS0 BASE @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS0_BASE_OFFSET), cs0_base, r0);
        printf("[DBG] CS0 END  @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS0_END_OFFSET),  cs0_end,  r1);
        printf("[DBG] CS1 BASE @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS1_BASE_OFFSET), cs1_base, r2);
        printf("[DBG] CS1 END  @0x%lx wrote=0x%08x read=0x%08x\n", (unsigned long)(base + HYPERBUS_CS1_END_OFFSET),  cs1_end,  r3);
    #endif

    if (r0 != cs0_base || r1 != cs0_end ||
        r2 != cs1_base || r3 != cs1_end) {
        printf("[ERROR] Mismatch on Hyperbus CS registers\n");
        return 1;
    }

    return 0; /* OK */
}



int main(void) {

    // PULP Island
    car_enable_domain(CAR_PULP_RST);
    car_init_uart();

    uint32_t error = 0;
    uint32_t errors = 0;
    bool PHY_MODE;              // Set to 1 for dual-PHY mode, 0 for single-PHY mode
    bool WHICH_PHY;             // Set to 0 for PHY 0, 1 for PHY 1 (valid only if PHY_MODE == 0)
    uint64_t *test_base;
    uint64_t *test_end;


    #ifndef CAR_PHY_SEL

        // Define HyperRAM address ranges depending on the PHY mode
        PHY_MODE = 1;
        WHICH_PHY = 0; // don't care in dual-PHY mode
        test_base = (uint64_t *)CAR_HYPERRAM_BASE_ADDR;
        test_end  = (uint64_t *)CAR_HYPERRAM_END_ADDR;

        // Configure Hyperbus CS registers
        if (configure_hyperbus_cs(PHY_MODE, WHICH_PHY)) {
            printf("[ERROR] configure_hyperbus_cs failed\n");
            return 2;
        }

        // Probe HyperRAM ranges
        error = probe_range_lfsr_wrwr(test_base, test_end);
        if (error) {
            printf("[ERROR] DUAL-PHY L3: WRWR failed (errors=%u)\n", error);
            errors += error;
        }

        error = probe_range_lfsr_wwrr(test_base, test_end);
        if (error) {
            printf("[ERROR] DUAL-PHY L3: WWRR failed (errors=%u)\n", error);
            errors += error;
        }

        // Define HyperRAM address ranges depending on the PHY mode
        PHY_MODE = 0;
        WHICH_PHY = 0;
        test_base = (uint64_t *)CAR_HYPERRAM_0_BASE_ADDR;
        test_end  = (uint64_t *)CAR_HYPERRAM_0_END_ADDR;

        // Configure Hyperbus CS registers
        if (configure_hyperbus_cs(PHY_MODE, WHICH_PHY)) {
            printf("[ERROR] configure_hyperbus_cs failed\n");
            return 2;
        }
    
        // Probe HyperRAM ranges
        error = probe_range_lfsr_wrwr(test_base, test_end);
        if (error) {
            printf("[ERROR] SINGLE-PHY-0 L3: WRWR failed (errors=%u)\n", error);
            errors += error;
        }
    
        error = probe_range_lfsr_wwrr(test_base, test_end);
        if (error) {
            printf("[ERROR] SINGLE-PHY-0 L3: WWRR failed (errors=%u)\n", error);
            errors += error;
        }

        // Define HyperRAM address ranges depending on the PHY mode
        WHICH_PHY = 1;
        test_base = (uint64_t *)CAR_HYPERRAM_1_BASE_ADDR;
        test_end  = (uint64_t *)CAR_HYPERRAM_1_END_ADDR;

        if (configure_hyperbus_cs(PHY_MODE, WHICH_PHY)) {
            printf("[ERROR] configure_hyperbus_cs failed\n");
            return 2;
        }

        // Probe HyperRAM ranges
        error = probe_range_lfsr_wrwr(test_base, test_end);
        if (error) {
            printf("[ERROR] SINGLE-PHY-1 L3: WRWR failed (errors=%u)\n", error);
            errors += error;
        }
    
        error = probe_range_lfsr_wwrr(test_base, test_end);
        if (error) {
            printf("[ERROR] SINGLE-PHY-1 L3: WWRR failed (errors=%u)\n", error);
            errors += error;
        }

    #else
        #if CAR_PHY_SEL == 0
            // Define HyperRAM address ranges depending on the PHY mode
            PHY_MODE = 0;
            WHICH_PHY = 0;
            test_base = (uint64_t *)CAR_HYPERRAM_0_BASE_ADDR;
            test_end  = (uint64_t *)CAR_HYPERRAM_0_END_ADDR;

            // Configure Hyperbus CS registers
            if (configure_hyperbus_cs(PHY_MODE, WHICH_PHY)) {
                printf("[ERROR] configure_hyperbus_cs failed\n");
                return 2;
            }
        
            // Probe HyperRAM ranges
            error = probe_range_lfsr_wrwr(test_base, test_end);
            if (error) {
                printf("[ERROR] SINGLE-PHY-0 L3: WRWR failed (errors=%u)\n", error);
                errors += error;
            }
        
            error = probe_range_lfsr_wwrr(test_base, test_end);
            if (error) {
                printf("[ERROR] SINGLE-PHY-0 L3: WWRR failed (errors=%u)\n", error);
                errors += error;
            }
        #elif CAR_PHY_SEL == 1
            // Define HyperRAM address ranges depending on the PHY mode
            PHY_MODE = 0;
            WHICH_PHY = 1;
            test_base = (uint64_t *)CAR_HYPERRAM_1_BASE_ADDR;
            test_end  = (uint64_t *)CAR_HYPERRAM_1_END_ADDR;

            if (configure_hyperbus_cs(PHY_MODE, WHICH_PHY)) {
                printf("[ERROR] configure_hyperbus_cs failed\n");
                return 2;
            }

            // Probe HyperRAM ranges
            error = probe_range_lfsr_wrwr(test_base, test_end);
            if (error) {
                printf("[ERROR] SINGLE-PHY-1 L3: WRWR failed (errors=%u)\n", error);
                errors += error;
            }
        
            error = probe_range_lfsr_wwrr(test_base, test_end);
            if (error) {
                printf("[ERROR] SINGLE-PHY-1 L3: WWRR failed (errors=%u)\n", error);
                errors += error;
            }
        #else
            #error "CAR_PHY_SEL must be 0 or 1"
        #endif
    #endif

    return errors;
}
