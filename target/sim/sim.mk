# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

## @section Carfield platform simulation

QUESTA ?= questa-2023.4
TBENCH ?= tb_astral

## Get HyperRAM verification IP (VIP) for simulation
$(CAR_TGT_DIR)/sim/src/hyp_vip:
	rm -rf $@
	git clone git@gitlab.chips.it:digitalresearchline/vips/hyp_vip.git $@

CAR_SIM_ALL += $(CHS_ROOT)/target/sim/models/s25fs512s.v
CAR_SIM_ALL += $(CHS_ROOT)/target/sim/models/24FC1025.v
CAR_SIM_ALL += $(CAR_TGT_DIR)/sim/src/hyp_vip

# Defines for hyperram model preload at time 0
HYP_USER_PRELOAD      ?= 0
HYP0_PRELOAD_MEM_FILE ?= ""
HYP1_PRELOAD_MEM_FILE ?= ""

RUNTIME_DEFINES := +define+HYP_USER_PRELOAD="$(HYP_USER_PRELOAD)"
RUNTIME_DEFINES += +define+HYP0_PRELOAD_MEM_FILE=\"$(HYP0_PRELOAD_MEM_FILE)\"
RUNTIME_DEFINES += +define+HYP1_PRELOAD_MEM_FILE=\"$(HYP1_PRELOAD_MEM_FILE)\"
RUNTIME_DEFINES += -timescale \"1 ns / 1 ps\"

include $(CAR_QSIM_DIR)/qsim.mk
include $(CAR_VSIM_DIR)/vsim.mk

## @section Global targets
.PHONY: car-sim-init

## Generate all required VIPs and compilation scripts for all supported simulators
car-sim-init: car-vsim-sim-init car-qsim-sim-init

