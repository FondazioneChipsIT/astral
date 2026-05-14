# Just a set of configuration registers for the HyperRam.

# HyperBus clock divider value
mww 0x210020f8 0x2
# HyperBus clock divider enable
mww 0x210020f4 0x1

# Chip 0 Base Address
mww 0x21004038 0x80000000
# Chip 0 End Address
mww 0x2100403c 0x88000000

# Chip 1 Base Address
mww 0x21004040 0x88000000
# Chip 1 End Address
mww 0x21004044 0x90000000

# Num phys: if 0x0 only one phy is used, if 0x1 two phys are used
mww 0x21004020 0x1
# Which phy: if two phys are used, this register is not used
mww 0x21004024 0x1

# Latency
mww 0x21004000 0x7
mww 0x2100400c 0x7

# Address Mask
mww 0x21004018 0x1b

