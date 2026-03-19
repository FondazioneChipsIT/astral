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
  localparam int unsigned REG_ADDR_WIDTH  = 7;
  typedef struct packed {
    int unsigned idx;
    logic [REG_ADDR_WIDTH-1:0] start_addr;
    logic [REG_ADDR_WIDTH-1:0] end_addr;
  } addr_rule_t;

  localparam addr_rule_t[NUM_PAD_DOMAINS-1:0] ADDR_DEMUX_RULES = '{
    '{ idx: 0, start_addr: 7'd0,  end_addr: 7'd92}
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

  // pad_fll_host
  assign static_connection_signals_soc2pad.botl.fll_host_clk_o   = signals_soc2pad.fll_host_clk_o;
  assign static_connection_signals_soc2pad.botl.fll_host_drv_str = reg2hw.pad_fll_host.drv_str;
  assign static_connection_signals_soc2pad.botl.fll_host_slew_en = reg2hw.pad_fll_host.slew_en;

  // pad_fll_secd
  assign static_connection_signals_soc2pad.botl.fll_secd_clk_o   = signals_soc2pad.fll_secd_clk_o;
  assign static_connection_signals_soc2pad.botl.fll_secd_drv_str = reg2hw.pad_fll_secd.drv_str;
  assign static_connection_signals_soc2pad.botl.fll_secd_slew_en = reg2hw.pad_fll_secd.slew_en;

  // pad_fll_bypass
  assign signals_pad2soc.fll_bypass_i = static_connection_signals_pad2soc.botl.fll_bypass_i;

  // pad_pwr_on_rst_n
  assign signals_pad2soc.pwr_on_rst_ni = static_connection_signals_pad2soc.botl.pwr_on_rst_ni;

  // pad_boot_mode_0
  assign signals_pad2soc.boot_mode_i_0 = static_connection_signals_pad2soc.botl.boot_mode_i_0;

  // pad_boot_mode_1
  assign signals_pad2soc.boot_mode_i_1 = static_connection_signals_pad2soc.botl.boot_mode_i_1;

  // pad_secure_boot
  assign signals_pad2soc.secure_boot_i = static_connection_signals_pad2soc.botl.secure_boot_i;

  // pad_ref_clk
  assign signals_pad2soc.ref_clk_i = static_connection_signals_pad2soc.botl.ref_clk_i;

  // pad_jtag_tclk
  assign signals_pad2soc.jtag_tclk_i = static_connection_signals_pad2soc.botl.jtag_tclk_i;

  // pad_jtag_trst_n
  assign signals_pad2soc.jtag_trst_ni = static_connection_signals_pad2soc.botl.jtag_trst_ni;

  // pad_jtag_tms
  assign signals_pad2soc.jtag_tms_i = static_connection_signals_pad2soc.botl.jtag_tms_i;

  // pad_jtag_tdi
  assign signals_pad2soc.jtag_tdi_i = static_connection_signals_pad2soc.botl.jtag_tdi_i;

  // pad_jtag_tdo
  assign static_connection_signals_soc2pad.botl.jtag_tdo_o       = signals_soc2pad.jtag_tdo_o;
  assign static_connection_signals_soc2pad.botl.jtag_tdo_drv_str = reg2hw.pad_jtag_tdo.drv_str;
  assign static_connection_signals_soc2pad.botl.jtag_tdo_slew_en = reg2hw.pad_jtag_tdo.slew_en;

  // pad_uart_tx
  assign static_connection_signals_soc2pad.botl.uart_tx_o       = signals_soc2pad.uart_tx_o;
  assign static_connection_signals_soc2pad.botl.uart_tx_drv_str = reg2hw.pad_uart_tx.drv_str;
  assign static_connection_signals_soc2pad.botl.uart_tx_slew_en = reg2hw.pad_uart_tx.slew_en;

  // pad_uart_rx
  assign signals_pad2soc.uart_rx_i = static_connection_signals_pad2soc.botl.uart_rx_i;

  // pad_gpio_0 - in
  assign signals_pad2soc.gpio_v_i_0 = static_connection_signals_pad2soc.botl.gpio_v_i_0 & reg2hw.pad_gpio_0.pad_en;

  // pad_gpio_0 - out
  assign static_connection_signals_soc2pad.botl.gpio_v_o_0     =  signals_soc2pad.gpio_v_o_0     & reg2hw.pad_gpio_0.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_in_en   = ~signals_soc2pad.gpio_v_oen_i_0 & reg2hw.pad_gpio_0.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_out_en  =  signals_soc2pad.gpio_v_oen_i_0 & reg2hw.pad_gpio_0.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_pd_en   =  reg2hw.pad_gpio_0.pd_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_pu_en   =  reg2hw.pad_gpio_0.pu_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_slew_en =  reg2hw.pad_gpio_0.slew_en      & reg2hw.pad_gpio_0.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_smt_en  =  reg2hw.pad_gpio_0.smt_en       & reg2hw.pad_gpio_0.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_0_drv_str =  reg2hw.pad_gpio_0.drv_str      & {2{reg2hw.pad_gpio_0.pad_en}};

  // pad_gpio_1 - in
  assign signals_pad2soc.gpio_v_i_1 = static_connection_signals_pad2soc.botl.gpio_v_i_1 & reg2hw.pad_gpio_1.pad_en;

  // pad_gpio_1 - out
  assign static_connection_signals_soc2pad.botl.gpio_v_o_1     =  signals_soc2pad.gpio_v_o_1     & reg2hw.pad_gpio_1.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_in_en   = ~signals_soc2pad.gpio_v_oen_i_1 & reg2hw.pad_gpio_1.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_out_en  =  signals_soc2pad.gpio_v_oen_i_1 & reg2hw.pad_gpio_1.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_pd_en   =  reg2hw.pad_gpio_1.pd_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_pu_en   =  reg2hw.pad_gpio_1.pu_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_slew_en =  reg2hw.pad_gpio_1.slew_en      & reg2hw.pad_gpio_1.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_smt_en  =  reg2hw.pad_gpio_1.smt_en       & reg2hw.pad_gpio_1.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_1_drv_str =  reg2hw.pad_gpio_1.drv_str      & {2{reg2hw.pad_gpio_1.pad_en}};

  // pad_gpio_2 - in
  assign signals_pad2soc.gpio_v_i_2 = static_connection_signals_pad2soc.botl.gpio_v_i_2 & reg2hw.pad_gpio_2.pad_en;

  // pad_gpio_2 - out
  assign static_connection_signals_soc2pad.botl.gpio_v_o_2     =  signals_soc2pad.gpio_v_o_2     & reg2hw.pad_gpio_2.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_in_en   = ~signals_soc2pad.gpio_v_oen_i_2 & reg2hw.pad_gpio_2.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_out_en  =  signals_soc2pad.gpio_v_oen_i_2 & reg2hw.pad_gpio_2.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_pd_en   =  reg2hw.pad_gpio_2.pd_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_pu_en   =  reg2hw.pad_gpio_2.pu_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_slew_en =  reg2hw.pad_gpio_2.slew_en      & reg2hw.pad_gpio_2.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_smt_en  =  reg2hw.pad_gpio_2.smt_en       & reg2hw.pad_gpio_2.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_2_drv_str =  reg2hw.pad_gpio_2.drv_str      & {2{reg2hw.pad_gpio_2.pad_en}};

  // pad_gpio_3 - in
  assign signals_pad2soc.gpio_v_i_3 = static_connection_signals_pad2soc.botl.gpio_v_i_3 & reg2hw.pad_gpio_3.pad_en;

  // pad_gpio_3 - out
  assign static_connection_signals_soc2pad.botl.gpio_v_o_3     =  signals_soc2pad.gpio_v_o_3     & reg2hw.pad_gpio_3.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_in_en   = ~signals_soc2pad.gpio_v_oen_i_3 & reg2hw.pad_gpio_3.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_out_en  =  signals_soc2pad.gpio_v_oen_i_3 & reg2hw.pad_gpio_3.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_pd_en   =  reg2hw.pad_gpio_3.pd_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_pu_en   =  reg2hw.pad_gpio_3.pu_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_slew_en =  reg2hw.pad_gpio_3.slew_en      & reg2hw.pad_gpio_3.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_smt_en  =  reg2hw.pad_gpio_3.smt_en       & reg2hw.pad_gpio_3.pad_en;
  assign static_connection_signals_soc2pad.botl.gpio_3_drv_str =  reg2hw.pad_gpio_3.drv_str      & {2{reg2hw.pad_gpio_3.pad_en}};

  // pad_ot_boot_mode
  assign signals_pad2soc.ot_boot_mode_i = static_connection_signals_pad2soc.botl.ot_boot_mode_i;

  // pad_jtag_ot_tclk
  assign signals_pad2soc.jtag_ot_tclk_i = static_connection_signals_pad2soc.botl.jtag_ot_tclk_i;

  // pad_jtag_ot_trst_n
  assign signals_pad2soc.jtag_ot_trst_ni = static_connection_signals_pad2soc.botl.jtag_ot_trst_ni;

  // pad_jtag_ot_tms
  assign signals_pad2soc.jtag_ot_tms_i = static_connection_signals_pad2soc.botl.jtag_ot_tms_i;

  // pad_jtag_ot_tdi
  assign signals_pad2soc.jtag_ot_tdi_i = static_connection_signals_pad2soc.botl.jtag_ot_tdi_i;

  // pad_jtag_ot_tdo
  assign static_connection_signals_soc2pad.botl.jtag_ot_tdo_o       = signals_soc2pad.jtag_ot_tdo_o;
  assign static_connection_signals_soc2pad.botl.jtag_ot_tdo_drv_str = reg2hw.pad_jtag_ot_tdo.drv_str;
  assign static_connection_signals_soc2pad.botl.jtag_ot_tdo_slew_en = reg2hw.pad_jtag_ot_tdo.slew_en;

  // pad_ot_uart_tx
  assign static_connection_signals_soc2pad.botl.ot_uart_tx_o       = signals_soc2pad.ot_uart_tx_o;
  assign static_connection_signals_soc2pad.botl.ot_uart_tx_drv_str = reg2hw.pad_ot_uart_tx.drv_str;
  assign static_connection_signals_soc2pad.botl.ot_uart_tx_slew_en = reg2hw.pad_ot_uart_tx.slew_en;

  // pad_ot_uart_rx
  assign signals_pad2soc.ot_uart_rx_i = static_connection_signals_pad2soc.botl.ot_uart_rx_i;

  // pad_spih_sck
  assign static_connection_signals_soc2pad.botl.spih_sck_out_en  = reg2hw.pad_spih_sck.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sck_o       = signals_soc2pad.spih_sck_o  & reg2hw.pad_spih_sck.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sck_drv_str = reg2hw.pad_spih_sck.drv_str & {2{reg2hw.pad_spih_sck.pad_en}};
  assign static_connection_signals_soc2pad.botl.spih_sck_slew_en = reg2hw.pad_spih_sck.slew_en & reg2hw.pad_spih_sck.pad_en;

  // pad_spih_csb
  assign static_connection_signals_soc2pad.botl.spih_csb_out_en  = reg2hw.pad_spih_csb.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_csb_o_1     = signals_soc2pad.spih_csb_o_1 & reg2hw.pad_spih_csb.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_csb_drv_str = reg2hw.pad_spih_csb.drv_str  & {2{reg2hw.pad_spih_csb.pad_en}};
  assign static_connection_signals_soc2pad.botl.spih_csb_slew_en = reg2hw.pad_spih_csb.slew_en  & reg2hw.pad_spih_csb.pad_en;

  // pad_spih_sd_0 - in
  assign signals_pad2soc.spih_sd_i_0 = static_connection_signals_pad2soc.botl.spih_sd_i_0 | ~reg2hw.pad_spih_sd_0.pad_en;

  // pad_spih_sd_0 - out
  assign static_connection_signals_soc2pad.botl.spih_sd_o_0       =  signals_soc2pad.spih_sd_o_0     & reg2hw.pad_spih_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_in_en   = ~signals_soc2pad.spih_sd_oen_i_0 & reg2hw.pad_spih_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_out_en  =  signals_soc2pad.spih_sd_oen_i_0 & reg2hw.pad_spih_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_pd_en   =  reg2hw.pad_spih_sd_0.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_pu_en   =  reg2hw.pad_spih_sd_0.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_slew_en =  reg2hw.pad_spih_sd_0.slew_en    & reg2hw.pad_spih_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_smt_en  =  reg2hw.pad_spih_sd_0.smt_en     & reg2hw.pad_spih_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_0_drv_str =  reg2hw.pad_spih_sd_0.drv_str    & {2{reg2hw.pad_spih_sd_0.pad_en}};

  // pad_spih_sd_1 - in
  assign signals_pad2soc.spih_sd_i_1 = static_connection_signals_pad2soc.botl.spih_sd_i_1 | ~reg2hw.pad_spih_sd_1.pad_en;

  // pad_spih_sd_1 - out
  assign static_connection_signals_soc2pad.botl.spih_sd_o_1       =  signals_soc2pad.spih_sd_o_1     & reg2hw.pad_spih_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_in_en   = ~signals_soc2pad.spih_sd_oen_i_1 & reg2hw.pad_spih_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_out_en  =  signals_soc2pad.spih_sd_oen_i_1 & reg2hw.pad_spih_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_pd_en   =  reg2hw.pad_spih_sd_1.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_pu_en   =  reg2hw.pad_spih_sd_1.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_slew_en =  reg2hw.pad_spih_sd_1.slew_en    & reg2hw.pad_spih_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_smt_en  =  reg2hw.pad_spih_sd_1.smt_en     & reg2hw.pad_spih_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_1_drv_str =  reg2hw.pad_spih_sd_1.drv_str    & {2{reg2hw.pad_spih_sd_1.pad_en}};

  // pad_spih_sd_2 - in
  assign signals_pad2soc.spih_sd_i_2 = static_connection_signals_pad2soc.botl.spih_sd_i_2 | ~reg2hw.pad_spih_sd_2.pad_en;

  // pad_spih_sd_2 - out
  assign static_connection_signals_soc2pad.botl.spih_sd_o_2       =  signals_soc2pad.spih_sd_o_2     & reg2hw.pad_spih_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_in_en   = ~signals_soc2pad.spih_sd_oen_i_2 & reg2hw.pad_spih_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_out_en  =  signals_soc2pad.spih_sd_oen_i_2 & reg2hw.pad_spih_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_pd_en   =  reg2hw.pad_spih_sd_2.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_pu_en   =  reg2hw.pad_spih_sd_2.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_slew_en =  reg2hw.pad_spih_sd_2.slew_en    & reg2hw.pad_spih_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_smt_en  =  reg2hw.pad_spih_sd_2.smt_en     & reg2hw.pad_spih_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_2_drv_str =  reg2hw.pad_spih_sd_2.drv_str    & {2{reg2hw.pad_spih_sd_2.pad_en}};

  // pad_spih_sd_3 - in
  assign signals_pad2soc.spih_sd_i_3 = static_connection_signals_pad2soc.botl.spih_sd_i_3 | ~reg2hw.pad_spih_sd_3.pad_en;

  // pad_spih_sd_3 - out
  assign static_connection_signals_soc2pad.botl.spih_sd_o_3       =  signals_soc2pad.spih_sd_o_3     & reg2hw.pad_spih_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_in_en   = ~signals_soc2pad.spih_sd_oen_i_3 & reg2hw.pad_spih_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_out_en  =  signals_soc2pad.spih_sd_oen_i_3 & reg2hw.pad_spih_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_pd_en   =  reg2hw.pad_spih_sd_3.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_pu_en   =  reg2hw.pad_spih_sd_3.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_slew_en =  reg2hw.pad_spih_sd_3.slew_en    & reg2hw.pad_spih_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_smt_en  =  reg2hw.pad_spih_sd_3.smt_en     & reg2hw.pad_spih_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_sd_3_drv_str =  reg2hw.pad_spih_sd_3.drv_str    & {2{reg2hw.pad_spih_sd_3.pad_en}};

  // pad_spih_ot_sck
  assign static_connection_signals_soc2pad.botl.spih_ot_sck_out_en  = reg2hw.pad_spih_ot_sck.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sck_o       = signals_soc2pad.spih_ot_sck_o  & reg2hw.pad_spih_ot_sck.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sck_drv_str = reg2hw.pad_spih_ot_sck.drv_str & {2{reg2hw.pad_spih_ot_sck.pad_en}};
  assign static_connection_signals_soc2pad.botl.spih_ot_sck_slew_en = reg2hw.pad_spih_ot_sck.slew_en & reg2hw.pad_spih_ot_sck.pad_en;

  // pad_spih_ot_csb
  assign static_connection_signals_soc2pad.botl.spih_ot_csb_out_en  = reg2hw.pad_spih_ot_csb.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_csb_o       = signals_soc2pad.spih_ot_csb_o   & reg2hw.pad_spih_ot_csb.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_csb_drv_str = reg2hw.pad_spih_ot_csb.drv_str  & {2{reg2hw.pad_spih_ot_csb.pad_en}};
  assign static_connection_signals_soc2pad.botl.spih_ot_csb_slew_en = reg2hw.pad_spih_ot_csb.slew_en  & reg2hw.pad_spih_ot_csb.pad_en;

  // pad_spih_ot_sd_0 - in
  assign signals_pad2soc.spih_ot_sd_i_0 = static_connection_signals_pad2soc.botl.spih_ot_sd_i_0 | ~reg2hw.pad_spih_ot_sd_0.pad_en;

  // pad_spih_ot_sd_0 - out
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_o_0       =  signals_soc2pad.spih_ot_sd_o_0     & reg2hw.pad_spih_ot_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_in_en   = ~signals_soc2pad.spih_ot_sd_oen_i_0 & reg2hw.pad_spih_ot_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_out_en  =  signals_soc2pad.spih_ot_sd_oen_i_0 & reg2hw.pad_spih_ot_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_pd_en   =  reg2hw.pad_spih_ot_sd_0.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_pu_en   =  reg2hw.pad_spih_ot_sd_0.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_slew_en =  reg2hw.pad_spih_ot_sd_0.slew_en    & reg2hw.pad_spih_ot_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_smt_en  =  reg2hw.pad_spih_ot_sd_0.smt_en     & reg2hw.pad_spih_ot_sd_0.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_0_drv_str =  reg2hw.pad_spih_ot_sd_0.drv_str    & {2{reg2hw.pad_spih_ot_sd_0.pad_en}};

  // pad_spih_ot_sd_1 - in
  assign signals_pad2soc.spih_ot_sd_i_1 = static_connection_signals_pad2soc.botl.spih_ot_sd_i_1 | ~reg2hw.pad_spih_ot_sd_1.pad_en;

  // pad_spih_ot_sd_1 - out
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_o_1       =  signals_soc2pad.spih_ot_sd_o_1     & reg2hw.pad_spih_ot_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_in_en   = ~signals_soc2pad.spih_ot_sd_oen_i_1 & reg2hw.pad_spih_ot_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_out_en  =  signals_soc2pad.spih_ot_sd_oen_i_1 & reg2hw.pad_spih_ot_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_pd_en   =  reg2hw.pad_spih_ot_sd_1.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_pu_en   =  reg2hw.pad_spih_ot_sd_1.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_slew_en =  reg2hw.pad_spih_ot_sd_1.slew_en    & reg2hw.pad_spih_ot_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_smt_en  =  reg2hw.pad_spih_ot_sd_1.smt_en     & reg2hw.pad_spih_ot_sd_1.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_1_drv_str =  reg2hw.pad_spih_ot_sd_1.drv_str    & {2{reg2hw.pad_spih_ot_sd_1.pad_en}};

  // pad_spih_ot_sd_2 - in
  assign signals_pad2soc.spih_ot_sd_i_2 = static_connection_signals_pad2soc.botl.spih_ot_sd_i_2 | ~reg2hw.pad_spih_ot_sd_2.pad_en;

  // pad_spih_ot_sd_2 - out
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_o_2       =  signals_soc2pad.spih_ot_sd_o_2     & reg2hw.pad_spih_ot_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_in_en   = ~signals_soc2pad.spih_ot_sd_oen_i_2 & reg2hw.pad_spih_ot_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_out_en  =  signals_soc2pad.spih_ot_sd_oen_i_2 & reg2hw.pad_spih_ot_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_pd_en   =  reg2hw.pad_spih_ot_sd_2.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_pu_en   =  reg2hw.pad_spih_ot_sd_2.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_slew_en =  reg2hw.pad_spih_ot_sd_2.slew_en    & reg2hw.pad_spih_ot_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_smt_en  =  reg2hw.pad_spih_ot_sd_2.smt_en     & reg2hw.pad_spih_ot_sd_2.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_2_drv_str =  reg2hw.pad_spih_ot_sd_2.drv_str    & {2{reg2hw.pad_spih_ot_sd_2.pad_en}};

  // pad_spih_ot_sd_3 - in
  assign signals_pad2soc.spih_ot_sd_i_3 = static_connection_signals_pad2soc.botl.spih_ot_sd_i_3 | ~reg2hw.pad_spih_ot_sd_3.pad_en;

  // pad_spih_ot_sd_3 - out
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_o_3       =  signals_soc2pad.spih_ot_sd_o_3     & reg2hw.pad_spih_ot_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_in_en   = ~signals_soc2pad.spih_ot_sd_oen_i_3 & reg2hw.pad_spih_ot_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_out_en  =  signals_soc2pad.spih_ot_sd_oen_i_3 & reg2hw.pad_spih_ot_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_pd_en   =  reg2hw.pad_spih_ot_sd_3.pd_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_pu_en   =  reg2hw.pad_spih_ot_sd_3.pu_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_slew_en =  reg2hw.pad_spih_ot_sd_3.slew_en    & reg2hw.pad_spih_ot_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_smt_en  =  reg2hw.pad_spih_ot_sd_3.smt_en     & reg2hw.pad_spih_ot_sd_3.pad_en;
  assign static_connection_signals_soc2pad.botl.spih_ot_sd_3_drv_str =  reg2hw.pad_spih_ot_sd_3.drv_str    & {2{reg2hw.pad_spih_ot_sd_3.pad_en}};

endmodule
