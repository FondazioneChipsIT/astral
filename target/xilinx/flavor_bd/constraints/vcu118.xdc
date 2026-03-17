# VIOs are asynchronous
set_false_path -through [get_pins -of_objects [get_cells design_1_i/vio_0] -filter {NAME =~ *probe*}]


##############################
# BOARD SPECIFIC CONSTRAINTS #
##############################

set_property PACKAGE_PIN AW25     [get_ports "uart_rx_i"] ;# Bank  67 VCCO - VCC1V8   - IO_L2N_T0L_N3_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_rx_i"] ;
set_property PACKAGE_PIN BB21     [get_ports "uart_tx_o"] ;# Bank  67 VCCO - VCC1V8   - IO_L2P_T0L_N2_67
set_property IOSTANDARD  LVCMOS18 [get_ports "uart_tx_o"] ;

set_property PACKAGE_PIN L19 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports cpu_reset]

# Default 250MHz clk1
set_property PACKAGE_PIN D12      [get_ports "dram_sys_clk_n"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13N_T2L_N1_GC_QBC_47
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "dram_sys_clk_n"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13N_T2L_N1_GC_QBC_47
set_property PACKAGE_PIN E12      [get_ports "dram_sys_clk_p"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13P_T2L_N0_GC_QBC_47
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "dram_sys_clk_p"] ;# Bank  47 VCCO - VCC1V2_FPGA - IO_L13P_T2L_N0_GC_QBC_47

# Default sysclk1 300MHz
set_property PACKAGE_PIN F31      [get_ports "sys_clk_n"] ;
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "sys_clk_n"] ;
set_property PACKAGE_PIN G31      [get_ports "sys_clk_p"] ;
set_property IOSTANDARD  DIFF_SSTL12 [get_ports "sys_clk_p"] ;
