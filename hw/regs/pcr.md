## Summary

| Name                                                                         | Offset   |   Length | Description                                                                |
|:-----------------------------------------------------------------------------|:---------|---------:|:---------------------------------------------------------------------------|
| carfield.[`VERSION0`](#version0)                                             | 0x0      |        4 | Cheshire sha256 commit                                                     |
| carfield.[`VERSION1`](#version1)                                             | 0x4      |        4 | Safety Island sha256 commit                                                |
| carfield.[`VERSION2`](#version2)                                             | 0x8      |        4 | Security Island sha256 commit                                              |
| carfield.[`VERSION3`](#version3)                                             | 0xc      |        4 | PULP Cluster sha256 commit                                                 |
| carfield.[`VERSION4`](#version4)                                             | 0x10     |        4 | Spatz CLuster sha256 commit                                                |
| carfield.[`JEDEC_IDCODE`](#jedec_idcode)                                     | 0x14     |        4 | JEDEC ID CODE -TODO assign-                                                |
| carfield.[`GENERIC_SCRATCH0`](#generic_scratch0)                             | 0x18     |        4 | Scratch                                                                    |
| carfield.[`GENERIC_SCRATCH1`](#generic_scratch1)                             | 0x1c     |        4 | Scratch                                                                    |
| carfield.[`HOST_RST`](#host_rst)                                             | 0x20     |        4 | Host Domain reset -active high, inverted in HW-                            |
| carfield.[`PERIPH_RST`](#periph_rst)                                         | 0x24     |        4 | Periph Domain reset -active high, inverted in HW-                          |
| carfield.[`SECURITY_ISLAND_RST`](#security_island_rst)                       | 0x28     |        4 | Security Island reset -active high, inverted in HW-                        |
| carfield.[`PERIPH_ISOLATE`](#periph_isolate)                                 | 0x2c     |        4 | Periph Domain  AXI isolate                                                 |
| carfield.[`SECURITY_ISLAND_ISOLATE`](#security_island_isolate)               | 0x30     |        4 | Security Island AXI isolate                                                |
| carfield.[`PERIPH_ISOLATE_STATUS`](#periph_isolate_status)                   | 0x34     |        4 | Periph Domain AXI isolate status                                           |
| carfield.[`SECURITY_ISLAND_ISOLATE_STATUS`](#security_island_isolate_status) | 0x38     |        4 | Security Island AXI isolate status                                         |
| carfield.[`PERIPH_CLK_EN`](#periph_clk_en)                                   | 0x3c     |        4 | Periph Domain clk gate enable                                              |
| carfield.[`SECURITY_ISLAND_CLK_EN`](#security_island_clk_en)                 | 0x40     |        4 | Security Island clk gate enable                                            |
| carfield.[`PERIPH_CLK_SEL`](#periph_clk_sel)                                 | 0x44     |        4 | Periph Domain fll select (0 -> host fll, 1 -> periph fll, 2 -> secd fll)   |
| carfield.[`SECURITY_ISLAND_CLK_SEL`](#security_island_clk_sel)               | 0x48     |        4 | Security Island fll select (0 -> host fll, 1 -> periph fll, 2 -> secd fll) |
| carfield.[`PERIPH_CLK_DIV_VALUE`](#periph_clk_div_value)                     | 0x4c     |        4 | Periph Domain clk divider value                                            |
| carfield.[`SECURITY_ISLAND_CLK_DIV_VALUE`](#security_island_clk_div_value)   | 0x50     |        4 | Security Island clk divider value                                          |
| carfield.[`HOST_FETCH_ENABLE`](#host_fetch_enable)                           | 0x54     |        4 | Host Domain fetch enable                                                   |
| carfield.[`SECURITY_ISLAND_FETCH_ENABLE`](#security_island_fetch_enable)     | 0x58     |        4 | Security Island fetch enable                                               |
| carfield.[`HOST_BOOT_ADDR`](#host_boot_addr)                                 | 0x5c     |        4 | Host boot address                                                          |
| carfield.[`SECURITY_ISLAND_BOOT_ADDR`](#security_island_boot_addr)           | 0x60     |        4 | Security Island boot address                                               |
| carfield.[`HYPERBUS_CLK_DIV_EN`](#hyperbus_clk_div_en)                       | 0x64     |        4 | Hyperbus clock divider enable bit                                          |
| carfield.[`HYPERBUS_CLK_DIV_VALUE`](#hyperbus_clk_div_value)                 | 0x68     |        4 | Hyperbus clock divider value                                               |
| carfield.[`FLL_LOCK`](#fll_lock)                                             | 0x6c     |        4 | FLL lock status                                                            |
| carfield.[`HOST_DEBUG_CLK_EN`](#host_debug_clk_en)                           | 0x70     |        4 | Host domain debug clock divider (default active)                           |
| carfield.[`SECURED_DEBUG_CLK_EN`](#secured_debug_clk_en)                     | 0x74     |        4 | Secure domain debug clock divider (default active)                         |
| carfield.[`PERIPH_DEBUG_CLK_EN`](#periph_debug_clk_en)                       | 0x78     |        4 | Peripheral domain debug clock divider (default active)                     |
| carfield.[`HOST_DEBUG_CLK_DIV_VALUE`](#host_debug_clk_div_value)             | 0x7c     |        4 | Host Domain debug clk divider value                                        |
| carfield.[`SECURED_DEBUG_CLK_DIV_VALUE`](#secured_debug_clk_div_value)       | 0x80     |        4 | Secure Domain debug clk divider value                                      |
| carfield.[`PERIPH_DEBUG_CLK_DIV_VALUE`](#periph_debug_clk_div_value)         | 0x84     |        4 | Peripheral Domain debug clk divider value                                  |

## VERSION0
Cheshire sha256 commit
- Offset: `0x0`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "VERSION0", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |   0x0   | VERSION0 |               |

## VERSION1
Safety Island sha256 commit
- Offset: `0x4`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "VERSION1", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |   0x0   | VERSION1 |               |

## VERSION2
Security Island sha256 commit
- Offset: `0x8`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "VERSION2", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |   0x0   | VERSION2 |               |

## VERSION3
PULP Cluster sha256 commit
- Offset: `0xc`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "VERSION3", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |   0x0   | VERSION3 |               |

## VERSION4
Spatz CLuster sha256 commit
- Offset: `0x10`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "VERSION4", "bits": 32, "attr": ["ro"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:0  |   ro   |   0x0   | VERSION4 |               |

## JEDEC_IDCODE
JEDEC ID CODE -TODO assign-
- Offset: `0x14`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "JEDEC_IDCODE", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name         | Description   |
|:------:|:------:|:-------:|:-------------|:--------------|
|  31:0  |   rw   |   0x0   | JEDEC_IDCODE |               |

## GENERIC_SCRATCH0
Scratch
- Offset: `0x18`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "GENERIC_SCRATCH0", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name             | Description   |
|:------:|:------:|:-------:|:-----------------|:--------------|
|  31:0  |   rw   |   0x0   | GENERIC_SCRATCH0 |               |

## GENERIC_SCRATCH1
Scratch
- Offset: `0x1c`
- Reset default: `0x0`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "GENERIC_SCRATCH1", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name             | Description   |
|:------:|:------:|:-------:|:-----------------|:--------------|
|  31:0  |   rw   |   0x0   | GENERIC_SCRATCH1 |               |

## HOST_RST
Host Domain reset -active high, inverted in HW-
- Offset: `0x20`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HOST_RST", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 100}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:1  |        |         |          | Reserved      |
|   0    |   ro   |   0x0   | HOST_RST |               |

## PERIPH_RST
Periph Domain reset -active high, inverted in HW-
- Offset: `0x24`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_RST", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 120}}
```

|  Bits  |  Type  |  Reset  | Name       | Description   |
|:------:|:------:|:-------:|:-----------|:--------------|
|  31:1  |        |         |            | Reserved      |
|   0    |   rw   |   0x0   | PERIPH_RST |               |

## SECURITY_ISLAND_RST
Security Island reset -active high, inverted in HW-
- Offset: `0x28`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_RST", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 210}}
```

|  Bits  |  Type  |  Reset  | Name                | Description   |
|:------:|:------:|:-------:|:--------------------|:--------------|
|  31:1  |        |         |                     | Reserved      |
|   0    |   rw   |   0x0   | SECURITY_ISLAND_RST |               |

## PERIPH_ISOLATE
Periph Domain  AXI isolate
- Offset: `0x2c`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_ISOLATE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 160}}
```

|  Bits  |  Type  |  Reset  | Name           | Description   |
|:------:|:------:|:-------:|:---------------|:--------------|
|  31:1  |        |         |                | Reserved      |
|   0    |   rw   |   0x0   | PERIPH_ISOLATE |               |

## SECURITY_ISLAND_ISOLATE
Security Island AXI isolate
- Offset: `0x30`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_ISOLATE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 250}}
```

|  Bits  |  Type  |  Reset  | Name                    | Description   |
|:------:|:------:|:-------:|:------------------------|:--------------|
|  31:1  |        |         |                         | Reserved      |
|   0    |   rw   |   0x1   | SECURITY_ISLAND_ISOLATE |               |

## PERIPH_ISOLATE_STATUS
Periph Domain AXI isolate status
- Offset: `0x34`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_ISOLATE_STATUS", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 230}}
```

|  Bits  |  Type  |  Reset  | Name                  | Description   |
|:------:|:------:|:-------:|:----------------------|:--------------|
|  31:1  |        |         |                       | Reserved      |
|   0    |   rw   |   0x0   | PERIPH_ISOLATE_STATUS |               |

## SECURITY_ISLAND_ISOLATE_STATUS
Security Island AXI isolate status
- Offset: `0x38`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_ISOLATE_STATUS", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 320}}
```

|  Bits  |  Type  |  Reset  | Name                           | Description   |
|:------:|:------:|:-------:|:-------------------------------|:--------------|
|  31:1  |        |         |                                | Reserved      |
|   0    |   rw   |   0x0   | SECURITY_ISLAND_ISOLATE_STATUS |               |

## PERIPH_CLK_EN
Periph Domain clk gate enable
- Offset: `0x3c`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_CLK_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 150}}
```

|  Bits  |  Type  |  Reset  | Name          | Description   |
|:------:|:------:|:-------:|:--------------|:--------------|
|  31:1  |        |         |               | Reserved      |
|   0    |   rw   |   0x1   | PERIPH_CLK_EN |               |

## SECURITY_ISLAND_CLK_EN
Security Island clk gate enable
- Offset: `0x40`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_CLK_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 240}}
```

|  Bits  |  Type  |  Reset  | Name                   | Description   |
|:------:|:------:|:-------:|:-----------------------|:--------------|
|  31:1  |        |         |                        | Reserved      |
|   0    |   rw   |   0x0   | SECURITY_ISLAND_CLK_EN |               |

## PERIPH_CLK_SEL
Periph Domain fll select (0 -> host fll, 1 -> periph fll, 2 -> secd fll)
- Offset: `0x44`
- Reset default: `0x0`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_CLK_SEL", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 160}}
```

|  Bits  |  Type  |  Reset  | Name           | Description   |
|:------:|:------:|:-------:|:---------------|:--------------|
|  31:2  |        |         |                | Reserved      |
|  1:0   |   rw   |   0x0   | PERIPH_CLK_SEL |               |

## SECURITY_ISLAND_CLK_SEL
Security Island fll select (0 -> host fll, 1 -> periph fll, 2 -> secd fll)
- Offset: `0x48`
- Reset default: `0x1`
- Reset mask: `0x3`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_CLK_SEL", "bits": 2, "attr": ["rw"], "rotate": -90}, {"bits": 30}], "config": {"lanes": 1, "fontsize": 10, "vspace": 250}}
```

|  Bits  |  Type  |  Reset  | Name                    | Description   |
|:------:|:------:|:-------:|:------------------------|:--------------|
|  31:2  |        |         |                         | Reserved      |
|  1:0   |   rw   |   0x1   | SECURITY_ISLAND_CLK_SEL |               |

## PERIPH_CLK_DIV_VALUE
Periph Domain clk divider value
- Offset: `0x4c`
- Reset default: `0x1`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_CLK_DIV_VALUE", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                 | Description   |
|:------:|:------:|:-------:|:---------------------|:--------------|
| 31:24  |        |         |                      | Reserved      |
|  23:0  |   rw   |   0x1   | PERIPH_CLK_DIV_VALUE |               |

## SECURITY_ISLAND_CLK_DIV_VALUE
Security Island clk divider value
- Offset: `0x50`
- Reset default: `0x1`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_CLK_DIV_VALUE", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                          | Description   |
|:------:|:------:|:-------:|:------------------------------|:--------------|
| 31:24  |        |         |                               | Reserved      |
|  23:0  |   rw   |   0x1   | SECURITY_ISLAND_CLK_DIV_VALUE |               |

## HOST_FETCH_ENABLE
Host Domain fetch enable
- Offset: `0x54`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HOST_FETCH_ENABLE", "bits": 1, "attr": ["ro"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 190}}
```

|  Bits  |  Type  |  Reset  | Name              | Description   |
|:------:|:------:|:-------:|:------------------|:--------------|
|  31:1  |        |         |                   | Reserved      |
|   0    |   ro   |   0x0   | HOST_FETCH_ENABLE |               |

## SECURITY_ISLAND_FETCH_ENABLE
Security Island fetch enable
- Offset: `0x58`
- Reset default: `0x0`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_FETCH_ENABLE", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 300}}
```

|  Bits  |  Type  |  Reset  | Name                         | Description   |
|:------:|:------:|:-------:|:-----------------------------|:--------------|
|  31:1  |        |         |                              | Reserved      |
|   0    |   rw   |   0x0   | SECURITY_ISLAND_FETCH_ENABLE |               |

## HOST_BOOT_ADDR
Host boot address
- Offset: `0x5c`
- Reset default: `0x1000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "HOST_BOOT_ADDR", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name           | Description   |
|:------:|:------:|:-------:|:---------------|:--------------|
|  31:0  |   rw   | 0x1000  | HOST_BOOT_ADDR |               |

## SECURITY_ISLAND_BOOT_ADDR
Security Island boot address
- Offset: `0x60`
- Reset default: `0x70000000`
- Reset mask: `0xffffffff`

### Fields

```wavejson
{"reg": [{"name": "SECURITY_ISLAND_BOOT_ADDR", "bits": 32, "attr": ["rw"], "rotate": 0}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |   Reset    | Name                      | Description   |
|:------:|:------:|:----------:|:--------------------------|:--------------|
|  31:0  |   rw   | 0x70000000 | SECURITY_ISLAND_BOOT_ADDR |               |

## HYPERBUS_CLK_DIV_EN
Hyperbus clock divider enable bit
- Offset: `0x64`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HYPERBUS_CLK_DIV_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 210}}
```

|  Bits  |  Type  |  Reset  | Name                | Description   |
|:------:|:------:|:-------:|:--------------------|:--------------|
|  31:1  |        |         |                     | Reserved      |
|   0    |   rw   |   0x1   | HYPERBUS_CLK_DIV_EN |               |

## HYPERBUS_CLK_DIV_VALUE
Hyperbus clock divider value
- Offset: `0x68`
- Reset default: `0x1`
- Reset mask: `0xfffff`

### Fields

```wavejson
{"reg": [{"name": "HYPERBUS_CLK_DIV_VALUE", "bits": 20, "attr": ["rw"], "rotate": 0}, {"bits": 12}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                   | Description   |
|:------:|:------:|:-------:|:-----------------------|:--------------|
| 31:20  |        |         |                        | Reserved      |
|  19:0  |   rw   |   0x1   | HYPERBUS_CLK_DIV_VALUE |               |

## FLL_LOCK
FLL lock status
- Offset: `0x6c`
- Reset default: `0x0`
- Reset mask: `0x1f`

### Fields

```wavejson
{"reg": [{"name": "FLL_LOCK", "bits": 5, "attr": ["ro"], "rotate": 0}, {"bits": 27}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name     | Description   |
|:------:|:------:|:-------:|:---------|:--------------|
|  31:5  |        |         |          | Reserved      |
|  4:0   |   ro   |   0x0   | FLL_LOCK |               |

## HOST_DEBUG_CLK_EN
Host domain debug clock divider (default active)
- Offset: `0x70`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "HOST_DEBUG_CLK_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 190}}
```

|  Bits  |  Type  |  Reset  | Name              | Description   |
|:------:|:------:|:-------:|:------------------|:--------------|
|  31:1  |        |         |                   | Reserved      |
|   0    |   rw   |   0x1   | HOST_DEBUG_CLK_EN |               |

## SECURED_DEBUG_CLK_EN
Secure domain debug clock divider (default active)
- Offset: `0x74`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "SECURED_DEBUG_CLK_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 220}}
```

|  Bits  |  Type  |  Reset  | Name                 | Description   |
|:------:|:------:|:-------:|:---------------------|:--------------|
|  31:1  |        |         |                      | Reserved      |
|   0    |   rw   |   0x1   | SECURED_DEBUG_CLK_EN |               |

## PERIPH_DEBUG_CLK_EN
Peripheral domain debug clock divider (default active)
- Offset: `0x78`
- Reset default: `0x1`
- Reset mask: `0x1`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_DEBUG_CLK_EN", "bits": 1, "attr": ["rw"], "rotate": -90}, {"bits": 31}], "config": {"lanes": 1, "fontsize": 10, "vspace": 210}}
```

|  Bits  |  Type  |  Reset  | Name                | Description   |
|:------:|:------:|:-------:|:--------------------|:--------------|
|  31:1  |        |         |                     | Reserved      |
|   0    |   rw   |   0x1   | PERIPH_DEBUG_CLK_EN |               |

## HOST_DEBUG_CLK_DIV_VALUE
Host Domain debug clk divider value
- Offset: `0x7c`
- Reset default: `0xa`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "HOST_DEBUG_CLK_DIV_VALUE", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                     | Description   |
|:------:|:------:|:-------:|:-------------------------|:--------------|
| 31:24  |        |         |                          | Reserved      |
|  23:0  |   rw   |   0xa   | HOST_DEBUG_CLK_DIV_VALUE |               |

## SECURED_DEBUG_CLK_DIV_VALUE
Secure Domain debug clk divider value
- Offset: `0x80`
- Reset default: `0xa`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "SECURED_DEBUG_CLK_DIV_VALUE", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                        | Description   |
|:------:|:------:|:-------:|:----------------------------|:--------------|
| 31:24  |        |         |                             | Reserved      |
|  23:0  |   rw   |   0xa   | SECURED_DEBUG_CLK_DIV_VALUE |               |

## PERIPH_DEBUG_CLK_DIV_VALUE
Peripheral Domain debug clk divider value
- Offset: `0x84`
- Reset default: `0xa`
- Reset mask: `0xffffff`

### Fields

```wavejson
{"reg": [{"name": "PERIPH_DEBUG_CLK_DIV_VALUE", "bits": 24, "attr": ["rw"], "rotate": 0}, {"bits": 8}], "config": {"lanes": 1, "fontsize": 10, "vspace": 80}}
```

|  Bits  |  Type  |  Reset  | Name                       | Description   |
|:------:|:------:|:-------:|:---------------------------|:--------------|
| 31:24  |        |         |                            | Reserved      |
|  23:0  |   rw   |   0xa   | PERIPH_DEBUG_CLK_DIV_VALUE |               |

