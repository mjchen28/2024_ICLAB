/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: SA
// FILE NAME: SA_wocg.v
// VERSRION: 1.0
// DATE: Nov 06, 2024
// AUTHOR: Yen-Ning Tung, NYCU AIG
// CODE TYPE: RTL or Behavioral Level (Verilog)
// DESCRIPTION: 2024 Spring IC Lab / Exersise Lab08 / SA_wocg
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

module SA(
	// Input signals
	clk,
	rst_n,
	in_valid,
	T,
	in_data,
	w_Q,
	w_K,
	w_V,
	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input [3:0] T;
input signed [7:0] in_data;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [63:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
integer i, j, k;

//==============================================//
//           reg & wire declaration             //
//==============================================//
reg  [7:0]  count_cs, count_ns;
reg  [1:0]  t_cs, t_ns;
reg  signed [56:0] out_cs; 
wire signed [56:0] out_ns;
reg         over_flag_cs, over_flag_ns;

reg  signed [7:0]  in_data_cs [0:7][0:7];
reg  signed [7:0]  in_data_ns [0:7][0:7];
// reg  signed [7:0]  w_cs [0:7][0:7];
// reg  signed [7:0]  w_ns [0:7][0:7];
reg  signed [38:0] q_cs [0:7][0:7];
reg  signed [38:0] q_ns [0:7][0:7];
reg  signed [18:0] k_cs [0:7][0:7];
reg  signed [18:0] k_ns [0:7][0:7];
reg  signed [18:0] v_cs [0:7][0:7];
reg  signed [18:0] v_ns [0:7][0:7];

reg  signed [18:0] mul_in1  [0:63];
reg  signed [18:0] mul_in2  [0:63];
wire signed [37:0] mul_out  [0:63];
reg  signed [38:0] div_in   [0:1];
wire signed [38:0] div_out  [0:1];
reg  signed [38:0] relu_in  [0:1];
wire signed [38:0] relu_out [0:1];
reg  signed [38:0] ans_mul1 [0:7];
reg  signed [18:0] ans_mul2 [0:7];
wire signed [56:0] ans_out  [0:7];
wire signed [38:0] qk_add   [0:7];

//==============================================//
//                  design                      //
//==============================================//
//======================================================================//
//                                  FFs                                 //
//======================================================================//
// Asynchronous reset
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
		count_cs	<= 0;
		t_cs 		<= 0;
		out_cs 		<= 0;
		over_flag_cs <= 1;
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) in_data_cs[i][j] <= 0;
		// for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) w_cs[i][j] <= 0;
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) q_cs[i][j] <= 0;
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) k_cs[i][j] <= 0;
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) v_cs[i][j] <= 0;
    end
    else begin
		count_cs 	<= count_ns;
		t_cs 		<= t_ns;
		out_cs 		<= out_ns;
		over_flag_cs <= over_flag_ns;
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) in_data_cs[i][j] <= in_data_ns[i][j];
		// for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) w_cs[i][j] <= w_ns[i][j];
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) q_cs[i][j] <= q_ns[i][j];
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) k_cs[i][j] <= k_ns[i][j];
		for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) v_cs[i][j] <= v_ns[i][j];
    end
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//

//======================================================================//
//                              SUB_MODULES                             //
//======================================================================//
assign mul_out[0]  = mul_in1[0]  * mul_in2[0];
assign mul_out[1]  = mul_in1[1]  * mul_in2[1];
assign mul_out[2]  = mul_in1[2]  * mul_in2[2];
assign mul_out[3]  = mul_in1[3]  * mul_in2[3];
assign mul_out[4]  = mul_in1[4]  * mul_in2[4];
assign mul_out[5]  = mul_in1[5]  * mul_in2[5];
assign mul_out[6]  = mul_in1[6]  * mul_in2[6];
assign mul_out[7]  = mul_in1[7]  * mul_in2[7];
assign mul_out[8]  = mul_in1[8]  * mul_in2[8];
assign mul_out[9]  = mul_in1[9]  * mul_in2[9];
assign mul_out[10] = mul_in1[10] * mul_in2[10];
assign mul_out[11] = mul_in1[11] * mul_in2[11];
assign mul_out[12] = mul_in1[12] * mul_in2[12];
assign mul_out[13] = mul_in1[13] * mul_in2[13];
assign mul_out[14] = mul_in1[14] * mul_in2[14];
assign mul_out[15] = mul_in1[15] * mul_in2[15];
assign mul_out[16] = mul_in1[16] * mul_in2[16];
assign mul_out[17] = mul_in1[17] * mul_in2[17];
assign mul_out[18] = mul_in1[18] * mul_in2[18];
assign mul_out[19] = mul_in1[19] * mul_in2[19];
assign mul_out[20] = mul_in1[20] * mul_in2[20];
assign mul_out[21] = mul_in1[21] * mul_in2[21];
assign mul_out[22] = mul_in1[22] * mul_in2[22];
assign mul_out[23] = mul_in1[23] * mul_in2[23];
assign mul_out[24] = mul_in1[24] * mul_in2[24];
assign mul_out[25] = mul_in1[25] * mul_in2[25];
assign mul_out[26] = mul_in1[26] * mul_in2[26];
assign mul_out[27] = mul_in1[27] * mul_in2[27];
assign mul_out[28] = mul_in1[28] * mul_in2[28];
assign mul_out[29] = mul_in1[29] * mul_in2[29];
assign mul_out[30] = mul_in1[30] * mul_in2[30];
assign mul_out[31] = mul_in1[31] * mul_in2[31];
assign mul_out[32] = mul_in1[32] * mul_in2[32];
assign mul_out[33] = mul_in1[33] * mul_in2[33];
assign mul_out[34] = mul_in1[34] * mul_in2[34];
assign mul_out[35] = mul_in1[35] * mul_in2[35];
assign mul_out[36] = mul_in1[36] * mul_in2[36];
assign mul_out[37] = mul_in1[37] * mul_in2[37];
assign mul_out[38] = mul_in1[38] * mul_in2[38];
assign mul_out[39] = mul_in1[39] * mul_in2[39];
assign mul_out[40] = mul_in1[40] * mul_in2[40];
assign mul_out[41] = mul_in1[41] * mul_in2[41];
assign mul_out[42] = mul_in1[42] * mul_in2[42];
assign mul_out[43] = mul_in1[43] * mul_in2[43];
assign mul_out[44] = mul_in1[44] * mul_in2[44];
assign mul_out[45] = mul_in1[45] * mul_in2[45];
assign mul_out[46] = mul_in1[46] * mul_in2[46];
assign mul_out[47] = mul_in1[47] * mul_in2[47];
assign mul_out[48] = mul_in1[48] * mul_in2[48];
assign mul_out[49] = mul_in1[49] * mul_in2[49];
assign mul_out[50] = mul_in1[50] * mul_in2[50];
assign mul_out[51] = mul_in1[51] * mul_in2[51];
assign mul_out[52] = mul_in1[52] * mul_in2[52];
assign mul_out[53] = mul_in1[53] * mul_in2[53];
assign mul_out[54] = mul_in1[54] * mul_in2[54];
assign mul_out[55] = mul_in1[55] * mul_in2[55];
assign mul_out[56] = mul_in1[56] * mul_in2[56];
assign mul_out[57] = mul_in1[57] * mul_in2[57];
assign mul_out[58] = mul_in1[58] * mul_in2[58];
assign mul_out[59] = mul_in1[59] * mul_in2[59];
assign mul_out[60] = mul_in1[60] * mul_in2[60];
assign mul_out[61] = mul_in1[61] * mul_in2[61];
assign mul_out[62] = mul_in1[62] * mul_in2[62];
assign mul_out[63] = mul_in1[63] * mul_in2[63];

