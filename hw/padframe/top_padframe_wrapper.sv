// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Author: Riccardo Fiorani Gallotta <riccardo.fiorani3@unibo.it>

module top_padframe_wrapper
  import pkg_astral_padframe::*;
  import top_padframe_pkg::*;
  import top_padframe_config_reg_pkg::*;
#(
  parameter int unsigned   AW = 32,
  parameter int unsigned   DW = 32,
  parameter type           req_t = logic, // reg_interface request type
  parameter type           resp_t = logic, // reg_interface response type
  parameter logic [DW-1:0] DecodeErrRespData = 32'hdeadda7a
)(
  input  logic                          clk_i,
  input  logic                          rst_ni,
  output top_padframe_signals_pad2soc_t signals_pad2soc,
  input  top_padframe_signals_soc2pad_t signals_soc2pad,
  // Landing Pads
  inout  wire logic                     pad_botl_config_tc_pad_internal_signals_0,
  inout  wire logic                     pad_botl_config_tc_pad_internal_signals_1,
  inout  wire logic                     pad_botl_config_tc_pad_internal_signals_2,
  inout  wire logic                     pad_botl_config_tc_pad_internal_signals_3,
  inout  wire logic                     pad_botl_fll_host_pad,
  inout  wire logic                     pad_botl_fll_secd_pad,
  inout  wire logic                     pad_botl_fll_bypass_pad,
  inout  wire logic                     pad_botl_pwr_on_rst_n_pad,
  inout  wire logic                     pad_botl_boot_mode_0_pad,
  inout  wire logic                     pad_botl_boot_mode_1_pad,
  inout  wire logic                     pad_botl_secure_boot_pad,
  inout  wire logic                     pad_botl_ref_clk_pad,
  inout  wire logic                     pad_botl_jtag_tclk_pad,
  inout  wire logic                     pad_botl_jtag_trst_n_pad,
  inout  wire logic                     pad_botl_jtag_tms_pad,
  inout  wire logic                     pad_botl_jtag_tdi_pad,
  inout  wire logic                     pad_botl_jtag_tdo_pad,
  inout  wire logic                     pad_botl_uart_tx_pad,
  inout  wire logic                     pad_botl_uart_rx_pad,
  inout  wire logic                     pad_botl_gpio_0_pad,
  inout  wire logic                     pad_botl_gpio_1_pad,
  inout  wire logic                     pad_botl_gpio_2_pad,
  inout  wire logic                     pad_botl_gpio_3_pad,
  inout  wire logic                     pad_botl_ot_boot_mode_pad,
  inout  wire logic                     pad_botl_jtag_ot_tclk_pad,
  inout  wire logic                     pad_botl_jtag_ot_trst_n_pad,
  inout  wire logic                     pad_botl_jtag_ot_tms_pad,
  inout  wire logic                     pad_botl_jtag_ot_tdi_pad,
  inout  wire logic                     pad_botl_jtag_ot_tdo_pad,
  inout  wire logic                     pad_botl_ot_uart_tx_pad,
  inout  wire logic                     pad_botl_ot_uart_rx_pad,
  inout  wire logic                     pad_botl_spih_sck_pad,
  inout  wire logic                     pad_botl_spih_csb_pad,
  inout  wire logic                     pad_botl_spih_sd_0_pad,
  inout  wire logic                     pad_botl_spih_sd_1_pad,
  inout  wire logic                     pad_botl_spih_sd_2_pad,
  inout  wire logic                     pad_botl_spih_sd_3_pad,
  inout  wire logic                     pad_botl_spih_ot_sck_pad,
  inout  wire logic                     pad_botl_spih_ot_csb_pad,
  inout  wire logic                     pad_botl_spih_ot_sd_0_pad,
  inout  wire logic                     pad_botl_spih_ot_sd_1_pad,
  inout  wire logic                     pad_botl_spih_ot_sd_2_pad,
  inout  wire logic                     pad_botl_spih_ot_sd_3_pad,
  // Config Interface
  input  req_t                          config_req_i,
  output resp_t                         config_rsp_o
);


  req_t  reg_config_req;
  resp_t reg_config_resp;
  req_t  error_slave_req;
  resp_t error_slave_rsp;

  localparam int unsigned NUM_PAD_DOMAINS = 1;
  localparam int unsigned REG_ADDR_WIDTH  = 4;
  typedef struct packed {
    int unsigned idx;
    logic [REG_ADDR_WIDTH-1:0] start_addr;
    logic [REG_ADDR_WIDTH-1:0] end_addr;
  } addr_rule_t;

  localparam addr_rule_t[NUM_PAD_DOMAINS-1:0] ADDR_DEMUX_RULES = '{
    '{ idx: 0, start_addr: 4'd0,  end_addr: 4'd12}
  };

  logic[$clog2(NUM_PAD_DOMAINS+1)-1:0] pad_domain_sel; // +1 since there is an additional error slave

  addr_decode #(
    .NoIndices(NUM_PAD_DOMAINS+1),
    .NoRules(NUM_PAD_DOMAINS),
    .addr_t(logic[REG_ADDR_WIDTH-1:0]),
    .rule_t(addr_rule_t)
  ) i_addr_decode(
    .addr_i(config_req_i.addr[REG_ADDR_WIDTH-1:0]),
    .addr_map_i(ADDR_DEMUX_RULES),
    .dec_valid_o(),
    .dec_error_o(),
    .idx_o(pad_domain_sel),
    .en_default_idx_i(1'b1),
    .default_idx_i(1'd1) // The last entry is the error slave
  );

  // Config Interface demultiplexing
  reg_demux #(
    .NoPorts(NUM_PAD_DOMAINS+1), //+1 for the error slave
    .req_t(req_t),
    .rsp_t(resp_t)
  ) i_config_demuxer (
    .clk_i,
    .rst_ni,
    .in_select_i(pad_domain_sel),
    .in_req_i(config_req_i),
    .in_rsp_o(config_rsp_o),
    .out_req_o({error_slave_req, reg_config_req}),
    .out_rsp_i({error_slave_rsp, reg_config_resp})
  );

  assign error_slave_rsp.error = 1'b1;
  assign error_slave_rsp.rdata = DecodeErrRespData;
  assign error_slave_rsp.ready = 1'b1;

  top_padframe_config_reg2hw_t reg2hw;

  top_padframe_config_reg_top #(
    .reg_req_t ( req_t  ),
    .reg_rsp_t ( resp_t )
  ) i_top_padframe_config_reg_top (
    .clk_i     ( clk_i           ),
    .rst_ni    ( rst_ni          ),
    .reg_req_i ( reg_config_req  ),
    .reg_rsp_o ( reg_config_resp ),
    .reg2hw    ( reg2hw          ),
    .devmode_i ( 1'b1            )
  );

  static_connection_signals_soc2pad_t static_connection_signals_soc2pad;
  static_connection_signals_pad2soc_t static_connection_signals_pad2soc;

  astral_padframe #(
    .AW                ( AW                ),
    .DW                ( DW                ),
    .req_t             ( req_t             ),
    .resp_t            ( resp_t            ),
    .DecodeErrRespData ( DecodeErrRespData )
  ) i_astral_padframe (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),
    .static_connection_signals_pad2soc,
    .static_connection_signals_soc2pad,
    .pad_botl_config_tc_pad_internal_signals_0,
    .pad_botl_config_tc_pad_internal_signals_1,
    .pad_botl_config_tc_pad_internal_signals_2,
    .pad_botl_config_tc_pad_internal_signals_3,
    .pad_botl_fll_host_pad,
    .pad_botl_fll_secd_pad,
    .pad_botl_fll_bypass_pad,
    .pad_botl_pwr_on_rst_n_pad,
    .pad_botl_boot_mode_0_pad,
    .pad_botl_boot_mode_1_pad,
    .pad_botl_secure_boot_pad,
    .pad_botl_ref_clk_pad,
    .pad_botl_jtag_tclk_pad,
    .pad_botl_jtag_trst_n_pad,
    .pad_botl_jtag_tms_pad,
    .pad_botl_jtag_tdi_pad,
    .pad_botl_jtag_tdo_pad,
    .pad_botl_uart_tx_pad,
    .pad_botl_uart_rx_pad,
    .pad_botl_gpio_0_pad,
    .pad_botl_gpio_1_pad,
    .pad_botl_gpio_2_pad,
    .pad_botl_gpio_3_pad,
    .pad_botl_ot_boot_mode_pad,
    .pad_botl_jtag_ot_tclk_pad,
    .pad_botl_jtag_ot_trst_n_pad,
    .pad_botl_jtag_ot_tms_pad,
    .pad_botl_jtag_ot_tdi_pad,
    .pad_botl_jtag_ot_tdo_pad,
    .pad_botl_ot_uart_tx_pad,
    .pad_botl_ot_uart_rx_pad,
    .pad_botl_spih_sck_pad,
    .pad_botl_spih_csb_pad,
    .pad_botl_spih_sd_0_pad,
    .pad_botl_spih_sd_1_pad,
    .pad_botl_spih_sd_2_pad,
    .pad_botl_spih_sd_3_pad,
    .pad_botl_spih_ot_sck_pad,
    .pad_botl_spih_ot_csb_pad,
    .pad_botl_spih_ot_sd_0_pad,
    .pad_botl_spih_ot_sd_1_pad,
    .pad_botl_spih_ot_sd_2_pad,
    .pad_botl_spih_ot_sd_3_pad,
    .config_req_i ( '0 ),
    .config_rsp_o (    )
  );

