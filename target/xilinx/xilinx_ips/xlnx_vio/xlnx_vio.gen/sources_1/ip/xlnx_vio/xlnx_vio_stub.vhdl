-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
-- Date        : Tue Sep  1 14:22:02 2026
-- Host        : chips-rdp-stanis running 64-bit AlmaLinux release 8.10 (Cerulean Leopard)
-- Command     : write_vhdl -force -mode synth_stub
--               /data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xlnx_vio/xlnx_vio.gen/sources_1/ip/xlnx_vio/xlnx_vio_stub.vhdl
-- Design      : xlnx_vio
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcvu9p-flga2104-2L-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xlnx_vio is
  Port ( 
    clk : in STD_LOGIC;
    probe_out0 : out STD_LOGIC_VECTOR ( 0 to 0 );
    probe_out1 : out STD_LOGIC_VECTOR ( 1 downto 0 );
    probe_out2 : out STD_LOGIC_VECTOR ( 1 downto 0 )
  );

end xlnx_vio;

architecture stub of xlnx_vio is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe_out0[0:0],probe_out1[1:0],probe_out2[1:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "vio,Vivado 2020.2";
begin
end;