assign div_out[0] = div_in[0] / $signed(3);
assign div_out[1] = div_in[1] / $signed(3);

assign relu_out[0] = (relu_in[0] >= 0) ? relu_in[0] : 0;
assign relu_out[1] = (relu_in[1] >= 0) ? relu_in[1] : 0;

assign ans_out[0] = ans_mul1[0] * ans_mul2[0];
assign ans_out[1] = ans_mul1[1] * ans_mul2[1];
assign ans_out[2] = ans_mul1[2] * ans_mul2[2];
assign ans_out[3] = ans_mul1[3] * ans_mul2[3];
assign ans_out[4] = ans_mul1[4] * ans_mul2[4];
assign ans_out[5] = ans_mul1[5] * ans_mul2[5];
assign ans_out[6] = ans_mul1[6] * ans_mul2[6];
assign ans_out[7] = ans_mul1[7] * ans_mul2[7];

assign qk_add[0] = mul_out[0]  + mul_out[1]  + mul_out[2]  + mul_out[3]  + mul_out[4]  + mul_out[5]  + mul_out[6]  + mul_out[7];
assign qk_add[1] = mul_out[8]  + mul_out[9]  + mul_out[10] + mul_out[11] + mul_out[12] + mul_out[13] + mul_out[14] + mul_out[15];
assign qk_add[2] = mul_out[16] + mul_out[17] + mul_out[18] + mul_out[19] + mul_out[20] + mul_out[21] + mul_out[22] + mul_out[23];
assign qk_add[3] = mul_out[24] + mul_out[25] + mul_out[26] + mul_out[27] + mul_out[28] + mul_out[29] + mul_out[30] + mul_out[31];
assign qk_add[4] = mul_out[32] + mul_out[33] + mul_out[34] + mul_out[35] + mul_out[36] + mul_out[37] + mul_out[38] + mul_out[39];
assign qk_add[5] = mul_out[40] + mul_out[41] + mul_out[42] + mul_out[43] + mul_out[44] + mul_out[45] + mul_out[46] + mul_out[47];
assign qk_add[6] = mul_out[48] + mul_out[49] + mul_out[50] + mul_out[51] + mul_out[52] + mul_out[53] + mul_out[54] + mul_out[55];
assign qk_add[7] = mul_out[56] + mul_out[57] + mul_out[58] + mul_out[59] + mul_out[60] + mul_out[61] + mul_out[62] + mul_out[63];

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
// over_flag_ns logic
always @(*) begin
	if(count_cs == 192) over_flag_ns = 0;
	else begin
		case (t_cs)
			0: begin
				if(count_cs == 200)	over_flag_ns = 1;
				else 				over_flag_ns = over_flag_cs;
			end 
			1: begin
				if(count_cs == 224)	over_flag_ns = 1;
				else 				over_flag_ns = over_flag_cs;
			end 
			2: begin
				if(count_cs == 0)	over_flag_ns = 1;
				else 				over_flag_ns = over_flag_cs;
			end 
			default: over_flag_ns = over_flag_cs;
		endcase
	end
end

// count_ns logic
always @(*) begin
	if(in_valid || !over_flag_cs || (count_cs == 192))	count_ns = count_cs + 1;
	else 												count_ns = 0;
end

// t_ns
always @(*) begin
	if(in_valid && (count_cs == 0)) begin
		case (T)
			1: t_ns = 0;
			4: t_ns = 1;
			8: t_ns = 2;
			default: t_ns = 0;
		endcase
	end	
	else t_ns = t_cs;
end

