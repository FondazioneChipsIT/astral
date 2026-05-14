# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# This script can be used when the OCD is driven by the bscan primitive of the Xilinx FPGA

transport select jtag
telnet port disabled
tcl port disabled
reset_config none

set irlen_xcvu9p 24

set _CHIPNAME riscv
jtag newtap $_CHIPNAME cpu -irlen ${irlen_xcvu9p}

set _TARGETNAME $_CHIPNAME.cpu
target create $_TARGETNAME riscv -chain-position $_TARGETNAME -coreid 0

# This takes into account that we are remapping the idcode, dtmcs and dmi registers on the different user registers (3 and 4) of the FPGA.
# More information can be found in https://github.com/pulp-platform/riscv-dbg/blob/master/doc/debug-system.md
riscv set_ir idcode 0x249249
riscv set_ir dtmcs 0x8a4924
riscv set_ir dmi 0x8e4924

gdb report_data_abort enable
gdb report_register_access_error enable

riscv set_command_timeout_sec 120
riscv set_command_timeout_sec 120


# Exit when debugger detaches
$_TARGETNAME configure -event gdb-detach {
    echo "GDB detached; ending debugging session."
    shutdown
}

init
halt
echo "Ready for Remote Connections."
