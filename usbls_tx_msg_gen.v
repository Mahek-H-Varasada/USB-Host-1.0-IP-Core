//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_msg_gen
// Module Name:     usbls_tx_msg_gen.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    This module concentate whole transmit message based upon input flag selection
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

module usbls_tx_msg_gen(
    input              set_report,
	input              set_idle,
	input              set_config,
	input              set_addr,
	input              configu,
	input              device,
	input              interface,
	input              endpoint,
	input              string,
	input              data_s,
	input              hid,
	input              setup,
	input              in,
	input              out,
	input              token,
	input              data,
	input              handshake,
	input      [4:0]   crc5,
	input      [15:0]  crc16,
	input      [0:63]  data_me,
	input      [0:10]  addr_endp,
	input      [0:7]   pid,
	output     [0:31]  t_m_o,
	output     [0:95]  d_m_o,
	output     [0:15]  h_m_o,
	output     [0:31]  o_m_o,
    output     [0:40]  o1_m_o,
	output             t_f_o,
	output             d_f_o,
	output             h_f_o,
	output             o_f_o,
    output             o1_f_o
);

	reg        [0:7]   sync;
	reg        [0:31]  t_m = 32'b0;
	reg        [0:95]  d_m = 96'b0;
	reg        [0:15]  h_m = 16'b0;
	reg        [0:31]  o_m = 32'b0;
    reg        [0:39]  o1_m= 40'b0; 
	reg                t_f = 1'b0;
	reg                d_f = 1'b0;
	reg                h_f = 1'b0;
	reg                o_f = 1'b0;
    reg                o1_f = 1'b0;

	always @(*) begin
		sync = 8'b00000001;
		// message
		t_m <= 32'b0;
		d_m <= 96'b0;
		h_m <= 16'b0;
		o_m <= 32'b0;
        o1_m <= 41'b0;
		// flags
		t_f <= 0;
		d_f <= 0;
		h_f <= 0;
		o_f <= 0;
        o1_f <= 0;

		if (token == 1 && 
			(set_addr == 1 || device == 1 || configu == 1 || interface == 1 || 
			 endpoint == 1 || string == 1 || hid == 1 || data_s == 1 || 
			 set_config == 1 || set_idle == 1 || set_report == 1) && 
			(setup == 1 || in == 1 || out == 1)) begin
			t_m <= {sync, pid, addr_endp, crc5[0], crc5[1], crc5[2], 
					crc5[3], crc5[4]};
			t_f <= 1;
		end
		else if (data == 1 && 
				 (set_addr == 1 || device == 1 || configu == 1 || 
				  interface == 1 || endpoint == 1 || string == 1 || 
				  hid == 1 || set_config == 1 || set_idle == 1||set_report ==1) && 
				 setup == 1) begin
			d_m <= {sync, pid, data_me, crc16[0], crc16[1], crc16[2], 
					crc16[3], crc16[4], crc16[5], crc16[6], crc16[7], 
					crc16[8], crc16[9], crc16[10], crc16[11], crc16[12], 
					crc16[13], crc16[14], crc16[15]};
			d_f <= 1;
		end
		else if (data == 1 && 
				 (device == 1 || configu == 1 || interface == 1 || 
				  endpoint == 1 || string == 1 || hid == 1) && 
				 out == 1) begin
			o_m <= {sync, pid, 16'b0};
			o_f <= 1;
		end
        else if (data == 1 &&              
				 (set_report ==1) && 
				 out == 1) begin                             //set_report
			o1_m <= {sync, pid, 8'b0,17'b00000010111111001};
			o1_f <= 1;
		end
		else if (handshake == 1 && 
				 (set_addr == 1 || device == 1 || configu == 1 || 
				  interface == 1 || endpoint == 1 || string == 1 || 
				  hid == 1 || set_config == 1 || set_idle == 1 || 
				  data_s == 1 || set_report == 1) && 
				 in == 1) begin
			h_m <= {sync, pid};
			h_f <= 1;
		end
	end

	assign t_m_o = t_m;
	assign d_m_o = d_m;
	assign h_m_o = h_m;
	assign o_m_o = o_m;
    assign o1_m_o = o1_m;
	assign t_f_o = t_f;
	assign d_f_o = d_f;
	assign h_f_o = h_f;
	assign o_f_o = o_f;
    assign o1_f_o =o1_f;
endmodule