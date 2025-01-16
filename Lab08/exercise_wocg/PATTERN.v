/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: SA
// FILE NAME: PATTERN.v
// VERSRION: 1.0
// DATE: Nov 06, 2024
// AUTHOR: Yen-Ning Tung, NYCU AIG
// CODE TYPE: RTL or Behavioral Level (Verilog)
// DESCRIPTION: 2024 Fall IC Lab / Exersise Lab08 / PATTERN
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
// Number of patterns
`define PATTERN_NUMBER 100
`define SIMPLE_PAT_NUM 10
`define CORNER_CASE_NUM 20

module PATTERN(
	// Output signals
	clk,
	rst_n,
	in_valid,
	T,
	in_data,
	w_Q,
	w_K,
	w_V,

	// Input signals
	out_valid,
	out_data
);

output reg clk;
output reg rst_n;
output reg in_valid;
output reg [3:0] T;
output reg signed [7:0] in_data;
output reg signed [7:0] w_Q;
output reg signed [7:0] w_K;
output reg signed [7:0] w_V;

input out_valid;
input signed [63:0] out_data;

//================================================================
// Clock
//================================================================


//================================================================
// parameters & integer
//================================================================
integer SEED = 5487;
integer PAT_NUM = `PATTERN_NUMBER;
integer SIMPLE_PAT_NUM = `SIMPLE_PAT_NUM;
integer CORNER_CASE_NUM = `CORNER_CASE_NUM;
integer pat_count, set_count;
integer latency, total_latency;
integer i, j, k, l;
// file_output
integer fout_debug;



//================================================================
// Wire & Reg Declaration
//================================================================
reg [3:0] gold_T;
reg signed [7:0] gold_in_data [0:7][0:7];
reg signed [7:0] gold_wQ [0:7][0:7];
reg signed [7:0] gold_wK [0:7][0:7];
reg signed [7:0] gold_wV [0:7][0:7];

reg signed [48:0] gold_Q [0:7][0:7];
reg signed [48:0] gold_K [0:7][0:7];
reg signed [48:0] gold_KT [0:7][0:7];  // Transpose of gold_K
reg signed [48:0] gold_V [0:7][0:7];
reg signed [48:0] gold_matmul1 [0:7][0:7];
reg signed [48:0] gold_scale [0:7][0:7];
reg signed [48:0] gold_RELU [0:7][0:7];
reg signed [63:0] gold_out_data [0:7][0:7];

//================================================================
// clock
//================================================================
real CYCLE = 50.0;
always	#(CYCLE/2.0) clk = ~clk;
initial	clk = 0;

//================================================================
// initial
//================================================================
initial begin

    // Initialize signals
    reset_task;

    // Iterate through random pattern
    for(pat_count=0 ; pat_count<PAT_NUM ; pat_count=pat_count+1) begin
		pattern_input_task;
		check_ans_task;
    end

    // Pass all the pattern
    YOU_PASS_task;
	#(CYCLE); $finish;
end

//================================================================
// task
//================================================================
/* Check for invalid overlap */
always @(*) begin
    if (in_valid && out_valid) begin
		fail_task;
        $display("************************************************************");  
        $display("*                         FAIL!                            *");    
        $display("*    The out_valid signal cannot overlap with in_valid.    *");
        $display("************************************************************");
		repeat(2) #(CYCLE);
        $finish;            
    end    
end

task reset_task; begin

    // Initialize output signals
    rst_n 		= 1'b1;
	in_valid 	= 1'b0;
	T	     	= 4'dx;
	in_data		= 8'dx;
	w_Q	     	= 8'dx;
	w_K	     	= 8'dx;
	w_V	     	= 8'dx;
	

    // Initialize pattern signals
    latency = 0;
    total_latency = 0;

	gold_T = 0;
	for(i=0 ; i<8 ; i+=1) begin
		for(j=0 ; j<8 ; j+=1) begin
			gold_in_data[i][j] 	= 0;
			gold_wQ[i][j] 	   	= 0;
			gold_wK[i][j] 	   	= 0;
			gold_wV[i][j] 	   	= 0;
			gold_Q[i][j] 		= 0;
			gold_K[i][j] 		= 0;
			gold_V[i][j] 		= 0;
			gold_matmul1[i][j] 	= 0;
			gold_scale[i][j]   	= 0;
			gold_RELU[i][j]    	= 0;
			gold_out_data[i][j] = 0;
		end
	end

    force clk = 0; 

    // Apply reset
    #CYCLE; rst_n = 1'b0; 
    #CYCLE; rst_n = 1'b1;
    
    // Check initial conditions
    if((out_valid !== 0) || (out_data !== 0)) begin
        fail_task;
		$display ("--------------------------------------------------");
		$display ("                       FAIL                       ");
		$display ("        output signal should be 0 after reset     ");
		$display ("--------------------------------------------------");
		repeat(2) #(CYCLE);
		$finish;
    end

	#CYCLE; 
	release clk;
