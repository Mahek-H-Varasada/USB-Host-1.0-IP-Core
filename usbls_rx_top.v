

module usbls_rx_top(
	input              clk,
	input              dp_IN,
	input              dn_IN,
	input              dp_OE,
	input              dn_OE,
	input              rx_en,
	output             sync_flag,
	output      [3:0]  pid_flag,          // {DATA0,DATA1,ACK,NAK} gets 1 as detected
	output      [7:0]  pid,
	output      [15:0] crcdata,
	output      [63:0] data,
	output      [3:0]  byte_size,
	output             receive_complete,
	output reg         eop_flag
);

// Receiver Module ---------------------------------------------------------------------------------------
reg        r_dp_last      = 1'b1;
reg        ri_dp_last     = 1'b1;
reg  [7:0] r_rxd          = 8'b01111111;
reg        bit_unstuff    = 1'b0;
reg  [2:0] unstuff_cnt    = 0;
reg        sample_unstuff;
reg        sample_unstuff2;

always @(posedge clk)
if (rx_en) begin
	if (r_rxd[7] == 1'b1) begin // rxd[7] = 1
		unstuff_cnt = unstuff_cnt + 1;
		if (unstuff_cnt == 3'b110) begin // count till 6 ones
			bit_unstuff = 1;
			unstuff_cnt = 3'b000;
		end else begin
			bit_unstuff = 0;
		end
	end else begin // rxd[7] = 0
		unstuff_cnt = 3'b000;
		bit_unstuff = 0;
	end
end else begin
	unstuff_cnt = 3'b000;
	bit_unstuff = 0;
end

always @(posedge clk)
begin
	if (rx_en) begin
		if (state_flag_fsm == DATA) begin
			r_rxd = 8'b01111111;
		end else begin
			if (dp_OE || dn_OE) begin
				r_dp_last = 1'b1;
			end else begin
				case (r_dp_last ^ dp_IN)
					0: begin
						r_rxd <= {1'b1, r_rxd[7:1]};
					end
					1: begin
						r_rxd <= {1'b0, r_rxd[7:1]};
					end
				endcase
				r_dp_last <= dp_IN;
				eop_flag  = (!dp_IN && !dn_IN) ? 1'b1 : 1'b0;
			end
		end
	end else begin
		eop_flag = 1'b0;
        r_rxd          = 8'b01111111;
	end
end

// Main FSM ---------------------------------------------------------------------------------------------

reg  [2:0] state_flag_fsm   = 3'b001;
reg        wait_check_fsm   = 1'b0;
reg        r_sync_flag;
reg        sync_cnt         = 1'b0;
reg  [3:0] r_pid_flag; // {DATA0,DATA1,ACK,NAK} gets 1 as detected
reg  [2:0] cnt              = 3'b000; // count till 8 after sync detected for complete PID
integer    cnt2             = 0;
reg  [7:0] r_pid;
reg  [15:0] r_crcdata;
reg  [63:0] r_data;
reg  [3:0] r_byte_size;
reg  [79:0] r_combdata;
reg        r_receive_complete;
integer    i;

// state_flag fsm Parameters
localparam WAIT2 = 3'b000;
localparam SYNC  = 3'b001;
localparam PID   = 3'b010;
localparam DATA  = 3'b011;

// wait_check_fsm fsm Parameters
localparam WAIT  = 1'b0;
localparam CHECK = 1'b1;

always @(posedge clk)
begin
	if (rx_en) begin
		if (dp_OE || dn_OE) begin
			r_pid_flag      = 4'b0000;
			wait_check_fsm  <= WAIT;
			state_flag_fsm  <= SYNC;
		end else begin
			case (state_flag_fsm)
				SYNC: begin
					wait_check_fsm <= WAIT;
					if (r_rxd == 8'b10000000 && eop_flag == 1'b0) begin
						r_sync_flag     <= 1'b1;
                        r_crcdata       = 15'b0;
						cnt2            = 0;
						r_pid_flag      = 4'b0000;
						r_byte_size     = 4'b0000;
						cnt             = 3'b000;
						r_combdata      = 80'b0;
                        r_data          = 64'b0;
						state_flag_fsm  <= PID;
					end else begin
						r_sync_flag     <= 1'b0;
						state_flag_fsm  <= SYNC;
					end
				end
				PID: begin
					r_sync_flag <= 1'b0;
					case (wait_check_fsm)
						WAIT: begin
							if (cnt == 3'b111) begin // count till 8 after sync detected for complete PID
								wait_check_fsm <= CHECK;
								r_pid          <= r_rxd; // store pid in diff. reg
								state_flag_fsm <= PID;
								cnt            = 3'b000;
							end else begin
								cnt            <= cnt + 1'b1;
								wait_check_fsm <= WAIT;
								state_flag_fsm <= PID;
							end
						end
						CHECK: begin
							case (r_pid)
								8'b11000011: begin // DATA0 (0011) r_pid = {~PID,PID}
									r_pid_flag = 4'b1000;
									if ((dp_IN == 1'b0) && (dn_IN == 1'b0) && (r_dp_last == 1'b0)) begin
										case (cnt2)
											79, 71, 63, 55, 47, 39, 31, 23, 15: begin
												r_combdata = {r_rxd[7], r_combdata[79:1]};
												state_flag_fsm <= DATA;
												wait_check_fsm <= WAIT;
												cnt2           = cnt2 + 1;
												r_crcdata      = r_combdata[79:64];
												r_data         = {r_combdata[7:0], r_combdata[15:8], 
																  r_combdata[23:16], r_combdata[31:24],
																  r_combdata[39:32], r_combdata[47:40], 
																  r_combdata[55:48], r_combdata[63:56]};
												r_byte_size    <= ((cnt2 - 16) / 8);
											end
											default: begin
												state_flag_fsm <= DATA;
												wait_check_fsm <= WAIT;
												r_crcdata      = r_combdata[79:64];
												r_data         = {r_combdata[7:0], r_combdata[15:8], 
																  r_combdata[23:16], r_combdata[31:24],
																  r_combdata[39:32], r_combdata[47:40], 
																  r_combdata[55:48], r_combdata[63:56]};
												r_byte_size    <= ((cnt2 - 16) / 8);
											end
										endcase
									end else begin
										if (!bit_unstuff) begin
											r_combdata[78:0] <= r_combdata[79:1]; // store data meanwhile
											r_combdata[79]   <= r_rxd[7];
											cnt2             <= cnt2 + 1'b1; // count cycles till EOP comes
											wait_check_fsm   <= CHECK;
											state_flag_fsm   <= PID;
										end else begin
											r_combdata <= r_combdata;
											cnt2       <= cnt2;
										end
									end
								end
								8'b01001011: begin // DATA1 (1011)
									r_pid_flag = 4'b0100;
									if ((dp_IN == 1'b0) && (dn_IN == 1'b0) && (r_dp_last == 1'b0)) begin
										case (cnt2)
											79, 71, 63, 55, 47, 39, 31, 23, 15: begin
												r_combdata = {r_rxd[7], r_combdata[79:1]};
												state_flag_fsm <= DATA;
												wait_check_fsm <= WAIT;
												cnt2           = cnt2 + 1;
												r_crcdata      = r_combdata[79:64];
												r_data         = {r_combdata[7:0], r_combdata[15:8], 
																  r_combdata[23:16], r_combdata[31:24],
																  r_combdata[39:32], r_combdata[47:40], 
																  r_combdata[55:48], r_combdata[63:56]};
												r_byte_size    <= ((cnt2 - 16) / 8);
											end
											default: begin
												state_flag_fsm <= DATA;
												wait_check_fsm <= WAIT;
												r_crcdata      = r_combdata[79:64];
												r_data         = {r_combdata[7:0], r_combdata[15:8], 
																  r_combdata[23:16], r_combdata[31:24],
																  r_combdata[39:32], r_combdata[47:40], 
																  r_combdata[55:48], r_combdata[63:56]};
												r_byte_size    <= ((cnt2 - 16) / 8);
											end
										endcase
									end else begin
										if (!bit_unstuff) begin
											r_combdata[78:0] <= r_combdata[79:1]; // store data meanwhile
											r_combdata[79]   <= r_rxd[7];
											cnt2             <= cnt2 + 1'b1; // count cycles till EOP comes
											wait_check_fsm   <= CHECK;
											state_flag_fsm   <= PID;
										end else begin
											r_combdata <= r_combdata;
											cnt2       <= cnt2;
										end
									end
								end
								8'b11010010: begin // ACK (0010)
									r_pid_flag      = 4'b0010;
									state_flag_fsm  <= SYNC;
									wait_check_fsm  <= WAIT;
								end
								8'b01011010: begin // NAK (1010)
									r_pid_flag      = 4'b0001;
									state_flag_fsm  <= SYNC;
									wait_check_fsm  <= WAIT;
								end
								default: begin
									r_pid_flag      = 4'b0000;
									state_flag_fsm  <= DATA;
								end
							endcase
						end
					endcase
				end
				DATA: begin
					r_crcdata          = r_combdata[79:64];
					r_data             = {r_combdata[7:0], r_combdata[15:8], 
										  r_combdata[23:16], r_combdata[31:24],
										  r_combdata[39:32], r_combdata[47:40], 
										  r_combdata[55:48], r_combdata[63:56]};
					r_byte_size        <= ((cnt2 - 16) / 8);
					r_receive_complete = 1'b1;
					r_pid              = 8'b00000000;
					r_receive_complete = (!dp_IN && !dn_IN) ? 1'b1 : 1'b0;
					state_flag_fsm     <= SYNC;
					wait_check_fsm     <= WAIT;
				end
				default: state_flag_fsm <= SYNC;
			endcase
		end
	end else begin
		wait_check_fsm <= WAIT;
		state_flag_fsm <= SYNC;
	end
end

assign sync_flag        = r_sync_flag;
assign pid_flag         = r_pid_flag;
assign pid              = r_pid;
assign crcdata          = r_crcdata;
assign data             = r_data;
assign byte_size        = r_byte_size;
assign receive_complete = r_receive_complete;

endmodule
