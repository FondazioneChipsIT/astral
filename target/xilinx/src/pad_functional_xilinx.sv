// Copyright 2018 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module pad_functional_pd
(
   input  logic             OEN,
   input  logic             I,
   output logic             O,
   input  logic             PEN,
   inout  logic             PAD
);
  
  (* PULLDOWN = "YES" *)
  IOBUF iobuf_i (
    .T ( OEN ),
    .I ( I    ),
    .O ( O    ),
    .IO( PAD  )
  );

endmodule

module pad_functional_pu
(
   input  logic             OEN,
   input  logic             I,
   output logic             O,
   input  logic             PEN,
   inout  logic             PAD
);

  (* PULLUP = "YES" *)
  IOBUF iobuf_i (
    .T ( OEN ),
    .I ( I    ),
    .O ( O    ),
    .IO( PAD  )
  );

endmodule