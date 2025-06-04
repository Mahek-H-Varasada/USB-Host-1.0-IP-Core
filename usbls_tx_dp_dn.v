//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_dp_dn
// Module Name:     usbls_tx_dp_dn.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    This module transmits the message in NRZI encoded format at dp,dn lines.  
// 
// Dependencies: 
// 
// Version:
//    1.0 - 02/04/2025 - MKV - Initial release
// 
// Additional Comments: 
//  currently bit stuffing is done mannually for this module. 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------
module usbls_tx_dp_dn(
	input        clk,
	input        tx_en,
	input        keep_alive,
	input  [0:31] t_m,
	input  [0:95] d_m,
	input  [0:31] o_m,
    input  [0:40] o1_m,
	input  [0:15] h_m,
	input        t_f,
	input        d_f,
	input        o_f,
    input        o1_f,
	input        h_f,
    input        make_reset,
	output reg   dp_OUT = 1'b0,
	output reg   dn_OUT = 1'b1,
	output reg   dp_OE,
	output reg   dn_OE,
	output reg   EOP
);
	integer i = 0;
	integer j = 0;
	integer kcnt = 1'b0;

	always @(posedge clk) begin
		if (tx_en == 1) begin
			EOP = 0;
        if(make_reset == 1) begin
            dp_OE = 1;
		    dn_OE = 1;
			dp_OUT = 1'b0;
			dn_OUT = 1'b0;
		end else if (t_f == 1) begin
				if (i < 32) begin
					if (t_m[i] == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = dp_OUT;
						dn_OUT = dn_OUT;
					end else if (t_m[i] == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = ~dp_OUT;
						dn_OUT = ~dn_OUT;
					end
					i = i + 1;
				end else if (i == 32) begin
					if (j == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						j = j + 1;
						i = 32;
					end else if (j == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						EOP = 1;
						j = j + 1;
					end else if (j == 2) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 1;
						j = 0;
						i = 0;
					end
				end
                
			end else if (d_f == 1) begin
				if (i < 96) begin
					if (d_m[i] == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = dp_OUT;
						dn_OUT = dn_OUT;
					end else if (d_m[i] == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = ~dp_OUT;
						dn_OUT = ~dn_OUT;
					end
					i = i + 1;
				end else if (i == 96) begin
					if (j == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						j = j + 1;
						i = 96;
					end else if (j == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						EOP = 1;
						j = j + 1;
					end else if (j == 2) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 1;
						j = 0;
						i = 0;
					end
				end
			end else if (h_f == 1) begin
				if (i < 16) begin
					if (h_m[i] == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = dp_OUT;
						dn_OUT = dn_OUT;
					end else if (h_m[i] == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = ~dp_OUT;
						dn_OUT = ~dn_OUT;
					end
					i = i + 1;
				end else if (i == 16) begin
					if (j == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						j = j + 1;
						i = 16;
					end else if (j == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						EOP = 1;
						j = j + 1;
					end else if (j == 2) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 1;
						j = 0;
						i = 0;
					end
				end
             end else if (o1_f == 1) begin
				if (i < 41) begin
					if (o1_m[i] == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = dp_OUT;
						dn_OUT = dn_OUT;
					end else if (o1_m[i] == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = ~dp_OUT;
						dn_OUT = ~dn_OUT;
					end
					i = i + 1;
				end else if (i == 41) begin
					if (j == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						j = j + 1;
						i = 40;
					end else if (j == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						EOP = 1;
						j = j + 1;
					end else if (j == 2) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 1;
						j = 0;
						i = 0;
					end
				end   
			end else if (o_f == 1) begin
				if (i < 32) begin
					if (o_m[i] == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = dp_OUT;
						dn_OUT = dn_OUT;
					end else if (o_m[i] == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = ~dp_OUT;
						dn_OUT = ~dn_OUT;
					end
					i = i + 1;
				end else if (i == 32) begin
					if (j == 0) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						j = j + 1;
						i = 32;
					end else if (j == 1) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 0;
						EOP = 1;
						j = j + 1;
					end else if (j == 2) begin
						dp_OE = 1;
						dn_OE = 1;
						dp_OUT = 0;
						dn_OUT = 1;
						j = 0;
						i = 0;
					end
				end
			end else begin
				dp_OE = 1;
				dn_OE = 1;
				dp_OUT = 0;
				dn_OUT = 1;
				j = 0;
				i = 0;
			end
		end else if (tx_en == 0) begin
			if (keep_alive) begin
				if (kcnt < 2) begin
					dp_OE = 1;
					dn_OE = 1;
					dp_OUT = 0;
					dn_OUT = 0;
					kcnt = kcnt + 1;
				end else if (kcnt == 2) begin
					dp_OE = 1;
					dn_OE = 1;
					dp_OUT = 0;
					dn_OUT = 1;
					kcnt = 0;
					j = 0;
					i = 0;
				end
			end else if (!keep_alive) begin
				dp_OE = 0;
				dn_OE = 0;
				kcnt = 0;
				i = 0;
				j = 0;
			end
		end
	end
endmodule
