# Copyright 2026 ETH Zurich, University of Bologna and Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luigi Ghionda - Fondazione Chips-IT

.PHONY: all clean

# Select build tool for snooper_test: 'make' (default) or 'bazel'
BUILD_TOOL ?= make

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

SNOOPER_TEST = $(SECD_ROOT)/sw/tests/scarv/snooper_test/snooper_test.elf
$(SECD_ROOT)/sw/tests/scarv/snooper_test/snooper_test.elf:
ifeq ($(BUILD_TOOL),bazel)
	$(MAKE) -C $(SECD_ROOT) compile-bazel-sram test_name=snooper_test target=scarv
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_test/bazel-out/snooper_test.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_test/bazel-out/snooper_test.dis $(CAR_SECD_SW)/
else
	$(MAKE) -C $(SECD_ROOT)/sw/tests/scarv/snooper_test clean all io=host_uart NO_STANDALONE=1
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_test/snooper_test.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_test/snooper_test.dis $(CAR_SECD_SW)/
endif

SNOOPER_STRESS_TEST = $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/snooper_stress_test.elf
$(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/snooper_stress_test.elf:
ifeq ($(BUILD_TOOL),bazel)
	$(MAKE) -C $(SECD_ROOT) compile-bazel-sram test_name=snooper_stress_test target=scarv
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/bazel-out/snooper_stress_test.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/bazel-out/snooper_stress_test.dis $(CAR_SECD_SW)/
else
	$(MAKE) -C $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test clean all io=host_uart NO_STANDALONE=1
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/snooper_stress_test.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/snooper_stress_test/snooper_stress_test.dis $(CAR_SECD_SW)/
endif

MBOX_TEST_HOST = $(SECD_ROOT)/sw/tests/scarv/mbox_test_host/mbox_test_host.elf
$(SECD_ROOT)/sw/tests/scarv/mbox_test_host/mbox_test_host.elf:
ifeq ($(BUILD_TOOL),bazel)
	$(MAKE) -C $(SECD_ROOT) compile-bazel-sram test_name=mbox_test_host target=scarv
	cp -f $(SECD_ROOT)/sw/tests/scarv/mbox_test_host/bazel-out/mbox_test_host.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/mbox_test_host/bazel-out/mbox_test_host.dis $(CAR_SECD_SW)/
else
	$(MAKE) -C $(SECD_ROOT)/sw/tests/scarv/mbox_test_host clean all io=host_uart NO_STANDALONE=1
	cp -f $(SECD_ROOT)/sw/tests/scarv/mbox_test_host/mbox_test_host.elf $(CAR_SECD_SW)/
	cp -f $(SECD_ROOT)/sw/tests/scarv/mbox_test_host/mbox_test_host.dis $(CAR_SECD_SW)/
endif

# Global targets
secd-sw-all: $(SECD_PULPD_BUILD_TARGETS) $(SNOOPER_TEST) $(SNOOPER_STRESS_TEST) $(MBOX_TEST_HOST)
snoop_test: $(SNOOPER_TEST)
snoop_stress_test: $(SNOOPER_STRESS_TEST)
mbox_test_host: $(MBOX_TEST_HOST)

secd-sw-clean:
	# Clean all the directories in 'tests'
	. $(CAR_ROOT)/env/secd-env.sh; \
	$(foreach dir, $(SECD_PULPD_TEST_DIRS), $(MAKE) -C $(dir) clean;)