// in_data logic
always @(*) begin
	for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) in_data_ns[i][j] = in_data_cs[i][j];

	if(in_valid) begin
		case (t_cs)
			0: begin
				case (count_cs)
					0:  in_data_ns[0][0] = in_data;
					1:  in_data_ns[0][1] = in_data;
					2:  in_data_ns[0][2] = in_data;
					3:  in_data_ns[0][3] = in_data;
					4:  in_data_ns[0][4] = in_data;
					5:  in_data_ns[0][5] = in_data;
					6:  in_data_ns[0][6] = in_data;
					7:  in_data_ns[0][7] = in_data;
					8:  in_data_ns[1][0] = 0;
					9:  in_data_ns[1][1] = 0;
					10: in_data_ns[1][2] = 0;
					11: in_data_ns[1][3] = 0;
					12: in_data_ns[1][4] = 0;
					13: in_data_ns[1][5] = 0;
					14: in_data_ns[1][6] = 0;
					15: in_data_ns[1][7] = 0;
					16: in_data_ns[2][0] = 0;
					17: in_data_ns[2][1] = 0;
					18: in_data_ns[2][2] = 0;
					19: in_data_ns[2][3] = 0;
					20: in_data_ns[2][4] = 0;
					21: in_data_ns[2][5] = 0;
					22: in_data_ns[2][6] = 0;
					23: in_data_ns[2][7] = 0;
					24: in_data_ns[3][0] = 0;
					25: in_data_ns[3][1] = 0;
					26: in_data_ns[3][2] = 0;
					27: in_data_ns[3][3] = 0;
					28: in_data_ns[3][4] = 0;
					29: in_data_ns[3][5] = 0;
					30: in_data_ns[3][6] = 0;
					31: in_data_ns[3][7] = 0;
					32: in_data_ns[4][0] = 0;
					33: in_data_ns[4][1] = 0;
					34: in_data_ns[4][2] = 0;
					35: in_data_ns[4][3] = 0;
					36: in_data_ns[4][4] = 0;
					37: in_data_ns[4][5] = 0;
					38: in_data_ns[4][6] = 0;
					39: in_data_ns[4][7] = 0;
					40: in_data_ns[5][0] = 0;
					41: in_data_ns[5][1] = 0;
					42: in_data_ns[5][2] = 0;
					43: in_data_ns[5][3] = 0;
					44: in_data_ns[5][4] = 0;
					45: in_data_ns[5][5] = 0;
					46: in_data_ns[5][6] = 0;
					47: in_data_ns[5][7] = 0;
					48: in_data_ns[6][0] = 0;
					49: in_data_ns[6][1] = 0;
					50: in_data_ns[6][2] = 0;
					51: in_data_ns[6][3] = 0;
					52: in_data_ns[6][4] = 0;
					53: in_data_ns[6][5] = 0;
					54: in_data_ns[6][6] = 0;
					55: in_data_ns[6][7] = 0;
					56: in_data_ns[7][0] = 0;
					57: in_data_ns[7][1] = 0;
					58: in_data_ns[7][2] = 0;
					59: in_data_ns[7][3] = 0;
					60: in_data_ns[7][4] = 0;
					61: in_data_ns[7][5] = 0;
					62: in_data_ns[7][6] = 0;
					63: in_data_ns[7][7] = 0;
				endcase
			end
			1: begin
				case (count_cs)
					0:  in_data_ns[0][0] = in_data;
					1:  in_data_ns[0][1] = in_data;
					2:  in_data_ns[0][2] = in_data;
					3:  in_data_ns[0][3] = in_data;
					4:  in_data_ns[0][4] = in_data;
					5:  in_data_ns[0][5] = in_data;
					6:  in_data_ns[0][6] = in_data;
					7:  in_data_ns[0][7] = in_data;
					8:  in_data_ns[1][0] = in_data;
					9:  in_data_ns[1][1] = in_data;
					10: in_data_ns[1][2] = in_data;
					11: in_data_ns[1][3] = in_data;
					12: in_data_ns[1][4] = in_data;
					13: in_data_ns[1][5] = in_data;
					14: in_data_ns[1][6] = in_data;
					15: in_data_ns[1][7] = in_data;
					16: in_data_ns[2][0] = in_data;
					17: in_data_ns[2][1] = in_data;
					18: in_data_ns[2][2] = in_data;
					19: in_data_ns[2][3] = in_data;
					20: in_data_ns[2][4] = in_data;
					21: in_data_ns[2][5] = in_data;
					22: in_data_ns[2][6] = in_data;
					23: in_data_ns[2][7] = in_data;
					24: in_data_ns[3][0] = in_data;
					25: in_data_ns[3][1] = in_data;
					26: in_data_ns[3][2] = in_data;
					27: in_data_ns[3][3] = in_data;
					28: in_data_ns[3][4] = in_data;
					29: in_data_ns[3][5] = in_data;
					30: in_data_ns[3][6] = in_data;
					31: in_data_ns[3][7] = in_data;
					32: in_data_ns[4][0] = 0;
					33: in_data_ns[4][1] = 0;
					34: in_data_ns[4][2] = 0;
					35: in_data_ns[4][3] = 0;
					36: in_data_ns[4][4] = 0;
					37: in_data_ns[4][5] = 0;
					38: in_data_ns[4][6] = 0;
					39: in_data_ns[4][7] = 0;
					40: in_data_ns[5][0] = 0;
					41: in_data_ns[5][1] = 0;
					42: in_data_ns[5][2] = 0;
					43: in_data_ns[5][3] = 0;
					44: in_data_ns[5][4] = 0;
					45: in_data_ns[5][5] = 0;
					46: in_data_ns[5][6] = 0;
					47: in_data_ns[5][7] = 0;
					48: in_data_ns[6][0] = 0;
					49: in_data_ns[6][1] = 0;
					50: in_data_ns[6][2] = 0;
					51: in_data_ns[6][3] = 0;
					52: in_data_ns[6][4] = 0;
					53: in_data_ns[6][5] = 0;
					54: in_data_ns[6][6] = 0;
					55: in_data_ns[6][7] = 0;
					56: in_data_ns[7][0] = 0;
					57: in_data_ns[7][1] = 0;
					58: in_data_ns[7][2] = 0;
					59: in_data_ns[7][3] = 0;
					60: in_data_ns[7][4] = 0;
					61: in_data_ns[7][5] = 0;
					62: in_data_ns[7][6] = 0;
					63: in_data_ns[7][7] = 0;
				endcase
			end
			2: begin
				case (count_cs)
					0:  in_data_ns[0][0] = in_data;
					1:  in_data_ns[0][1] = in_data;
					2:  in_data_ns[0][2] = in_data;
					3:  in_data_ns[0][3] = in_data;
					4:  in_data_ns[0][4] = in_data;
					5:  in_data_ns[0][5] = in_data;
					6:  in_data_ns[0][6] = in_data;
					7:  in_data_ns[0][7] = in_data;
					8:  in_data_ns[1][0] = in_data;
					9:  in_data_ns[1][1] = in_data;
					10: in_data_ns[1][2] = in_data;
					11: in_data_ns[1][3] = in_data;
					12: in_data_ns[1][4] = in_data;
					13: in_data_ns[1][5] = in_data;
					14: in_data_ns[1][6] = in_data;
					15: in_data_ns[1][7] = in_data;
					16: in_data_ns[2][0] = in_data;
					17: in_data_ns[2][1] = in_data;
					18: in_data_ns[2][2] = in_data;
					19: in_data_ns[2][3] = in_data;
					20: in_data_ns[2][4] = in_data;
					21: in_data_ns[2][5] = in_data;
					22: in_data_ns[2][6] = in_data;
					23: in_data_ns[2][7] = in_data;
					24: in_data_ns[3][0] = in_data;
					25: in_data_ns[3][1] = in_data;
					26: in_data_ns[3][2] = in_data;
					27: in_data_ns[3][3] = in_data;
					28: in_data_ns[3][4] = in_data;
					29: in_data_ns[3][5] = in_data;
					30: in_data_ns[3][6] = in_data;
					31: in_data_ns[3][7] = in_data;
					32: in_data_ns[4][0] = in_data;
					33: in_data_ns[4][1] = in_data;
					34: in_data_ns[4][2] = in_data;
					35: in_data_ns[4][3] = in_data;
					36: in_data_ns[4][4] = in_data;
					37: in_data_ns[4][5] = in_data;
					38: in_data_ns[4][6] = in_data;
					39: in_data_ns[4][7] = in_data;
					40: in_data_ns[5][0] = in_data;
					41: in_data_ns[5][1] = in_data;
					42: in_data_ns[5][2] = in_data;
					43: in_data_ns[5][3] = in_data;
					44: in_data_ns[5][4] = in_data;
					45: in_data_ns[5][5] = in_data;
					46: in_data_ns[5][6] = in_data;
					47: in_data_ns[5][7] = in_data;
					48: in_data_ns[6][0] = in_data;
					49: in_data_ns[6][1] = in_data;
					50: in_data_ns[6][2] = in_data;
					51: in_data_ns[6][3] = in_data;
					52: in_data_ns[6][4] = in_data;
					53: in_data_ns[6][5] = in_data;
					54: in_data_ns[6][6] = in_data;
					55: in_data_ns[6][7] = in_data;
					56: in_data_ns[7][0] = in_data;
					57: in_data_ns[7][1] = in_data;
					58: in_data_ns[7][2] = in_data;
					59: in_data_ns[7][3] = in_data;
					60: in_data_ns[7][4] = in_data;
					61: in_data_ns[7][5] = in_data;
					62: in_data_ns[7][6] = in_data;
					63: in_data_ns[7][7] = in_data;
				endcase
			end
		endcase
		
	end
