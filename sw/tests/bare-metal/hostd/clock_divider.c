// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Yvan Tortorella
//
// Silly clock divider configuration test

#include "car_util.h"
#include "regs/soc_ctrl.h"
#include "printf.h"

#define HostDebugClockDivEnReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x100
#define HostDebugClockDivValueReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x11C
#define SecuredDebugClockDivEnReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x114
#define SecuredDebugClockDivValueReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x130
#define PeriphDebugClockDivEnReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x118
#define PeriphDebugClockDivValueReg CAR_SOC_CTRL_BASE_ADDR(car_soc_ctrl) + 0x134

int main(void) {

    car_init_start();

    // Just checking we can configure and disable the host secure, and peripheral clock dividers
    uint32_t divider_value = 20;
    uint32_t divider_disable = 0;

    uint8_t error = 0;

    writew(divider_value, HostDebugClockDivValueReg);
    error += readw(HostDebugClockDivValueReg) != divider_value;

    writew(divider_value+4, SecuredDebugClockDivValueReg);
    error += readw(SecuredDebugClockDivValueReg) != divider_value+4;

    writew(divider_value+8, PeriphDebugClockDivValueReg);
    error += readw(PeriphDebugClockDivValueReg) != divider_value+8;

    for (volatile int i = 0; i < 100; i++);

    writew(divider_disable, HostDebugClockDivEnReg);
    error += readw(HostDebugClockDivEnReg) != divider_disable;

    writew(divider_disable, SecuredDebugClockDivEnReg);
    error += readw(SecuredDebugClockDivEnReg) != divider_disable;

    writew(divider_disable, PeriphDebugClockDivEnReg);
    error += readw(PeriphDebugClockDivEnReg) != divider_disable;

    return error;
}
