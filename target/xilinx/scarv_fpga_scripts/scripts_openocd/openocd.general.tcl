# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# OpenOCD script used to drive N targets over the same jtag chain. 

transport select jtag
telnet_port disabled
tcl_port disabled
reset_config none

#set CoreNames {opentitan cheshire}

set i 0
foreach core $CoreNames {
    set gdb_port_$core [expr {$gdb_port + $i}]
    source [file dirname [info script]]/openocd.$core.tcl
    incr i
}

init
#reset halt

echo "Ready for Remote Connections."
