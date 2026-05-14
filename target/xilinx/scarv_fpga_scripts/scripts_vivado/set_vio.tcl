# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# The scritps controls the output of the VIO core used to reset the design and change the boot mode.

set ProbeFilename [lindex $argv 0]
set command [lindex $argv 1]
set serial [lindex $argv 2]
set probe [lindex $argv 3]
set hwDeviceName [lindex $argv 4]
set port [lindex $argv 5]

if { [string trim $command] eq "jtag"} {
   set output 0
} elseif { [string trim $command] eq "spi"} { 
   set output 2
} else {
   set output 1
}

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

#Refreshing probe files
set_property PROBES.FILE $ProbeFilename [get_hw_devices $hwDevice]
set_property FULL_PROBES.FILE $ProbeFilename [get_hw_devices $hwDevice]
refresh_hw_device [lindex [get_hw_devices $hwDevice] 0]

set cmd [string trim $probe]
set filter "NAME =~ *$cmd*"
puts $filter
puts "[string trim $probe]"

if { [string trim $probe] eq "reset"} {
	set_property OUTPUT_VALUE 1 [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]
	commit_hw_vio [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]
	set_property OUTPUT_VALUE 0 [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]
	commit_hw_vio [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]
} elseif { [string trim $probe] eq "git_hash" } {
	set vio [lindex [get_hw_vios] 0]
	refresh_hw_vio $vio
    set value [get_property INPUT_VALUE [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]]
    puts "****** GIT_HASH ******   0x$value"
} elseif { [string trim $probe] eq "vio_boot_mode" } {
	set_property OUTPUT_VALUE $output [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]
	commit_hw_vio [get_hw_probes [lindex [get_hw_probes -of_objects [get_hw_vios] -filter $filter] 0]]
} else {
	puts "****** NO PROBE FOUND ******"
		foreach probes [get_hw_probes -of_objects [get_hw_vios]] {
		puts "Probe		: $probes"
	}
}


exit
