-- Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2020.2 (lin64) Build 3064766 Wed Nov 18 09:12:47 MST 2020
-- Date        : Tue Sep  1 14:24:50 2026
-- Host        : chips-rdp-stanis running 64-bit AlmaLinux release 8.10 (Cerulean Leopard)
-- Command     : write_vhdl -force -mode synth_stub
--               /data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xilinx_rom_bank_1024x22/xilinx_rom_bank_1024x22.gen/sources_1/ip/xilinx_rom_bank_1024x22/xilinx_rom_bank_1024x22_stub.vhdl
-- Design      : xilinx_rom_bank_1024x22
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcvu9p-flga2104-2L-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xilinx_rom_bank_1024x22 is
  Port ( 
    a : in STD_LOGIC_VECTOR ( 9 downto 0 );
    clk : in STD_LOGIC;
    spo : out STD_LOGIC_VECTOR ( 21 downto 0 )
  );

end xilinx_rom_bank_1024x22;

architecture stub of xilinx_rom_bank_1024x22 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "a[9:0],clk,spo[21:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "dist_mem_gen_v8_0_13,Vivado 2020.2";
begin
end;
