// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
// Date        : Tue Sep  1 14:22:02 2026
// Host        : chips-rdp-stanis running 64-bit AlmaLinux release 8.10 (Cerulean Leopard)
// Command     : write_verilog -force -mode synth_stub
//               /data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xlnx_vio/xlnx_vio.gen/sources_1/ip/xlnx_vio/xlnx_vio_stub.v
// Design      : xlnx_vio
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu9p-flga2104-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "vio,Vivado 2020.2" *)
module xlnx_vio(clk, probe_out0, probe_out1, probe_out2)
/* synthesis syn_black_box black_box_pad_pin="clk,probe_out0[0:0],probe_out1[1:0],probe_out2[1:0]" */;
  input clk;
  output [0:0]probe_out0;
  output [1:0]probe_out1;
  output [1:0]probe_out2;
endmodule
