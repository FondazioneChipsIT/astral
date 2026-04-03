# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#

export NO_STANDALONE=1

# set up environment variables for rtl simulation
ROOTD=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
[[ -d "$ROOTD/opentitan/sw/tests/pulp-runtime" ]] && source "$ROOTD//opentitan/sw/tests/pulp-runtime/configs/opentitan-cluster.sh"
