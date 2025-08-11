
module usbls_crc16_top (
	input           clk,
	input   [63:0]  data_in,
	input   [3:0]   byte_size,
	output  [15:0]  crc_out
);
	reg     [15:0]  crc_in_i = 16'hFFFF;
	reg     [7:0]   din_i;
	reg     [7:0]   data[7:0];
	reg     [15:0]  crc_out_o;
	integer         i = 0;
	integer         j = 0;  
	reg     [2:0]   r;

	always @(posedge clk) begin
		r = (byte_size - 3'b001); 
		
		for (j = 0; j <= r; j = j + 1) begin
			data[j] = data_in[8 * (r - j) +: 8]; // data aligner 
		end 

		if (byte_size == 0) begin
			crc_out_o = 16'hFFFF;
		end else begin
			for (i = 0; i <= r; i = i + 1) begin  // Fixed loop condition
				din_i = data[i];
				crc_out_o[15] = din_i[0] ^ din_i[1] ^ din_i[2] ^ din_i[3] ^ 
								din_i[4] ^ din_i[5] ^ din_i[6] ^ din_i[7] ^ 
								crc_in_i[7] ^ crc_in_i[6] ^ crc_in_i[5] ^ 
								crc_in_i[4] ^ crc_in_i[3] ^ crc_in_i[2] ^ 
								crc_in_i[1] ^ crc_in_i[0];
				crc_out_o[14] = din_i[0] ^ din_i[1] ^ din_i[2] ^ din_i[3] ^ 
								din_i[4] ^ din_i[5] ^ din_i[6] ^ 
								crc_in_i[6] ^ crc_in_i[5] ^ crc_in_i[4] ^ 
								crc_in_i[3] ^ crc_in_i[2] ^ crc_in_i[1] ^ 
								crc_in_i[0];
				crc_out_o[13] = din_i[6] ^ din_i[7] ^ crc_in_i[7] ^ crc_in_i[6];
				crc_out_o[12] = din_i[5] ^ din_i[6] ^ crc_in_i[6] ^ crc_in_i[5];
				crc_out_o[11] = din_i[4] ^ din_i[5] ^ crc_in_i[5] ^ crc_in_i[4];
				crc_out_o[10] = din_i[3] ^ din_i[4] ^ crc_in_i[4] ^ crc_in_i[3];
				crc_out_o[9]  = din_i[2] ^ din_i[3] ^ crc_in_i[3] ^ crc_in_i[2];
				crc_out_o[8]  = din_i[1] ^ din_i[2] ^ crc_in_i[2] ^ crc_in_i[1];
				crc_out_o[7]  = din_i[0] ^ din_i[1] ^ crc_in_i[15] ^ 
								crc_in_i[1] ^ crc_in_i[0];
				crc_out_o[6]  = din_i[0] ^ crc_in_i[14] ^ crc_in_i[0];
				crc_out_o[5]  = crc_in_i[13];
				crc_out_o[4]  = crc_in_i[12];
				crc_out_o[3]  = crc_in_i[11];
				crc_out_o[2]  = crc_in_i[10];
				crc_out_o[1]  = crc_in_i[9];
				crc_out_o[0]  = din_i[0] ^ din_i[1] ^ din_i[2] ^ din_i[3] ^ 
								din_i[4] ^ din_i[5] ^ din_i[6] ^ din_i[7] ^ 
								crc_in_i[8] ^ crc_in_i[7] ^ crc_in_i[6] ^ 
								crc_in_i[5] ^ crc_in_i[4] ^ crc_in_i[3] ^ 
								crc_in_i[2] ^ crc_in_i[1] ^ crc_in_i[0];
				crc_in_i = crc_out_o;
			end
			crc_in_i = 16'hFFFF;  // Reset CRC after computation
		end
	end
	assign crc_out = ~crc_out_o;
endmodule
