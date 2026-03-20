# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Cyril Koenig <cykoenig@iis.ee.ethz.ch>

####################
#     Clock Mux    #
####################

set SOC_TCK 20

proc handle_domain_clock_mux { clk_sel_path clk_name } {
  set clocks [list clk_50 clk_10 clk_20]
  # Start from a known clk_sel register and get fanout to find the clk_mux
  set domain_clk_mux [lindex [regexp -inline {[^ ]*gen_domain_clock_mux\[[0-9]*\]} [filter [all_fanout -flat [get_pins $clk_sel_path/q[*]]] -filter {NAME=~*gen_domain_clock_mux*}]] 0]
  # This domain_clk_mux not be here if the island is not activated
  if { $domain_clk_mux != "" } {
      set gen_clks {}
      # Generate a different clock for every input of the clock mux
      for {set i 0} {$i < [llength $clocks]} {incr i} {
            create_generated_clock -source [get_pins [concat i_xlnx_clk_wiz/[lindex $clocks $i]]] \
                                   -divide_by 1  \
                                   -name clk$i\_$clk_name \
                                   [get_pins $domain_clk_mux.i_clk_mux/clks_i[$i]]
            lappend gen_clks -group clk$i\_$clk_name
      }
    # Telling Vivado that the clocks are logically exclusive
    set_clock_groups -logically_exclusive {*}$gen_clks
    puts "$gen_clks"
    puts "Generated domain clock $clk_name"
  }
}


handle_domain_clock_mux [get_cells -hier u_periph_clk_sel] periph_domain_clk
handle_domain_clock_mux [get_cells -hier u_security_island_clk_sel] security_domain_clk
#handle_domain_clock_mux [get_cells -hier u_pulp_cluster_clk_sel] pulp_domain_clk
#handle_domain_clock_mux [get_cells -hier u_spatz_cluster_clk_sel] spatz_domain_clk
#handle_domain_clock_mux [get_cells -hier u_l2_clk_sel] l2_domain_clk
#handle_domain_clock_mux [get_cells -hier u_safety_island_clk_sel] safety_domain_clk

#################
# Carfield CDCs #
#################

# Safety Island
################

proc handle_slv_cdc { slv_cdc_path } {
  upvar SOC_TCK SOC_TCK
  # Start from a known slv cdc_dst and get fanout to find the mst cdc_src
  set mst_cdc_path [lindex [regexp -inline {.*gen_ext_slv_src_cdc\[[0-9]*\]} [lindex [filter [all_fanout -flat [get_pins $slv_cdc_path/*rptr*]] -filter {NAME =~ *gen_ext_slv_src_cdc*}] 0]] 0]
  if { $mst_cdc_path != "" } {
    set_max_delay -datapath \
     -from [get_pins $mst_cdc_path.i_cheshire_ext_slv_cdc_src/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $slv_cdc_path/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $slv_cdc_path/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $mst_cdc_path.i_cheshire_ext_slv_cdc_src/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $mst_cdc_path.i_cheshire_ext_slv_cdc_src/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $slv_cdc_path/i_cdc_fifo_gray_*/*i_sync/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $slv_cdc_path/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $mst_cdc_path.i_cheshire_ext_slv_cdc_src/i_cdc_fifo_gray_*/*i_sync/*reg*/D] \
     "$SOC_TCK"
  }

}

handle_slv_cdc [get_cells -hier gen_periph.i_cdc_dst_peripherals]
handle_slv_cdc [get_cells -hier gen_ethernet.i_ethernet_cdc_dst]
handle_slv_cdc [get_cells -hier gen_l2.i_reconfigurable_l2]/gen_cdc_fifos[1].i_dst_cdc
handle_slv_cdc [get_cells -hier gen_safety_island.i_safety_island_wrap]/i_cdc_in
handle_slv_cdc [get_cells -hier gen_spatz_cluster.i_fp_cluster_wrapper]/i_spatz_cluster_cdc_dst
handle_slv_cdc [get_cells -hier gen_pulp_cluster.i_integer_cluster]/axi_slave_cdc_i
handle_slv_cdc [get_cells -hier gen_l2.i_reconfigurable_l2]/gen_cdc_fifos[0].i_dst_cdc

proc handle_mst_cdc { mst_cdc_path } {
  upvar SOC_TCK SOC_TCK
  # Get the dst_cdc in cheshire
  set slv_cdc_path [lindex [regexp -inline {.*gen_ext_mst_dst_cdc\[[0-9]*\]} [lindex [filter [all_fanout -flat [get_pins $mst_cdc_path/*wptr*]] -filter {NAME =~ *gen_ext_mst_dst_cdc*}] 0]] 0]
  if { $slv_cdc_path != "" } {
    # From Safety Island master
    set_max_delay -datapath \
     -from [get_pins $mst_cdc_path/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $slv_cdc_path.i_cheshire_ext_mst_cdc_dst/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $slv_cdc_path.i_cheshire_ext_mst_cdc_dst/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $mst_cdc_path/i_cdc_fifo_gray_*/i_spill_register/spill_register_flushable_i/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $mst_cdc_path/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $slv_cdc_path.i_cheshire_ext_mst_cdc_dst/i_cdc_fifo_gray_*/*i_sync/*reg*/D] \
     "$SOC_TCK"
    set_max_delay -datapath \
     -from [get_pins $slv_cdc_path.i_cheshire_ext_mst_cdc_dst/i_cdc_fifo_gray_*/*reg*/C] \
     -to [get_pins $mst_cdc_path/i_cdc_fifo_gray_*/*i_sync/*reg*/D] \
     "$SOC_TCK"
  }

}

handle_mst_cdc [get_cells -hier gen_safety_island.i_safety_island_wrap]/i_cdc_out
handle_mst_cdc [get_cells -hier gen_spatz_cluster.i_fp_cluster_wrapper]/i_spatz_cluster_cdc_src
handle_mst_cdc [get_cells -hier gen_pulp_cluster.i_integer_cluster]/axi_master_cdc_i
handle_mst_cdc [get_cells -hier gen_secure_subsystem.i_security_island]/i_cdc_out_tlul2axi
