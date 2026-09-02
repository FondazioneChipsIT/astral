# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>


###################
# Top level reset #
###################

# The output of the top level reset synchronizer
set_false_path -through [get_pins {i_rstgen_main/i_rstgen_bypass/synch_regs_q_reg[*]/*}]
set_max_delay -through [get_pins -filter {DIRECTION == OUT} -leaf -of_objects [get_nets rst_n]] 20.000
set_false_path -hold -through [get_pins -filter {DIRECTION == OUT} -leaf -of_objects [get_nets rst_n]]

##########
# Clocks #
##########

# Rtc clock is asynchronous
create_generated_clock -name rtc_clk -source [get_pins -filter {DIRECTION == OUT} -leaf -of_objects [get_nets clk_10]] -divide_by 10 [get_pins rtc_clk_q_reg/Q]
set_clock_groups -asynchronous -group rtc_clk

# System Clock
# [see in $XILINX_BOARD.xdc]

# JTAG Clock
create_clock -period 100.000 -name clk_jtag [get_ports jtag_tck_i]
set_input_jitter clk_jtag 1.000
set_clock_groups -name jtag_grp -asynchronous -group clk_jtag

##########
# BUFG   #
##########

# JTAG are on non clock capable GPIOs (if not using BSCANE)
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_ports jtag_tck_i]]
set_property CLOCK_BUFFER_TYPE NONE [get_nets -of [get_ports jtag_tck_i]]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_ports cpu_reset]]
set_property CLOCK_BUFFER_TYPE NONE [get_nets -of [get_ports cpu_reset]]

########
# JTAG #
########

set_input_delay -clock clk_jtag -min 10.000 [get_ports {jtag_tdi_i jtag_tms_i}]
set_input_delay -clock clk_jtag -max 20.000 [get_ports {jtag_tdi_i jtag_tms_i}]

set_output_delay -clock clk_jtag -min 10.000 [get_ports jtag_tdo_o]
set_output_delay -clock clk_jtag -max 20.000 [get_ports jtag_tdo_o]

# This port is unused
# set_max_delay  -from [get_ports jtag_trst_ni] $JTAG_TCK
# set_false_path -hold -from [get_ports jtag_trst_ni]

########
# UART #
########

set_max_delay -from [get_ports uart_rx_i] 70.000
set_false_path -hold -from [get_ports uart_rx_i]

set_max_delay -to [get_ports uart_tx_o] 70.000
set_false_path -hold -to [get_ports uart_tx_o]

########
# VIOs #
########

set_false_path -through [get_pins -of_object [get_cells -hier -filter {REF_NAME =~ xlnx_vio || ORIG_REF_NAME =~ xlnx_vio}] -filter {NAME =~ *probe*}]

#################
# Carfield CDCs #
#################

# Hyper
###################

# i_hyper_cdc_dst
set_max_delay -datapath -from [get_pins i_hyper_cdc_dst/i_cdc_fifo_gray_*/*reg*/C] -to [get_pins i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] 20
set_max_delay -datapath -from [get_pins i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*reg*/C] -to [get_pins i_hyper_cdc_dst/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] 20
set_max_delay -datapath -from [get_pins i_hyper_cdc_dst/i_cdc_fifo_gray_*/*reg*/C] -to [get_pins i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*i_sync/*reg*/D] 20
set_max_delay -datapath -from [get_pins i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*reg*/C] -to [get_pins i_hyper_cdc_dst/i_cdc_fifo_gray_*/*i_sync/*reg*/D] 20

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 16384 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list soc_clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 2 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {vio_boot_mode[0]} {vio_boot_mode[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 2 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {vio_boot_mode_safety[0]} {vio_boot_mode_safety[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list vio_reset]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets soc_clk]
