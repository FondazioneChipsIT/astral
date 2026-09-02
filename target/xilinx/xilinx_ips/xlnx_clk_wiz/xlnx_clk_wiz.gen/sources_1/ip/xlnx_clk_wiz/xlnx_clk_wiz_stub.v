// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
// Date        : Tue Sep  1 14:19:17 2026
// Host        : chips-rdp-stanis running 64-bit AlmaLinux release 8.10 (Cerulean Leopard)
// Command     : write_verilog -force -mode synth_stub
//               /data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xlnx_clk_wiz/xlnx_clk_wiz.gen/sources_1/ip/xlnx_clk_wiz/xlnx_clk_wiz_stub.v
// Design      : xlnx_clk_wiz
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu9p-flga2104-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module xlnx_clk_wiz(clk_100, clk_50, clk_20, clk_10, reset, locked, 
  clk_in1)
/* synthesis syn_black_box black_box_pad_pin="clk_100,clk_50,clk_20,clk_10,reset,locked,clk_in1" */;
  output clk_100;
  output clk_50;
  output clk_20;
  output clk_10;
  input reset;
  output locked;
  input clk_in1;
endmodule
