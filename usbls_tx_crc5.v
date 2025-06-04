//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_crc5
// Module Name:     usbls_tx_crc5.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    This module calculates USB CRC5 on 11 bits inputs    
// 
// Dependencies: 
// 
// Version:
//    1.0 - 02/04/2025 - MKV - Initial release
// 
// Additional Comments: 
//   input data is {endpoint(4 bits), address(7 bits)} 
//   ex:- endpt = 0x02 , address = 0x01 then input is  0010_0000001 ans is 0x18(11000)
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module usbls_tx_crc5 (
	input  [10:0] data,    // 11-bit input data
	output [4:0]  crc_out  // 5-bit CRC output
);
	wire [4:0] initial_crc;
	assign initial_crc = 5'b11111;
	wire [4:0] crc_shift [11:0]; // Store intermediate CRC values
	assign crc_shift[0] = initial_crc;
	genvar i;
	generate
		for (i = 0; i < 11; i = i + 1) begin : crc_calc
			assign crc_shift[i+1] = (data[i] ^ crc_shift[i][0]) ?
									(crc_shift[i] >> 1) ^ 5'b10100 :
									(crc_shift[i] >> 1);
		end
	endgenerate
	assign crc_out = (crc_shift[11] ^ 5'b11111); // Final XOR correction
endmodule