end endtask


task pattern_input_task; begin
	// Wait for 1~3 cycles
	repeat($urandom_range(2, 5)) @(negedge clk);

	// Generate stimulus
	gold_T = $urandom_range(0, 2);
	case(gold_T)
		0: gold_T = 1;
		1: gold_T = 4;
		2: gold_T = 8;
		default: gold_T = 4'dx;
	endcase

	if(pat_count < SIMPLE_PAT_NUM) begin
		for(i=0 ; i<8 ; i+=1) begin
			for(j=0 ; j<8 ; j+=1) begin
				gold_in_data[i][j] 	= $random % 2;
				gold_wQ[i][j] 	   	= $random % 2;
				gold_wK[i][j] 	   	= $random % 2;
				gold_wV[i][j] 	   	= $random % 2;
			end
		end
	end
	else if(pat_count > PAT_NUM - CORNER_CASE_NUM)begin
		if(pat_count % 2 == 0) begin
			for(i=0 ; i<8 ; i+=1) begin
				for(j=0 ; j<8 ; j+=1) begin
					gold_in_data[i][j] 	= 127;
					gold_wQ[i][j] 	   	= 127;
					gold_wK[i][j] 	   	= 127;
					gold_wV[i][j] 	   	= 127;
				end
			end
		end
		else begin
			for(i=0 ; i<8 ; i+=1) begin
				for(j=0 ; j<8 ; j+=1) begin
					gold_in_data[i][j] 	= -128;
					gold_wQ[i][j] 	   	= -128;
					gold_wK[i][j] 	   	= -128;
					gold_wV[i][j] 	   	= -128;
				end
			end
		end
	end
	else begin
		for(i=0 ; i<8 ; i+=1) begin
			for(j=0 ; j<8 ; j+=1) begin
				gold_in_data[i][j] 	= $random % 256;
				gold_wQ[i][j] 	   	= $random % 256;
				gold_wK[i][j] 	   	= $random % 256;
				gold_wV[i][j] 	   	= $random % 256;
			end
		end
	end

	// Calculate answer
	for(i=0; i<8; i+=1) begin
		for(j=0; j<8; j+=1) begin
            gold_Q[i][j] = 0;
            gold_K[i][j] = 0;
            gold_V[i][j] = 0;
			gold_matmul1[i][j] = 0;
			gold_out_data[i][j] = 0;
		end
	end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            for (k = 0; k < 8; k = k + 1) begin
                gold_Q[i][j] += gold_in_data[i][k] * gold_wQ[k][j];
                gold_K[i][j] += gold_in_data[i][k] * gold_wK[k][j];
                gold_V[i][j] += gold_in_data[i][k] * gold_wV[k][j];
            end
        end
    end

	//transpose k
    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            gold_KT[i][j] = gold_K[j][i];
        end
    end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            for (k = 0; k < 8; k = k + 1) begin
                gold_matmul1[i][j] += gold_Q[i][k] * gold_KT[k][j];
            end
        end
    end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            gold_scale[i][j] = gold_matmul1[i][j] / 3;
        end
    end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            if (gold_scale[i][j] < 0)
                gold_RELU[i][j] = 0;
            else
                gold_RELU[i][j] = gold_scale[i][j];
        end
    end

    for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            for (k = 0; k < gold_T; k = k + 1) begin
                gold_out_data[i][j] += gold_RELU[i][k] * gold_V[k][j];
            end
        end
    end


	// Write debug.txt
	fout_debug = $fopen("../00_TESTBED/debug.txt", "w");
	$fwrite(fout_debug, "// ==================== PATTERN %5d ==================== //\n\n", pat_count+1);

	$fwrite(fout_debug, "T :\n");
	$fwrite(fout_debug, "%1d\n\n", gold_T);
	$fwrite(fout_debug, "In_data :\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%4d ", gold_in_data[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "w_Q:\n\n");
	for(i=0 ; i<8 ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%4d ", gold_wQ[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "w_K:\n\n");
	for(i=0 ; i<8 ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%4d ", gold_wK[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "w_V:\n\n");
	for(i=0 ; i<8 ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%4d ", gold_wV[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");
	
	$fwrite(fout_debug, "Q:\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%6d ", gold_Q[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "K:\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%6d ", gold_K[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "V:\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%6d ", gold_V[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");
	

	$fwrite(fout_debug, "MatMul 1 :\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<gold_T ; j=j+1) $fwrite(fout_debug, "%15d ", gold_matmul1[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "after relu :\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<gold_T ; j=j+1) $fwrite(fout_debug, "%15d ", gold_scale[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "after scale + relu :\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<gold_T ; j=j+1) $fwrite(fout_debug, "%15d ", gold_RELU[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fwrite(fout_debug, "Output data :\n\n");
	for(i=0 ; i<gold_T ; i=i+1) begin
		for(j=0 ; j<8 ; j=j+1) $fwrite(fout_debug, "%19d ", gold_out_data[i][j]);
		$fwrite(fout_debug, "\n");
	end
	$fwrite(fout_debug, "\n");

	$fclose(fout_debug);

	// Pattern input
	in_valid = 1'b1;
	for(i=0 ; i<64 ; i=i+1) begin
		if(i == 0)
			T = gold_T;
		else
			T = 4'dx;
		
		if(i/8 < gold_T)
			in_data = gold_in_data[i/8][i%8];
		else
			in_data = 8'dx;

		w_Q = gold_wQ[i/8][i%8];
		w_K = 8'dx;
		w_V = 8'dx;

		@(negedge clk); 
	end

	for(i=0 ; i<64 ; i=i+1) begin
		w_Q = 8'dx;
		w_K = gold_wK[i/8][i%8];
		w_V = 8'dx;
		in_data = 8'dx;
		@(negedge clk); 
	end

	for(i=0 ; i<64 ; i=i+1) begin
		w_Q = 8'dx;
		w_K = 8'dx;
		w_V = gold_wV[i/8][i%8];
		in_data = 8'dx;
		@(negedge clk); 
	end
	
	// Input end
	in_valid = 1'd0;
	w_Q = 8'dx;
	w_K = 8'dx;
	w_V = 8'dx;
	in_data = 8'dx;
	T = 4'dx;

end endtask


task check_ans_task; begin
	latency = 0;

	// Check out_data
	while(out_valid !== 1) begin

		if(out_data !== 0) begin
			fail_task;
			$display ("-------------------------------------------------------");
			$display ("                         FAIL                          ");
			$display ("        output value should be 0 when valid is low     ");
			$display ("-------------------------------------------------------");
			#(CYCLE); $finish;
		end

		latency = latency + 1;
		if(latency > 2000) begin
			fail_task;
			$display ("-------------------------------------------------------");
			$display ("                         FAIL                          ");
			$display ("       excution latency is limited in 2000 cycles      ");
			$display ("-------------------------------------------------------");
			#(CYCLE); $finish;
		end
		// Wait a cycle
		@(negedge clk);
	end
	//latency = latency + 1;

	for(i=0; i<gold_T; i+=1) begin
		for(j=0; j<8; j+=1) begin
			if(out_data !== gold_out_data[i][j]) begin
				fail_task;
				$display ("-------------------------------------------------------");
				$display ("                         FAIL                          ");
				$display ("                  wrong output value                   ");
				$display ("-------------------------------------------------------");
				$display ("      PATTERN %5d, OUTPUT MAP 1, ROW %1d, COL %1d      ", pat_count+1, i+1, j+1);
				$display ("                golden_out_data : %3d                  ", gold_out_data[i][j]);
				$display ("                  your_out_data : %3d                  ", out_data);
				$display ("-------------------------------------------------------");
				#(CYCLE); $finish;
			end

			@(negedge clk);
		end
	end

	$display("\033[0;34mPASS PATTERN NO.%5d, \033[m \033[0;32mExecution Cycle: %3d\033[m", pat_count+1, latency);
	total_latency = total_latency + latency;
	latency = 0;
end endtask


task YOU_PASS_task; begin
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
$display("                                                   Congratulations!               ");
$display("                                               execution cycles = %8d", total_latency);
$display("                                               clock period = %4fns", CYCLE);
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

