//###############################################################################################
//***********************************************************************************************
//    File Name   : SORT_IP_demo.v
//    Module Name : SORT_TP_demo
//***********************************************************************************************
//###############################################################################################


//synopsys translate_off   
`include "HAMMING_IP.v"
//synopsys translate_on

module HAMMING_IP_demo #(parameter IP_BIT = 8)(
	//Input signals
	IN_code,
	//Output signals
	OUT_code
);

// ======================================================
// Input & Output Declaration
// ======================================================
input [IP_BIT+4-1:0]  IN_code;

output [IP_BIT-1:0] OUT_code;

// ======================================================
// Soft IP
// ======================================================
HAMMING_IP #(.IP_BIT(IP_BIT)) I_HAMMING_IP(.IN_code(IN_code), .OUT_code(OUT_code)); 

endmodule