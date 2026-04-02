# Copyright 2026 ETH Zurich, University of Bologna and Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luigi Ghionda - Fondazione Chips-IT

.PHONY: all clean

# Make fragment for security island bare-metal tests.

# List all the directories in the 'tests' folder
CAR_SECD_SW := $(CAR_SW_DIR)/tests/bare-metal/secd
SECD_SW_DIR := $(SECD_ROOT)/sw/tests
SECD_PULPD_SW_DIR := $(SECD_SW_DIR)/regression_tests/opentitan-cluster
SECD_PULPD_TEST_DIRS := $(filter-out %/deeploy,$(wildcard $(SECD_SW_DIR)/regression_tests/opentitan-cluster/*))

# Generate the list of build targets based on the directories
SECD_PULPD_BUILD_TARGETS := $(addsuffix /build,$(SECD_PULPD_TEST_DIRS))

# We have a target per test. The target (1) compiles the binary and (2) generates the needed stimuli
# file format, if any is required.
$(SECD_PULPD_SW_DIR)/%/build: $(SECD_ROOT)
	# Compile
	$(MAKE) -C $(SECD_PULPD_SW_DIR)/$* all io=host_uart
	$(MAKE) -C $(SECD_PULPD_SW_DIR)/$* dis > $(CAR_SECD_SW)/$*.dump
	cp $@/test/test $(CAR_SECD_SW)/$*.elf
	@echo $(SECD_PULPD_SW_DIR)

CLUSTER_OFFLOAD = $(SECD_SW_DIR)/cluster_offload/cluster_offload.elf

$(SECD_SW_DIR)/cluster_offload/cluster_offload.elf:
	$(MAKE) -C $(patsubst %/,%,$(dir $@)) clean all
	cp $(patsubst %/,%,$(dir $@))/cluster_offload.elf $(CAR_SECD_SW)/
	cp $(patsubst %/,%,$(dir $@))/cluster_offload.dis $(CAR_SECD_SW)/

# Global targets
secd-sw-all: $(SECD_PULPD_BUILD_TARGETS) $(CLUSTER_OFFLOAD)

secd-sw-clean:
	# Clean all the directories in 'tests'
	. $(CAR_ROOT)/env/secd-env.sh; \
	$(foreach dir, $(SECD_PULPD_TEST_DIRS), $(MAKE) -C $(dir) clean;)