end

// calculate Q, K, V, QK
always @(*) begin
	for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) q_ns[i][j] = q_cs[i][j];
	for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) k_ns[i][j] = k_cs[i][j];
	for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) v_ns[i][j] = v_cs[i][j];

	for(i=0 ; i<64 ; i=i+1) begin mul_in1[i] = 0; mul_in2[i] = 0; end
	for(i=0 ; i<2 ; i=i+1) div_in[i] = 0;
	for(i=0 ; i<2 ; i=i+1) relu_in[i] = 0;
	
	// if(in_valid) beginL
		case (count_cs)
			0:   q_ns[0][0] = w_Q;
			1:   q_ns[0][1] = w_Q;
			2:   q_ns[0][2] = w_Q;
			3:   q_ns[0][3] = w_Q;
			4:   q_ns[0][4] = w_Q;
			5:   q_ns[0][5] = w_Q;
			6:   q_ns[0][6] = w_Q;
			7:   q_ns[0][7] = w_Q;
			8:   q_ns[1][0] = w_Q;
			9:   q_ns[1][1] = w_Q;
			10:  q_ns[1][2] = w_Q;
			11:  q_ns[1][3] = w_Q;
			12:  q_ns[1][4] = w_Q;
			13:  q_ns[1][5] = w_Q;
			14:  q_ns[1][6] = w_Q;
			15:  q_ns[1][7] = w_Q;
			16:  q_ns[2][0] = w_Q;
			17:  q_ns[2][1] = w_Q;
			18:  q_ns[2][2] = w_Q;
			19:  q_ns[2][3] = w_Q;
			20:  q_ns[2][4] = w_Q;
			21:  q_ns[2][5] = w_Q;
			22:  q_ns[2][6] = w_Q;
			23:  q_ns[2][7] = w_Q;
			24:  q_ns[3][0] = w_Q;
			25:  q_ns[3][1] = w_Q;
			26:  q_ns[3][2] = w_Q;
			27:  q_ns[3][3] = w_Q;
			28:  q_ns[3][4] = w_Q;
			29:  q_ns[3][5] = w_Q;
			30:  q_ns[3][6] = w_Q;
			31:  q_ns[3][7] = w_Q;
			32:  q_ns[4][0] = w_Q;
			33:  q_ns[4][1] = w_Q;
			34:  q_ns[4][2] = w_Q;
			35:  q_ns[4][3] = w_Q;
			36:  q_ns[4][4] = w_Q;
			37:  q_ns[4][5] = w_Q;
			38:  q_ns[4][6] = w_Q;
			39:  q_ns[4][7] = w_Q;
			40:  q_ns[5][0] = w_Q;
			41:  q_ns[5][1] = w_Q;
			42:  q_ns[5][2] = w_Q;
			43:  q_ns[5][3] = w_Q;
			44:  q_ns[5][4] = w_Q;
			45:  q_ns[5][5] = w_Q;
			46:  q_ns[5][6] = w_Q;
			47:  q_ns[5][7] = w_Q;
			48:  q_ns[6][0] = w_Q;
			49:  q_ns[6][1] = w_Q;
			50:  q_ns[6][2] = w_Q;
			51:  q_ns[6][3] = w_Q;
			52:  q_ns[6][4] = w_Q;
			53:  q_ns[6][5] = w_Q;
			54:  q_ns[6][6] = w_Q;
			55:  q_ns[6][7] = w_Q;
			56:  q_ns[7][0] = w_Q;
			57:  q_ns[7][1] = w_Q;
			58:  q_ns[7][2] = w_Q;
			59:  q_ns[7][3] = w_Q;
			60:  q_ns[7][4] = w_Q;
			61:  q_ns[7][5] = w_Q;
			62:  q_ns[7][6] = w_Q;
			63:  q_ns[7][7] = w_Q;
			64: begin
				k_ns[0][0] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][0];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][0] = qk_add[i];
			end
			65: begin
				k_ns[0][1] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][1];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][1] = qk_add[i];
			end
			66: begin
				k_ns[0][2] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][2];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][2] = qk_add[i];
			end
			67: begin
				k_ns[0][3] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][3];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][3] = qk_add[i];
			end
			68: begin
				k_ns[0][4] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][4];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][4] = qk_add[i];
			end
			69: begin
				k_ns[0][5] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][5];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][5] = qk_add[i];
			end
			70: begin
				k_ns[0][6] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][6];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][6] = qk_add[i];
			end
			71:  begin
				k_ns[0][7] = w_K;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = q_cs[j][7];
				end
				for(i=0 ; i<8 ; i=i+1) q_ns[i][7] = qk_add[i];
			end
			72:  k_ns[1][0] = w_K;
			73:  k_ns[1][1] = w_K;
			74:  k_ns[1][2] = w_K;
			75:  k_ns[1][3] = w_K;
			76:  k_ns[1][4] = w_K;
			77:  k_ns[1][5] = w_K;
			78:  k_ns[1][6] = w_K;
			79:  k_ns[1][7] = w_K;
			80:  k_ns[2][0] = w_K;
			81:  k_ns[2][1] = w_K;
			82:  k_ns[2][2] = w_K;
			83:  k_ns[2][3] = w_K;
			84:  k_ns[2][4] = w_K;
			85:  k_ns[2][5] = w_K;
			86:  k_ns[2][6] = w_K;
			87:  k_ns[2][7] = w_K;
			88:  k_ns[3][0] = w_K;
			89:  k_ns[3][1] = w_K;
			90:  k_ns[3][2] = w_K;
			91:  k_ns[3][3] = w_K;
			92:  k_ns[3][4] = w_K;
			93:  k_ns[3][5] = w_K;
			94:  k_ns[3][6] = w_K;
			95:  k_ns[3][7] = w_K;
			96:  k_ns[4][0] = w_K;
			97:  k_ns[4][1] = w_K;
			98:  k_ns[4][2] = w_K;
			99:  k_ns[4][3] = w_K;
			100: k_ns[4][4] = w_K;
			101: k_ns[4][5] = w_K;
			102: k_ns[4][6] = w_K;
			103: k_ns[4][7] = w_K;
			104: k_ns[5][0] = w_K;
			105: k_ns[5][1] = w_K;
			106: k_ns[5][2] = w_K;
			107: k_ns[5][3] = w_K;
			108: k_ns[5][4] = w_K;
			109: k_ns[5][5] = w_K;
			110: k_ns[5][6] = w_K;
			111: k_ns[5][7] = w_K;
			112: k_ns[6][0] = w_K;
			113: k_ns[6][1] = w_K;
			114: k_ns[6][2] = w_K;
			115: k_ns[6][3] = w_K;
			116: k_ns[6][4] = w_K;
			117: k_ns[6][5] = w_K;
			118: k_ns[6][6] = w_K;
			119: k_ns[6][7] = w_K;
			120: k_ns[7][0] = w_K;
			121: k_ns[7][1] = w_K;
			122: k_ns[7][2] = w_K;
			123: k_ns[7][3] = w_K;
			124: k_ns[7][4] = w_K;
			125: k_ns[7][5] = w_K;
			126: k_ns[7][6] = w_K;
			127: k_ns[7][7] = w_K;
			// K
			128: begin
				v_ns[0][0] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][0];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][0] = qk_add[i];
			end
			129: begin
				v_ns[0][1] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][1];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][1] = qk_add[i];
			end
			130: begin
				v_ns[0][2] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][2];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][2] = qk_add[i];
			end
			131: begin
				v_ns[0][3] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][3];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][3] = qk_add[i];
			end
			132: begin
				v_ns[0][4] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][4];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][4] = qk_add[i];
			end
			133: begin
				v_ns[0][5] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][5];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][5] = qk_add[i];
			end
			134: begin
				v_ns[0][6] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][6];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][6] = qk_add[i];
			end
			135:  begin
				v_ns[0][7] = w_V;
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = k_cs[j][7];
				end
				for(i=0 ; i<8 ; i=i+1) k_ns[i][7] = qk_add[i];
			end

			// QK
			136: begin
				v_ns[1][0] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[0][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[0][j] = qk_add[j];
			end
			137: begin
				v_ns[1][1] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[1][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[1][j] = qk_add[j];
			end
			138: begin
				v_ns[1][2] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[2][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[2][j] = qk_add[j];
			end
			139: begin
				v_ns[1][3] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[3][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[3][j] = qk_add[j];
			end
			140: begin
				v_ns[1][4] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[4][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[4][j] = qk_add[j];
			end
			141: begin
				v_ns[1][5] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[5][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[5][j] = qk_add[j];
			end
			142: begin
				v_ns[1][6] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[6][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[6][j] = qk_add[j];
			end
			143: begin
				v_ns[1][7] = w_V;
				for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = q_cs[7][j];
					mul_in2[8*i+j] = k_cs[i][j];
				end

				for(j=0 ; j<8 ; j=j+1) q_ns[7][j] = qk_add[j];
			end
			// divide by 3 & relu
			144: begin
				v_ns[2][0] = w_V;
				div_in[0] = q_cs[0][0];  q_ns[0][0] = div_out[0];
				div_in[1] = q_cs[0][1];  q_ns[0][1] = div_out[1];
			end
			145: begin
				v_ns[2][1] = w_V;
				div_in[0] = q_cs[0][2];  q_ns[0][2] = div_out[0];
				div_in[1] = q_cs[0][3];  q_ns[0][3] = div_out[1];

				relu_in[0] = q_cs[0][0];  q_ns[0][0] = relu_out[0];
				relu_in[1] = q_cs[0][1];  q_ns[0][1] = relu_out[1];
			end
			146: begin
				v_ns[2][2] = w_V;
				div_in[0] = q_cs[0][4];  q_ns[0][4] = div_out[0];
				div_in[1] = q_cs[0][5];  q_ns[0][5] = div_out[1];

				relu_in[0] = q_cs[0][2];  q_ns[0][2] = relu_out[0];
				relu_in[1] = q_cs[0][3];  q_ns[0][3] = relu_out[1];
			end
			147: begin
				v_ns[2][3] = w_V;
				div_in[0] = q_cs[0][6];  q_ns[0][6] = div_out[0];
				div_in[1] = q_cs[0][7];  q_ns[0][7] = div_out[1];

				relu_in[0] = q_cs[0][4];  q_ns[0][4] = relu_out[0];
				relu_in[1] = q_cs[0][5];  q_ns[0][5] = relu_out[1];
			end
			148: begin
				v_ns[2][4] = w_V;
				div_in[0] = q_cs[1][0];  q_ns[1][0] = div_out[0];
				div_in[1] = q_cs[1][1];  q_ns[1][1] = div_out[1];

				relu_in[0] = q_cs[0][6];  q_ns[0][6] = relu_out[0];
				relu_in[1] = q_cs[0][7];  q_ns[0][7] = relu_out[1];
			end
			149: begin
				v_ns[2][5] = w_V;
				div_in[0] = q_cs[1][2];  q_ns[1][2] = div_out[0];
				div_in[1] = q_cs[1][3];  q_ns[1][3] = div_out[1];

				relu_in[0] = q_cs[1][0];  q_ns[1][0] = relu_out[0];
				relu_in[1] = q_cs[1][1];  q_ns[1][1] = relu_out[1];
			end
			150: begin
				v_ns[2][6] = w_V;
				div_in[0] = q_cs[1][4];  q_ns[1][4] = div_out[0];
				div_in[1] = q_cs[1][5];  q_ns[1][5] = div_out[1];

				relu_in[0] = q_cs[1][2];  q_ns[1][2] = relu_out[0];
				relu_in[1] = q_cs[1][3];  q_ns[1][3] = relu_out[1];
			end
			151: begin
				v_ns[2][7] = w_V;
				div_in[0] = q_cs[1][6];  q_ns[1][6] = div_out[0];
				div_in[1] = q_cs[1][7];  q_ns[1][7] = div_out[1];

				relu_in[0] = q_cs[1][4];  q_ns[1][4] = relu_out[0];
				relu_in[1] = q_cs[1][5];  q_ns[1][5] = relu_out[1];
			end
			152: begin
				v_ns[3][0] = w_V;
				div_in[0] = q_cs[2][0];  q_ns[2][0] = div_out[0];
				div_in[1] = q_cs[2][1];  q_ns[2][1] = div_out[1];

				relu_in[0] = q_cs[1][6];  q_ns[1][6] = relu_out[0];
				relu_in[1] = q_cs[1][7];  q_ns[1][7] = relu_out[1];
			end
			153: begin
				v_ns[3][1] = w_V;
				div_in[0] = q_cs[2][2];  q_ns[2][2] = div_out[0];
				div_in[1] = q_cs[2][3];  q_ns[2][3] = div_out[1];

				relu_in[0] = q_cs[2][0];  q_ns[2][0] = relu_out[0];
				relu_in[1] = q_cs[2][1];  q_ns[2][1] = relu_out[1];
			end
			154: begin
				v_ns[3][2] = w_V;
				div_in[0] = q_cs[2][4];  q_ns[2][4] = div_out[0];
				div_in[1] = q_cs[2][5];  q_ns[2][5] = div_out[1];

				relu_in[0] = q_cs[2][2];  q_ns[2][2] = relu_out[0];
				relu_in[1] = q_cs[2][3];  q_ns[2][3] = relu_out[1];
			end
			155: begin
				v_ns[3][3] = w_V;
				div_in[0] = q_cs[2][6];  q_ns[2][6] = div_out[0];
				div_in[1] = q_cs[2][7];  q_ns[2][7] = div_out[1];

				relu_in[0] = q_cs[2][4];  q_ns[2][4] = relu_out[0];
				relu_in[1] = q_cs[2][5];  q_ns[2][5] = relu_out[1];
			end
			156: begin
				v_ns[3][4] = w_V;
				div_in[0] = q_cs[3][0];  q_ns[3][0] = div_out[0];
				div_in[1] = q_cs[3][1];  q_ns[3][1] = div_out[1];

				relu_in[0] = q_cs[2][6];  q_ns[2][6] = relu_out[0];
				relu_in[1] = q_cs[2][7];  q_ns[2][7] = relu_out[1];
			end
			157: begin
				v_ns[3][5] = w_V;
				div_in[0] = q_cs[3][2];  q_ns[3][2] = div_out[0];
				div_in[1] = q_cs[3][3];  q_ns[3][3] = div_out[1];

				relu_in[0] = q_cs[3][0];  q_ns[3][0] = relu_out[0];
				relu_in[1] = q_cs[3][1];  q_ns[3][1] = relu_out[1];
			end
			158: begin
				v_ns[3][6] = w_V;
				div_in[0] = q_cs[3][4];  q_ns[3][4] = div_out[0];
				div_in[1] = q_cs[3][5];  q_ns[3][5] = div_out[1];

				relu_in[0] = q_cs[3][2];  q_ns[3][2] = relu_out[0];
				relu_in[1] = q_cs[3][3];  q_ns[3][3] = relu_out[1];
			end
			159: begin
				v_ns[3][7] = w_V;
				div_in[0] = q_cs[3][6];  q_ns[3][6] = div_out[0];
				div_in[1] = q_cs[3][7];  q_ns[3][7] = div_out[1];

				relu_in[0] = q_cs[3][4];  q_ns[3][4] = relu_out[0];
				relu_in[1] = q_cs[3][5];  q_ns[3][5] = relu_out[1];
			end
			160: begin
				v_ns[4][0] = w_V;
				div_in[0] = q_cs[4][0];  q_ns[4][0] = div_out[0];
				div_in[1] = q_cs[4][1];  q_ns[4][1] = div_out[1];

				relu_in[0] = q_cs[3][6];  q_ns[3][6] = relu_out[0];
				relu_in[1] = q_cs[3][7];  q_ns[3][7] = relu_out[1];
			end
			161: begin
				v_ns[4][1] = w_V;
				div_in[0] = q_cs[4][2];  q_ns[4][2] = div_out[0];
				div_in[1] = q_cs[4][3];  q_ns[4][3] = div_out[1];

				relu_in[0] = q_cs[4][0];  q_ns[4][0] = relu_out[0];
				relu_in[1] = q_cs[4][1];  q_ns[4][1] = relu_out[1];
			end
			162: begin
				v_ns[4][2] = w_V;
				div_in[0] = q_cs[4][4];  q_ns[4][4] = div_out[0];
				div_in[1] = q_cs[4][5];  q_ns[4][5] = div_out[1];

				relu_in[0] = q_cs[4][2];  q_ns[4][2] = relu_out[0];
				relu_in[1] = q_cs[4][3];  q_ns[4][3] = relu_out[1];
			end
			163: begin
				v_ns[4][3] = w_V;
				div_in[0] = q_cs[4][6];  q_ns[4][6] = div_out[0];
				div_in[1] = q_cs[4][7];  q_ns[4][7] = div_out[1];

				relu_in[0] = q_cs[4][4];  q_ns[4][4] = relu_out[0];
				relu_in[1] = q_cs[4][5];  q_ns[4][5] = relu_out[1];
			end
			164: begin
				v_ns[4][4] = w_V;
				div_in[0] = q_cs[5][0];  q_ns[5][0] = div_out[0];
				div_in[1] = q_cs[5][1];  q_ns[5][1] = div_out[1];

				relu_in[0] = q_cs[4][6];  q_ns[4][6] = relu_out[0];
				relu_in[1] = q_cs[4][7];  q_ns[4][7] = relu_out[1];
			end
			165: begin
				v_ns[4][5] = w_V;
				div_in[0] = q_cs[5][2];  q_ns[5][2] = div_out[0];
				div_in[1] = q_cs[5][3];  q_ns[5][3] = div_out[1];

				relu_in[0] = q_cs[5][0];  q_ns[5][0] = relu_out[0];
				relu_in[1] = q_cs[5][1];  q_ns[5][1] = relu_out[1];
			end
			166: begin
				v_ns[4][6] = w_V;
				div_in[0] = q_cs[5][4];  q_ns[5][4] = div_out[0];
				div_in[1] = q_cs[5][5];  q_ns[5][5] = div_out[1];

				relu_in[0] = q_cs[5][2];  q_ns[5][2] = relu_out[0];
				relu_in[1] = q_cs[5][3];  q_ns[5][3] = relu_out[1];
			end
			167: begin
				v_ns[4][7] = w_V;
				div_in[0] = q_cs[5][6];  q_ns[5][6] = div_out[0];
				div_in[1] = q_cs[5][7];  q_ns[5][7] = div_out[1];

				relu_in[0] = q_cs[5][4];  q_ns[5][4] = relu_out[0];
				relu_in[1] = q_cs[5][5];  q_ns[5][5] = relu_out[1];
			end
			168: begin
				v_ns[5][0] = w_V;
				div_in[0] = q_cs[6][0];  q_ns[6][0] = div_out[0];
				div_in[1] = q_cs[6][1];  q_ns[6][1] = div_out[1];

				relu_in[0] = q_cs[5][6];  q_ns[5][6] = relu_out[0];
				relu_in[1] = q_cs[5][7];  q_ns[5][7] = relu_out[1];
			end
			169: begin
				v_ns[5][1] = w_V;
				div_in[0] = q_cs[6][2];  q_ns[6][2] = div_out[0];
				div_in[1] = q_cs[6][3];  q_ns[6][3] = div_out[1];

				relu_in[0] = q_cs[6][0];  q_ns[6][0] = relu_out[0];
				relu_in[1] = q_cs[6][1];  q_ns[6][1] = relu_out[1];
			end
			170: begin
				v_ns[5][2] = w_V;
				div_in[0] = q_cs[6][4];  q_ns[6][4] = div_out[0];
				div_in[1] = q_cs[6][5];  q_ns[6][5] = div_out[1];

				relu_in[0] = q_cs[6][2];  q_ns[6][2] = relu_out[0];
				relu_in[1] = q_cs[6][3];  q_ns[6][3] = relu_out[1];
			end
			171: begin
				v_ns[5][3] = w_V;
				div_in[0] = q_cs[6][6];  q_ns[6][6] = div_out[0];
				div_in[1] = q_cs[6][7];  q_ns[6][7] = div_out[1];

				relu_in[0] = q_cs[6][4];  q_ns[6][4] = relu_out[0];
				relu_in[1] = q_cs[6][5];  q_ns[6][5] = relu_out[1];
			end
			172: begin
				v_ns[5][4] = w_V;
				div_in[0] = q_cs[7][0];  q_ns[7][0] = div_out[0];
				div_in[1] = q_cs[7][1];  q_ns[7][1] = div_out[1];

				relu_in[0] = q_cs[6][6];  q_ns[6][6] = relu_out[0];
				relu_in[1] = q_cs[6][7];  q_ns[6][7] = relu_out[1];
			end
			173: begin
				v_ns[5][5] = w_V;
				div_in[0] = q_cs[7][2];  q_ns[7][2] = div_out[0];
				div_in[1] = q_cs[7][3];  q_ns[7][3] = div_out[1];

				relu_in[0] = q_cs[7][0];  q_ns[7][0] = relu_out[0];
				relu_in[1] = q_cs[7][1];  q_ns[7][1] = relu_out[1];
			end
			174: begin
				v_ns[5][6] = w_V;
				div_in[0] = q_cs[7][4];  q_ns[7][4] = div_out[0];
				div_in[1] = q_cs[7][5];  q_ns[7][5] = div_out[1];

				relu_in[0] = q_cs[7][2];  q_ns[7][2] = relu_out[0];
				relu_in[1] = q_cs[7][3];  q_ns[7][3] = relu_out[1];
			end
			175: begin
				v_ns[5][7] = w_V;
				div_in[0] = q_cs[7][6];  q_ns[7][6] = div_out[0];
				div_in[1] = q_cs[7][7];  q_ns[7][7] = div_out[1];

				relu_in[0] = q_cs[7][4];  q_ns[7][4] = relu_out[0];
				relu_in[1] = q_cs[7][5];  q_ns[7][5] = relu_out[1];
			end
			176: begin
				v_ns[6][0] = w_V;
				relu_in[0] = q_cs[7][6];  q_ns[7][6] = relu_out[0];
				relu_in[1] = q_cs[7][7];  q_ns[7][7] = relu_out[1];
			end
			177: v_ns[6][1] = w_V;
			178: v_ns[6][2] = w_V;
			179: v_ns[6][3] = w_V;
			180: v_ns[6][4] = w_V;
			181: v_ns[6][5] = w_V;
			182: v_ns[6][6] = w_V;
			183: v_ns[6][7] = w_V;
			184: v_ns[7][0] = w_V;
			185: v_ns[7][1] = w_V;
			186: v_ns[7][2] = w_V;
			187: v_ns[7][3] = w_V;
			188: v_ns[7][4] = w_V;
			189: v_ns[7][5] = w_V;
			190: v_ns[7][6] = w_V;
			191: v_ns[7][7] = w_V;

			// V
			192: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][0];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][0] = qk_add[i];
			end
			193: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][1];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][1] = qk_add[i];
			end
			194: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][2];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][2] = qk_add[i];
			end
			195: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][3];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][3] = qk_add[i];
			end
			196: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][4];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][4] = qk_add[i];
			end
			197: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][5];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][5] = qk_add[i];
			end
			198: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][6];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][6] = qk_add[i];
			end
			199: begin
				for(i=0 ; i<8 ; i=i+1)for(j=0 ; j<8 ; j=j+1) begin
					mul_in1[8*i+j] = in_data_cs[i][j];
					mul_in2[8*i+j] = v_cs[j][7];
				end
				for(i=0 ; i<8 ; i=i+1) v_ns[i][7] = qk_add[i];
			end
		endcase
	// endL
