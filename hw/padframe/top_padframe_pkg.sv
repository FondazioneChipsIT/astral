// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Riccardo Fiorani Gallotta <riccardo.fiorani3@unibo.it>

package top_padframe_pkg;

  //Static connections signals
  typedef struct packed {
    logic        fll_host_clk_o;
    logic        fll_secd_clk_o;
    logic        gpio_v_o_0;
    logic        gpio_v_o_1;
    logic        gpio_v_o_2;
    logic        gpio_v_o_3;
    logic        gpio_v_oen_i_0;
    logic        gpio_v_oen_i_1;
    logic        gpio_v_oen_i_2;
    logic        gpio_v_oen_i_3;
    logic        jtag_ot_tdo_o;
    logic        jtag_tdo_o;
    logic        ot_uart_tx_o;
    logic        spih_csb_o_1;
    logic        spih_ot_csb_o;
    logic        spih_ot_sck_o;
    logic        spih_ot_sd_o_1;
    logic        spih_ot_sd_o_2;
    logic        spih_ot_sd_o_3;
    logic        spih_ot_sd_o_4;
    logic        spih_ot_sd_oen_i_1;
    logic        spih_ot_sd_oen_i_2;
    logic        spih_ot_sd_oen_i_3;
    logic        spih_ot_sd_oen_i_4;
    logic        spih_sck_o;
    logic        spih_sd_o_0;
    logic        spih_sd_o_1;
    logic        spih_sd_o_2;
    logic        spih_sd_o_3;
    logic        spih_sd_oen_i_0;
    logic        spih_sd_oen_i_1;
    logic        spih_sd_oen_i_2;
    logic        spih_sd_oen_i_3;
    logic        uart_tx_o;
  } top_padframe_signals_soc2pad_t;

  typedef struct packed {
    logic        boot_mode_i_0;
    logic        boot_mode_i_1;
    logic        fll_bypass_i;
    logic        gpio_v_i_0;
    logic        gpio_v_i_1;
    logic        gpio_v_i_2;
    logic        gpio_v_i_3;
    logic        jtag_ot_tclk_i;
    logic        jtag_ot_tdi_i;
    logic        jtag_ot_tms_i;
    logic        jtag_ot_trst_ni;
    logic        jtag_tclk_i;
    logic        jtag_tdi_i;
    logic        jtag_tms_i;
    logic        jtag_trst_ni;
    logic        ot_boot_mode_i;
    logic        ot_uart_rx_i;
    logic        pwr_on_rst_ni;
    logic        ref_clk_i;
    logic        secure_boot_i;
    logic        spih_ot_sd_i_1;
    logic        spih_ot_sd_i_2;
    logic        spih_ot_sd_i_3;
    logic        spih_ot_sd_i_4;
    logic        spih_sd_i_0;
    logic        spih_sd_i_1;
    logic        spih_sd_i_2;
    logic        spih_sd_i_3;
    logic        uart_rx_i;
  } top_padframe_signals_pad2soc_t;

endpackage : top_padframe_pkg
