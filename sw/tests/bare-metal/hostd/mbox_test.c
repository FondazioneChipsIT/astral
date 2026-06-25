// Copyright 2023 ETH Zurich, University of Bologna and and Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Maicol Ciani <maicol.ciani@unibo.it>
//

#ifndef VERBOSE
#define VERBOSE 1
#endif
#define LOG(fmt, ...) do { if (VERBOSE) printf(fmt, ##__VA_ARGS__); } while (0)

#include "car_memory_map.h"
#include "io.h"
#include "regs/cheshire.h"
#include "dif/rv_plic.h" // Cheshire/CVA6 PLIC driver
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include "car_util.h"
#include "printf.h"

#define IRQID CHS_PLIC_IRQ_SECD_MBOX_HOSTD // security island -> hostd mailbox IRQ
// Synchronization values (ibex -> CVA6 via CHESHIRE_SCRATCH_4)
#define SYNC_IBEX_READY  0xa5a5a5a5  // ibex interrupt setup done, CVA6 may send mbox message

int main(int argc, char const *argv[]) {

    // Init the HW (this also includes UART)
    car_init_start();

    int mbox_msg;
    unsigned global_irq_en   = 0x00001808;
    unsigned external_irq_en = 0x00000800;
    LOG("Hello cheshire\n\r");

    asm volatile("csrw  mstatus, %0\n" : : "r"(global_irq_en  ));     // Set global interrupt enable in CVA6 csr
    asm volatile("csrw  mie, %0\n"     : : "r"(external_irq_en));     // Set external interrupt enable in CVA6 csr

    // PLIC setup via Cheshire PLIC driver
    chs_plic_irq_set_priority(&__base_plic, IRQID, 1u);
    chs_plic_irq_set_enabled (&__base_plic, IRQID, 0u, 1);
    // Wait for ibex to finish setting up its interrupt handler before sending
    while (*reg32(&__base_regs, CHESHIRE_SCRATCH_4_REG_OFFSET) != (int)SYNC_IBEX_READY)
        ;

    writew(0xBAADC0DE, MBOX_CAR_LETTER0(0x1));
    mbox_msg = readw(MBOX_CAR_LETTER0(1));
    if (mbox_msg == 0xBAADC0DE) {
      writew(0x00000001, MBOX_CAR_INT_SND_SET(0x1)); // ring doorbell if mailbox is accessible
      writew(0x00000001, MBOX_CAR_INT_SND_EN(0x1));
    }
    wfi();
    return 0;
}

void trap_vector (void){
   chs_plic_irq_id_t claimed_irq;
   LOG("[mbox_test] trap_vector: interrupt fired\n\r");
   chs_plic_irq_claim(&__base_plic, 0u, &claimed_irq);
   if (claimed_irq != IRQID) {
      LOG("[mbox_test] FAILED: unexpected IRQ %u (expected %u)\n\r",
             (unsigned)claimed_irq, (unsigned)IRQID);
      chs_plic_irq_complete(&__base_plic, 0u, claimed_irq);
      return;
   }
   LOG("[mbox_test] claimed IRQ %u (expected %u) OK\n\r",
       (unsigned)claimed_irq, (unsigned)IRQID);

   writew(0x0, MBOX_CAR_INT_SND_SET(0x7));
   writew(0x0, MBOX_CAR_INT_SND_EN(0x7));
   writew(0x1, MBOX_CAR_INT_SND_CLR(0x7));
   chs_plic_irq_complete(&__base_plic, 0u,  claimed_irq);
   LOG("[mbox_test] PASSED\n\r");
   return;
}