end

// output answer logic
assign out_ns = ans_out[0] + ans_out[1] + ans_out[2] + ans_out[3] + ans_out[4] + ans_out[5] + ans_out[6] + ans_out[7];
always @(*) begin
	for(i=0 ; i<8 ; i=i+1) ans_mul1[i] = 0;
	for(i=0 ; i<8 ; i=i+1) ans_mul2[i] = 0;

	case (count_cs)

		192: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		193: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		194: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		195: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		196: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		197: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		198: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		199: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[0][i];
				ans_mul2[i] = qk_add[i];
			end
		end
		200: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		201: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		202: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		203: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		204: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		205: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		206: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		207: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[1][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		208: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		209: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		210: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		211: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		212: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		213: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		214: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		215: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[2][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		216: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		217: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		218: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		219: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		220: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		221: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		222: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		223: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[3][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		224: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		225: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		226: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		227: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		228: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		229: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		230: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		231: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[4][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		232: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		233: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		234: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		235: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		236: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		237: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		238: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		239: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[5][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		240: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		241: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		242: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		243: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		244: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		245: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		246: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		247: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[6][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
		248: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][0];
			end
		end
		249: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][1];
			end
		end
		250: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][2];
			end
		end
		251: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][3];
			end
		end
		252: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][4];
			end
		end
		253: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][5];
			end
		end
		254: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][6];
			end
		end
		255: begin
			for(i=0 ; i<8 ; i=i+1) begin
				ans_mul1[i] = q_cs[7][i];
				ans_mul2[i] = v_cs[i][7];
			end
		end
	endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always @(*) begin
	if(!over_flag_cs) begin
		out_valid = 1;
		out_data = {{7{out_cs[56]}}, out_cs};
	end
	else begin
		out_valid = 0;
		out_data = 0;
	end
end

endmodule
