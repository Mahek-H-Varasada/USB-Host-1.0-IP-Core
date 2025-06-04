//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_addr_endp_inv
// Module Name:     usbls_tx_addr_endp_inv.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    reverse the address,endpoint(11 bits) to endpoint,address  
// 
// Dependencies: 
// 
// Version:
//    1.0 - 02/04/2025 - MKV - Initial release
// 
// Additional Comments: 
//  
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

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
