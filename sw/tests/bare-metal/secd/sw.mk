# Copyright 2026 ETH Zurich, University of Bologna and Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Luigi Ghionda - Fondazione Chips-IT

.PHONY: all clean

# Make fragment for security island bare-metal tests.

# List all the directories in the 'tests' folder
CAR_SECD_SW := $(CAR_SW_DIR)/tests/bare-metal/secd
CAR_SECD_PULPD_SW := $(CAR_SW_DIR)/tests/bare-metal/secd/pulpd
SECD_SW_DIR := $(SECD_ROOT)/sw/tests
SECD_SCARV_SW_DIR := $(SECD_ROOT)/sw/tests/scarv
SECD_PULPD_SW_DIR := $(SECD_SW_DIR)/regression_tests/opentitan-cluster

SCARV_TESTS := \
	cluster_offload \
	idma_test \
	mbox_host \
	mbox_wu_cluster \
	snooper_stress_test 

PULP_TEST_DIRS    := $(filter-out %deeploy/ %neureka/, $(wildcard $(SECD_PULPD_SW_DIR)/*/))
NEUREKA_TEST_DIRS := $(wildcard $(SECD_PULPD_SW_DIR)/neureka/*/)
DEEPLOY_TEST_DIRS := $(wildcard $(SECD_PULPD_SW_DIR)/deeploy/*/*/)

ALL_PULPD_TEST_DIRS := $(PULP_TEST_DIRS) $(NEUREKA_TEST_DIRS) $(DEEPLOY_TEST_DIRS)

.PHONY: secd-pulpd-sw-build secd-pulpd-sw-clean ot-sw-build ot-sw-clean secd-sw-all secd-sw-clean

secd-pulpd-sw-build:
	mkdir -p $(CAR_SECD_PULPD_SW)
	$(foreach test, $(PULP_TEST_DIRS),    $(MAKE) -C $(test) all io=host_uart;)
	$(foreach test, $(NEUREKA_TEST_DIRS), $(MAKE) -C $(test) all MODE=1 io=host_uart;)
	$(foreach test, $(DEEPLOY_TEST_DIRS), $(MAKE) -C $(test) pulp_nn all io=host_uart;)
	$(foreach test, $(ALL_PULPD_TEST_DIRS), cp $(test)/build/test/test $(CAR_SECD_PULPD_SW)/$(notdir $(test:%/=%)).elf;)

secd-pulpd-sw-clean:
	$(foreach test, $(ALL_PULPD_TEST_DIRS), $(MAKE) -C $(test) clean;)

ot-sw-build:
	$(foreach test, $(SCARV_TESTS), CHS_ROOT=$(CHS_ROOT) $(MAKE) -C $(SECD_ROOT) compile-bazel-sram target=scarv test_name=$(test) defines=NO_STANDALONE=1;)
	$(foreach test, $(SCARV_TESTS), install -m 755 $(SECD_SCARV_SW_DIR)/$(test)/bazel-out/$(test).elf $(CAR_SECD_SW)/$(test).elf;)

ot-sw-clean:
	$(foreach test, $(SCARV_TESTS), $(MAKE) -C $(SECD_ROOT) clean-sram target=scarv test_name=$(test);)

# Global targets
secd-sw-all: secd-pulpd-sw-build ot-sw-build

secd-sw-clean:
	# Clean all the directories in 'tests'
	rm -f $(CAR_SECD_SW)/*.elf  $(CAR_SECD_PULPD_SW)/*.elf
	. $(CAR_ROOT)/env/secd-env.sh; \
	$(MAKE) secd-pulpd-sw-clean ot-sw-clean
