# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

reset:
	$(MAKE) set_vio VIO_PROBE=reset PROJECT_NAME=$(PROJECT_NAME) USB_SERIAL=$(USB_SERIAL)

boot_jtag:
	$(MAKE) set_vio VIO_COMMAND=jtag VIO_PROBE=vio_boot_mode PROJECT_NAME=$(PROJECT_NAME) USB_SERIAL=$(USB_SERIAL)

boot_spi:
	$(MAKE) set_vio VIO_COMMAND=spi VIO_PROBE=vio_boot_mode PROJECT_NAME=$(PROJECT_NAME) USB_SERIAL=$(USB_SERIAL)

hash:
	$(MAKE) set_vio VIO_PROBE=git_hash PROJECT_NAME=$(PROJECT_NAME) USB_SERIAL=$(USB_SERIAL)