

module usbls_tx_top(
	input        clk,
	input        tx_en,
	input        handshake,
	input        data,
	input        token,
	input        out,
	input        in,
	input        setup,
	input        data_s,
	input        string,
	input        endpoint,
	input        interface,
	input        device,
	input        configu,
	input        set_addr,
	input        set_config,
	input        set_idle,
	input        hid,
    input        set_report,
	input        crc_c,
	input        keep_alive,
	input  [0:10] addr_endp,
    input        make_reset,
	output       dp_OUT,
	output       dn_OUT,
	output       dp_OE,
	output       dn_OE,
	output       EOP
);

	// wire [0:10]addr_endp=11'b10000000000;   //mg_tx 0100000 0100
	wire [10:0]  endp_addr;  // crc5  0010 0000010
	wire [0:63]  data_me;
	wire [63:0]  data_me_in;
	wire [0:7]   pid;
	wire [15:0]  crc16;
	wire [4:0]   crc5;
	wire         t_f_o, d_f_o, o_f_o, o1_f_o, h_f_o;
	wire [0:95]  d_m_o;
	wire [0:31]  t_m_o, o_m_o;
    wire [0:40]  o1_m_o;
	wire [0:15]  h_m_o;

	usbls_tx_addr_endp_inv uai(
		.addr_endp (addr_endp),
		.endp_addr (endp_addr)
	);

	usbls_tx_data udt(
		.data       (data),
		.setup      (setup),
		.set_addr   (set_addr),
		.configu    (configu),
		.device     (device),
		.interface  (interface),
		.endpoint   (endpoint),
		.string     (string),
		.set_config (set_config),
		.set_idle   (set_idle),
		.hid        (hid),
        .set_report (set_report),
		.data_me    (data_me),
		.data_me_in (data_me_in)
	);

	usbls_tx_pid_gen upt(
		.crc_c      (crc_c),
        .set_report (set_report),
		.set_config (set_config),
		.set_idle   (set_idle),
		.set_addr   (set_addr),
		.configu    (configu),
		.device     (device),
		.interface  (interface),
		.endpoint   (endpoint),
		.string     (string),
		.data_s     (data_s),
		.hid        (hid),
		.setup      (setup),
		.in         (in),
		.out        (out),
		.token      (token),
		.data       (data),
		.handshake  (handshake),
		.pid        (pid)
	);

	usbls_crc16_top uc16(
		.clk       (clk),
		.data_in   (data_me_in),
		.byte_size (4'b1000),
		.crc_out   (crc16)
	);

	usbls_tx_crc5 uc5(
		.data    (endp_addr),
		.crc_out (crc5)
	);

	usbls_tx_msg_gen umt(
		.set_addr   (set_addr),
		.configu    (configu),
        .set_report (set_report),
		.set_config (set_config),
		.set_idle   (set_idle),
		.device     (device),
		.interface  (interface),
		.endpoint   (endpoint),
		.string     (string),
		.data_s     (data_s),
		.hid        (hid),
		.setup      (setup),
		.in         (in),
		.out        (out),
		.token      (token),
		.data       (data),
		.handshake  (handshake),
		.crc5       (crc5),
		.crc16      (crc16),
		.data_me    (data_me),
		.addr_endp  (addr_endp),
		.pid        (pid),
		.t_m_o      (t_m_o),
		.d_m_o      (d_m_o),
		.h_m_o      (h_m_o),
		.o_m_o      (o_m_o),
        .o1_m_o     (o1_m_o),
		.t_f_o      (t_f_o),
		.d_f_o      (d_f_o),
		.h_f_o      (h_f_o),
		.o_f_o      (o_f_o),
        .o1_f_o     (o1_f_o)
	);

	usbls_tx_dp_dn ut(
		.clk        (clk),
		.tx_en      (tx_en),
		.t_m        (t_m_o),
		.h_m        (h_m_o),
		.d_m        (d_m_o),
		.o_m        (o_m_o),
        .o1_m       (o1_m_o),
		.t_f        (t_f_o),
		.o_f        (o_f_o),
        .o1_f       (o1_f_o),
		.d_f        (d_f_o),
		.h_f        (h_f_o),
        .make_reset (make_reset),
		.keep_alive (keep_alive),
		.dp_OUT     (dp_OUT),
		.dn_OUT     (dn_OUT),
		.dp_OE      (dp_OE),
		.dn_OE      (dn_OE),
		.EOP        (EOP)
	);

endmodule
