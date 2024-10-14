/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: TETRIS
// FILE NAME: TETRIS.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / TETRIS
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module TETRIS (
	//INPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//OUTPUT
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n, clk, in_valid;
input		[2:0]	tetrominoes;
input		[2:0]	position;
output reg			tetris_valid, score_valid, fail;
output reg	[3:0]	score;
output reg 	[71:0]	tetris;


//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z;

parameter IDLE  = 3'b000;
parameter PLAZ  = 3'b001;
parameter CLEAN = 3'b100;
parameter KEEP  = 3'b011;
parameter FAIL  = 3'b101;
parameter OVER  = 3'b111;

//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg [2:0] mode_cs;
reg [2:0] mode_ns;
reg 	  map_cs   [13:0][0:5];
reg 	  map_ns   [15:0][0:5];
reg [2:0] score_cs;
reg [2:0] score_ns;
reg [4:0] count_cs;
reg [4:0] count_ns;
reg [2:0] tet_cs;
reg [2:0] tet_ns;
reg [2:0] pos_cs;
reg [2:0] pos_ns;
reg [3:0] possible_y_cs [3:0];
reg [3:0] possible_y_ns [3:0];

wire [3:0] col_top [5:0];
wire [3:0] possible_y [3:0];
wire [3:0] y_position;
reg        filled [11:0];
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_cs     	<= IDLE;
		score_cs 		<= 0;
		count_cs 		<= 0;
		tet_cs 			<= 0;
		pos_cs 			<= 0;
		for(x=0 ; x<4 ; x=x+1) possible_y_cs[x] <= 0;
        for(x=0 ; x<14 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_cs[x][y] = 0;
    end
    else begin
        mode_cs     	<= mode_ns;
		score_cs 		<= score_ns;
		count_cs 		<= count_ns;
		tet_cs 			<= tet_ns;
		pos_cs 			<= pos_ns;
		for(x=0 ; x<4 ; x=x+1) possible_y_cs[x] <= possible_y_ns[x];
        for(x=0 ; x<14 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_cs[x][y] = map_ns[x][y];
    end
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(*) begin
	case (mode_cs)

		IDLE: begin
			if(in_valid) mode_ns = PLAZ;
			else 		 mode_ns = mode_cs;
		end 

		PLAZ: begin
			casez ({filled[11], filled[10], filled[9], filled[8], filled[7], filled[6], filled[5], filled[4], filled[3], filled[2], filled[1], filled[0], map_ns[12][0], map_ns[12][1], map_ns[12][2], map_ns[12][3], map_ns[12][4], map_ns[12][5], count_cs})
				// Has filled row, go to CLEAN
				23'b1??????????????????????: mode_ns = CLEAN;
				23'b01?????????????????????: mode_ns = CLEAN;
				23'b001????????????????????: mode_ns = CLEAN;
				23'b0001???????????????????: mode_ns = CLEAN;
				23'b00001??????????????????: mode_ns = CLEAN;
				23'b000001?????????????????: mode_ns = CLEAN;
				23'b0000001????????????????: mode_ns = CLEAN;
				23'b00000001???????????????: mode_ns = CLEAN;
				23'b000000001??????????????: mode_ns = CLEAN;
				23'b0000000001?????????????: mode_ns = CLEAN;
				23'b00000000001????????????: mode_ns = CLEAN;
				23'b000000000001???????????: mode_ns = CLEAN;

				// Exceed the tetris map, go to FAIL
				23'b0000000000001??????????: mode_ns = FAIL;
				23'b00000000000001?????????: mode_ns = FAIL;
				23'b000000000000001????????: mode_ns = FAIL;
				23'b0000000000000001???????: mode_ns = FAIL;
				23'b00000000000000001??????: mode_ns = FAIL;
				23'b000000000000000001?????: mode_ns = FAIL;

				// Block 16, go to OVER
				23'b00000000000000000010000: mode_ns = OVER;

				default: mode_ns = KEEP;
			endcase
		end

		CLEAN: begin
			casez ({filled[11], filled[10], filled[9], filled[8], filled[7], filled[6], filled[5], filled[4], filled[3], filled[2], filled[1], filled[0], map_ns[12][0], map_ns[12][1], map_ns[12][2], map_ns[12][3], map_ns[12][4], map_ns[12][5], count_cs})
				// Has filled row, go to CLEAN
				23'b1??????????????????????: mode_ns = CLEAN;
				23'b01?????????????????????: mode_ns = CLEAN;
				23'b001????????????????????: mode_ns = CLEAN;
				23'b0001???????????????????: mode_ns = CLEAN;
				23'b00001??????????????????: mode_ns = CLEAN;
				23'b000001?????????????????: mode_ns = CLEAN;
				23'b0000001????????????????: mode_ns = CLEAN;
				23'b00000001???????????????: mode_ns = CLEAN;
				23'b000000001??????????????: mode_ns = CLEAN;
				23'b0000000001?????????????: mode_ns = CLEAN;
				23'b00000000001????????????: mode_ns = CLEAN;
				23'b000000000001???????????: mode_ns = CLEAN;

				// Exceed the tetris map, go to FAIL
				23'b0000000000001??????????: mode_ns = FAIL;
				23'b00000000000001?????????: mode_ns = FAIL;
				23'b000000000000001????????: mode_ns = FAIL;
				23'b0000000000000001???????: mode_ns = FAIL;
				23'b00000000000000001??????: mode_ns = FAIL;
				23'b000000000000000001?????: mode_ns = FAIL;

				// Block 16, go to OVER
				23'b00000000000000000010000: mode_ns = OVER;

				default: mode_ns = KEEP;
			endcase
		end

		KEEP: mode_ns = IDLE;

        FAIL: mode_ns = IDLE;

        OVER: mode_ns = IDLE;

		default: mode_ns = mode_cs;

	endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
FIND_COL_TOP FCT0(.current_map(map_cs), .col_top(col_top));
// FIND_Y_POSITION FYP0(.tetrominoes(tetrominoes), .position(position), .col_top(col_top), .y_position(y_position));

FIND_Y_POSITION_1 FYP1_0(.tetrominoes(tetrominoes), .position(position), .col_top(col_top), .possible_y(possible_y));
FIND_Y_POSITION_2 FYP2_0(.tetrominoes(tet_cs), .possible_y(possible_y_cs), .y_position(y_position));

// tet_ns &　pos_ns combinational circuit
always @(*) begin
	case (mode_cs)

		IDLE: begin
			if(in_valid) begin
				tet_ns = tetrominoes;
				pos_ns = position;
			end
			else begin
				tet_ns = 0;
				pos_ns = 0;
			end
		end

		PLAZ: begin
			tet_ns = tet_cs;
			pos_ns = pos_cs;
		end

		CLEAN: begin
			tet_ns = tet_cs;
			pos_ns = pos_cs;
		end

		KEEP: begin
			tet_ns = 0;
			pos_ns = 0;
		end

		FAIL: begin
			tet_ns = 0;
			pos_ns = 0;
		end

		OVER: begin
			tet_ns = 0;
			pos_ns = 0;
		end

		default: begin
			tet_ns = tet_cs;
			pos_ns = pos_cs;
		end

	endcase
end

// possible_y_ns logic
always @(*) begin
	case (mode_cs)

		IDLE: begin
			if(in_valid) for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = possible_y[i];
			else 		 for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = possible_y_cs[i];
		end

		PLAZ: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = possible_y_cs[i];

		CLEAN: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = possible_y_cs[i];

		KEEP: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = 0;

		FAIL: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = 0;

		OVER: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = 0;

		default: for(i=0 ; i<4 ; i=i+1) possible_y_ns[i] = possible_y_cs[i];

	endcase
end

// map_ns & score_ns & filled logic
always @(*) begin
    for(x=0 ; x<14 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = map_cs[x][y];
	for(x=14 ; x<16 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = 0;
    score_ns = score_cs;
	for(i=0 ; i<12 ; i=i+1) filled[i] = (map_ns[i][0] && map_ns[i][1] && map_ns[i][2] && map_ns[i][3] && map_ns[i][4] && map_ns[i][5]);

	case (mode_cs)

		IDLE: begin
			// Same as default
		end

		PLAZ: begin
			case (tet_cs)
				3'd0: begin
					map_ns[y_position][pos_cs]     = 1;
					map_ns[y_position][pos_cs+1]   = 1;
					map_ns[y_position+1][pos_cs]   = 1;
					map_ns[y_position+1][pos_cs+1] = 1;
				end
				3'd1: begin
					map_ns[y_position][pos_cs]   = 1;
					map_ns[y_position+1][pos_cs] = 1;
					map_ns[y_position+2][pos_cs] = 1;
					map_ns[y_position+3][pos_cs] = 1;
				end
				3'd2: begin
					map_ns[y_position][pos_cs]   = 1;
					map_ns[y_position][pos_cs+1] = 1;
					map_ns[y_position][pos_cs+2] = 1;
					map_ns[y_position][pos_cs+3] = 1;
				end
				3'd3: begin
					map_ns[y_position][pos_cs]     = 1;
					map_ns[y_position][pos_cs+1]   = 1;
					map_ns[y_position-1][pos_cs+1] = 1;
					map_ns[y_position-2][pos_cs+1] = 1;
				end
				3'd4: begin
					map_ns[y_position][pos_cs]     = 1;
					map_ns[y_position+1][pos_cs]   = 1;
					map_ns[y_position+1][pos_cs+1] = 1;
					map_ns[y_position+1][pos_cs+2] = 1;
				end
				3'd5: begin
					map_ns[y_position][pos_cs]   = 1;
					map_ns[y_position+1][pos_cs] = 1;
					map_ns[y_position+2][pos_cs] = 1;
					map_ns[y_position][pos_cs+1] = 1;
				end
				3'd6: begin
					map_ns[y_position][pos_cs]     = 1;
					map_ns[y_position+1][pos_cs]   = 1;
					map_ns[y_position][pos_cs+1]   = 1;
					map_ns[y_position-1][pos_cs+1] = 1;
				end
				3'd7: begin
					map_ns[y_position][pos_cs]     = 1;
					map_ns[y_position][pos_cs+1]   = 1;
					map_ns[y_position+1][pos_cs+1] = 1;
					map_ns[y_position+1][pos_cs+2] = 1;
				end
			endcase

			for(i=0 ; i<12 ; i=i+1) filled[i] = (map_ns[i][0] && map_ns[i][1] && map_ns[i][2] && map_ns[i][3] && map_ns[i][4] && map_ns[i][5]);
		end

		CLEAN: begin
			// for(x=0 ; x<14 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = map_cs[x][y];
			// for(x=14 ; x<16 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = 0;
			score_ns = score_cs + 1;

			// if(filled[11]) begin
			// 	for(i=11 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[10]) begin
			// 	for(i=10 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[9]) begin
			// 	for(i=9 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[8]) begin
			// 	for(i=8 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[7]) begin
			// 	for(i=7 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[6]) begin
			// 	for(i=6 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[5]) begin
			// 	for(i=5 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[4]) begin
			// 	for(i=4 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[3]) begin
			// 	for(i=3 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[2]) begin
			// 	for(i=2 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else if(filled[1]) begin
			// 	for(i=1 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end
			// else begin
			// 	for(i=0 ; i<15 ; i=i+1) begin
			// 			map_ns[i][0] = map_ns[i+1][0];
			// 			map_ns[i][1] = map_ns[i+1][1];
			// 			map_ns[i][2] = map_ns[i+1][2];
			// 			map_ns[i][3] = map_ns[i+1][3];
			// 			map_ns[i][4] = map_ns[i+1][4];
			// 			map_ns[i][5] = map_ns[i+1][5];
			// 		end

			// 		map_ns[15][0] = 0;
			// 		map_ns[15][1] = 0;
			// 		map_ns[15][2] = 0;
			// 		map_ns[15][3] = 0;
			// 		map_ns[15][4] = 0;
			// 		map_ns[15][5] = 0;
			// end

			casez ({filled[11], filled[10], filled[9], filled[8], filled[7], filled[6], filled[5], filled[4], filled[3], filled[2], filled[1], filled[0]})
				12'b1???????????: begin
					for(i=11 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b01??????????: begin
					for(i=10 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b001?????????: begin
					for(i=9 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b0001????????: begin
					for(i=8 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b00001???????: begin
					for(i=7 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b000001??????: begin
					for(i=6 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b0000001?????: begin
					for(i=5 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b00000001????: begin
					for(i=4 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b000000001???: begin
					for(i=3 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b0000000001??: begin
					for(i=2 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b00000000001?: begin
					for(i=1 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				12'b000000000001: begin
					for(i=0 ; i<15 ; i=i+1) begin
						map_ns[i][0] = map_ns[i+1][0];
						map_ns[i][1] = map_ns[i+1][1];
						map_ns[i][2] = map_ns[i+1][2];
						map_ns[i][3] = map_ns[i+1][3];
						map_ns[i][4] = map_ns[i+1][4];
						map_ns[i][5] = map_ns[i+1][5];
					end

					map_ns[15][0] = 0;
					map_ns[15][1] = 0;
					map_ns[15][2] = 0;
					map_ns[15][3] = 0;
					map_ns[15][4] = 0;
					map_ns[15][5] = 0;
				end
				default: begin
					for(x=0 ; x<14 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = map_cs[x][y];
					for(x=14 ; x<16 ; x=x+1) for(y=0 ; y<6 ; y=y+1) map_ns[x][y] = 0;
				end		

			endcase

			for(i=0 ; i<12 ; i=i+1) filled[i] = (map_ns[i][0] && map_ns[i][1] && map_ns[i][2] && map_ns[i][3] && map_ns[i][4] && map_ns[i][5]);

			// for(i=11 ; i>=0 ; i=i-1) begin
            //     if((map_ns[i][0]) && (map_ns[i][1]) && (map_ns[i][2]) && (map_ns[i][3]) && (map_ns[i][4]) && (map_ns[i][5])) begin
            //         for(j=i ; j<15 ; j=j+1) begin
            //             map_ns[j][0] = map_ns[j+1][0];
			// 			map_ns[j][1] = map_ns[j+1][1];
			// 			map_ns[j][2] = map_ns[j+1][2];
			// 			map_ns[j][3] = map_ns[j+1][3];
			// 			map_ns[j][4] = map_ns[j+1][4];
			// 			map_ns[j][5] = map_ns[j+1][5];

            //             map_ns[j+1][0] = 0;
			// 			map_ns[j+1][1] = 0;
			// 			map_ns[j+1][2] = 0;
			// 			map_ns[j+1][3] = 0;
			// 			map_ns[j+1][4] = 0;
			// 			map_ns[j+1][5] = 0;
            //         end

			// 		score_ns = score_ns + 1;
            //     end
            // end
		end

		KEEP: begin
            // Same as default
        end

        FAIL: begin
            for(l=0 ; l<16 ; l=l+1) begin
				map_ns[l][0] = 0;
				map_ns[l][1] = 0;
				map_ns[l][2] = 0;
				map_ns[l][3] = 0;
				map_ns[l][4] = 0;
				map_ns[l][5] = 0;
			end 
            score_ns = 0;
        end

        OVER: begin
            for(m=0 ; m<16 ; m=m+1) begin
				map_ns[m][0] = 0;
				map_ns[m][1] = 0;
				map_ns[m][2] = 0;
				map_ns[m][3] = 0;
				map_ns[m][4] = 0;
				map_ns[m][5] = 0;
			end 
            score_ns = 0;
        end

	endcase
end

// count_ns logic
always @(*) begin
	case (mode_cs)
		IDLE: begin
            if(in_valid) count_ns = count_cs + 1;
            else count_ns = count_cs;
        end 

		PLAZ: count_ns = count_cs;

		CLEAN: count_ns = count_cs;

		KEEP: count_ns = count_cs;

        FAIL: count_ns = 0;

        OVER: count_ns = 0;

		default: count_ns = count_cs;

	endcase
end
//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always @(*) begin
	case (mode_cs)
		IDLE: begin
			tetris_valid    = 0;
            score_valid     = 0;
            fail            = 0;
            score           = 0;
            tetris          = 0;
		end

		PLAZ: begin
			tetris_valid    = 0;
            score_valid     = 0;
            fail            = 0;
            score           = 0;
            tetris          = 0;
		end

		CLEAN: begin
			tetris_valid    = 0;
            score_valid     = 0;
            fail            = 0;
            score           = 0;
            tetris          = 0;
		end

		KEEP: begin
			tetris_valid    = 0;
            score_valid     = 1;
            fail            = 0;
            score           = score_cs;
            tetris          = 0;
		end

        FAIL: begin
			tetris_valid    = 1;
            score_valid     = 1;
            fail            = 1;
            score           = score_cs;
            for(n=0 ; n<6 ; n=n+1) for(q=0 ; q<12 ; q=q+1) tetris[6*q+n] = map_cs[q][n];
		end

        OVER: begin
			tetris_valid    = 1;
            score_valid     = 1;
            fail            = 0;
            score           = score_cs;
            for(p=0 ; p<6 ; p=p+1) for(r=0 ; r<12 ; r=r+1) tetris[6*r+p] = map_cs[r][p];
		end

		default: begin
			tetris_valid    = 0;
            score_valid     = 0;
            fail            = 0;
            score           = 0;
            tetris          = 0;
		end

	endcase
end

endmodule


module FIND_COL_TOP(
    // Input
    current_map,
    // Output
    col_top
);

integer i1, j1;
input current_map [13:0][0:5];
output reg [3:0] col_top [5:0];

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(*) begin

    for(i1=0 ; i1<6 ; i1=i1+1) begin
        col_top[i1] = 0;
        
        for(j1=0 ; j1<12 ; j1=j1+1) begin
            if(current_map[j1][i1] == 1) col_top[i1] = j1 + 1;
        end
    end
end
    
endmodule


module FIND_Y_POSITION(
    // Input
    tetrominoes,
    position,
    col_top,
    // Output
    y_position
);
input [2:0] tetrominoes, position;
input [3:0] col_top [5:0];
output reg [3:0] y_position;

reg [3:0] temp_position;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(*) begin
    case (tetrominoes)
        3'd0: begin
			temp_position = 4'd0;
			y_position = (col_top[position] > col_top[position+1]) ? col_top[position] : col_top[position+1];
		end
		3'd1: begin
			temp_position = 4'd0;
			y_position = col_top[position];
		end
		3'd2: begin
			temp_position = (col_top[position] > col_top[position+1]) ? col_top[position] : col_top[position+1];
			y_position = (col_top[position+2] > col_top[position+3]) ? ((col_top[position+2] > temp_position) ? col_top[position+2] : temp_position) : ((col_top[position+3] > temp_position) ? col_top[position+3] : temp_position);
		end
		3'd3: begin
			temp_position = 4'd0;
			y_position = (col_top[position] > (col_top[position+1]+2)) ? col_top[position] : (col_top[position+1]+2);
		end
		3'd4: begin
			temp_position = (col_top[position+1] > col_top[position+2]) ? col_top[position+1] : col_top[position+2];
			y_position = ((col_top[position]+1) > temp_position)? col_top[position] : temp_position-1;
		end
		3'd5: begin
			temp_position = 4'd0;
			y_position = (col_top[position] > col_top[position+1]) ? col_top[position] : col_top[position+1];
		end
		3'd6: begin
			temp_position = 4'd0;
			y_position = (col_top[position] > (col_top[position+1]+1)) ? col_top[position] : (col_top[position+1]+1);
		end
		3'd7: begin
			temp_position = (col_top[position] > col_top[position+1]) ? col_top[position] : col_top[position+1];
			y_position = ((temp_position+1) > col_top[position+2])? temp_position : (col_top[position+2]-1);
		end
        default: begin
            temp_position = 0;
            y_position = 0;
        end
    endcase
end
    
endmodule


module FIND_Y_POSITION_1(
    // Input
    tetrominoes,
    position,
    col_top,
    // Output
    possible_y
);
input [2:0] tetrominoes, position;
input [3:0] col_top [5:0];
output reg [3:0] possible_y [3:0];

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(*) begin
    case (tetrominoes)
        3'd0: begin
			possible_y[0] = col_top[position];
			possible_y[1] = col_top[position+1];
			possible_y[2] = 0;
			possible_y[3] = 0;
		end
		3'd1: begin
			possible_y[0] = col_top[position];
			possible_y[1] = 0;
			possible_y[2] = 0;
			possible_y[3] = 0;
		end
		3'd2: begin
			possible_y[0] = col_top[position];
			possible_y[1] = col_top[position+1];
			possible_y[2] = col_top[position+2];
			possible_y[3] = col_top[position+3];
		end
		3'd3: begin
			possible_y[0] = col_top[position];
			possible_y[1] = col_top[position+1]+2;
			possible_y[2] = 0;
			possible_y[3] = 0;
		end
		3'd4: begin
			possible_y[0] = col_top[position]+1;
			possible_y[1] = col_top[position+1];
			possible_y[2] = col_top[position+2];
			possible_y[3] = 0;
		end
		3'd5: begin
			possible_y[0] = col_top[position];
			possible_y[1] = col_top[position+1];
			possible_y[2] = 0;
			possible_y[3] = 0;
		end
		3'd6: begin
			possible_y[0] = col_top[position];
			possible_y[1] = col_top[position+1]+1;
			possible_y[2] = 0;
			possible_y[3] = 0;
		end
		3'd7: begin
			possible_y[0] = col_top[position]+1;
			possible_y[1] = col_top[position+1]+1;
			possible_y[2] = col_top[position+2];
			possible_y[3] = 0;
		end
        default: begin
			possible_y[0] = 0;
			possible_y[1] = 0;
			possible_y[2] = 0;
			possible_y[3] = 0;
        end
    endcase
end
    
endmodule

module FIND_Y_POSITION_2(
    // Input
    tetrominoes,
    possible_y,
    // Output
    y_position
);
input [2:0] tetrominoes;
input [3:0] possible_y [3:0];
output reg [3:0] y_position;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(*) begin
	y_position = (possible_y[0]>possible_y[1])? ((possible_y[2]>possible_y[3])? ((possible_y[0]>possible_y[2])? possible_y[0]:possible_y[2]):((possible_y[0]>possible_y[3])? possible_y[0]:possible_y[3])):((possible_y[2]>possible_y[3])? ((possible_y[1]>possible_y[2])? possible_y[1]:possible_y[2]):((possible_y[1]>possible_y[3])? possible_y[1]:possible_y[3]));
    
	case (tetrominoes)
		3'd4: begin
			y_position = (possible_y[0]>possible_y[1])? ((possible_y[2]>possible_y[3])? ((possible_y[0]>possible_y[2])? possible_y[0]-1:possible_y[2]-1):((possible_y[0]>possible_y[3])? possible_y[0]-1:possible_y[3])):((possible_y[2]>possible_y[3])? ((possible_y[1]>possible_y[2])? possible_y[1]-1:possible_y[2]-1):((possible_y[1]>possible_y[3])? possible_y[1]-1:possible_y[3]));
		end
		3'd7: begin
			y_position = (possible_y[0]>possible_y[1])? ((possible_y[2]>possible_y[3])? ((possible_y[0]>possible_y[2])? possible_y[0]-1:possible_y[2]-1):((possible_y[0]>possible_y[3])? possible_y[0]-1:possible_y[3])):((possible_y[2]>possible_y[3])? ((possible_y[1]>possible_y[2])? possible_y[1]-1:possible_y[2]-1):((possible_y[1]>possible_y[3])? possible_y[1]-1:possible_y[3]));
		end
    endcase
end
    
endmodule

// 36610.36 4 22427