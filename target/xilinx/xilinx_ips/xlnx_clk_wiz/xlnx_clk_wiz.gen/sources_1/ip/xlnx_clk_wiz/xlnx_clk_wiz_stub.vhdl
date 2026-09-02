-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
-- Date        : Tue Sep  1 14:19:18 2026
-- Host        : chips-rdp-stanis running 64-bit AlmaLinux release 8.10 (Cerulean Leopard)
-- Command     : write_vhdl -force -mode synth_stub
--               /data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xlnx_clk_wiz/xlnx_clk_wiz.gen/sources_1/ip/xlnx_clk_wiz/xlnx_clk_wiz_stub.vhdl
-- Design      : xlnx_clk_wiz
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcvu9p-flga2104-2L-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xlnx_clk_wiz is
  Port ( 
    clk_100 : out STD_LOGIC;
    clk_50 : out STD_LOGIC;
    clk_20 : out STD_LOGIC;
    clk_10 : out STD_LOGIC;
    reset : in STD_LOGIC;
    locked : out STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end xlnx_clk_wiz;

architecture stub of xlnx_clk_wiz is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_100,clk_50,clk_20,clk_10,reset,locked,clk_in1";
begin
end;
