# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# The scritps programs the FPGA via JTAG.

set Filename [lindex $argv 0]
set ProbeFilename [lindex $argv 1]
set serial [lindex $argv 2]
set hwDeviceName [lindex $argv 3]
set port [lindex $argv 4]

if {$port eq "0" || $port eq ""} {
    set host localhost:3121
} else {
    set host localhost.localdomain:$port
}

open_hw_manager
connect_hw_server -url $host
current_hw_target [get_hw_targets -filter "NAME =~ *$serial"]
open_hw_target

current_hw_device [get_hw_devices $hwDeviceName]
set hwDevice [lindex [get_hw_devices $hwDeviceName] 0]

refresh_hw_device -update_hw_probes false $hwDevice

set_property PROBES.FILE $ProbeFilename [get_hw_devices $hwDevice]
set_property FULL_PROBES.FILE $ProbeFilename [get_hw_devices $hwDevice]
set_property PROGRAM.FILE $Filename [get_hw_devices $hwDevice]
program_hw_devices [get_hw_devices $hwDevice]
refresh_hw_device [lindex [get_hw_devices $hwDevice] 0]

exit

