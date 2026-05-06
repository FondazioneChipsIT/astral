# Targets

A *target* refers to an end use of SCAR-V. This could be a simulation setup, an FPGA or ASIC
implementation, or the less common integration into other SoCs.

Target setups can either be *included* in this repository or live in an *external* repository and
use SCAR-V as a dependency.

## Included Targets

Included target setups live in the `target` directory. Each included target has a *documentation
page* in this chapter:

- [Simulation](sim.md)
- [Synthesis and physical implementation](synth.md)
- [Xilinx FPGAs](xilinx.md)
