//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_pid_gen
// Module Name:     usbls_tx_pid_gen.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    This module selects appropriate PID based on Input flags
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
module usbls_tx_pid_gen(
	input              crc_c,
    input              set_report,
	input              set_config,
	input              set_idle,
	input              set_addr,
	input              configu,
	input              device,
	input              interface,
	input              endpoint,
	input              string,
	input              hid,
	input              data_s,
	input              setup,
	input              in,
	input              out,
	input              token,
	input              data,
	input              handshake,
	output     [0:7]   pid
);

reg [0:7] pid_r = 8'b0;

always @(*) begin
	if (token == 1 && setup == 1 && 
		(set_addr == 1 || device == 1 || configu == 1 || 
		 interface == 1 || endpoint == 1 || string == 1 || 
		 hid == 1 || set_config == 1 || set_idle == 1 || set_report == 1)) begin
		pid_r = 8'b10110100;
	end
	else if (token == 1 && in == 1 && 
			 (set_addr == 1 || device == 1 || configu == 1 || 
			  interface == 1 || endpoint == 1 || string == 1 || 
			  data_s == 1 || hid == 1 || set_config == 1 || 
			  set_idle == 1 || set_report ==1)) begin
		pid_r = 8'b10010110;
	end
	else if (token == 1 && out == 1 && 
			 (device == 1 || configu == 1 || interface == 1 || 
			  endpoint == 1 || hid == 1 || string == 1 || set_report ==1)) begin
		pid_r = 8'b10000111;
	end
	else if (data == 1 && setup == 1 && 
			 (set_addr == 1 || device == 1 || configu == 1 || 
			  interface == 1 || endpoint == 1 || string == 1 || 
			  hid == 1 || set_config == 1 || set_idle == 1 || set_report ==1 )) begin
		pid_r = 8'b11000011;
	end
	else if (data == 1 && out == 1 && 
			 (device == 1 || configu == 1 || interface == 1 || 
			  endpoint == 1 || string == 1 || hid == 1 || set_report ==1)) begin
		pid_r = 8'b11010010;
	end
	else if (handshake == 1 && crc_c == 1 && in == 1 && 
			 (set_addr == 1 || device == 1 || configu == 1 || 
			  interface == 1 || endpoint == 1 || string == 1 || 
			  data_s == 1 || hid == 1 || set_config == 1 || 
			  set_idle == 1 || set_report == 1)) begin
		pid_r = 8'b01001011;
	end
	else if (handshake == 1 && crc_c == 0 && in == 1 && 
			 (set_addr == 1 || device == 1 || configu == 1 || 
			  interface == 1 || endpoint == 1 || string == 1 || 
			  hid == 1 || data_s == 1 || set_config == 1 || 
			  set_idle == 1 || set_report ==1)) begin
		pid_r = 8'b01011010;
	end
	else begin
		pid_r = 8'b0;
	end
end

assign pid = pid_r;

endmodule
