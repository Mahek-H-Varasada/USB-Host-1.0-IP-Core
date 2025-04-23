# USB-Host-1.0-
This repo is Representations of USB 1.0 Host Core IP . 

The System Level BLock DIagram  :- 

![image](https://github.com/user-attachments/assets/caaeb8a3-e6ae-4019-8205-ac59bbc27bc9)

Logic Analyzer Capture When mouse/keyboard connected to PC :- Device Descriptors (Frame Sent by HID Device). 

![image](https://github.com/user-attachments/assets/1e7bd2a7-56f3-4709-83b8-bf53d481bf3c)

Screenshot Capture when connected with USB 1.0 Host IP Core Tested On FPGA Platform. Tested For all the various Transactions Also.
(Frame Succesfully Received on USB 1.0 Host Core IP.)

![image](https://github.com/user-attachments/assets/2af7fb05-0066-4c19-ac55-90ada7488d2a)

The Host Performs CRC Calculations, ACK /NAK logic, Address/Endpoints Logic, Bit Unstuffing/Stuffing on Concurrent 1's for CLock Recovery .
The module ALso Handles NRZI Decoding and Encoding Logic .

The Core is Also Responsible for Various Descriptor Types- Like Device descriptors, Configuration Descriptors , String Descriptors etc.
Basically host core sends various Setups FOR Particular Signals the DEvice responds with Data for that descriptor .

Then once we know the Device Descriptors We can set Particular Drivers Based on Mouse/Keyboards to Control and Decode its 
Data like Ascii Values(keyboard) , x,y Movement , Button Presses. and So On.

Thank you For Reading :) 
  


 
