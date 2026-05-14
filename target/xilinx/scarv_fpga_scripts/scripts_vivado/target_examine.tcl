# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# The scripts prints the available targets on the server.

set host localhost:3121

open_hw_manager -quiet
connect_hw_server -url $host -quiet
set targets [get_hw_targets]

foreach t $targets {
    open_hw_target $t -quiet
    set device [get_hw_devices]
    puts "TARGET $t    DEVICE $device" 
    close_hw_target -quiet
}
exit