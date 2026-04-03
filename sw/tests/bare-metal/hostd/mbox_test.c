// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Maicol Ciani <maicol.ciani@unibo.it>
//

#include "car_memory_map.h"
#include "io.h"
#include "regs/cheshire.h"
#include "sw/device/lib/dif/dif_rv_plic.h" // to be changed accoridng to correct hash
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include "car_util.h"
#include "printf.h"

static dif_rv_plic_t plic0;

#define IRQID 64 // index of mbox irq in the irq vector input to the PLIC

int main(int argc, char const *argv[]) {

    // Put SMP Hart to sleep
    // if (hart_id() != 0) wfi();
        // Init the HW (this also includes UART)
    car_init_start();

    int prio = 0x1;
    int a,b,c,d,e;
    bool t;
    unsigned global_irq_en   = 0x00001808;
    unsigned external_irq_en = 0x00000800;
    printf("hello cheshire\n\r");

    // // Uart setup
    // uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    // uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    // uart_init(&__base_uart, reset_freq, 115200);

    asm volatile("csrw  mstatus, %0\n" : : "r"(global_irq_en  ));     // Set global interrupt enable in CVA6 csr
    asm volatile("csrw  mie, %0\n"     : : "r"(external_irq_en));     // Set external interrupt enable in CVA6 csr
    // PLIC setup
    mmio_region_t plic_base_addr = mmio_region_from_addr(&__base_plic);
    t = dif_rv_plic_init(plic_base_addr, &plic0);
    // Set two consecutive interrupts otherwise the SLINK breaks while loading the binary...
    for (int i = 0; i < 2; i++) {
      t = dif_rv_plic_irq_set_priority(&plic0, IRQID+i*5, prio);
      t = dif_rv_plic_irq_set_enabled(&plic0, IRQID+i*5, 0, kDifToggleEnabled);
    }
    writew(0xBAADC0DE, MBOX_CAR_LETTER0(0x1));
    a = readw(MBOX_CAR_LETTER0(1));
    if( a == 0xBAADC0DE ) {
      writew(0x00000001, MBOX_CAR_INT_SND_SET(0x1)); // ring doorbell if mailbox is accessible
      writew(0x00000001, MBOX_CAR_INT_SND_EN(0x1));
    }
    wfi();
    return 0;
}

void trap_vector (void){
   int * claim_irq;
   printf("Interrupt catched");
   dif_rv_plic_irq_claim(&plic0, 0, &claim_irq);
   dif_rv_plic_irq_complete(&plic0, 0, &claim_irq);
   writew(0x0, MBOX_CAR_INT_SND_SET(0x7));
   writew(0x0, MBOX_CAR_INT_SND_EN(0x7));
   writew(0x1, MBOX_CAR_INT_SND_CLR(0x7));
   printf("[mbox_test] PASSED\n\r");
   return;
}
