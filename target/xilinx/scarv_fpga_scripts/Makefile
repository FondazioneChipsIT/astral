# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


# SOFTWARE used by the Makefile
# Vivado is used to program the board via the buit-in jtag chain of the FPGA
# Openocd is used to connect to the debug module inside the design; it also opens a port enabling debug-request from gdb
# GDB is used to debug the riscv cores inside the design; it requires a connection to the port exposed by openocd  
VIVADO	 	?= vivado_lab
OPENOCD		?= openocd
GDB 		?= riscv64-unknown-elf-gdb

# SCRIPTS directories
VIVADO_DIR 		?= scripts_vivado
OPENOCD_DIR 	?= scripts_openocd

# BINARIES directories
ELF_DIR 		?= bit_under_test/elf_secd
BITSTREAM_DIR 	?= bit_under_test/fix
PROBES_DIR 		?= $(BITSTREAM_DIR)

# SCRIPTS
PROGRAM_TCL 	?= $(VIVADO_DIR)/jtag_program.tcl
WRITE_CFG_TCL 	?= $(VIVADO_DIR)/write_cfgmem.tcl
VIO_TCL     	?= $(VIVADO_DIR)/set_vio.tcl
TARGET_EXAMINE  ?= $(VIVADO_DIR)/target_examine.tcl
OPENOCD_SCRIPT 	?= $(OPENOCD_DIR)/openocd.hs2.tcl #$(OPENOCD_DIR)/openocd.olimex.tcl

# BINARIES
PROJECT_NAME	?= $(BITSTREAM_DIR)/carfield_top_xilinx
ELF_FILE_APP 	?= $(ELF_DIR)/test
# LINUX CONFIG 
# PAYLOAD is composed of the opensbi firmware + a payload (the linux kernel in this configuration)
# DTB_FILE is the device tree blob
# DTB_ADDR is the address where the device tree blob is stored.
PAYLOAD       	?= fw_payload.elf
DTB_FILE      	?= linux.dtb
DTB_ADDR      	?= 0x81800000

# Is Hyperram used?
HYPER ?= 0

# This is the serial used by openocd to identify the ftdi connected to the debug module in the design
# The value can be obtained by inspecting the vivado hardware manager or simply launching lsusb -v
USB_SERIAL 	?= 210308BA4E87
OLIMEX_BUS	:= 15ba:002b
HS2_BUS		:= 0403:6014

USE_HW_FILTER ?= 0
PORT ?= 0

GDB_PORT	?= 6667

CORES ?= cheshire

VIO_PROBE 	?= boot_mode
VIO_COMMAND ?= jtag

DEVICE 		?= xcvu9p_0

COMMON_ARGS := -mode batch -nojournal -nolog -quiet

setup_env:
	./setup_env.sh

# This targets prints the available jtag devices, so that the user can select the right one. It is not possible to know "a priori" which one is the usb connected to the desired FPGA.
serial:
	@echo "Scanning Olimex devices..."
	@lsusb -d $(OLIMEX_BUS) -v | grep iSerial | awk '{print $$3}'
	@echo "Scanning HS2 devices..."
	@lsusb -d $(HS2_BUS) -v | grep iSerial | awk '{print $$3}'

# This targets prevents Vivado to take over all the available devices.
hw_server_filtered:
	hw_server -s tcp::$(PORT) -e "set jtag-port-filter $(USB_SERIAL)" &

program: $(if $(filter 1,$(USE_HW_FILTER)),hw_server_filtered)
	@echo "====================== PROGRAMMING FPGA ===================="
	@echo "  BITSTREAM    = $(PROJECT_NAME).bit"
	@echo "  LTX          = $(PROJECT_NAME).ltx"
	@echo "  USB_SERIAL   = $(USB_SERIAL)"
	@echo "  DEVICE       = $(DEVICE)"
	@echo "============================================================"
	$(VIVADO) $(COMMON_ARGS) \
		-source $(PROGRAM_TCL) \
		-tclargs $(PROJECT_NAME).bit $(PROJECT_NAME).ltx $(USB_SERIAL) $(DEVICE) $(PORT)
	@pkill hw_server

set_vio: $(if $(filter 1,$(USE_HW_FILTER)),hw_server_filtered)
	@echo "======================= SETTING VIO ========================"
	@echo "  BITSTREAM    = $(PROJECT_NAME).bit"
	@echo "  LTX          = $(PROJECT_NAME).ltx"
	@echo "  USB_SERIAL   = $(USB_SERIAL)"
	@echo "  DEVICE       = $(DEVICE)"
	@echo "  VIO PROBE    = $(VIO_PROBE)"
	$(if $(filter vio_boot_mode,$(VIO_PROBE)),@echo  "  MODE         = $(VIO_COMMAND)")
	@echo "============================================================"
	$(VIVADO) $(COMMON_ARGS) \
		-source $(VIO_TCL) \
		-tclargs $(PROJECT_NAME).ltx $(VIO_COMMAND) $(USB_SERIAL) $(VIO_PROBE) $(DEVICE) $(PORT)
	@pkill hw_server

targets: 
	$(VIVADO) $(COMMON_ARGS) \
		-source $(TARGET_EXAMINE)
	@pkill hw_server

openocd:
	@echo "====================== LAUNCHING OPENOCD ===================="
	@echo "USB_SERIAL     = $(USB_SERIAL)"
	@echo "GDB_PORT       = $(GDB_PORT)"
	@echo "SCRIPT         = $(OPENOCD_SCRIPT)"
	@echo "HYPER          = $(HYPER)"
	@echo "============================================================="
	$(OPENOCD) \
	-c "set CoreNames {$(CORES)}" \
	-c "set serial $(USB_SERIAL)" \
	-c "set gdb_port $(GDB_PORT)" \
	-f $(OPENOCD_SCRIPT) \
	$(if $(filter 1,$(HYPER)),-c "script hyper_init.tcl",)
	@echo "Openocd launched"

gdb_run:
	$(GDB)  $(ELF_FILE_APP) \
		-ex "target remote localhost:$(GDB_PORT)" \
		-ex "load" \
		-ex "c"

write_bin_mem: $(if $(filter 1,$(USE_HW_FILTER)),hw_server_filtered)
	$(VIVADO) $(COMMON_ARGS) \
		-source $(WRITE_CFG_TCL) \
		-tclargs $(USB_SERIAL) $(PORT) $(PAYLOAD)

run-linux:
	$(GDB) $(PAYLOAD) \
	-ex "target extended-remote :$(GDB_PORT)" \
	-ex "monitor load_image $(DTB_FILE) $(DTB_ADDR)" \
	-ex "set \$$pc=_start" -ex "info registers pc" -ex "set \$$a1=0x81800000" -ex "info registers a1" \
	-ex "load" \
	-ex "continue"

include wrapper.mk
