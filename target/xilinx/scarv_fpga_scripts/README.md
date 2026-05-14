# SCAR-V FPGA SCRIPTS

A collection of scripts to interact with the RTL cores (Ibex, CVA6) of the SCAR-V design.

## Project structure

```text
.
├── hyper_init.tcl
├── Makefile
├── wrapper.mk
├── README.md
├── scripts_openocd
│   ├── openocd.bscan.tcl
│   ├── openocd.cheshire.tcl
│   ├── openocd.hs2.tcl
│   ├── openocd.olimex.tcl
│   ├── openocd.opentitan.tcl
│   └── openocd.general.tcl
├── scripts_vivado
│   ├── jtag_program.tcl
│   ├── set_vio.tcl
│   ├── target_examine.tcl
│   └── write_cfgmem.tcl
└── setup_env.sh
```

### `scripts_vivado/`
It contains all the scripts used by vivado to program, reset, change boot mode and more. 

### `scripts_openocd/`
It contains all the scripts used to lauch openocd.
OpenOCD should be started with one of the following:
- `openocd.hs2.tcl`
- `openocd.olimex.tcl`

These scripts act as top-level configuration entry points, and they:
- Select the correct debug adapter configuration
- Launch a wrapper openocd scripts: 

  - `openocd.general.tcl`

The `openocd.general.tcl` can be used for a configurable number of cores connected in a daisy chain. 

To configure the chain, the variable CORES should be passed to the Makefile
```bash
 CORES="opentitan cheshire"
```
Each entry in CORES identifies a target connected to the shared JTAG chain. To be noted that the order is important.
For every name in the list, a corresponding core-specific configuration script is automatically loaded.
  
In the example above, the following scripts are sourced:

  - `openocd.cheshire.tcl`
  - `openocd.opentitan.tcl`


## Common Commands

### Program FPGA

```bash
make program DEVICE=<device> PROJECT_NAME=<path> USB_SERIAL=<serial>
```

### Set VIO

```bash
make set_vio USB_SERIAL=<serial> DEVICE=<device> PROJECT_NAME=<path> VIO_COMMAND=<cmd> VIO_PROBE=<probe>
```

### Run OpenOCD

```bash
make openocd USB_SERIAL=<serial> CORES="cheshire opentitan"
```

---

## Example workflow

The first step is to determine which FPGA targets are available on the server. Each FPGA target exposes a JTAG interface through an onboard Digilent USB-to-JTAG controller, typically implemented using an FTDI FT2232-series chip. Because each FTDI device has a unique USB serial number, FPGA targets can be uniquely identified using that serial number. The following command lists the available targets together with their serial numbers and device names.
```bash
make targets
```
Once the serial numbers corresponding to the FPGA targets have been identified, the next step is to discover the external debuggers used to probe the RTL design. It is assumed that the supported devices are either an Olimex debugger (USB ID 15ba:002b) or a Digilent HS2 debugger (USB ID 0403:6014). The following command lists all USB devices matching either an Olimex or HS2 debugger. Note that the Digilent HS2 debugger and the onboard Xilinx JTAG interface both rely on FTDI USB interface chips. As a result, the command may also display the serial numbers associated with the FPGA targets.
```bash
make serial
```
With the information about the FPGA targets, it is possible to program the FPGA.
```bash
make program \
  DEVICE=xcvu9p_0 \
  PROJECT_NAME=/path/to/file/bit_name \
  USB_SERIAL=1234
```
Then we can launch openocd using the correct debugger.
```bash
make openocd USB_SERIAL=5678
```
In the above example, 1234 is the serial number of the onboard Digilent USB-to-JTAG controller, which programs the FPGA. Instead, 5678, is the serial number of the HS2 debugger, used to probe the design.


## Virtual Input Output (VIO)
Some designs (e.g., SCARV) include a Virtual Input/Output (VIO) core to configure the system (e.g., reset and boot mode). The following commands provide examples of how to use the scripts available in this repository. These scripts specifically target SCARV configuration. Moreover, these scripts are currently supported only for bitstreams generated with the flavour_vanilla flow.
```bash
make set_vio \
  USB_SERIAL=1234 \
  DEVICE=xcvu9p_0 \
  PROJECT_NAME=/path/to/file/bit_name \
  VIO_COMMAND=jtag \
  VIO_PROBE=vio_boot_mode

make set_vio \
  USB_SERIAL=1234 \
  DEVICE=xcvu9p_0 \
  PROJECT_NAME=/path/to/file/bit_name \
  VIO_PROBE=reset

make set_vio \
  USB_SERIAL=1234 \
  DEVICE=xcvu9p_0 \
  PROJECT_NAME=/path/to/file/bit_name \
  VIO_PROBE=git_hash
```

To simplify the usage of the vio core, some additional targets are integrated in the Makefile (in wrapper.mk). In particular:

```bash
make boot_jtag PROJECT_NAME=/path/to/file/bit_name

make boot_spi PROJECT_NAME=/path/to/file/bit_name

make reset PROJECT_NAME=/path/to/file/bit_name

make hash PROJECT_NAME=/path/to/file/bit_name
```
These are just wrappers of the set_vio targets.

---


## Configuration

These are some of the variables that can be set inside the Makefile

| Variable     | Description            | Example                 |
| ------------ | ---------------------- | ------------------------|
| USB_SERIAL   | FPGA board serial      | 1234                    |
| DEVICE       | Target FPGA device     | xcvu9p_0                |
| PROJECT_NAME | Bitstream/project path | out/carfield_top_xilinx |
| VIO_COMMAND  | VIO action             | jtag / reset            |
| VIO_PROBE    | Target probe           | vio_boot_mode           |


## HyperRam

When the FPGA is used with an HyperRam, instead of the onboard Xilinx DRAM, the following registers should be set up. The value of some registers depends on the specific HyperRam chip, other depends on the design working configuration. These registers are set by means of a minimal script (hyper_init.tcl) which is launched by openocd.

| Register     | Description            | Default Value   |
| ------------ | ---------------------- | ----------------|
| 0x210020f8   | Clock Divider Value    | 0x2             |
| 0x210020f4   | Clock Divider Enable   | 0x1             |
| 0x21004000   | Latency                | 0x6             |
| 0x2100400c   | Additional Latency     | 0x6             |
| 0x21004018   | Address Mask           | 0x1b            |
| 0x21004020   | Num Phys               | 0x1             |
| 0x21004024   | Which Phy              | 0x1             |
| 0x21004038   | Chip 0 Base Address    | 0x80000000      |
| 0x2100403c   | Chip 0 End Address     | 0x88000000      |
| 0x21004040   | Chip 1 Base Address    | 0x88000000      |
| 0x21004044   | Chip 1 End Address     | 0x90000000      |

---
