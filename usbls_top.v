
module usbls_top(
    input  usbls_clk,
    input  usbls_dp_in,
    input  usbls_dn_in,
    output usbls_dp_out,
    output usbls_dn_out,
    output usbls_dp_oe,
    output usbls_dn_oe

    /* RX Signals */
    , output [63:0] usbls_data
    , output [ 3:0] byte_size
    , output        crc_c
    , output        status_led
);



  //-----------------------------------wires & Reg ---------------------------------
  /* control wires (prefix = wc-wire control module)*/
  wire           wc_DP_OE;
  wire           wc_DN_OE;
  wire    [63:0] wc_DATA;
  integer        reset_count;
  integer        cnt0;
  integer        cntk = 0;
  integer        cntk2 = 0;
  integer        i = 0;
  integer        cnt_nodata = 0;
  integer        dead_count = 0;

  /* TX reg (prefix = rt- reg transmitter module) */
  reg            rt_tx_en = 1'b0;
  //-------------packet----------------
  reg            rt_handshake = 1'b0;
  reg            rt_data = 1'b0;
  reg            rt_token = 1'b0;
  //-------------pid----------------
  reg            rt_out = 1'b0;
  reg            rt_in = 1'b0;
  reg            rt_setup = 1'b0;
  //------------descriptor----------------
  reg            rt_string = 1'b0;
  reg            rt_endpoint = 1'b0;
  reg            rt_interface = 1'b0;
  reg            rt_device = 1'b0;
  reg            rt_configu = 1'b0;
  reg            rt_set_addr = 1'b0;
  reg            rt_set_config = 1'b0;
  reg            rt_set_idle = 1'b0;
  reg            rt_hid = 1'b0;
  reg            rt_data_s = 1'b0;
  reg            rt_set_report = 1'b0;
  //----------------------------
  reg            rt_crc_c = 1'b0;
  reg            rt_keep_alive = 1'b0;
  reg     [0:10] rt_addr_endp = 11'b0;
  reg            rt_make_reset = 1'b0;
  wire           rt_EOP;

  /* RX wires (prefix = wr-wire receiver module) */
  wire           wr_sync_flag;
  wire    [ 3:0] wr_pid_flag;
  wire    [ 7:0] wr_pid;
  wire    [15:0] wr_crcdata;
  wire    [ 3:0] wr_byte_size;
  wire           wr_receive_complete;
  wire           wr_eop_flag;
  reg            rx_en = 1'b0;

  /* CRC wires (prefix = wcr-wire CRC module) */
  wire    [15:0] wcrc_rxdatacrc;
  //--------------------------------------------------------------------------



  //-----------------------------------module Instantiation -------------------------------
  usbls_tx_top u_tx_top (
      .clk       (usbls_clk),
      .tx_en     (rt_tx_en),
      .handshake (rt_handshake),
      .data      (rt_data),
      .token     (rt_token),
      .out       (rt_out),
      .in        (rt_in),
      .setup     (rt_setup),
      .data_s    (rt_data_s),
      .string    (rt_string),
      .endpoint  (rt_endpoint),
      .interface (rt_interface),
      .device    (rt_device),
      .configu   (rt_configu),
      .set_addr  (rt_set_addr),
      .set_config(rt_set_config),
      .set_idle  (rt_set_idle),
      .hid       (rt_hid),
      .set_report(rt_set_report),
      .crc_c     (rt_crc_c),
      .keep_alive(rt_keep_alive),
      .addr_endp (rt_addr_endp),
      .make_reset(rt_make_reset),
      .dp_OUT    (usbls_dp_out),
      .dn_OUT    (usbls_dn_out),
      .dp_OE     (wc_DP_OE),
      .dn_OE     (wc_DN_OE),
      .EOP       (rt_EOP)
  );

  usbls_rx_top u_usb_rx (
      .clk             (usbls_clk),
      .dp_IN           (usbls_dp_in),
      .dn_IN           (usbls_dn_in),
      .dp_OE           (wc_DP_OE),
      .dn_OE           (wc_DN_OE),
      .rx_en           (rx_en),
      .sync_flag       (wr_sync_flag),
      .pid_flag        (wr_pid_flag),
      .pid             (wr_pid),
      .crcdata         (wr_crcdata),
      .data            (wc_DATA),
      .byte_size       (wr_byte_size),
      .receive_complete(wr_receive_complete),
      .eop_flag        (wr_eop_flag)
  );

  usbls_crc16_top u_crc16 (
      .clk (usbls_clk),
      .data_in  (wc_DATA),
      .byte_size(wr_byte_size),
      .crc_out  (wcrc_rxdatacrc)
  );
  //---------------------------------------------------------------------------------------



  //-----------------------------------Control module logic ---------------------------------
  reg [3:0] fsm_des = 4'b1100;
  localparam set_addr = 4'b0000;  //0
  localparam device_des = 4'b0001;  //1
  localparam config_des = 4'b0010;  //2
  localparam interf_des = 4'b0011;  //3
  localparam endpnt_des = 4'b0100;  //4
  localparam string_des = 4'b0101;  //5
  localparam data_state = 4'b0110;  //6
  localparam reset = 4'b0111;  //7
  localparam set_config = 4'b1000;  //8
  localparam set_idle = 4'b1001;  //9
  localparam hid = 4'b1010;  //10
  localparam ini_dev = 4'b1011;  //11
  localparam ini_reset = 4'b1100;  //12
  localparam make_reset = 4'b1110;  //14
  localparam set_report = 4'b1101;  //13

  reg [1:0] fsm_pid = 2'b00;
  localparam setup_pid = 2'b00;
  localparam in_pid = 2'b01;
  localparam out_pid = 2'b10;
  localparam data_s_pid = 2'b11;

  reg [1:0] fsm_pkt = 2'b00;
  localparam token_pkt = 2'b00;
  localparam data_pkt = 2'b01;
  localparam handshk_pkt = 2'b10;
  //-------------------------------------------
  localparam keepcnt = 1496;
  always @(posedge usbls_clk) begin
    if (!rt_tx_en && fsm_des != 4'b0111 && fsm_des != 4'b1100  && fsm_des != 4'b1110 && !(rx_en)) begin
      if (cntk == keepcnt) begin
        rt_keep_alive = 1'b1;
        cntk = cntk + 1;
      end else if (cntk == keepcnt + 1) begin
        rt_keep_alive = 1'b1;
        cntk = cntk + 1;
      end else if (cntk == keepcnt + 2) begin
        rt_keep_alive = 1'b1;
        cntk = 0;
        cntk2 = cntk2 + 1;

      end else begin
        rt_keep_alive = 1'b0;
        cntk = cntk + 1;
      end
    end else rt_keep_alive = 1'b0;
  end

  always @(posedge usbls_clk) begin
  
    //////////////////////////////////////////////////////when no response reset /////////////////////////////////////////////
    if (fsm_des == 4'b0110) begin  //reset when suspend in data state
      if (dead_count == 200000) begin
        dead_count = 0;

        fsm_des <= ini_reset;
        fsm_pid <= setup_pid;
        fsm_pkt <= token_pkt;
        cnt0 = 0;
        cnt_nodata = 0;
      end else if (usbls_dp_in == 1'b0 && usbls_dn_in == 1'b0) begin
        dead_count = dead_count + 1;
      end
    end

    if (fsm_des == 4'b1101) begin  // reset when no response in set report
      if (cnt_nodata == 2000) begin
        fsm_des <= ini_reset;
        fsm_pid <= setup_pid;
        fsm_pkt <= token_pkt;
        cnt0 = 0;
        cnt_nodata = 0;
      end
    end

    if (fsm_des == 4'b1011) begin  // reset when no response in handshk
      if (cnt_nodata == 200) begin
        fsm_des <= ini_reset;
        fsm_pid <= setup_pid;
        fsm_pkt <= token_pkt;
        cnt0 = 0;
        cnt_nodata = 0;
      end
    end

    if (fsm_des == 4'b0001 && fsm_pid == 2'b01) begin  // try till 7 device descriptor
      if (cnt_nodata == 7) begin
        fsm_des <= ini_reset;
        fsm_pid <= setup_pid;
        fsm_pkt <= token_pkt;
        cnt0 = 0;
        cnt_nodata = 0;
      end
    end

    if(fsm_des == 4'b0001 && fsm_pid == 2'b10 )begin   // try till 7 handshakes pid out for device descriptor
      if (cnt_nodata == 7) begin
        fsm_des <= ini_reset;
        fsm_pid <= setup_pid;
        fsm_pkt <= token_pkt;
        cnt0 = 0;
        cnt_nodata = 0;
      end
    end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
//                                                                main control events FSM
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    case (fsm_des)

      //12//////////////////////////////////////////////////////////////12-ini_reset//////////////////////////////////////////////
      ini_reset: begin
        if (usbls_dp_in == 0 && usbls_dn_in == 1) begin
          if (reset_count < 162100) begin  //89000
            reset_count <= reset_count + 1;
            fsm_des     <= ini_reset;
          end else if (reset_count == 162100) begin
            reset_count <= 0;
            fsm_des     <= make_reset;
          end
        end else fsm_des <= ini_reset;
      end

      //14//////////////////////////////////////////////////////////////14-make_reset//////////////////////////////////////////////
      make_reset: begin
        if (reset_count == 82200) begin
          fsm_des <= ini_dev;
          rt_make_reset <= 1'b0;
          rt_tx_en = 1'b0;
          reset_count = 0;
        end else begin
          fsm_des <= make_reset;
          rt_make_reset <= 1'b1;
          rt_tx_en = 1'b1;
          rx_en=0;
          reset_count = reset_count + 1;
        end
      end

      //11-//////////////////////////////////////////////////////////////11-ini_dev//////////////////////////////////////////////
      ini_dev: begin

        case (fsm_pid)
          //11//0//
          setup_pid: begin
            case (fsm_pkt)
              //11//0//0
              token_pkt: begin
                rx_en        = 1'b0;
                rt_addr_endp = 11'b00000000000;
                if (cnt0 == 90000) begin  //18933

                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_setup  = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= ini_dev;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_setup  = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= ini_dev;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                    rt_tx_en    = 1'b0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //11//0//1
              data_pkt: begin
                rt_tx_en  = 1'b1;
                rt_device = 1'b1;
                rt_setup  = 1'b1;
                rt_data   = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= ini_dev;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en  = 1'b0;
                  rt_device = 1'b0;
                  rt_setup  = 1'b0;
                  rt_data   = 1'b0;
                  fsm_des <= ini_dev;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                  rt_tx_en = 1'b0;
                end
              end
              //11//0//2
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010  ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= ini_dev;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end else begin
                    fsm_des <= ini_dev;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= ini_dev;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                end

              end
              default: begin
              end
            endcase
          end
          //11//1//
          in_pid: begin

            case (fsm_pkt)
              //11//1//0
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 256) begin

                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_in     = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_in     = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //11//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= ini_dev;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011 || wr_pid ==8'b11000011 )begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end else begin
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;//token_pkt

                  end
                end
              end
              //11//1//2
              handshk_pkt: begin  // check crc and send ack or nak
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_device    = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_device    = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_device    = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= ini_dev;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_device    = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    if (i == 2) begin
                      fsm_des <= ini_dev;
                      fsm_pid <= out_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      i       <= 0;
                    end else begin
                      fsm_des <= ini_dev;
                      fsm_pid <= in_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      i       <= i + 1;
                    end

                  end

                end
              end
              default: begin
              end
            endcase

          end
          //11//2//
          out_pid: begin
            //                                                                          

            case (fsm_pkt)
              //11//2//0
              token_pkt: begin

                if (cnt0 == 256) begin
                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_out    = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= ini_dev;
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_out    = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= ini_dev;
                    fsm_pid <= out_pid;
                    fsm_pkt <= data_pkt;
                    cnt_nodata = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end

              end
              //11//2//1
              data_pkt: begin
                rt_tx_en  = 1'b1;
                rt_device = 1'b1;
                rt_out    = 1'b1;
                rt_data   = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= ini_dev;
                  fsm_pid <= out_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en  = 1'b0;
                  rt_device = 1'b0;
                  rt_out    = 1'b0;
                  rt_data   = 1'b0;
                  fsm_des <= ini_dev;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;

                  rt_tx_en = 1'b0;
                end
              end
              //11//2//2
              handshk_pkt: begin
                //
                cnt_nodata = cnt_nodata+1;
                rx_en    = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010 || wr_pid == 8'b00011110 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= reset;  //RECEIVED ACK
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0 = 0;
                    cnt_nodata = 0;
                  end else begin
                    fsm_des <= ini_dev;  // received nak again from token
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0  = 0;
                  end
                end else begin
                  fsm_des <= ini_dev;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;
                end

              end
              default: begin
              end
            endcase
          end


          default: begin
          end
        endcase



      end


      //7//////////////////////////////////////////////////////////////7-reset//////////////////////////////////////////////
      reset: begin
        if (reset_count == 40000) begin
          fsm_des <= set_addr;
          fsm_pid <= setup_pid;
          fsm_pkt <= token_pkt;
          rt_make_reset <= 1'b0;
          reset_count = 0;
          rt_tx_en = 1'b0;
        end else begin
          fsm_des <= reset;
          rt_make_reset <= 1'b1;
          rt_tx_en = 1'b1;
          reset_count = reset_count + 1;
        end

      end
      //0//////////////////////////////////////////////////////////////0-set_addr//////////////////////////////////////////////
      set_addr: begin
        rt_addr_endp = 11'b00000000000;
        case (fsm_pid)
          //0//0//        
          setup_pid: begin
            case (fsm_pkt)
              //0//0//0
              token_pkt: begin
                if (cnt0 == 90000) begin
                  rt_tx_en    = 1'b1;
                  rt_set_addr = 1'b1;
                  rt_setup    = 1'b1;
                  rt_token    = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_addr;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en    = 1'b0;
                    rt_set_addr = 1'b0;
                    rt_setup    = 1'b0;
                    rt_token    = 1'b0;
                    fsm_des <= set_addr;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  fsm_des <= set_addr;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= token_pkt;
                  cnt0 = cnt0 + 1;
                end
              end
              //0//0//1
              data_pkt: begin
                rt_tx_en    = 1'b1;
                rt_set_addr = 1'b1;
                rt_setup    = 1'b1;
                rt_data     = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= set_addr;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en    = 1'b0;
                  rt_set_addr = 1'b0;
                  rt_setup    = 1'b0;
                  rt_data     = 1'b0;
                  fsm_des <= set_addr;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;

                end
              end
              //0//0//2
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_addr;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end else begin
                    fsm_des <= set_addr;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= set_addr;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                end
              end
              default: begin
              end
            endcase
          end
          //0//1//
          in_pid: begin
            case (fsm_pkt)
              //0//1//0
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 256) begin

                  rt_tx_en    = 1'b1;
                  rt_set_addr = 1'b1;
                  rt_in       = 1'b1;
                  rt_token    = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en    = 1'b0;
                    rt_set_addr = 1'b0;
                    rt_in       = 1'b0;
                    rt_token    = 1'b0;
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //0//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= set_addr;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011)begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end else begin
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end
                end
              end
              //0//1//2
              handshk_pkt: begin  // check crc and send ack or nak
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_set_addr  = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_addr  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= set_addr;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_set_addr  = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_addr;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_addr  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= device_des;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                  end

                end
              end
              default: begin
              end
            endcase
          end

          default: begin
          end
        endcase
      end
      //1//////////////////////////////////////////////////////////////1-device_des//////////////////////////////////////////////      
      device_des: begin
        case (fsm_pid)
          //1//0//
          setup_pid: begin
            case (fsm_pkt)
              //1//0//0
              token_pkt: begin
                rx_en        = 1'b0;
                rt_addr_endp = 11'b10000000000;
                if (cnt0 == 18933) begin

                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_setup  = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= device_des;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_setup  = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= device_des;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                    rt_tx_en    = 1'b0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //1//0//1
              data_pkt: begin
                rt_tx_en  = 1'b1;
                rt_device = 1'b1;
                rt_setup  = 1'b1;
                rt_data   = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= device_des;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en  = 1'b0;
                  rt_device = 1'b0;
                  rt_setup  = 1'b0;
                  rt_data   = 1'b0;
                  fsm_des <= device_des;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                  rt_tx_en = 1'b0;
                  cnt_nodata =0;
                end
              end
              //1//0//2
              handshk_pkt: begin
                
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010  ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= device_des;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt_nodata =0;
                  end else begin
                    fsm_des <= device_des;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= device_des;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                  cnt_nodata = cnt_nodata +1;
                  if(cnt_nodata ==300)begin
                    fsm_des <= ini_reset; // received nothing restart
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt_nodata=0;
                  end
                end

              end
              default: begin
              end
            endcase
          end
          //1//1//
          in_pid: begin

            case (fsm_pkt)
              //1//1//0
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 256) begin

                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_in     = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_in     = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //1//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= device_des;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011 || wr_pid ==8'b11000011 )begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end else begin
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end
                end
              end
              //1//1//2
              handshk_pkt: begin  // check crc and send ack or nak
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_device    = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_device    = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from token again
                    cnt_nodata = cnt_nodata + 1;  //check counter for reset if in continuous state
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_device    = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= device_des;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state

                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_device    = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    if (i == 2) begin
                      fsm_des <= device_des;
                      fsm_pid <= out_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      cnt_nodata = 0;
                      i <= 0;
                    end else begin
                      fsm_des <= device_des;
                      fsm_pid <= in_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      i       <= i + 1;
                    end

                  end

                end
              end
              default: begin
              end
            endcase

          end
          //1//2//
          out_pid: begin
            case (fsm_pkt)
              //1//2//0
              token_pkt: begin
                if (cnt0 == 256) begin
                  rt_tx_en  = 1'b1;
                  rt_device = 1'b1;
                  rt_out    = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= device_des;
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_device = 1'b0;
                    rt_out    = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= device_des;
                    fsm_pid <= out_pid;
                    fsm_pkt <= data_pkt;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end

              end
              //1//2//1
              data_pkt: begin
                rt_tx_en  = 1'b1;
                rt_device = 1'b1;
                rt_out    = 1'b1;
                rt_data   = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= device_des;
                  fsm_pid <= out_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en  = 1'b0;
                  rt_device = 1'b0;
                  rt_out    = 1'b0;
                  rt_data   = 1'b0;
                  fsm_des <= device_des;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;

                  rt_tx_en = 1'b0;
                end
              end
              //1//2//2
              handshk_pkt: begin
                rx_en    = 1'b1;  //rx active
                cnt_nodata= cnt_nodata+1;
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010|| wr_pid == 8'b00011110 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_config;  //RECEIVED ACK
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0 = 0;
                    cnt_nodata = 0;
                  end else begin
                    fsm_des <= device_des;  // received nak again from token
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0  = 0;
                  end
                end else begin
                  fsm_des <= device_des;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;
                end

              end
              default: begin
              end
            endcase
          end


          default: begin
          end
        endcase

      end
      
      //8//////////////////////////////////////////////////////////////8-set_config//////////////////////////////////////////////                    
      set_config: begin
        case (fsm_pid)
          //8//0        
          setup_pid: begin
            case (fsm_pkt)
              //8//0//0     
              token_pkt: begin
                if (cnt0 == 256) begin
                  rt_tx_en      = 1'b1;
                  rt_set_config = 1'b1;
                  rt_setup      = 1'b1;
                  rt_token      = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_config;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en      = 1'b0;
                    rt_set_config = 1'b0;
                    rt_setup      = 1'b0;
                    rt_token      = 1'b0;
                    fsm_des <= set_config;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //8//0//1                 
              data_pkt: begin
                rt_tx_en      = 1'b1;
                rt_set_config = 1'b1;
                rt_setup      = 1'b1;
                rt_data       = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= set_config;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en    = 1'b0;
                  rt_set_addr = 1'b0;
                  rt_setup    = 1'b0;
                  rt_data     = 1'b0;
                  fsm_des <= set_config;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;

                end
              end
              //8//0//2                
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;  //rx active
                  if(wr_pid ==8'b11010010 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_config;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end else begin
                    fsm_des <= set_config;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= set_config;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                end
              end
              default: begin
              end
            endcase
          end
          //8//1            
          in_pid: begin
            case (fsm_pkt)
              //8//1//0              
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 3482) begin

                  rt_tx_en      = 1'b1;
                  rt_set_config = 1'b1;
                  rt_in         = 1'b1;
                  rt_token      = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en      = 1'b0;
                    rt_set_config = 1'b0;
                    rt_in         = 1'b0;
                    rt_token      = 1'b0;
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //8//1//1              
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= set_config;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011)begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end else begin
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end
                end
              end
              //8//1//2              
              handshk_pkt: begin
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en      = 1'b1;  //send NAK
                  rt_set_config = 1'b1;
                  rt_in         = 1'b1;
                  rt_handshake  = 1'b1;
                  rt_crc_c      = 1'b0;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_addr  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= set_config;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_set_addr  = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_config;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_addr  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= set_idle;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // ack transmit complete move to set idle
                  end

                end
              end
              default: begin
              end
            endcase
          end

          default: begin
          end
        endcase
      end
      //9//////////////////////////////////////////////////////////////9-set_idle//////////////////////////////////////////////      
      set_idle: begin
        case (fsm_pid)
          //9//0        
          setup_pid: begin
            case (fsm_pkt)
              //9//0//0            
              token_pkt: begin
                if (cnt0 == 496496) begin
                  rt_tx_en    = 1'b1;
                  rt_set_idle = 1'b1;
                  rt_setup    = 1'b1;
                  rt_token    = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_idle;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en    = 1'b0;
                    rt_set_idle = 1'b0;
                    rt_setup    = 1'b0;
                    rt_token    = 1'b0;
                    fsm_des <= set_idle;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //9//0//1              
              data_pkt: begin
                rt_tx_en    = 1'b1;
                rt_set_idle = 1'b1;
                rt_setup    = 1'b1;
                rt_data     = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= set_idle;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en    = 1'b0;
                  rt_set_addr = 1'b0;
                  rt_setup    = 1'b0;
                  rt_data     = 1'b0;
                  fsm_des <= set_idle;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;

                end
              end
              //9//0//2
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_idle;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end else begin
                    fsm_des <= set_idle;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= set_idle;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                end
              end
              default: begin
              end
            endcase
          end
          //9//1          
          in_pid: begin
            case (fsm_pkt)
              //9//1//0      
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 35) begin

                  rt_tx_en    = 1'b1;
                  rt_set_idle = 1'b1;
                  rt_in       = 1'b1;
                  rt_token    = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en    = 1'b0;
                    rt_set_idle = 1'b0;
                    rt_in       = 1'b0;
                    rt_token    = 1'b0;
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //9//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= set_idle;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                  cnt_nodata=cnt_nodata+1;
                   if(cnt_nodata ==300)begin
                    fsm_des <= ini_reset; // received nothing restart
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt_nodata=0;
                  end
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011|| wr_pid ==8'b11000011)begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end else begin
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;

                  end
                end
              end
              //9//1//2              
              handshk_pkt: begin
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_set_idle  = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_idle  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= set_idle;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_set_idle  = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_idle;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_set_idle  = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= hid;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;  // ack transmit complete move to set idle
                  end

                end
              end
              default: begin
              end
            endcase
          end
          default: begin
          end
        endcase
      end
      //10//////////////////////////////////////////////////////////////10-hid//////////////////////////////////////////////      
      hid: begin
        case (fsm_pid)
          //10//0        
          setup_pid: begin
            case (fsm_pkt)
              //10//0//0            
              token_pkt: begin
                rx_en        = 1'b0;
                rt_addr_endp = 11'b10000000000;
                if (cnt0 == 289) begin

                  rt_tx_en = 1'b1;
                  rt_hid   = 1'b1;
                  rt_setup = 1'b1;
                  rt_token = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= hid;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en = 1'b0;
                    rt_hid   = 1'b0;
                    rt_setup = 1'b0;
                    rt_token = 1'b0;
                    fsm_des <= hid;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                    rt_tx_en    = 1'b0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //10//0//1
              data_pkt: begin
                rt_tx_en = 1'b1;
                rt_hid   = 1'b1;
                rt_setup = 1'b1;
                rt_data  = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= hid;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en = 1'b0;
                  rt_hid   = 1'b0;
                  rt_setup = 1'b0;
                  rt_data  = 1'b0;
                  fsm_des <= hid;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;


                end
              end
              //10//0//2
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;  //rx active
                  if(wr_pid ==8'b11010010  ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= hid;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt_nodata =0;
                  end else begin
                    fsm_des <= hid;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= hid;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                  cnt_nodata=cnt_nodata+1;
                   if(cnt_nodata ==300)begin
                    fsm_des <= ini_reset; // received nothing restart
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt_nodata=0;
                  end
                end

              end
              default: begin
              end
            endcase
          end
          //10//1
          in_pid: begin

            case (fsm_pkt)
              //10//1//0
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 181) begin

                  rt_tx_en = 1'b1;
                  rt_hid   = 1'b1;
                  rt_in    = 1'b1;
                  rt_token = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en = 1'b0;
                    rt_hid   = 1'b0;
                    rt_in    = 1'b0;
                    rt_token = 1'b0;
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //10//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= hid;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                  cnt_nodata=cnt_nodata+1;
                  if(cnt_nodata==300)begin
                  fsm_des <= ini_reset;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= token_pkt;
                  cnt_nodata=0;
                  end
                  
                end else begin
                  rx_en = 1'b0;  //rx active
                  cnt_nodata=0;
                  if(wr_pid ==8'b01001011 || wr_pid ==8'b11000011 )begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;
                    
                  end else begin
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt; //token_pkt

                  end
                end
              end
              //10//1//2
              handshk_pkt: begin  // check crc and send ack or nak
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_hid       = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_hid       = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en     = 1'b1;  //send ack and next stage	
                  rt_hid       = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b1;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= hid;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_hid       = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    //mouse-keyboard change
                    if (i == 7) begin  // 12 -- > mouse , 7--> keyboard
                      fsm_des <= hid;
                      fsm_pid <= out_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      i       <= 0;
                    end else begin
                      fsm_des <= hid;
                      fsm_pid <= in_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to device des
                      i       <= i + 1;
                    end

                  end

                end
              end
              default: begin
              end
            endcase

          end
          //10//2
          out_pid: begin
            case (fsm_pkt)
              //10//2//0
              token_pkt: begin
                if (cnt0 == 10) begin
                  rt_tx_en = 1'b1;
                  rt_hid   = 1'b1;
                  rt_out   = 1'b1;
                  rt_token = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= hid;
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en = 1'b0;
                    rt_hid   = 1'b0;
                    rt_out   = 1'b0;
                    rt_token = 1'b0;
                    fsm_des <= hid;
                    fsm_pid <= out_pid;
                    fsm_pkt <= data_pkt;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end

              end
              //10//2//1
              data_pkt: begin
                rt_tx_en = 1'b1;
                rt_hid   = 1'b1;
                rt_out   = 1'b1;
                rt_data  = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= hid;
                  fsm_pid <= out_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en = 1'b0;
                  rt_hid   = 1'b0;
                  rt_out   = 1'b0;
                  rt_data  = 1'b0;
                  fsm_des <= hid;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;

                  rt_tx_en = 1'b0;
                end
              end
              //10//2//2
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010 || wr_pid ==8'b00011110   ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= data_state;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rt_addr_endp = 11'b10000001000;

                    rx_en        = 1'b0;
                    cnt0         = 0;
                  end else begin
                    fsm_des <= hid;  // received nak again from token
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0  = 0;
                  end
                end else begin
                  fsm_des <= hid;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;
                end

              end
              default: begin
              end
            endcase
          end

          default: begin
          end
        endcase
      end
      //13//////////////////////////////////////////////////////////////13-set_report//////////////////////////////////////////////      
      set_report: begin

        case (fsm_pid)
          //13//0
          setup_pid: begin
            case (fsm_pkt)
              //13//0//0                                                        
              token_pkt: begin
                rx_en = 1'b0;
                rt_addr_endp = 11'b10000000000;
                if (cnt0 == 614) begin
                  rt_tx_en      = 1'b1;
                  rt_set_report = 1'b1;
                  rt_setup      = 1'b1;
                  rt_token      = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en      = 1'b0;
                    rt_set_report = 1'b0;
                    rt_setup      = 1'b0;
                    rt_token      = 1'b0;
                    fsm_des <= set_report;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //13//0//1  
              data_pkt: begin
                if (cnt0 == 10) begin
                  rt_tx_en      = 1'b1;
                  rt_set_report = 1'b1;
                  rt_setup      = 1'b1;
                  rt_data       = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= data_pkt;
                  end else begin
                    rt_tx_en      = 1'b0;
                    rt_set_report = 1'b0;
                    rt_setup      = 1'b0;
                    rt_data       = 1'b0;
                    fsm_des <= set_report;
                    fsm_pid <= setup_pid;
                    fsm_pkt <= handshk_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //13//0//2                                                                      
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010 ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_report;  //RECEIVED ACK
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end else begin
                    fsm_des <= set_report;  // received nak again from token
                    fsm_pid <= setup_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                  end
                end else begin
                  fsm_des <= set_report;
                  fsm_pid <= setup_pid;
                  fsm_pkt <= handshk_pkt;
                end
              end

              default: begin
              end
            endcase
          end
          //13//2                                              

          out_pid: begin
            case (fsm_pkt)
              //13//2//0
              token_pkt: begin
                if (cnt0 == 12) begin
                  rt_tx_en  = 1'b1;
                  rt_set_report = 1'b1;
                  rt_out    = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_set_report = 1'b0;
                    rt_out    = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= set_report;
                    fsm_pid <= out_pid;
                    fsm_pkt <= data_pkt;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end

              end
              //13//2//1
              data_pkt: begin
                rt_tx_en  = 1'b1;
                rt_set_report = 1'b1;
                rt_out    = 1'b1;
                rt_data   = 1'b1;
                if (rt_EOP == 1'b0) begin
                  fsm_des <= set_report;
                  fsm_pid <= out_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rt_tx_en  = 1'b0;
                  rt_set_report = 1'b0;
                  rt_out    = 1'b0;
                  rt_data   = 1'b0;
                  fsm_des <= set_report;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;

                  rt_tx_en = 1'b0;
                end
              end
              //13//2/2                                                                      
              handshk_pkt: begin
                rx_en = 1'b1;  //rx active
                if (wr_eop_flag) begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b11010010  ) begin   //check ack ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_report;  //RECEIVED ACK
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0  = 0;
                  end else begin
                    fsm_des <= set_report;  // received nak again from token
                    fsm_pid <= out_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;
                    cnt0  = 0;
                  end
                end else begin
                  fsm_des <= set_report;
                  fsm_pid <= out_pid;
                  fsm_pkt <= handshk_pkt;
                end

              end
              default: begin
              end
            endcase
          end

          //13//1                                              

          in_pid: begin
            case (fsm_pkt)
              //13//1//0
              token_pkt: begin
                rx_en = 1'b0;
                if (cnt0 == 4) begin

                  rt_tx_en = 1'b1;
                  rt_set_report   = 1'b1;
                  rt_in    = 1'b1;
                  rt_token = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en = 1'b0;
                    rt_set_report   = 1'b0;
                    rt_in    = 1'b0;
                    rt_token = 1'b0;
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //13//1//1
              data_pkt: begin
                cnt_nodata = cnt_nodata + 1;
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= set_report;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                end else begin
                  rx_en = 1'b0;  //rx active
                  if((wr_pid ==8'b01001011) || (wr_pid ==8'b11000011) )begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;
                    rx_en = 1'b0;
                    cnt_nodata = 0;
                  end else begin
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;
                    rx_en = 1'b0;
                  end
                end
              end
              //13//1//2                                                                      
              handshk_pkt: begin  // check crc and send ack or nak
                rx_en = 1'b0;
                if (wcrc_rxdatacrc != wr_crcdata) begin
                  rt_tx_en      = 1'b1;  //send NAK
                  rt_set_report = 1'b1;
                  rt_in         = 1'b1;
                  rt_handshake  = 1'b1;
                  rt_crc_c      = 1'b0;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en      = 1'b0;
                    rt_set_report = 1'b0;
                    rt_in         = 1'b0;
                    rt_handshake  = 1'b0;
                    rt_crc_c      = 1'b0;
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end
                end else begin
                  rt_tx_en      = 1'b1;  //send ack and next stage	
                  rt_set_report = 1'b1;
                  rt_in         = 1'b1;
                  rt_handshake  = 1'b1;
                  rt_crc_c      = 1'b1;

                  if (rt_EOP == 1'b0) begin
                    fsm_des <= set_report;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_hid       = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;  // ack transmit complete move to device des

                  end

                end
              end
              default: begin
              end
            endcase
          end


          default: begin
          end
        endcase

      end

      //6//////////////////////////////////////////////////////////////6-data_state//////////////////////////////////////////////      
      data_state: begin
        case (fsm_pid)
          setup_pid: begin
            case (fsm_pkt)
              token_pkt: begin
              end
              data_pkt: begin
              end
              handshk_pkt: begin
              end
              default: begin
              end
            endcase
          end
          //6//1          
          in_pid: begin
            case (fsm_pkt)
              //6//1//0
              token_pkt: begin
                rx_en = 1'b0;
                rt_addr_endp = 11'b10000001000;
                if (cnt0 == 12000) begin

                  rt_tx_en  = 1'b1;
                  rt_data_s = 1'b1;
                  rt_in     = 1'b1;
                  rt_token  = 1'b1;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                  end else begin
                    rt_tx_en  = 1'b0;
                    rt_data_s = 1'b0;
                    rt_in     = 1'b0;
                    rt_token  = 1'b0;
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= data_pkt;
                    cnt0 = 0;
                    cnt_nodata = 0;
                  end
                end else begin
                  cnt0 = cnt0 + 1;
                end
              end
              //6//1//1
              data_pkt: begin
                rx_en = 1'b1;  //rx active 
                if (wr_eop_flag == 1'b0) begin
                  fsm_des <= data_state;
                  fsm_pid <= in_pid;
                  fsm_pkt <= data_pkt;
                  if (cnt_nodata == 300) begin
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;
                    rx_en    = 1'b0;
                    rt_crc_c = 1'b0;
                  end else begin
                    cnt_nodata = cnt_nodata + 1;
                  end
                end else begin
                  rx_en = 1'b0;
                  if(wr_pid ==8'b01001011 || wr_pid ==8'b11000011 )begin   //check data1 ; wr_pid_flag ={DATA0,DATA1,ACK,NAK} gets 1 as detected 
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;
                    rx_en = 1'b0;

                  end else begin
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= token_pkt;
                    rx_en = 1'b0;

                  end
                end
              end
              //6//1//2
              handshk_pkt: begin
                rx_en = 1'b0;
                if (cnt_nodata == 300) begin
                  rt_tx_en     = 1'b1;  //send NAK
                  rt_data_s    = 1'b1;
                  rt_in        = 1'b1;
                  rt_handshake = 1'b1;
                  rt_crc_c     = 1'b0;
                  rx_en        = 1'b0;
                  cnt_nodata   = 0;
                  if (rt_EOP == 1'b0) begin
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;
                    fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                  end else begin
                    rt_tx_en     = 1'b0;
                    rt_data_s    = 1'b0;
                    rt_in        = 1'b0;
                    rt_handshake = 1'b0;
                    rt_crc_c     = 1'b0;
                    rx_en        = 1'b0;
                    fsm_des <= data_state;
                    fsm_pid <= in_pid;  // ******change*******
                    fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                  end

                end else begin
                  if ((wcrc_rxdatacrc != wr_crcdata)) begin
                    rt_tx_en     = 1'b1;  //send NAK
                    rt_data_s    = 1'b1;
                    rt_in        = 1'b1;
                    rt_handshake = 1'b1;
                    rt_crc_c     = 1'b0;
                    rx_en        = 1'b0;
                    cnt_nodata   = 0;
                    if (rt_EOP == 1'b0) begin
                      fsm_des <= data_state;
                      fsm_pid <= in_pid;
                      fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                    end else begin
                      rt_tx_en     = 1'b0;
                      rt_data_s    = 1'b0;
                      rt_in        = 1'b0;
                      rt_handshake = 1'b0;
                      rt_crc_c     = 1'b0;
                      rx_en        = 1'b0;
                      fsm_des <= data_state;
                      fsm_pid <= in_pid;  // ******change*******
                      fsm_pkt <= token_pkt;  // Nak transmit complete start from setup again
                    end
                  end else begin
                    rt_tx_en     = 1'b1;  //send ack and next stage	
                    rt_data_s    = 1'b1;
                    rt_in        = 1'b1;
                    rt_handshake = 1'b1;
                    rt_crc_c     = 1'b1;
                    rx_en        = 1'b0;
                    cnt_nodata   = 0;
                    if (rt_EOP == 1'b0) begin
                      fsm_des <= data_state;
                      fsm_pid <= in_pid;
                      fsm_pkt <= handshk_pkt;  //send till eop stays in same state
                    end else begin
                      rt_tx_en     = 1'b0;
                      rt_data_s    = 1'b0;
                      rt_in        = 1'b0;
                      rt_handshake = 1'b0;
                      rt_crc_c     = 1'b0;
                      rx_en        = 1'b0;
                      fsm_des <= data_state;
                      fsm_pid <= in_pid;
                      fsm_pkt <= token_pkt;  // ack transmit complete move to data - in_pid
                    end

                  end
                end  //300 vadu begin end
              end  //main begin
              default: begin
              end
            endcase
          end

          out_pid: begin
            case (fsm_pkt)
              token_pkt: begin
              end
              data_pkt: begin
              end
              handshk_pkt: begin
              end
              default: begin
              end
            endcase
          end

          default: begin
          end
        endcase
      end
      default: begin
        //fsm_des
      end
    endcase
  end
  
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
 //                                                                    *--*---*
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
 
  assign status_led = (fsm_des==data_state)? 1'b1 :1'b0; //active high if in data state we need led off :)
  assign byte_size  = wr_byte_size;
  assign crc_c      = rt_crc_c;
  assign usbls_data       = wc_DATA ;
  assign usbls_dp_oe      = wc_DP_OE;
  assign usbls_dn_oe      = wc_DN_OE;
endmodule