assign static_connection_signals_soc2pad.botl = '{
    drive_strength_grp_1:  reg2hw.drv_str_cfg.drv_str_pg_1,
    drive_strength_grp_2:  reg2hw.drv_str_cfg.drv_str_pg_2,
    drive_strength_grp_3:  reg2hw.drv_str_cfg.drv_str_pg_3,
    drive_strength_grp_4:  reg2hw.drv_str_cfg.drv_str_pg_4,
    drive_strength_grp_5:  reg2hw.drv_str_cfg.drv_str_pg_5,
    drive_strength_grp_6:  reg2hw.drv_str_cfg.drv_str_pg_6,
    drive_strength_grp_7:  reg2hw.drv_str_cfg.drv_str_pg_7,
    drive_strength_grp_8:  reg2hw.drv_str_cfg.drv_str_pg_8,
    drive_strength_grp_9:  reg2hw.drv_str_cfg.drv_str_pg_9,
    drive_strength_grp_10: reg2hw.drv_str_cfg.drv_str_pg_10,
    drive_strength_grp_11: reg2hw.drv_str_cfg.drv_str_pg_11,
    slew_en_grp_1:         reg2hw.slw_cfg.slw_pg_1,
    slew_en_grp_2:         reg2hw.slw_cfg.slw_pg_2,
    slew_en_grp_3:         reg2hw.slw_cfg.slw_pg_3,
    slew_en_grp_4:         reg2hw.slw_cfg.slw_pg_4,
    slew_en_grp_5:         reg2hw.slw_cfg.slw_pg_5,
    slew_en_grp_6:         reg2hw.slw_cfg.slw_pg_6,
    slew_en_grp_7:         reg2hw.slw_cfg.slw_pg_7,
    slew_en_grp_8:         reg2hw.slw_cfg.slw_pg_8,
    slew_en_grp_9:         reg2hw.slw_cfg.slw_pg_9,
    slew_en_grp_10:        reg2hw.slw_cfg.slw_pg_10,
    slew_en_grp_11:        reg2hw.slw_cfg.slw_pg_11,
    fll_host_clk_o:        signals_soc2pad.fll_host_clk_o,
    fll_secd_clk_o:        signals_soc2pad.fll_secd_clk_o,
    gpio_v_o_0:            signals_soc2pad.gpio_v_o_0,
    gpio_v_o_1:            signals_soc2pad.gpio_v_o_1,
    gpio_v_o_2:            signals_soc2pad.gpio_v_o_2,
    gpio_v_o_3:            signals_soc2pad.gpio_v_o_3,
    gpio_v_oen_i_0:        signals_soc2pad.gpio_v_oen_i_0,
    gpio_v_oen_i_1:        signals_soc2pad.gpio_v_oen_i_1,
    gpio_v_oen_i_2:        signals_soc2pad.gpio_v_oen_i_2,
    gpio_v_oen_i_3:        signals_soc2pad.gpio_v_oen_i_3,
    jtag_ot_tdo_o:         signals_soc2pad.jtag_ot_tdo_o,
    jtag_tdo_o:            signals_soc2pad.jtag_tdo_o,
    ot_uart_tx_o:          signals_soc2pad.ot_uart_tx_o,
    spih_csb_o_1:          signals_soc2pad.spih_csb_o_1,
    spih_ot_csb_o:         signals_soc2pad.spih_ot_csb_o,
    spih_ot_sck_o:         signals_soc2pad.spih_ot_sck_o,
    spih_ot_sd_o_1:        signals_soc2pad.spih_ot_sd_o_1,
    spih_ot_sd_o_2:        signals_soc2pad.spih_ot_sd_o_2,
    spih_ot_sd_o_3:        signals_soc2pad.spih_ot_sd_o_3,
    spih_ot_sd_o_4:        signals_soc2pad.spih_ot_sd_o_4,
    spih_ot_sd_oen_i_1:    signals_soc2pad.spih_ot_sd_oen_i_1,
    spih_ot_sd_oen_i_2:    signals_soc2pad.spih_ot_sd_oen_i_2,
    spih_ot_sd_oen_i_3:    signals_soc2pad.spih_ot_sd_oen_i_3,
    spih_ot_sd_oen_i_4:    signals_soc2pad.spih_ot_sd_oen_i_4,
    spih_sck_o:            signals_soc2pad.spih_sck_o,
    spih_sd_o_0:           signals_soc2pad.spih_sd_o_0,
    spih_sd_o_1:           signals_soc2pad.spih_sd_o_1,
    spih_sd_o_2:           signals_soc2pad.spih_sd_o_2,
    spih_sd_o_3:           signals_soc2pad.spih_sd_o_3,
    spih_sd_oen_i_0:       signals_soc2pad.spih_sd_oen_i_0,
    spih_sd_oen_i_1:       signals_soc2pad.spih_sd_oen_i_1,
    spih_sd_oen_i_2:       signals_soc2pad.spih_sd_oen_i_2,
    spih_sd_oen_i_3:       signals_soc2pad.spih_sd_oen_i_3,
    uart_tx_o:             signals_soc2pad.uart_tx_o
  };

  assign signals_pad2soc = '{
    boot_mode_i_0:   static_connection_signals_pad2soc.botl.boot_mode_i_0,
    boot_mode_i_1:   static_connection_signals_pad2soc.botl.boot_mode_i_1,
    fll_bypass_i:    static_connection_signals_pad2soc.botl.fll_bypass_i,
    gpio_v_i_0:      static_connection_signals_pad2soc.botl.gpio_v_i_0,
    gpio_v_i_1:      static_connection_signals_pad2soc.botl.gpio_v_i_1,
    gpio_v_i_2:      static_connection_signals_pad2soc.botl.gpio_v_i_2,
    gpio_v_i_3:      static_connection_signals_pad2soc.botl.gpio_v_i_3,
    jtag_ot_tclk_i:  static_connection_signals_pad2soc.botl.jtag_ot_tclk_i,
    jtag_ot_tdi_i:   static_connection_signals_pad2soc.botl.jtag_ot_tdi_i,
    jtag_ot_tms_i:   static_connection_signals_pad2soc.botl.jtag_ot_tms_i,
    jtag_ot_trst_ni: static_connection_signals_pad2soc.botl.jtag_ot_trst_ni,
    jtag_tclk_i:     static_connection_signals_pad2soc.botl.jtag_tclk_i,
    jtag_tdi_i:      static_connection_signals_pad2soc.botl.jtag_tdi_i,
    jtag_tms_i:      static_connection_signals_pad2soc.botl.jtag_tms_i,
    jtag_trst_ni:    static_connection_signals_pad2soc.botl.jtag_trst_ni,
    ot_boot_mode_i:  static_connection_signals_pad2soc.botl.ot_boot_mode_i,
    ot_uart_rx_i:    static_connection_signals_pad2soc.botl.ot_uart_rx_i,
    pwr_on_rst_ni:   static_connection_signals_pad2soc.botl.pwr_on_rst_ni,
    ref_clk_i:       static_connection_signals_pad2soc.botl.ref_clk_i,
    secure_boot_i:   static_connection_signals_pad2soc.botl.secure_boot_i,
    spih_ot_sd_i_1:  static_connection_signals_pad2soc.botl.spih_ot_sd_i_1,
    spih_ot_sd_i_2:  static_connection_signals_pad2soc.botl.spih_ot_sd_i_2,
    spih_ot_sd_i_3:  static_connection_signals_pad2soc.botl.spih_ot_sd_i_3,
    spih_ot_sd_i_4:  static_connection_signals_pad2soc.botl.spih_ot_sd_i_4,
    spih_sd_i_0:     static_connection_signals_pad2soc.botl.spih_sd_i_0,
    spih_sd_i_1:     static_connection_signals_pad2soc.botl.spih_sd_i_1,
    spih_sd_i_2:     static_connection_signals_pad2soc.botl.spih_sd_i_2,
    spih_sd_i_3:     static_connection_signals_pad2soc.botl.spih_sd_i_3,
    uart_rx_i:       static_connection_signals_pad2soc.botl.uart_rx_i
  };

endmodule
