//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Mahekkumar Varasada <mahekvarasada@gmail.com>
// 
// Create Date:     April 2, 2025
// Design Name:     usbls_tx_data
// Module Name:     usbls_tx_data.v
// Project:         PeriPlex
// Target Device:   Trion T120F324
// Tool Versions:   Efinix Efinity 2024.2 
// 
// Description: 
//    This module is data bank for various descriptor setup gets selected based on input flags
// 
// Dependencies: 
// 
// Version:
//    1.0 - 02/04/2025 - MKV - Initial release
// 
// Additional Comments: 
//   later this module wil receive data from linux drivers. 
// 
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2024
//-----------------------------------------------------------------------------

module usbls_tx_data(
	input        data,
	input        setup,
	input        set_addr,
	input        configu,
	input        device,
	input        interface,
	input        endpoint,
	input        string,
	input        set_config,
	input        set_idle,
	input        hid,
    input        set_report,
	output [0:63] data_me,
	output [63:0] data_me_in
);

	reg [0:63] data_m    = 64'b0;
	reg [63:0] data_m_in = 64'b0;

	always @(*) begin
        data_m=64'b0;
        data_m_in=64'b0;
        if(data==1 && setup==1 && set_addr==1)begin
            data_m<=64'b00000000_10100000_10000000_00000000_00000000_00000000_00000000_00000000;
            data_m_in<=64'b00000000_00000101_00000001_00000000_00000000_00000000_00000000_00000000;
        end
        else if(data==1 && setup==1 && device==1)begin
            data_m<=64'b00000001_01100000_00000000_10000000_00000000_00000000_01001000_00000000;
            data_m_in<=64'b10000000_00000110_00000000_00000001_00000000_00000000_00010010_00000000;
        end
        else if(data==1 && setup==1 && configu==1)begin
            data_m<=64'b00000001_01100000_00000000_01000000_00000000_00000000_10010000_00000000;
            data_m_in<=64'b10000000_00000110_00000000_00000010_00000000_00000000_00001001_00000000;
        end
        else if(data==1 && setup==1 && interface==1)begin
            data_m<=64'b00000001_01100000_00000000_00100000_00000000_00000000_10010000_00000000;
            data_m_in<=64'b10000000_00000110_00000000_00000100_00000000_00000000_00001001_00000000;
        end
        else if(data==1 && setup==1 && endpoint==1)begin
            data_m<=64'b00000001_01100000_00000000_10100000_00000000_00000000_11100000_00000000;
            data_m_in<=64'b10000000_00000110_00000000_00000101_00000000_00000000_00000111_00000000;
        end
        else if(data==1 && setup==1 && string==1)begin
            data_m<=64'b00000001_01100000_00000000_11000000_00000000_00000000_00100000_00000000;
            data_m_in<=64'b10000000_00000110_00000000_00000011_00000000_00000000_00000100_00000000;
        end
        else if(data==1 && setup==1 && set_config==1)begin
            data_m<=64'b00000000_10010000_10000000_00000000_00000000_00000000_00000000_00000000;
            data_m_in<=64'b00000000_00001001_00000001_00000000_00000000_00000000_00000000_00000000;
        end
        else if(data==1 && setup==1 && set_idle==1)begin
            data_m<=64'b10000100_01010000_00000000_00000000_00000000_00000000_00000000_00000000;
            data_m_in<=64'b00100001_00001010_00000000_00000000_00000000_00000000_00000000_00000000;
        end
        else if(data==1 && setup==1 && hid==1)begin
            data_m<=64'b10000001_01100000_00000000_01000100_00000000_00000000_10000001_00000000;
            data_m_in<=64'b10000001_00000110_00000000_00100010_00000000_00000000_10000001_00000000;
        end
        else if(data==1 && setup==1 && set_report==1)begin
            data_m<=64'b10000100_10010000_00000000_01000000_00000000_00000000_10000000_00000000;
            data_m_in<=64'b00100001_00001001_00000000_00000010_00000000_00000000_00000001_00000000;
        end
        
        else begin
            data_m<=64'b0;
            data_m_in<=64'b0;
        end
    end
    assign data_me=data_m;
    assign data_me_in=data_m_in;
endmodule 