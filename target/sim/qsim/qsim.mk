# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#

## @section Carfield platform simulation

#############
# Questasim #
#############

## @section Questasim simulator target
QUESTA_FLAGS += -suppress 3999 -suppress 12088 +UVM_NO_RELNOTES

ifdef DEBUG
	QOPT_FLAGS := -debug,cell +designfile $(QUESTA_FLAGS)
ifeq ($(DEBUG),live)
	QSIM_FLAGS := -qwavedb=+signal+memory $(QUESTA_FLAGS)
	RUN_AND_EXIT := run -all
else
	QSIM_FLAGS := -qwavedb=+signal+memory $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit;
	POST_SIM := qsim $(CAR_TGT_DIR)/sim/vsim/qwave.db $(CAR_TGT_DIR)/sim/vsim/design.bin
endif
else
	QOPT_FLAGS := $(QUESTA_FLAGS)
	QSIM_FLAGS := $(QUESTA_FLAGS) -c
	RUN_AND_EXIT := run -all; exit;
endif

.PHONY: $(CAR_QSIM_DIR)/compile.carfield_soc.tcl
$(CAR_QSIM_DIR)/compile.carfield_soc.tcl:
	mkdir -p $(CAR_QSIM_DIR)
	$(BENDER) script vsim $(common_targs) $(sim_targs) $(sim_defs) $(common_defs) $(safed_defs) --vlog-arg="$(RUNTIME_DEFINES)" --compilation-mode separate > $@
	echo 'vlog "$(CHS_ROOT)/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@
  # Need to add a wrapper to qopt to show log end exit gracefully
	echo 'if {[catch { echo [qopt $(QOPT_FLAGS) $(TBENCH) -o $(TBENCH)_opt] } message]} {echo $$message; return 1}' >> $@
	echo 'return 0' >> $@

CAR_QSIM_ALL += $(CAR_SIM_ALL)
CAR_QSIM_ALL += $(CAR_QSIM_DIR)/compile.carfield_soc.tcl

## Generate all required VIPs (SPI flash, I2c EEPROm, HyperRAM, etc) and compilation scripts for Questasim
.PHONY: car-qsim-sim-init
car-qsim-sim-init: $(CAR_QSIM_ALL)

## Compile Carfield HW using Questasim. Run `make car-sim-init` from the root directory to prepare
## the simulation environment before running this command.
.PHONY: car-qsim-sim-build
car-qsim-sim-build: $(CAR_QSIM_DIR)/compile.carfield_soc.tcl
	cd $(CAR_QSIM_DIR); $(QUESTA) qsim -c -do "quit -code [source $<]"

