`define CYCLE_TIME 10.0

`include "../00_TESTBED/pseudo_DRAM.v"

`define PAT_NUM 1000

`define DRAM_PATH "../00_TESTBED/DRAM/dram1.dat"

// CHECK_IF_MORE_LESS_1: 1 means accept the deviation (+1~-1)
//                       0 means not accept
`define CHECK_IF_MORE_LESS_1 1

// RAN: 1 means random mode, 0 means give pattern manually
//PIC_NO and MODE are in consideration when RAN = 0
`define RAN_FOR_PIC 1
`define PIC_NO 0
`define RAN_FOR_MODE 1
`define MODE 1



module PATTERN(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    in_pic_no,
    in_mode,
    in_ratio_mode,
    out_valid,
    out_data
);

/* Input for design */
output reg        clk, rst_n;
output reg        in_valid;

output reg [3:0] in_pic_no;
output reg       in_mode;
output reg [1:0] in_ratio_mode;

input out_valid;
input [7:0] out_data;


//////////////////////////////////////////////////////////////////////
// Write your own task here
//////////////////////////////////////////////////////////////////////

real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;


// Do it yourself, I believe you can!!!

reg have_reset;


parameter DRAM_p_r = `DRAM_PATH;
reg [7:0] DRAM_r [0:199607];


integer latency, total_latency;
integer file;
integer i_pat;
reg mode;
reg [31:0] count;


