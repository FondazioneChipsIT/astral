#!/bin/sh

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/tools/amd/2020.2/Vitis/2020.2/bin:/tools/amd/2020.2/Vivado/2020.2/ids_lite/ISE/bin/lin64:/tools/amd/2020.2/Vivado/2020.2/bin
else
  PATH=/tools/amd/2020.2/Vitis/2020.2/bin:/tools/amd/2020.2/Vivado/2020.2/ids_lite/ISE/bin/lin64:/tools/amd/2020.2/Vivado/2020.2/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/data2/fseratini/astral-vcu118-v2/target/xilinx/xilinx_ips/xlnx_clk_wiz/xlnx_clk_wiz.runs/xlnx_clk_wiz_synth_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

EAStep vivado -log xlnx_clk_wiz.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source xlnx_clk_wiz.tcl
