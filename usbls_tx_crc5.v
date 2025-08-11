

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