initial begin
    
    file = $fopen("../00_TESTBED/debug.txt", "w");
    $readmemh(DRAM_p_r, DRAM_r);

	have_reset = 0;
    reset_task;

	for (i_pat = 0; i_pat < `PAT_NUM; i_pat = i_pat + 1) begin  // ipat<1000
		
        repeat (2) @(negedge clk);
        $display();
        $display("Now in pattern %4d", i_pat);
        input_task;
        wait_out_valid_task;
        compare_with_gold_task;

		$display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32mExecution Cycle: %3d\033[m", i_pat, latency);
	end

    
    // All patterns passed
    YOU_PASS_task;
	$finish; // in YOU_PASS_task
end




reg [31:0] init_address;

task input_task; begin
	in_valid = 1;

    if(`RAN_FOR_PIC == 1) begin
        in_pic_no = $urandom_range(15, 0);
    end
    else begin
        in_pic_no = `PIC_NO;
    end

    if(`RAN_FOR_MODE == 1) begin
        in_mode = $urandom_range(1, 0);
    end
    else begin
        in_mode = `MODE;
    end

    // in_pic_no = $urandom_range(15, 0);
    // in_pic_no = 15;
    // in_mode = $urandom_range(1, 0);
    // in_mode = 1;
    
    $display("in_pic_no: %2d", in_pic_no);
    $display("in_mode: %3d", in_mode);

    if(in_mode) begin
        in_ratio_mode = $urandom_range(3, 0);
        $display("in_ratio_mode: %2d", in_ratio_mode);
        // in_ratio_mode = 1;
    end
    else begin
        in_ratio_mode = 2'bxx;
    end

    init_address = 32'h10000 + 3072*in_pic_no;

    write_input_task;

    if (in_mode) begin  // exposure
        exposure_task;
        write_change_task;
    end
    else begin  // focus
        focus_task;
        write_mid_task;
    end


    write_output_task;

    mode = in_mode;

	@(negedge clk);
	in_valid = 'b0;
	in_pic_no = 4'bxxxx;
    in_mode = 'bx;
    in_ratio_mode = 2'bxx;

end endtask

reg [31:0] i;
reg [7:0] midr [35:0];
reg [7:0] midg [35:0];
reg [7:0] midb [35:0];
reg [7:0] mid_compound [35:0];

reg [7:0] dmax;
reg [1:0] max_type;
reg [17:0] sum;
reg [7:0] average;

//////////////////////////////////////////////////// write file ////////////////////////////////////////////////////

task write_input_task; begin
    $fwrite(file, "========= PATTERN NO. %d =========\n", i_pat);
    if(!in_mode) $fwrite(file, "========  focus mode  =====\n");
    else $fwrite(file, "========  exposure mode  =====\n");
    $fwrite(file, "========  in_pic_no %d  =========\n", in_pic_no);
    $fwrite(file, "========  in_ratio %d  =========\n", in_ratio_mode);
    $fwrite(file, "\n");
    $fwrite(file, "complete DRAM R: \n");
    count = 0;
    for(i = init_address; i < init_address + 1024; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end

    $fwrite(file, "\n");
    $fwrite(file, "complete DRAM G: \n");
    count = 0;
    for(i = init_address + 1024; i < init_address + 2048; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end
    
    $fwrite(file, "\n");
    $fwrite(file, "complete DRAM B: \n");
    count = 0;
    for(i = init_address + 2048; i < init_address + 3072; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end

    count = 0;

end endtask

task write_change_task; begin
    $fwrite(file, "\n");
    $fwrite(file, "changed DRAM R: \n");
    count = 0;
    for(i = init_address; i < init_address + 1024; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end

    $fwrite(file, "\n");
    $fwrite(file, "changed DRAM G: \n");
    count = 0;
    for(i = init_address + 1024; i < init_address + 2048; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end
    
    $fwrite(file, "\n");
    $fwrite(file, "changed DRAM B: \n");
    count = 0;
    for(i = init_address + 2048; i < init_address + 3072; i = i + 1) begin
        $fwrite(file, "%4d ", DRAM_r[i]);
        count = count + 1;
        if(count == 32) begin
            $fwrite(file, "\n");
            count = 0;
        end
    end

    count = 0;
end endtask

task write_mid_task; begin
    
    count = 0;
    
    $fwrite(file, "\n");
    $fwrite(file, "partial DRAM r: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midr[count]);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "partial DRAM g: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midg[count]);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "partial DRAM b: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midb[count]);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "DRAM r/4: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midr[count]/4);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "DRAM g/2: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midg[count]/2);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "DRAM b/4: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", midb[count]/4);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;
    $fwrite(file, "\n");
    $fwrite(file, "partial DRAM compound: \n");
    while(count < 36) begin
        $fwrite(file, "%4d ", mid_compound[count]);
        count = count + 1;
        if(count%6 == 0) begin
            $fwrite(file, "\n");
        end
    end
    count = 0;

end endtask

task write_output_task; begin
    $fwrite(file, "\n");
    $fwrite(file, "in_mode_finally: %d\n", in_mode);
    if(!in_mode) begin
        $fwrite(file, "max_contrast: %d\n", dmax);
        $fwrite(file, "type of the block: %d\n", max_type);
    end
    else begin
        $fwrite(file, "average: %d\n", average);
    end
end endtask

//////////////////////////////////////////////////// focus ////////////////////////////////////////////////////

task focus_task; begin
    get_middle_task;
    cal_Gcenter_task;
    cal_Dcontrast_task;
    cal_max_task;
end endtask

task get_middle_task; begin
    count = 0;
    for(i = (init_address + 429); i <= (init_address + 594); i = i + 1) begin
        midr[count] = DRAM_r[i];
        count = count + 1;
        if(i == init_address + 562 || i == init_address + 434 || i == init_address + 466 || i == init_address + 498 || i == init_address + 530) i = i + 26;
    end

    count = 0;
    for(i = (init_address + 1024 + 429); i <= (init_address + 1024 + 594); i = i + 1) begin
        midg[count] = DRAM_r[i];
        count = count + 1;
        if(i == init_address + 1024 + 562 || i == init_address + 1024 + 434 || i == init_address + 1024 + 466 || i == init_address + 1024 + 498 || i == init_address + 1024 + 530) i = i + 26;
    end

    count = 0;
    for(i = (init_address + 2048 + 429); i <= (init_address + 2048 + 594); i = i + 1) begin
        midb[count] = DRAM_r[i];
        count = count + 1;
        if(i == init_address + 2048 + 562 || i == init_address + 2048 + 434 || i == init_address + 2048 + 466 || i == init_address + 2048 + 498 || i == init_address + 2048 + 530) i = i + 26;
    end
end endtask

task cal_Gcenter_task; begin
    for(i = 0; i < 36; i = i + 1) begin
        mid_compound[i] = midr[i]/4 + midg[i]/2 + midb[i]/4;
    end
end endtask

reg [18:0] d0, d1, d2;

task cal_Dcontrast_task; begin

    d0 = 0;
    d1 = 0;
    d2 = 0;

    // 0

    d0 = d0 + abs(14, 15);
    d0 = d0 + abs(14, 20);
    d0 = d0 + abs(15, 21);
    d0 = d0 + abs(20, 21);

    // 1
    count = 0;
    i = 8;
    while(count < 12) begin
        d1 = d1 + abs(i-1, i);

        if(count % 3 == 2) i = i + 4;
        else i = i + 1;

        count = count + 1;
    end

    count = 0;
    i = 13;
    while(count < 12) begin
        d1 = d1 + abs(i-6, i);

        if(count % 4 == 3) i = i + 3;
        else i = i + 1;

        count = count + 1;
    end

    // 2
    count = 0;
    i = 1;
    while(count < 30) begin
        d2 = d2 + abs(i-1, i);

        if(count % 5 == 4) i = i + 2;
        else i = i + 1;

        count = count + 1;

    end

    count = 0;
    i = 6;
    while(count < 30) begin
        d2 = d2 + abs(i-6, i);

        i = i + 1;
        count = count + 1;
    end

    $fwrite(file, "\n");
    $fwrite(file, "before divide: \n");
    $fwrite(file, "d0: %d\n", d0);
    $fwrite(file, "d1: %d\n", d1);
    $fwrite(file, "d2: %d\n", d2);
    d0 = d0/4;
    d1 = d1/16;
    d2 = d2/36;
    $fwrite(file, "after divide: \n");
    $fwrite(file, "d0: %d\n", d0);
    $fwrite(file, "d1: %d\n", d1);
    $fwrite(file, "d2: %d\n", d2);

end endtask

function [7:0] abs;
    input [5:0] a;
    input [5:0] b;
    if(mid_compound[a] > mid_compound[b]) begin
        abs = mid_compound[a] - mid_compound[b];
    end
    else begin
        abs = mid_compound[b] - mid_compound[a];
    end
endfunction

task cal_max_task; begin
    dmax = d0;
    max_type = 0;
    if(d1 > d0) begin
        dmax = d1;
        max_type = 1;
    end
    if(d2 > dmax) begin
        dmax = d2;
        max_type = 2;
    end
end endtask


//////////////////////////////////////////////////// exposure ////////////////////////////////////////////////////

task exposure_task; begin
    change_value_task;
    cal_avg_task;
end endtask

task change_value_task; begin
    for(i = init_address; i < init_address + 1024; i = i + 1) begin
        if(in_ratio_mode == 0) begin
            DRAM_r[i] = DRAM_r[i] / 4;
        end
        else if (in_ratio_mode == 1) begin
            DRAM_r[i] = DRAM_r[i] / 2;
        end
        else if (in_ratio_mode == 2) begin
            DRAM_r[i] = DRAM_r[i];
        end
        else if (in_ratio_mode == 3) begin
            if(DRAM_r[i] *2 > 255) DRAM_r[i] = 255;
            else DRAM_r[i] = DRAM_r[i] * 2;
        end
    end
    for(i = init_address + 1024; i < init_address + 1024 + 1024; i = i + 1) begin
        if(in_ratio_mode == 0) begin
            DRAM_r[i] = DRAM_r[i] / 4;
        end
        else if (in_ratio_mode == 1) begin
            DRAM_r[i] = DRAM_r[i] / 2;
        end
        else if (in_ratio_mode == 2) begin
            DRAM_r[i] = DRAM_r[i];
        end
        else if (in_ratio_mode == 3) begin
            if(DRAM_r[i] *2 > 255) DRAM_r[i] = 255;
            else DRAM_r[i] = DRAM_r[i] * 2;
        end
    end
    for(i = init_address + 2048; i < init_address + 2048 + 1024; i = i + 1) begin
        if(in_ratio_mode == 0) begin
            DRAM_r[i] = DRAM_r[i] / 4;
        end
        else if (in_ratio_mode == 1) begin
            DRAM_r[i] = DRAM_r[i] / 2;
        end
        else if (in_ratio_mode == 2) begin
            DRAM_r[i] = DRAM_r[i];
        end
        else if (in_ratio_mode == 3) begin
            if(DRAM_r[i] *2 > 255) DRAM_r[i] = 255;
            else DRAM_r[i] = DRAM_r[i] * 2;
        end
    end
end endtask

task cal_avg_task; begin
    sum = 0;
    for(i = init_address; i < init_address + 1024; i = i + 1) begin
        sum = sum + DRAM_r[i]/4 + DRAM_r[i + 1024]/2 + DRAM_r[i + 2048]/4;
    end
    average = sum / 1024;
end endtask


//////////////////////////////////////////////////// spec task ////////////////////////////////////////////////////



always @(negedge clk) begin
	if(have_reset) begin
		if((out_valid === 0) && (out_data !== 0)) begin
			$display("                    valid low but data raised                   ");
			$finish;
		end
	end
end

reg sv_last;
always @ (negedge clk) begin
	if((out_valid === 1 && sv_last === 1)) begin
		$display("                    valid high for over two cycle                   ");
		$finish;
	end
	sv_last = out_valid;
end


task wait_out_valid_task; begin
    latency = 0;
    while (out_valid !== 1'b1) begin
        latency = latency + 1;
        if (latency == 2000) begin
            // $display("********************************************************");     
            // $display("                          FAIL!                           ");
            // $display("*  The execution latency exceeded 2000 cycles at %8t   *", $time);
            // $display("********************************************************");
			$display("                    execute over 2000 cycles                   ");
            repeat (2) @(negedge clk);
            $finish;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end endtask

reg [7:0] average_up;
reg [7:0] average_down;

task compare_with_gold_task; begin

    average_up = (average == 255) ? 255 : average+1;
    average_down = (average == 0) ? 0 : average-1;

	if((out_valid === 0) && (out_data !== 0)) begin
		$display("                    valid low but data raised                   ");
		$finish;
	end

    if(!mode) begin
        if((out_valid !== 1'b1) || (out_data !== max_type)) begin
	    	$display("************************************************************");  
            $display("                       FAIL! wrong mode %d                    ", mode);
            $display("*  The output signals do not match the expected values at %8t *", $time);
            $display("************************************************************");
            $display("                    output data incorrect                   ");
	    	repeat (2) #CYCLE;
            $finish;
        end
    end
    else begin
        if(`CHECK_IF_MORE_LESS_1 == 1) begin
        if((out_valid !== 1'b1) || ((out_data !== average) && (out_data !== average_up) && (out_data != average_down))) begin
	    	$display("************************************************************");  
            $display("                       FAIL! wrong mode %d                    ", mode);
            $display("*  The output signals do not match the expected values at %8t *", $time);
            $display("************************************************************");
            $display("                    output data incorrect                   ");
	    	repeat (2) #CYCLE;
            $finish;
        end
        end
        else begin
        if((out_valid !== 1'b1) || (out_data !== average)) begin
	    	$display("************************************************************");  
            $display("                       FAIL! wrong mode %d                    ", mode);
            $display("*  The output signals do not match the expected values at %8t *", $time);
            $display("************************************************************");
            $display("                    output data incorrect                   ");
	    	repeat (2) #CYCLE;
            $finish;
        end
        end
    end
end endtask

task reset_task; begin
	rst_n = 1'b1;
    in_valid = 1'b0;
    in_pic_no = 4'bxxxx;
    in_mode = 1'bx;
    in_ratio_mode = 1'bx;
    total_latency = 0;

    force clk = 0;

    // Apply reset
    #CYCLE; rst_n = 1'b0; 
    #CYCLE; rst_n = 1'b1;
	
	if (out_valid !== 1'b0 || out_data !== 8'b0) begin
        $display("************************************************************");  
        $display("                          FAIL!                           ");    
        $display("*  Output signals should be 0 after initial RESET at %8t *", $time);
        $display("************************************************************");
		$display("                    output signals should be reset                   ");
        repeat (2) #CYCLE;
        $finish;
    end
	#CYCLE; release clk;
	have_reset = 1;
end endtask

task YOU_PASS_task; begin
    $display("----------------------------------------------------------------------------------------------------------------------");
    $display("                                                  Congratulations!                                                    ");
    $display("                                           You have passed all patterns!                                               ");
    $display("                                           Your execution cycles = %5d cycles                                          ", total_latency);
    $display("                                           Your clock period = %.1f ns                                                 ", CYCLE);
    $display("                                           Total Latency = %.1f ns                                                    ", total_latency * CYCLE);
    $display("----------------------------------------------------------------------------------------------------------------------");
    $display("                  Congratulations!               ");
	$display("              execution cycles = %4d", total_latency);
	$display("              clock period = %4fns", CYCLE);
	repeat (2) @(negedge clk);
    $finish;
end endtask






endmodule
