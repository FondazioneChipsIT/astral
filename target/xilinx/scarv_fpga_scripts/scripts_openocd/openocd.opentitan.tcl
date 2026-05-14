# Common OpenOCD script for Ibex.

set _CHIPNAME ibex

jtag newtap $_CHIPNAME tap -irlen 5 

set _TARGETNAME $_CHIPNAME.tap
target create $_TARGETNAME.0 riscv -chain-position $_TARGETNAME -gdb-port ${gdb_port_opentitan}
# -rtos hwthread
# Configure work area in on-chip SRAM
$_TARGETNAME.0 configure -work-area-phys 0x80000000 -work-area-size 1000 -work-area-backup 0

# This chip implements system bus access, use it.
# Accessing the memory through the system bus is faster than through
# instruction feeding.
#riscv set_mem_access sysbus

# Expose custom CSRs, cpuctrl and secureseed
# See https://ibex-core.readthedocs.io/en/latest/03_reference/cs_registers.html
riscv expose_csrs 1984=cpuctrl,1985=secureseed
#gdb port 6667
# Be verbose about GDB errors
#gdb port ${gdb_port_opentitan}
gdb report_data_abort enable
gdb report_register_access_error enable

# Always use hardware breakpoints. Since we don't use `flash bank` commands,
# OpenOCD won't provide a memory map to GDB. This means that GDB isn't be aware
# that the code resides in a read-only memory, and therefore should use hardware
# breakpoints. This setting makes OpenOCD convert the software breakpoints into
# hardware ones.
gdb breakpoint_override hard