# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Common OpenOCD script for Cheshire.

set _CHIPNAME riscv
jtag newtap $_CHIPNAME cpu -irlen ${irlen}

set _TARGETNAME $_CHIPNAME.cpu
target create $_TARGETNAME riscv -chain-position $_TARGETNAME -coreid 0 -gdb-port ${gdb_port_cheshire}