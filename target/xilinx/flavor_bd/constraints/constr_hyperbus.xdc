set SOC_TCK 20

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_ports pad_hyper_ck_0]]
set_property CLOCK_BUFFER_TYPE NONE [get_nets -of [get_ports pad_hyper_ck_0]]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of [get_ports pad_hyper_ckn_0]]
set_property CLOCK_BUFFER_TYPE NONE [get_nets -of [get_ports pad_hyper_ckn_0]]

set_property CLOCK_BUFFER_TYPE NONE [get_nets -hier -filter {NAME =~ *i_delay_rx_rwds_90/out_o}]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -hier -filter {NAME =~ *i_delay_rx_rwds_90/out_o}]

set period_hyperbus 200
set clk_rx_shift [expr $period_hyperbus/10]
set rwds_input_delay [expr $period_hyperbus/4]

create_clock -period $period_hyperbus -name RWDS0_CLK [get_ports {pad_hyper_rwds_0[0]}]
create_clock -period $period_hyperbus -name RWDS1_CLK [get_ports {pad_hyper_rwds_0[1]}]

create_clock -name CLK_HYP -period $period_hyperbus [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}]
create_generated_clock -name CLK_PHY -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}] -add -master_clock CLK_HYP -edges {1 3 5} [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyper_clk_gen/clk_phy_o_reg/Q}]

create_generated_clock -name CLK_PHY0_CK \
    -add \
    -master_clock [get_clocks CLK_HYP] \
    -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}] \
    -edges {2 4 6} \
    [get_ports pad_hyper_ck_0[0]]

create_generated_clock -name CLK_PHY0_CK_N \
    -add \
    -master_clock [get_clocks CLK_HYP] \
    -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}] \
    -edges {4 6 8} \
    [get_ports pad_hyper_ck_0[0]]

create_generated_clock -name CLK_PHY1_CK \
    -add \
    -master_clock [get_clocks CLK_HYP] \
    -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}] \
    -edges {2 4 6} \
    [get_ports pad_hyper_ck_0[1]]


create_generated_clock -name CLK_PHY1_CK_N \
    -add \
    -master_clock [get_clocks CLK_HYP] \
    -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/CLK}] \
    -edges {4 6 8} \
    [get_ports pad_hyper_ck_0[1]]
        

# RWDS clock
create_generated_clock [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyperbus/i_phy/phy_wrap.phy_unroll[0].i_phy/i_trx/i_delay_rx_rwds_90/in_i}] \
                       -name CLK_RWDS_0 -edges {1 2 3} -edge_shift "$clk_rx_shift $clk_rx_shift $clk_rx_shift" \
                       -source [get_ports pad_hyper_rwds_0[0]]
create_generated_clock [get_nets -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus/i_phy/phy_wrap.phy_unroll[0].i_phy/i_trx/rx_rwds_clk_n}] \
                        -name CLK_RWDS_SAMPLE_0 -invert  -divide_by 1  \ 
                        -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyperbus/i_phy/phy_wrap.phy_unroll[0].i_phy/i_trx/i_delay_rx_rwds_90/in_i}] 
                        
create_generated_clock [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyperbus/i_phy/phy_wrap.phy_unroll[1].i_phy/i_trx/i_delay_rx_rwds_90/in_i}] \
                       -name CLK_RWDS_1 -edges {1 2 3} -edge_shift "$clk_rx_shift $clk_rx_shift $clk_rx_shift" \
                       -source [get_ports pad_hyper_rwds_0[1]]
create_generated_clock [get_nets -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus/i_phy/phy_wrap.phy_unroll[1].i_phy/i_trx/rx_rwds_clk_n}] \
                        -name CLK_RWDS_SAMPLE_1 -invert  -divide_by 1  \ 
                        -source [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyperbus/i_phy/phy_wrap.phy_unroll[1].i_phy/i_trx/i_delay_rx_rwds_90/in_i}]                           
                        
                        
set_clock_groups -name CLK_GROUP_1 -asynchronous \
    -group {periph_domain_clk} \
    -group {CLK_HYP CLK_PHY} \
    -group {CLK_PHY0_CK CLK_PHY1_CK CLK_PHY0_CK_N CLK_PHY1_CK_N} \
    -group {CLK_RWDS_0 CLK_RWDS_SAMPLE_0 RWDS0_CLK} \
    -group {CLK_RWDS_1 CLK_RWDS_SAMPLE_1 RWDS1_CLK}


set output_ports {{pad_hyper_dq*} pad_hyper_rwds*}
set_output_delay [expr $period_hyperbus/2 ] -clock CLK_PHY0_CK [get_ports $output_ports] -max
set_output_delay [expr $period_hyperbus/-2] -clock CLK_PHY0_CK [get_ports $output_ports] -min -add_delay
set_output_delay [expr $period_hyperbus/2 ] -clock CLK_PHY0_CK [get_ports $output_ports] -max -clock_fall -add_delay
set_output_delay [expr $period_hyperbus/-2] -clock CLK_PHY0_CK [get_ports $output_ports] -min -clock_fall -add_delay

set input_ports {{pad_hyper_dq*} pad_hyper_rwds*}
set_input_delay -max [expr $period_hyperbus/2] -clock CLK_PHY0_CK [get_ports $input_ports]
set_input_delay -min [expr $period_hyperbus/2] -clock CLK_PHY0_CK [get_ports $input_ports] -add_delay
set_input_delay -max [expr $period_hyperbus/2] -clock CLK_PHY0_CK [get_ports $input_ports] -add_delay -clock_fall
set_input_delay -min [expr $period_hyperbus/2] -clock CLK_PHY0_CK [get_ports $input_ports] -add_delay -clock_fall


set_false_path -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_carfield_reg_top/u_hyperbus_clk_div_value/*reg*/C}]
set_false_path -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_carfield_reg_top/u_hyperbus_clk_div_en/*reg*/C}]
set_false_path -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyper_rstgen/i_rstgen_bypass/*reg*/C}]


##  CDC between Cheshire (Host Domain) and Hyperbus (Periph Domain)
set_max_delay -datapath -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyper_axi_cdc_dst/i_cdc_fifo_gray_*/*reg*/C}] -to [get_pins -hier -filter {NAME =~ *i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D}] 20
set_max_delay -datapath -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*reg*/C}] -to [get_pins -hier -filter {NAME =~ *i_carfield/i_hyperbus_wrap/i_hyper_axi_cdc_dst/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D}] 20
set_max_delay -datapath -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_hyperbus_wrap/i_hyper_axi_cdc_dst/i_cdc_fifo_gray_*/*reg*/C}] -to [get_pins -hier -filter {NAME =~ *i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*i_sync/*reg*/D}] 20
set_max_delay -datapath -from [get_pins -hier -filter {NAME =~ *i_carfield_xilinx/i_carfield/i_cheshire_wrap/i_cheshire_ext_llc_cdc_src/i_cdc_fifo_gray_*/*reg*/C}] -to [get_pins -hier -filter {NAME =~ *i_carfield/i_hyperbus_wrap/i_hyper_axi_cdc_dst/i_cdc_fifo_gray_*/*i_sync/*reg*/D}] 20