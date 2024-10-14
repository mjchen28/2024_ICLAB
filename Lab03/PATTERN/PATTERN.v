/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: PATTERN
// FILE NAME: PATTERN.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / PATTERN
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

`ifdef RTL
    `define CYCLE_TIME 4.0
`endif
`ifdef GATE
    `define CYCLE_TIME 4.0
`endif

module PATTERN(
	//OUTPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//INPUT
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg			rst_n, clk, in_valid;
output reg	[2:0]	tetrominoes;
output reg  [2:0]	position;
input 				tetris_valid, score_valid, fail;
input 		[3:0]	score;
input		[71:0]	tetris;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
real CYCLE = `CYCLE_TIME;

integer f_in;
integer PATNUM, pat_count;
integer game_num, block_num;
integer latency, total_latency;
integer i, j, k;
			
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg [2:0] tet, pos;
reg golden_fail;
reg golden_map [15:0][0:5];
reg [3:0] empty_top [0:5];		// Store the top index of the X axis
reg [3:0] golden_score;

reg [3:0] place_y_pos;
reg [3:0] middle_pos [1:0];
reg full [12:0];
reg [2:0] local_score;

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
always #(CYCLE/2.0) clk = ~clk;
initial	clk = 0;

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------
initial begin
	// Open input file
    f_in  = $fopen("../00_TESTBED/input.txt", "r");
    if (f_in == 0) begin
        $display("Failed to open input.txt");
        $finish;
    end

	// Initialize signals -- spec4
    reset_task;

	// Read pattern number
	k = $fscanf(f_in, "%d", PATNUM);

	// Check the functionality
	for(pat_count=0 ; pat_count<PATNUM ; pat_count=pat_count+1) begin
		while ((block_num < 16) && (golden_fail == 0)) begin
			// $display("Block number=%d", block_num);
			input_task;

			wait_score_valid_task;
			check_ans_task;
			// print_map;
			$display("\033[0;34mPASS PATTERN NO.%4d, BLOCK NO.%4d,\033[m \033[0;32mExecution Cycle: %3d", pat_count+1, block_num+1, latency);
			block_num = block_num + 1;
		end

		if(golden_fail == 1) begin
			// Skip the rest of the blocks if fail early
			for (i=0 ; i<(16-block_num) ; i=i+1) begin
				k = $fscanf(f_in, "%d   %d", tet, pos);
			end 
		end
		
		next_round;
	end

	// Pass all the pattern
	YOU_PASS_task;
	$finish;
end

//---------------------------------------------------------------------
//  ALWAYS
//---------------------------------------------------------------------
always @(posedge clk) begin
    if (score_valid === 0) begin
        if ((score !== 0) || (fail !== 0) || (tetris_valid !== 0)) begin
			fail_task;
			$display ("----------------------------------------------------------------");
            $display ("                         SPEC-5 FAIL                            ");
			$display ("score | fail | tetris_valid should be 0 when score_valid is low ");
			$display ("----------------------------------------------------------------");
            $finish;
        end
    end
end

always @(posedge clk) begin
    if (tetris_valid === 0) begin
        if (tetris !== 0) begin
			fail_task;
			$display ("--------------------------------------------------");
            $display ("                    SPEC-5 FAIL                   ");
			$display ("     tetris should be 0 when tetris_valid is low  ");
			$display ("--------------------------------------------------");
            $finish;
        end
    end
end

//---------------------------------------------------------------------
//  TASK
//---------------------------------------------------------------------
task reset_task; begin
	// Initialize signals
	rst_n = 1'b1;
	in_valid = 1'b0;
	tetrominoes = 3'dx;
	position = 3'dx;
	total_latency = 0;
	latency = 0;
	game_num = 0;
	block_num = 0;

	// Initialize circuit
	golden_fail = 0;
	golden_score = 0;
	for(i=0 ; i<6 ; i=i+1) empty_top[i] = 0;
	for(i=0 ; i<16 ; i=i+1) begin
		for(j=0 ; j<6 ; j=j+1) begin
			golden_map[i][j] = 0;
		end
	end
	place_y_pos = 0;
	local_score = 0;
	for(i=0 ; i<2 ; i=i+1) middle_pos[i] = 0;
	@(negedge clk);

	// Start reset
	force clk = 1'b0;
	#(CYCLE); rst_n = 1'b0;

	// spec 4 check
	#(100);
	if((tetris_valid !== 0) || (score_valid !== 0) || (fail !== 0) || (score !== 0) || (tetris !== 0)) begin
		fail_task;
		$display ("--------------------------------------------------");
		$display ("                    SPEC-4 FAIL                   ");
		$display ("        output signal should be 0 after reset     ");
		$display ("--------------------------------------------------");
		// repeat(2)@(negedge clk);
		$finish;
	end

	// Pass the reset check
	#(CYCLE); rst_n = 1'b1;
	#(CYCLE); release clk;
end
endtask

task input_task; begin
	// repeat($urandom_range(0, 3)) @(negedge clk);
	@(negedge clk);

	if(block_num === 0) k = $fscanf(f_in, "%d", game_num);
	
	in_valid = 1'b1;
	k = $fscanf(f_in, "%d   %d", tet, pos);
	tetrominoes = tet;
	position = pos;

	calculate_ans_task;

	@(negedge clk);

	in_valid = 1'b0;
	tetrominoes = 3'dx;
	position = 3'dx;
end
endtask

task wait_score_valid_task; begin
	// latency = 0;
	while(score_valid !== 1) begin
		// spec 6 check
		latency = latency + 1;
		if(latency > 1000) begin
			fail_task;
			$display ("-------------------------------------------------------");
			$display ("                      SPEC-6 FAIL                     ");
			$display ("  latency of each inputs set is limited in 1000 cycles");
			$display ("-------------------------------------------------------");
      		$finish;
		end

		@(negedge clk);
		// if(pat_count == 1 && latency == 46) $finish;
	end
	latency = latency + 1;
end
endtask

task calculate_ans_task; begin
	// Determine the placing y index
	case (tet)
		3'd0: begin
			place_y_pos = (empty_top[pos] > empty_top[pos+1]) ? empty_top[pos] : empty_top[pos+1];
		end
		3'd1: begin
			place_y_pos = empty_top[pos];
		end
		3'd2: begin
			middle_pos[0] = (empty_top[pos] > empty_top[pos+1]) ? empty_top[pos] : empty_top[pos+1];
			middle_pos[1] = (empty_top[pos+2] > empty_top[pos+3]) ? empty_top[pos+2] : empty_top[pos+3];

			place_y_pos = (middle_pos[0] > middle_pos[1]) ? middle_pos[0] : middle_pos[1];
		end
		3'd3: begin
			place_y_pos = (empty_top[pos] > (empty_top[pos+1]+2)) ? empty_top[pos] : (empty_top[pos+1]+2);
		end
		3'd4: begin
			middle_pos[0] = (empty_top[pos+1] > empty_top[pos+2]) ? empty_top[pos+1] : empty_top[pos+2];

			place_y_pos = ((empty_top[pos]+1) > middle_pos[0]) ? empty_top[pos] : (middle_pos[0]-1);
		end
		3'd5: begin
			place_y_pos = (empty_top[pos] > empty_top[pos+1]) ? empty_top[pos] : empty_top[pos+1];
		end
		3'd6: begin
			place_y_pos = (empty_top[pos] > (empty_top[pos+1]+1)) ? empty_top[pos] : (empty_top[pos+1]+1);
		end
		3'd7: begin
			middle_pos[0] = (empty_top[pos] > empty_top[pos+1]) ? empty_top[pos] : empty_top[pos+1];

			place_y_pos = ((middle_pos[0]+1) > empty_top[pos+2]) ? middle_pos[0] : (empty_top[pos+2]-1);
		end
	endcase

	// Update the Tetris map
	case (tet)
		3'd0: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
			golden_map[place_y_pos+1][pos] = 1;
			golden_map[place_y_pos+1][pos+1] = 1;
		end
		3'd1: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos+1][pos] = 1;
			golden_map[place_y_pos+2][pos] = 1;
			golden_map[place_y_pos+3][pos] = 1;
		end
		3'd2: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
			golden_map[place_y_pos][pos+2] = 1;
			golden_map[place_y_pos][pos+3] = 1;
		end
		3'd3: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
			golden_map[place_y_pos-1][pos+1] = 1;
			golden_map[place_y_pos-2][pos+1] = 1;
		end
		3'd4: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos+1][pos] = 1;
			golden_map[place_y_pos+1][pos+1] = 1;
			golden_map[place_y_pos+1][pos+2] = 1;
		end
		3'd5: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos+1][pos] = 1;
			golden_map[place_y_pos+2][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
		end
		3'd6: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos+1][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
			golden_map[place_y_pos-1][pos+1] = 1;
		end
		3'd7: begin
			golden_map[place_y_pos][pos] = 1;
			golden_map[place_y_pos][pos+1] = 1;
			golden_map[place_y_pos+1][pos+1] = 1;
			golden_map[place_y_pos+1][pos+2] = 1;
		end
	endcase

	// Update the empty_top
	case (tet)
		3'd0: begin
			empty_top[pos] = place_y_pos + 2;
			empty_top[pos+1] = place_y_pos + 2;
		end
		3'd1: begin
			empty_top[pos] = place_y_pos + 4;
		end
		3'd2: begin
			empty_top[pos] = place_y_pos + 1;
			empty_top[pos+1] = place_y_pos + 1;
			empty_top[pos+2] = place_y_pos + 1;
			empty_top[pos+3] = place_y_pos + 1;
		end
		3'd3: begin
			empty_top[pos] = place_y_pos + 1;
			empty_top[pos+1] = place_y_pos + 1;
		end
		3'd4: begin
			empty_top[pos] = place_y_pos + 2;
			empty_top[pos+1] = place_y_pos + 2;
			empty_top[pos+2] = place_y_pos + 2;
		end
		3'd5: begin
			empty_top[pos] = place_y_pos + 3;
			empty_top[pos+1] = place_y_pos + 1;
		end
		3'd6: begin
			empty_top[pos] = place_y_pos + 2;
			empty_top[pos+1] = place_y_pos + 1;
		end
		3'd7: begin
			empty_top[pos] = place_y_pos + 1;
			empty_top[pos+1] = place_y_pos + 2;
			empty_top[pos+2] = place_y_pos + 2;
		end
	endcase

	// Check if score
	for(i=0 ; i<12 ; i=i+1) full[i] = (golden_map[i][0] && golden_map[i][1] && golden_map[i][2] && golden_map[i][3] && golden_map[i][4] && golden_map[i][5]);
	for(i=11 ; i>=0 ; i=i-1) begin
		if(full[i]) begin
			local_score = local_score + 1;
			for(j=i ; j<13 ; j=j+1) begin
				golden_map[j] = golden_map[j+1];
			end
			for(j=0 ; j<6 ; j=j+1) begin
				for(k=11 ; k>=0 ; k=k-1) begin
					if(golden_map[k][j] === 1) begin
						empty_top[j] = k + 2;
						break;
					end
					else begin
						empty_top[j] = 0;
					end
				end
				if(empty_top[j] !== 0) empty_top[j] = empty_top[j] - 1;
			end
		end
	end
	// if(local_score > 1) begin
	// 	$display("score %1d", local_score);
	// 	print_map;
	// end 
	golden_score = golden_score + local_score;

	// print the whole golden_map
	// if(game_num > 16)print_map;

	// Check if fail
	full[12] = (golden_map[12][0] || golden_map[12][1] || golden_map[12][2] || golden_map[12][3] || golden_map[12][4] || golden_map[12][5]);
	if(full[12]) golden_fail = 1'b1;
end
endtask

task check_ans_task; begin
	
	if((golden_fail) || (block_num === 15)) begin		// End the round
		if((fail !== golden_fail) || (!tetris_valid) || (score !== golden_score)) begin
			fail_task;
			$display ("------------------------------------------------------------");
			$display ("                        SPEC-7 FAIL                          ");
			$display ("           golden_fail = %d, your_fail = %d              ", golden_fail, fail);
			$display ("           golden_tv = 1, your_tv = %d              ", tetris_valid);
			$display ("           golden_score = %3d, your_score = %3d              ", golden_score, score);
			$display ("------------------------------------------------------------");
			// repeat(2)@(negedge clk);
      		$finish;
		end

		for(i=0 ; i<12 ; i=i+1) begin
			for(j=0 ; j<6 ; j=j+1) begin
				if(tetris[6*i+j] !== golden_map[i][j]) begin
					fail_task;
					$display ("------------------------------------------------------------");
					$display("                         SPEC-7 FAIL                          ");
					$display("                    golden map incorrect                     ");
					$display("   golden_map[%2d][%2d] = %1d, your_map[%2d][%2d] = %1d   ", i, j, golden_map[i][j], i, j, tetris[6*i+j]);
					$display ("------------------------------------------------------------");
					// repeat(2)@(negedge clk);
      				$finish;
				end
			end
		end
	end
	else begin
		if((fail !== golden_fail) || (score !== golden_score)) begin
			fail_task;
			$display ("------------------------------------------------------------");
			$display ("                        SPEC-7 FAIL                          ");
			$display ("           golden_fail = %d, your_fail = %d              ", golden_fail, fail);
			$display ("           golden_score = %3d, your_score = %3d              ", golden_score, score);
			$display ("------------------------------------------------------------");
			// repeat(2)@(negedge clk);
      		$finish;
		end
	end
	
	local_score = 0;
	@(negedge clk);
  	if((score_valid !== 0) || (tetris_valid !== 0)) begin
		fail_task;
		$display ("------------------------------------------------------------");
		$display("                    SPEC-8 FAIL                   ");
		$display ("------------------------------------------------------------");
		// repeat(2)@(negedge clk);
      	$finish;
	end
end
endtask

task next_round; begin
	block_num = 0;
	golden_fail = 0;
	total_latency = total_latency + latency;
	latency = 0;

	// Initialize circuit
	golden_fail = 0;
	golden_score = 0;
	for(i=0 ; i<6 ; i=i+1) empty_top[i] = 0;
	for(i=0 ; i<16 ; i=i+1) begin
		for(j=0 ; j<6 ; j=j+1) begin
			golden_map[i][j] = 0;
		end
	end
	place_y_pos = 0;
	local_score = 0;
	for(i=0 ; i<2 ; i=i+1) middle_pos[i] = 0;
end
endtask

task print_map; begin
	$display("game = %3d, block num = %2d",game_num, block_num);
	$display("tetrix = %1d, position = %1d", tet, pos);
	$display("   %2d %2d %2d %2d %2d %2d", empty_top[0], empty_top[1], empty_top[2], empty_top[3], empty_top[4], empty_top[5]);
	$display("11| %1b %1b %1b %1b %1b %1b", golden_map[11][0], golden_map[11][1], golden_map[11][2], golden_map[11][3], golden_map[11][4], golden_map[11][5]);
	$display("10| %1b %1b %1b %1b %1b %1b", golden_map[10][0], golden_map[10][1], golden_map[10][2], golden_map[10][3], golden_map[10][4], golden_map[10][5]);
	$display(" 9| %1b %1b %1b %1b %1b %1b", golden_map[9][0], golden_map[9][1], golden_map[9][2], golden_map[9][3], golden_map[9][4], golden_map[9][5]);
	$display(" 8| %1b %1b %1b %1b %1b %1b", golden_map[8][0], golden_map[8][1], golden_map[8][2], golden_map[8][3], golden_map[8][4], golden_map[8][5]);
	$display(" 7| %1b %1b %1b %1b %1b %1b", golden_map[7][0], golden_map[7][1], golden_map[7][2], golden_map[7][3], golden_map[7][4], golden_map[7][5]);
	$display(" 6| %1b %1b %1b %1b %1b %1b", golden_map[6][0], golden_map[6][1], golden_map[6][2], golden_map[6][3], golden_map[6][4], golden_map[6][5]);
	$display(" 5| %1b %1b %1b %1b %1b %1b", golden_map[5][0], golden_map[5][1], golden_map[5][2], golden_map[5][3], golden_map[5][4], golden_map[5][5]);
	$display(" 4| %1b %1b %1b %1b %1b %1b", golden_map[4][0], golden_map[4][1], golden_map[4][2], golden_map[4][3], golden_map[4][4], golden_map[4][5]);
	$display(" 3| %1b %1b %1b %1b %1b %1b", golden_map[3][0], golden_map[3][1], golden_map[3][2], golden_map[3][3], golden_map[3][4], golden_map[3][5]);
	$display(" 2| %1b %1b %1b %1b %1b %1b", golden_map[2][0], golden_map[2][1], golden_map[2][2], golden_map[2][3], golden_map[2][4], golden_map[2][5]);
	$display(" 1| %1b %1b %1b %1b %1b %1b", golden_map[1][0], golden_map[1][1], golden_map[1][2], golden_map[1][3], golden_map[1][4], golden_map[1][5]);
	$display(" 0| %1b %1b %1b %1b %1b %1b", golden_map[0][0], golden_map[0][1], golden_map[0][2], golden_map[0][3], golden_map[0][4], golden_map[0][5]);
	$display("    -----------");
	$display("    0 1 2 3 4 5");
	$display("");
end
endtask

task YOU_PASS_task;begin
$display("\033[37m                                                                                                                                          ");        
$display("\033[37m                                                                                \033[32m      :BBQvi.                                              ");        
$display("\033[37m                                                              .i7ssrvs7         \033[32m     BBBBBBBBQi                                           ");        
$display("\033[37m                        .:r7rrrr:::.        .::::::...   .i7vr:.      .B:       \033[32m    :BBBP :7BBBB.                                         ");        
$display("\033[37m                      .Kv.........:rrvYr7v7rr:.....:rrirJr.   .rgBBBBg  Bi      \033[32m    BBBB     BBBB                                         ");        
$display("\033[37m                     7Q  :rubEPUri:.       ..:irrii:..    :bBBBBBBBBBBB  B      \033[32m   iBBBv     BBBB       vBr                               ");        
$display("\033[37m                    7B  BBBBBBBBBBBBBBB::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB :R     \033[32m   BBBBBKrirBBBB.     :BBBBBB:                            ");        
$display("\033[37m                   Jd .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: Bi    \033[32m  rBBBBBBBBBBBR.    .BBBM:BBB                             ");        
$display("\033[37m                  uZ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B    \033[32m  BBBB   .::.      EBBBi :BBU                             ");        
$display("\033[37m                 7B .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  B    \033[32m MBBBr           vBBBu   BBB.                             ");        
$display("\033[37m                .B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: JJ   \033[32m i7PB          iBBBBB.  iBBB                              ");        
$display("\033[37m                B. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  Lu             \033[32m  vBBBBPBBBBPBBB7       .7QBB5i                ");        
$display("\033[37m               Y1 KBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBi XBBBBBBBi :B            \033[32m :RBBB.  .rBBBBB.      rBBBBBBBB7              ");        
$display("\033[37m              :B .BBBBBBBBBBBBBsRBBBBBBBBBBBrQBBBBB. UBBBRrBBBBBBr 1BBBBBBBBB  B.          \033[32m    .       BBBB       BBBB  :BBBB             ");        
$display("\033[37m              Bi BBBBBBBBBBBBBi :BBBBBBBBBBE .BBK.  .  .   QBBBBBBBBBBBBBBBBBB  Bi         \033[32m           rBBBr       BBBB    BBBU            ");        
$display("\033[37m             .B .BBBBBBBBBBBBBBQBBBBBBBBBBBB       \033[38;2;242;172;172mBBv \033[37m.LBBBBBBBBBBBBBBBBBBBBBB. B7.:ii:   \033[32m           vBBB        .BBBB   :7i.            ");        
$display("\033[37m            .B  PBBBBBBBBBBBBBBBBBBBBBBBBBBBBbYQB. \033[38;2;242;172;172mBB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBB  Jr:::rK7 \033[32m             .7  BBB7   iBBBg                  ");        
$display("\033[37m           7M  PBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBB..i   .   v1                  \033[32mdBBB.   5BBBr                 ");        
$display("\033[37m          sZ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBB iD2BBQL.                 \033[32m ZBBBr  EBBBv     YBBBBQi     ");        
$display("\033[37m  .7YYUSIX5 .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBB. \033[37mBBBBBBBBBBBBBBBBBBBBBBBBY.:.      :B                 \033[32m  iBBBBBBBBD     BBBBBBBBB.   ");        
$display("\033[37m LB.        ..BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB. \033[38;2;242;172;172mBB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBMBBB. BP17si                 \033[32m    :LBBBr      vBBBi  5BBB   ");        
$display("\033[37m  KvJPBBB :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: \033[38;2;242;172;172mZB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBsiJr .i7ssr:                \033[32m          ...   :BBB:   BBBu  ");        
$display("\033[37m i7ii:.   ::BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBj \033[38;2;242;172;172muBi \033[37mQBBBBBBBBBBBBBBBBBBBBBBBBi.ir      iB                \033[32m         .BBBi   BBBB   iMBu  ");        
$display("\033[37mDB    .  vBdBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBg \033[38;2;242;172;172m7Bi \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBB rBrXPv.                \033[32m          BBBX   :BBBr        ");        
$display("\033[37m :vQBBB. BQBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBQ \033[38;2;242;172;172miB: \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .L:ii::irrrrrrrr7jIr   \033[32m          .BBBv  :BBBQ        ");        
$display("\033[37m :7:.   .. 5BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mBr \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBB:            ..... ..YB. \033[32m           .BBBBBBBBB:        ");        
$display("\033[37mBU  .:. BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  \033[38;2;242;172;172mB7 \033[37mgBBBBBBBBBBBBBBBBBBBBBBBBBB. gBBBBBBBBBBBBBBBBBB. BL \033[32m             rBBBBB1.         ");        
$display("\033[37m rY7iB: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: \033[38;2;242;172;172mB7 \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBB. QBBBBBBBBBBBBBBBBBi  v5                                ");        
$display("\033[37m     us EBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB \033[38;2;242;172;172mIr \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBgu7i.:BBBBBBBr Bu                                 ");        
$display("\033[37m      B  7BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.\033[38;2;242;172;172m:i \033[37mBBBBBBBBBBBBBBBBBBBBBBBBBBBv:.  .. :::  .rr    rB                                  ");        
$display("\033[37m      us  .BBBBBBBBBBBBBQLXBBBBBBBBBBBBBBBBBBBBBBBBq  .BBBBBBBBBBBBBBBBBBBBBBBBBv  :iJ7vri:::1Jr..isJYr                                   ");        
$display("\033[37m      B  BBBBBBB  MBBBM      qBBBBBBBBBBBBBBBBBBBBBB: BBBBBBBBBBBBBBBBBBBBBBBBBB  B:           iir:                                       ");        
$display("\033[37m     iB iBBBBBBBL       BBBP. :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  B.                                                       ");        
$display("\033[37m     P: BBBBBBBBBBB5v7gBBBBBB  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: Br                                                        ");        
$display("\033[37m     B  BBBs 7BBBBBBBBBBBBBB7 :BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B                                                         ");        
$display("\033[37m    .B :BBBB.  EBBBBBQBBBBBJ .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB. B.                                                         ");        
$display("\033[37m    ij qBBBBBg          ..  .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB .B                                                          ");        
$display("\033[37m    UY QBBBBBBBBSUSPDQL...iBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBK EL                                                          ");        
$display("\033[37m    B7 BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB: B:                                                          ");        
$display("\033[37m    B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBYrBB vBBBBBBBBBBBBBBBBBBBBBBBB. Ls                                                          ");        
$display("\033[37m    B  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBi_  /UBBBBBBBBBBBBBBBBBBBBBBBBB. :B:                                                        ");        
$display("\033[37m   rM .BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  ..IBBBBBBBBBBBBBBBBQBBBBBBBBBB  B                                                        ");        
$display("\033[37m   B  BBBBBBBBBdZBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBPBBBBBBBBBBBBEji:..     sBBBBBBBr Br                                                       ");        
$display("\033[37m  7B 7BBBBBBBr     .:vXQBBBBBBBBBBBBBBBBBBBBBBBBBQqui::..  ...i:i7777vi  BBBBBBr Bi                                                       ");        
$display("\033[37m  Ki BBBBBBB  rY7vr:i....  .............:.....  ...:rii7vrr7r:..      7B  BBBBB  Bi                                                       ");        
$display("\033[37m  B. BBBBBB  B:    .::ir77rrYLvvriiiiiiirvvY7rr77ri:..                 bU  iQBB:..rI                                                      ");        
$display("\033[37m.S: 7BBBBP  B.                                                          vI7.  .:.  B.                                                     ");        
$display("\033[37mB: ir:.   :B.                                                             :rvsUjUgU.                                                      ");        
$display("\033[37mrMvrrirJKur                                                                                                                               \033[m");
$display ("--------------------------------------------------------------------------------------------------------------------------------------------");
$display("                  Congratulations!               ");
$display("              execution cycles = %7d", total_latency);
$display("              clock period = %4fns", CYCLE);
$display ("--------------------------------------------------------------------------------------------------------------------------------------------");
	
end endtask


task fail_task; begin
$display("\033[38;2;252;238;238m                                                                                                                                           ");      
$display("\033[38;2;252;238;238m                                                                                                :L777777v7.                                ");
$display("\033[31m  i:..::::::i.      :::::         ::::    .:::.       \033[38;2;252;238;238m                                       .vYr::::::::i7Lvi                             ");
$display("\033[31m  BBBBBBBBBBBi     iBBBBBL       .BBBB    7BBB7       \033[38;2;252;238;238m                                      JL..\033[38;2;252;172;172m:r777v777i::\033[38;2;252;238;238m.ijL                           ");
$display("\033[31m  BBBB.::::ir.     BBB:BBB.      .BBBv    iBBB:       \033[38;2;252;238;238m                                    :K: \033[38;2;252;172;172miv777rrrrr777v7:.\033[38;2;252;238;238m:J7                         ");
$display("\033[31m  BBBQ            :BBY iBB7       BBB7    :BBB:       \033[38;2;252;238;238m                                   :d \033[38;2;252;172;172m.L7rrrrrrrrrrrrr77v: \033[38;2;252;238;238miI.                       ");
$display("\033[31m  BBBB            BBB. .BBB.      BBB7    :BBB:       \033[38;2;252;238;238m                                  .B \033[38;2;252;172;172m.L7rrrrrrrrrrrrrrrrr7v..\033[38;2;252;238;238mBr                      ");
$display("\033[31m  BBBB:r7vvj:    :BBB   gBBs      BBB7    :BBB:       \033[38;2;252;238;238m                                  S:\033[38;2;252;172;172m v7rrrrrrrrrrrrrrrrrrr7v. \033[38;2;252;238;238mB:                     ");
$display("\033[31m  BBBBBBBBBB7    BBB:   .BBB.     BBB7    :BBB:       \033[38;2;252;238;238m                                 .D \033[38;2;252;172;172mi7rrrrrrr777rrrrrrrrrrr7v. \033[38;2;252;238;238mB.                    ");
$display("\033[31m  BBBB    ..    iBBBBBBBBBBBP     BBB7    :BBB:       \033[38;2;252;238;238m                                 rv\033[38;2;252;172;172m v7rrrrrr7rirv7rrrrrrrrrr7v \033[38;2;252;238;238m:I                    ");
$display("\033[31m  BBBB          BBBBi7vviQBBB.    BBB7    :BBB.       \033[38;2;252;238;238m                                 2i\033[38;2;252;172;172m.v7rrrrrr7i  :v7rrrrrrrrrrvi \033[38;2;252;238;238mB:                   ");
$display("\033[31m  BBBB         rBBB.      BBBQ   .BBBv    iBBB2ir777L7\033[38;2;252;238;238m                                 2i.\033[38;2;252;172;172mv7rrrrrr7v \033[38;2;252;238;238m:..\033[38;2;252;172;172mv7rrrrrrrrr77 \033[38;2;252;238;238mrX                   ");
$display("\033[31m .BBBB        :BBBB       BBBB7  .BBBB    7BBBBBBBBBBB\033[38;2;252;238;238m                                 Yv \033[38;2;252;172;172mv7rrrrrrrv.\033[38;2;252;238;238m.B \033[38;2;252;172;172m.vrrrrrrrrrrL.\033[38;2;252;238;238m:5                   ");
$display("\033[31m  . ..        ....         ...:   ....    ..   .......\033[38;2;252;238;238m                                 .q \033[38;2;252;172;172mr7rrrrrrr7i \033[38;2;252;238;238mPv \033[38;2;252;172;172mi7rrrrrrrrrv.\033[38;2;252;238;238m:S                   ");
$display("\033[38;2;252;238;238m                                                                                        Lr \033[38;2;252;172;172m77rrrrrr77 \033[38;2;252;238;238m:B. \033[38;2;252;172;172mv7rrrrrrrrv.\033[38;2;252;238;238m:S                   ");
$display("\033[38;2;252;238;238m                                                                                         B: \033[38;2;252;172;172m7v7rrrrrv. \033[38;2;252;238;238mBY \033[38;2;252;172;172mi7rrrrrrr7v \033[38;2;252;238;238miK                   ");
$display("\033[38;2;252;238;238m                                                                              .::rriii7rir7. \033[38;2;252;172;172m.r77777vi \033[38;2;252;238;238m7B  \033[38;2;252;172;172mvrrrrrrr7r \033[38;2;252;238;238m2r                   ");
$display("\033[38;2;252;238;238m                                                                       .:rr7rri::......    .     \033[38;2;252;172;172m.:i7s \033[38;2;252;238;238m.B. \033[38;2;252;172;172mv7rrrrr7L..\033[38;2;252;238;238mB                    ");
$display("\033[38;2;252;238;238m                                                        .::7L7rriiiirr77rrrrrrrr72BBBBBBBBBBBBvi:..  \033[38;2;252;172;172m.  \033[38;2;252;238;238mBr \033[38;2;252;172;172m77rrrrrvi \033[38;2;252;238;238mKi                    ");
$display("\033[38;2;252;238;238m                                                    :rv7i::...........    .:i7BBBBQbPPPqPPPdEZQBBBBBr:.\033[38;2;252;238;238m ii \033[38;2;252;172;172mvvrrrrvr \033[38;2;252;238;238mvs                     ");
$display("\033[38;2;252;238;238m                    .S77L.                      .rvi:. ..:r7QBBBBBBBBBBBgri.    .:BBBPqqKKqqqqPPPPPEQBBBZi  \033[38;2;252;172;172m:777vi \033[38;2;252;238;238mvI                      ");
$display("\033[38;2;252;238;238m                    B: ..Jv                   isi. .:rBBBBBQZPPPPqqqPPdERBBBBBi.    :BBRKqqqqqqqqqqqqPKDDBB:  \033[38;2;252;172;172m:7. \033[38;2;252;238;238mJr                       ");
$display("\033[38;2;252;238;238m                   vv SB: iu                rL: .iBBBQEPqqPPqqqqqqqqqqqqqPPPPbQBBB:   .EBQKqqqqqqPPPqqKqPPgBB:  .B:                        ");
$display("\033[38;2;252;238;238m                  :R  BgBL..s7            rU: .qBBEKPqqqqqqqqqqqqqqqqqqqqqqqqqPPPEBBB:   EBEPPPEgQBBQEPqqqqKEBB: .s                        ");
$display("\033[38;2;252;238;238m               .U7.  iBZBBBi :ji         5r .MBQqPqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPKgBB:  .BBBBBdJrrSBBQKqqqqKZB7  I:                      ");
$display("\033[38;2;252;238;238m              v2. :rBBBB: .BB:.ru7:    :5. rBQqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPPBB:  :.        .5BKqqqqqqBB. Kr                     ");
$display("\033[38;2;252;238;238m             .B .BBQBB.   .RBBr  :L77ri2  BBqPqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPbBB   \033[38;2;252;172;172m.irrrrri  \033[38;2;252;238;238mQQqqqqqqKRB. 2i                    ");
$display("\033[38;2;252;238;238m              27 :BBU  rBBBdB \033[38;2;252;172;172m iri::::: \033[38;2;252;238;238m.BQKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqKRBs\033[38;2;252;172;172mirrr7777L: \033[38;2;252;238;238m7BqqqqqqqXZB. BLv772i              ");
$display("\033[38;2;252;238;238m               rY  PK  .:dPMB \033[38;2;252;172;172m.Y77777r.\033[38;2;252;238;238m:BEqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPPBqi\033[38;2;252;172;172mirrrrrv: \033[38;2;252;238;238muBqqqqqqqqqgB  :.:. B:             ");
$display("\033[38;2;252;238;238m                iu 7BBi  rMgB \033[38;2;252;172;172m.vrrrrri\033[38;2;252;238;238mrBEqKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPQgi\033[38;2;252;172;172mirrrrv. \033[38;2;252;238;238mQQqqqqqqqqqXBb .BBB .s:.           ");
$display("\033[38;2;252;238;238m                i7 BBdBBBPqbB \033[38;2;252;172;172m.vrrrri\033[38;2;252;238;238miDgPPbPqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPQDi\033[38;2;252;172;172mirr77 \033[38;2;252;238;238m:BdqqqqqqqqqqPB. rBB. .:iu7         ");
$display("\033[38;2;252;238;238m                iX.:iBRKPqKXB.\033[38;2;252;172;172m 77rrr\033[38;2;252;238;238mi7QPBBBBPqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPB7i\033[38;2;252;172;172mrr7r \033[38;2;252;238;238m.vBBPPqqqqqqKqBZ  BPBgri: 1B        ");
$display("\033[38;2;252;238;238m                 ivr .BBqqKXBi \033[38;2;252;172;172mr7rri\033[38;2;252;238;238miQgQi   QZKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPEQi\033[38;2;252;172;172mirr7r.  \033[38;2;252;238;238miBBqPqqqqqqPB:.QPPRBBB LK        ");
$display("\033[38;2;252;238;238m                   :I. iBgqgBZ \033[38;2;252;172;172m:7rr\033[38;2;252;238;238miJQPB.   gRqqqqqqqqPPPPPPPPqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqPQ7\033[38;2;252;172;172mirrr7vr.  \033[38;2;252;238;238mUBqqPPgBBQPBBKqqqKB  B         ");
$display("\033[38;2;252;238;238m                     v7 .BBR: \033[38;2;252;172;172m.r7ri\033[38;2;252;238;238miggqPBrrBBBBBBBBBBBBBBBBBBQEPPqqPPPqqqqqqqqqqqqqqqqqqqqqqqqqPgPi\033[38;2;252;172;172mirrrr7v7  \033[38;2;252;238;238mrBPBBP:.LBbPqqqqqB. u.        ");
$display("\033[38;2;252;238;238m                      .j. . \033[38;2;252;172;172m :77rr\033[38;2;252;238;238miiBPqPbBB::::::.....:::iirrSBBBBBBBQZPPPPPqqqqqqqqqqqqqqqqqqqqEQi\033[38;2;252;172;172mirrrrrr7v \033[38;2;252;238;238m.BB:     :BPqqqqqDB .B        ");
$display("\033[38;2;252;238;238m                       YL \033[38;2;252;172;172m.i77rrrr\033[38;2;252;238;238miLQPqqKQJ. \033[38;2;252;172;172m ............       \033[38;2;252;238;238m..:irBBBBBBZPPPqqqqqqqPPBBEPqqqdRr\033[38;2;252;172;172mirrrrrr7v \033[38;2;252;238;238m.B  .iBB  dQPqqqqPBi Y:       ");
$display("\033[38;2;252;238;238m                     :U:.\033[38;2;252;172;172mrv7rrrrri\033[38;2;252;238;238miPgqqqqKZB.\033[38;2;252;172;172m.v77777777777777ri::..   \033[38;2;252;238;238m  ..:rBBBBQPPqqqqPBUvBEqqqPRr\033[38;2;252;172;172mirrrrrrvi\033[38;2;252;238;238m iB:RBBbB7 :BQqPqKqBR r7       ");
$display("\033[38;2;252;238;238m                    iI.\033[38;2;252;172;172m.v7rrrrrrri\033[38;2;252;238;238midgqqqqqKB:\033[38;2;252;172;172m 77rrrrrrrrrrrrr77777777ri:..   \033[38;2;252;238;238m .:1BBBEPPB:   BbqqPQr\033[38;2;252;172;172mirrrr7vr\033[38;2;252;238;238m .BBBZPqqDB  .JBbqKPBi vi       ");
$display("\033[38;2;252;238;238m                   :B \033[38;2;252;172;172miL7rrrrrrrri\033[38;2;252;238;238mibgqqqqqqBr\033[38;2;252;172;172m r7rrrrrrrrrrrrrrrrrrrrr777777ri:.  \033[38;2;252;238;238m .iBBBBi  .BbqqdRr\033[38;2;252;172;172mirr7v7: \033[38;2;252;238;238m.Bi.dBBPqqgB:  :BPqgB  B        ");
$display("\033[38;2;252;238;238m                   .K.i\033[38;2;252;172;172mv7rrrrrrrri\033[38;2;252;238;238miZgqqqqqqEB \033[38;2;252;172;172m.vrrrrrrrrrrrrrrrrrrrrrrrrrrr777vv7i.  \033[38;2;252;238;238m :PBBBBPqqqEQ\033[38;2;252;172;172miir77:  \033[38;2;252;238;238m:BB:  .rBPqqEBB. iBZB. Rr        ");
$display("\033[38;2;252;238;238m                    iM.:\033[38;2;252;172;172mv7rrrrrrrri\033[38;2;252;238;238mUQPqqqqqPBi\033[38;2;252;172;172m i7rrrrrrrrrrrrrrrrrrrrrrrrr77777i.   \033[38;2;252;238;238m.  :BddPqqqqEg\033[38;2;252;172;172miir7. \033[38;2;252;238;238mrBBPqBBP. :BXKqgB  BBB. 2r         ");
$display("\033[38;2;252;238;238m                     :U:.\033[38;2;252;172;172miv77rrrrri\033[38;2;252;238;238mrBPqqqqqqPB: \033[38;2;252;172;172m:7777rrrrrrrrrrrrrrr777777ri.   \033[38;2;252;238;238m.:uBBBBZPqqqqqqPQL\033[38;2;252;172;172mirr77 \033[38;2;252;238;238m.BZqqPB:  qMqqPB. Yv:  Ur          ");
$display("\033[38;2;252;238;238m                       1L:.\033[38;2;252;172;172m:77v77rii\033[38;2;252;238;238mqQPqqqqqPbBi \033[38;2;252;172;172m .ir777777777777777ri:..   \033[38;2;252;238;238m.:rBBBRPPPPPqqqqqqqgQ\033[38;2;252;172;172miirr7vr \033[38;2;252;238;238m:BqXQ: .BQPZBBq ...:vv.           ");
$display("\033[38;2;252;238;238m                         LJi..\033[38;2;252;172;172m::r7rii\033[38;2;252;238;238mRgKPPPPqPqBB:.  \033[38;2;252;172;172m ............     \033[38;2;252;238;238m..:rBBBBPPqqKKKKqqqPPqPbB1\033[38;2;252;172;172mrvvvvvr  \033[38;2;252;238;238mBEEDQBBBBBRri. 7JLi              ");
$display("\033[38;2;252;238;238m                           .jL\033[38;2;252;172;172m  777rrr\033[38;2;252;238;238mBBBBBBgEPPEBBBvri:::::::::irrrbBBBBBBDPPPPqqqqqqXPPZQBBBBr\033[38;2;252;172;172m.......\033[38;2;252;238;238m.:BBBBg1ri:....:rIr                 ");
$display("\033[38;2;252;238;238m                            vI \033[38;2;252;172;172m:irrr:....\033[38;2;252;238;238m:rrEBBBBBBBBBBBBBBBBBBBBBBBBBBBBBQQBBBBBBBBBBBBBQr\033[38;2;252;172;172mi:...:.   \033[38;2;252;238;238m.:ii:.. .:.:irri::                    ");
$display("\033[38;2;252;238;238m                             71vi\033[38;2;252;172;172m:::irrr::....\033[38;2;252;238;238m    ...:..::::irrr7777777777777rrii::....  ..::irvrr7sUJYv7777v7ii..                         ");
$display("\033[38;2;252;238;238m                               .i777i. ..:rrri77rriiiiiii:::::::...............:::iiirr7vrrr:.                                             ");
$display("\033[38;2;252;238;238m                                                      .::::::::::::::::::::::::::::::                                                      \033[m");
end endtask

endmodule