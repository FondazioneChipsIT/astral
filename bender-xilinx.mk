# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Author: Cyril Koenig <cykoenig@iis.ee.ethz.ch>

# bender targets
xilinx_targs_common += -t fpga -t xilinx
# bender defines
xilinx_defs_common += -D PULP_FPGA_EMUL

# track the git hash
GIT_HASH := $(shell git rev-parse --short=8 HEAD)
xilinx_defs_common += -D GIT_HASH=32\'h$(GIT_HASH)

# Conditionally add GEN_{island} to bender define
define check_enable_island
ifeq ($($(1)),1)
xilinx_defs_common += -D$(1)=1
endif
endef

$(eval $(call check_enable_island,GEN_NO_HYPERBUS))
$(eval $(call check_enable_island,GEN_EXT_JTAG))
$(eval $(call check_enable_island,GEN_AUX_JTAG))

ifeq ($(GEN_EXT_JTAG),0)
xilinx_targs_common += -t bscane
endif

ifneq ($(GEN_NO_HYPERBUS),1)
xilinx_targs_common += -t hyperbus_dline
endif

# note : bender targets are later modified in xilinx.mk
