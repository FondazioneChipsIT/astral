##############################
# BOARD SPECIFIC CONSTRAINTS #
##############################

#############
# Sys clock #
#############

# 250 MHz ref clock
set SYS_TCK 4
create_clock -period $SYS_TCK -name sys_clk [get_pins u_ibufg_sys_clk/O]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins u_ibufg_sys_clk/O]
set_clock_groups -name sys_clk_async -asynchronous -group {sys_clk}

#############
# Mig clock #
#############

# Dram axi clock : 1600ps * 4
set MIG_TCK 6.4
set MIG_RST [get_pins i_dram_wrapper/i_dram/c0_ddr4_ui_clk_sync_rst]
create_clock -period $MIG_TCK -name dram_axi_clk [get_pins i_dram_wrapper/i_dram/c0_ddr4_ui_clk]
set_clock_groups -name dram_async -asynchronous -group {dram_axi_clk}
set_false_path -hold -through $MIG_RST
set_max_delay -through $MIG_RST $MIG_TCK

########
# CDCs #
########

set_max_delay -through [get_nets -of_objects [get_cells i_dram_wrapper/gen_cdc.i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/*] -filter {NAME=~*async*}] $MIG_TCK
#set_max_delay -datapath -from [get_pins i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_*/*reg*/C] -to [get_pins i_axi_cdc_mig/i_axi_cdc_*/i_cdc_fifo_gray_dst_*/*i_sync/reg*/D] $MIG_TCK

#-------------- MCS Generation ----------------------
#set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-1  [current_design]
#set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4          [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE          [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone      [current_design]
#set_property CFGBVS GND                               [current_design]
#set_property CONFIG_VOLTAGE 1.8                       [current_design]
#set_property CONFIG_MODE SPIx8                        [current_design]


#################################################################################

set_property PACKAGE_PIN AW25     [get_ports "uart_rx_i"] ;# Bank  67 VCCO - VCC1V8   - IO_L2N_T0L_N3_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_rx_i"] ;# Bank  67 VCCO - VCC1V8   - IO_L2N_T0L_N3_67
set_property PACKAGE_PIN BB21     [get_ports "uart_tx_o"] ;# Bank  67 VCCO - VCC1V8   - IO_L2P_T0L_N2_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_tx_o"] ;# Bank  67 VCCO - VCC1V8   - IO_L2P_T0L_N2_67

set_property PACKAGE_PIN L19 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports cpu_reset]

set_property PACKAGE_PIN AW15    [get_ports jtag_tdo_o] ;# AW15 (PMOD0_2_LS) - J52.5 - TDO
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdo_o]

set_property PACKAGE_PIN AV15    [get_ports jtag_tck_i] ;# AV15 (PMOD0_3_LS) - J52.7 - TCK
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tck_i] ;

set_property PACKAGE_PIN AY14    [get_ports jtag_tms_i] ;# AY14 (PMOD0_0_LS) - J52.1 - TMS
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tms_i] ;

set_property PACKAGE_PIN AY15    [get_ports jtag_tdi_i] ;# AY15 (PMOD0_1_LS) - J52.3 - TDI
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdi_i] ;

set_property PACKAGE_PIN AT32     [get_ports "led0_o"] ; # Bank 40
set_property IOSTANDARD  LVCMOS12 [get_ports "led0_o"] ; # Bank 40
set_property PACKAGE_PIN AV34     [get_ports "led1_o"] ; # Bank 40
set_property IOSTANDARD  LVCMOS12 [get_ports "led1_o"] ; # Bank 40

# Default 250MHz clk1
set_property PACKAGE_PIN D12      [get_ports "sys_clk_n"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13N_T2L_N1_GC_QBC_47
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "sys_clk_n"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13N_T2L_N1_GC_QBC_47
set_property PACKAGE_PIN E12      [get_ports "sys_clk_p"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13P_T2L_N0_GC_QBC_47
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "sys_clk_p"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13P_T2L_N0_GC_QBC_47


set_property -dict "PACKAGE_PIN AW13 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_csn[0][0]]
set_property -dict "PACKAGE_PIN AY13 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_csn[0][1]]
set_property -dict "PACKAGE_PIN AY9 IOSTANDARD LVCMOS18"    [get_ports pad_hyper_ck[0]]
set_property -dict "PACKAGE_PIN BA9 IOSTANDARD LVCMOS18"    [get_ports pad_hyper_ckn[0]]
set_property -dict "PACKAGE_PIN BC14 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_rwds[0]]
set_property -dict "PACKAGE_PIN AT12 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_reset[0]]
set_property -dict "PACKAGE_PIN BF15 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][0]]
set_property -dict "PACKAGE_PIN BE15 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][1]]
set_property -dict "PACKAGE_PIN BE12 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][2]]
set_property -dict "PACKAGE_PIN BD12 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][3]]
set_property -dict "PACKAGE_PIN AV9 IOSTANDARD LVCMOS18"    [get_ports pad_hyper_dq[0][4]]
set_property -dict "PACKAGE_PIN AV8 IOSTANDARD LVCMOS18"    [get_ports pad_hyper_dq[0][5]]
set_property -dict "PACKAGE_PIN AW11 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][6]]
set_property -dict "PACKAGE_PIN AY10 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_dq[0][7]]

#HYPER RAM2
set_property -dict "PACKAGE_PIN AP16 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_csn[1][0]]
set_property -dict "PACKAGE_PIN AT14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_csn[1][1]]
set_property -dict "PACKAGE_PIN AP12 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_ck[1]]
set_property -dict "PACKAGE_PIN AR12 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_ckn[1]]
set_property -dict "PACKAGE_PIN AL14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_rwds[1]]
set_property -dict "PACKAGE_PIN AW7 IOSTANDARD LVCMOS18"   [get_ports pad_hyper_reset[1]]
set_property -dict "PACKAGE_PIN BE14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][0]]
set_property -dict "PACKAGE_PIN BF14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][1]]
set_property -dict "PACKAGE_PIN BA14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][2]]
set_property -dict "PACKAGE_PIN BB14 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][3]]
set_property -dict "PACKAGE_PIN BD13 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][4]]
set_property -dict "PACKAGE_PIN BE13 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][5]]
set_property -dict "PACKAGE_PIN BB13 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][6]]
set_property -dict "PACKAGE_PIN BB12 IOSTANDARD LVCMOS18"  [get_ports pad_hyper_dq[1][7]]