// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Cells to be used for Xilinx FPGA mappings

module tc_clk_and2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  assign clk_o = clk0_i & clk1_i;

endmodule

module tc_clk_buffer (
  input  logic clk_i,
  output logic clk_o
);

  assign clk_o = clk_i;

endmodule

// Disable clock gating on FPGA as it behaves differently than expected
module tc_clk_gating #(
  /// This paramaeter is a hint for tool/technology specific mappings of this
  /// tech_cell. It indicates wether this particular clk gate instance is
  /// required for functional correctness or just instantiated for power
  /// savings. If IS_FUNCTIONAL == 0, technology specific mappings might
  /// replace this cell with a feedthrough connection without any gating.
  parameter bit IS_FUNCTIONAL = 1'b0
)(
   input  logic clk_i,
   input  logic en_i,
   input  logic test_en_i,
   output logic clk_o
);
  if (IS_FUNCTIONAL) begin : gen_functional
    BUFGCE #(
      .CE_TYPE        ( "SYNC"       ),
      .IS_CE_INVERTED ( 1'b0         ),
      .IS_I_INVERTED  ( 1'b0         ),
      .SIM_DEVICE     ( "ULTRASCALE" )
    ) i_clk_gate (
      .I  ( clk_i ),
      .CE ( en_i  ),
      .O  ( clk_o )
    );
  end else begin : gen_non_functional
    assign clk_o = clk_i;
  end

endmodule

module tc_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);

  assign clk_o = ~clk_i;

endmodule

module tc_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);

  assign clk_o = clk_sel_i ? clk1_i : clk0_i;

endmodule

module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  assign clk_o = clk0_i ^ clk1_i;

endmodule

module tc_clk_or2 (
  input logic clk0_i,
  input logic clk1_i,
  output logic clk_o
);

  assign clk_o = clk0_i | clk1_i;

endmodule


