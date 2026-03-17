set_property PACKAGE_PIN AY14    [get_ports jtag_tms_i] ;# AY14 (PMOD0_0_LS) - J52.1 - TMS
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tms_i] ;

set_property PACKAGE_PIN AY15    [get_ports jtag_tdi_i] ;# AY15 (PMOD0_1_LS) - J52.3 - TDI
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdi_i] ;

set_property PACKAGE_PIN AW15    [get_ports jtag_tdo_o] ;# AW15 (PMOD0_2_LS) - J52.5 - TDO
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tdo_o]

set_property PACKAGE_PIN AV15    [get_ports jtag_tck_i] ;# AV15 (PMOD0_3_LS) - J52.7 - TCK
set_property IOSTANDARD LVCMOS18 [get_ports jtag_tck_i] ;
