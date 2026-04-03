// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "regs/snooper_regs.h"
#include "printf.h"
#include "car_util.h"





int main(void) {
    extern char dummy1_code_start, dummy1_code_end, dummy2_code_start, dummy2_code_end;
    car_init_start();
    // enable watermark interrupt for security island
    car_irq_router_enable(58, IRQ_ROUTER_TARGET_SECURITY_ISLAND);
    // enable trigger interrupt for security island
    car_irq_router_enable(59, IRQ_ROUTER_TARGET_SECURITY_ISLAND);

    fence();

    printf("hello cheshire\n\r");

    uint32_t instructions[] = {0xf3000017, 0xf3000017, 
                                0x00100013, 0xda678013,
                                0xf3000017, 0x00200013, 
                                0xd9a78013, 0xf3000017, 
                                0x00300013, 0xd8e78013,
                                0xf3000017, 0xf3000017, 
                                0xd8270013, 0xf3000017,  
                                0xd7278013, 0xf3000017, 
                                0xd6678013};


    //---------------------------------------------------------------------------------------------//
    //--------------------------------------INSTR MODE TEST----------------------------------------//
    //---------------------------------------------------------------------------------------------//

    // Publish dummy code addresses so the security island can read them at runtime
    *reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) = (uintptr_t)&dummy1_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_5_REG_OFFSET) = (uintptr_t)&dummy1_code_end;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_6_REG_OFFSET) = (uintptr_t)&dummy2_code_start;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_7_REG_OFFSET) = (uintptr_t)&dummy2_code_end;
    // Sentinel: signal ibex that addresses are valid
    *reg32(&__base_regs, CHESHIRE_SCRATCH_8_REG_OFFSET) = 0xdeadbeef;
    fence();

    // Enable security island
    car_enable_domain(CAR_SECURITY_RST);

    // Wait for ibex to read the addresses and configure the snooper
    for (volatile uint32_t d = 0; d < 2000000; d++);

    

    asm volatile (
        "dummy1_code_start: \n\r"
        "auipc	zero,0xf3000 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,1 \n\r"
        "addi	zero,a5,-602 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,2 \n\r"
        "addi	zero,a5,-614 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "li	zero,3 \n\r"
        "addi	zero,a5,-626 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "addi	zero,a4,-638 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "addi	zero,a5,-654 \n\r"
        "auipc	zero,0xf3000 \n\r"
        "dummy1_code_end: \n\r"
        "addi	zero,a5,-666 \n\r"
    );

    
    // Wait for ibex to reconfigure the snooper for addr-mode test
    for (volatile uint32_t d = 0; d < 2000000; d++);

   
    asm volatile ("dummy2_code_start:");

    *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_1_REG_OFFSET) = 1;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_2_REG_OFFSET) = 2;
    *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET) = 3;
    for (int i=0; i<(int) *reg32(&__base_regs, CHESHIRE_SCRATCH_3_REG_OFFSET); i++) {
        *reg32(&__base_regs, CHESHIRE_SCRATCH_0_REG_OFFSET) = 0;  
    }

    asm volatile ("dummy2_code_end:");


    
    return 0;
}