.PHONY: car-qsim-sim-clean
## Remove all Questasim simulation build artifacts
car-qsim-sim-clean:
	rm -rf $(CAR_QSIM_DIR)/uart $(CAR_QSIM_DIR)/FETCH* $(CAR_QSIM_DIR)/logs $(CAR_QSIM_DIR)/*.ini $(CAR_QSIM_DIR)/trace* $(CAR_QSIM_DIR)/*.wlf $(CAR_QSIM_DIR)/transcript $(CAR_QSIM_DIR)/work $(CAR_QSIM_DIR)/*lib $(CAR_QSIM_DIR)/*Lib $(CAR_QSIM_DIR)/*.vstf $(CAR_QSIM_DIR)/*.log $(CAR_QSIM_DIR)/*.txt $(CAR_TGT_DIR)/sim/qsim/qwave.db $(CAR_TGT_DIR)/sim/qsim/design.bin

.PHONY: car-qsim-sim-run
## Run simulation of the carfield RTL.
## @param HYP_USER_PRELOAD=0 Whether to preload code in the HyperRAM model.
## @param CHS_BOOTMODE=0 The bootmode of host domain <0 JTAG|1 Serial Link>
## @param CHS_PRELMODE=1 If 1, use the serial link for host domain memory preloading, otherwise JTAG.
## @param CHS_BINARY=<path_to_elf> ELF to be executed on host domain
## @param CHS_IMAGE=<path_to_memh> Raw image (ROMs) or GPT disk image to be executed on Cheshire (when CHS_BOOTMODE >= 1)
## @param SECD_BINARY=<path_to_elf> ELF to be executed on the host domain
## @param SECD_IMAGE=<path_to_memh> Raw image (ROMs) or GPT disk image to be executed on Cheshire (when CHS_BOOTMODE >= 1)
## @param SECD_BOOTMODE=0 The bootmode of secure domain <0 JTAG|1 Serial Link>
## @param SECD_PULP_CL_BIN=<path_to_elf> ELF to be executed on the pulp cluster inside the Security Island
## @param SAFED_BINARY=<path_to_elf> ELF to be executed on safe domain
## @param SAFED_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param PULPD_BINARY=<path_to_elf> ELF to be executed on integer PMCA
## @param PULPD_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param SPATZD_BINARY==<path_to_elf> ELF to be executed on integer PMCA
## @param SPATZD_BOOTMODE=0 The bootmode of safe domain <0 JTAG|1 Serial Link>
## @param TESTBENCH=tb_astral_opt The optimised toplevel testbench to use. Defaults to 'tb_astral_opt'.
## @param VSIM_FLAGS The flags for the vsim invocation

pargs+=+HYP_USER_PRELOAD=$(HYP_USER_PRELOAD)
pargs+=+BYPASS_PLL=$(BYPASS_PLL)
pargs+=+SECURE_BOOT=$(SECURE_BOOT)
pargs+=+CHS_BOOTMODE=$(CHS_BOOTMODE)
pargs+=+CHS_PRELMODE=$(CHS_PRELMODE)
pargs+=+CHS_BINARY=$(CHS_BINARY_ABS)
pargs+=+CHS_IMAGE=$(CHS_IMAGE_ABS)
pargs+=+SECD_BINARY=$(SECD_BINARY_ABS)
pargs+=+SECD_BOOTMODE=$(SECD_BOOTMODE)
pargs+=+SECD_IMAGE=$(SECD_IMAGE_ABS)
pargs+=+SECD_PULP_CL_BIN=$(SECD_PULP_CL_BIN_ABS)
pargs+=+SAFED_BINARY=$(SAFED_BINARY_ABS)
pargs+=+SAFED_BOOTMODE=$(SAFED_BOOTMODE)
pargs+=+PULPD_BINARY=$(PULPD_BINARY_ABS)
pargs+=+PULPD_BOOTMODE=$(PULPD_BOOTMODE)
pargs+=+SPATZD_BINARY=$(SPATZD_BINARY_ABS)
pargs+=+SPATZD_BOOTMODE=$(SPATZD_BOOTMODE)

ifneq ($(CAR_PHY_SEL),)
  pargs+=+CAR_PHY_SEL=$(CAR_PHY_SEL)
endif

car-qsim-sim-run:
ifneq ($(CHS_BINARY),)
	$(eval CHS_BINARY_ABS := $(realpath $(CHS_BINARY)))
endif
ifneq ($(CHS_IMAGE),)
	$(eval CHS_IMAGE_ABS := $(realpath $(CHS_IMAGE)))
endif
ifneq ($(SECD_BINARY),)
	$(eval SECD_BINARY_ABS := $(realpath $(SECD_BINARY)))
endif
ifneq ($(SECD_PULP_CL_BIN),)
	$(eval SECD_PULP_CL_BIN_ABS := $(realpath $(SECD_PULP_CL_BIN)))
endif
ifneq ($(SECD_IMAGE),)
	$(eval SECD_IMAGE_ABS := $(realpath $(SECD_IMAGE)))
endif
ifneq ($(SAFED_BINARY),)
	$(eval SAFED_BINARY_ABS := $(realpath $(SAFED_BINARY)))
endif
ifneq ($(PULPD_BINARY),)
	$(eval PULPD_BINARY_ABS := $(realpath $(PULPD_BINARY)))
endif
ifneq ($(SPATZD_BINARY),)
	$(eval SPATZD_BINARY_ABS := $(realpath $(SPATZD_BINARY)))
endif
	cd $(CAR_QSIM_DIR); \
  qsim $(pargs) +designfile +permissive $(QSIM_FLAGS) +notimingchecks +nospecify +init_mem_data=0 -t 1ps $(TBENCH)_opt -do "$(RUN_AND_EXIT)"; \
	$(POST_SIM)

## Generate all required VIPs and compilation scripts for all supported simulators
car-sim-init: car-qsim-sim-init
