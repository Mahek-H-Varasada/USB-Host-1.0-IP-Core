

module usbls_tx_addr_endp_inv (
    input  [0:10] addr_endp,
    output [10:0] endp_addr
);

  assign endp_addr = {
    addr_endp[10],
    addr_endp[9],
    addr_endp[8],
    addr_endp[7],
    addr_endp[6],
    addr_endp[5],
    addr_endp[4],
    addr_endp[3],
    addr_endp[2],
    addr_endp[1],
    addr_endp[0]
  };

endmodule
