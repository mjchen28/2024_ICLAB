
// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

// debug.txt is in 01_RTL !!
`define CYCLE_TIME 4.2
`define PATTERN_NUMER 5800
// Set testing action type : 0->Index_Check, 1->Update, 2->Check_Valid_Date, 3->Random
`define TEST_TYPE 3

//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter MAX_CYCLE=1000;

integer SEED = 111;
integer PAT_NUM = `PATTERN_NUMER;
integer TESTING = `TEST_TYPE;
integer pat_count;
integer latency, total_latency;
integer i, j, k, load, discard;
integer tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7, tmp8, tmp9, tmp10, tmp11, tmp12;
integer cnt2;
// file_output
integer fout_debug;

// golden data
typedef struct packed {
    Action          g_action;
    Mode            g_mode;
    Date            g_date;
    Formula_Type    g_formula;
    Data_No         g_data_no;
    Warn_Msg        g_warn;
    Index           g_index_A;
    Index           g_index_B;
    Index           g_index_C;
    Index           g_index_D;
    int             g_threshold;
    int             g_result;

    Date            g_dram_date;
    Index           g_dram_index_A;
    Index           g_dram_index_B;
    Index           g_dram_index_C;
    Index           g_dram_index_D;
} Gold;

// random pattern gen
class rand_pattern;
    rand Action r_action;
    rand Formula_Type r_formula;
    rand Mode r_mode;
    rand int r_month;
    rand int r_day;
    rand int r_data_no;
    rand int r_index1;
    rand int r_index2;
    rand int r_index3;
    rand int r_index4;

    int test_type;

    function new(int seed, int value);
        this.srandom(seed);
        this.test_type = value;
    endfunction

    constraint limit{
        if(test_type == 0){
            r_action == Index_Check;
        } else if(test_type == 1){
             r_action == Update;
        } else if(test_type == 2){
             r_action == Check_Valid_Date;
        } else {
            r_action inside{Index_Check, Update, Check_Valid_Date};
        }
        // r_action inside{Index_Check, Update, Check_Valid_Date};

        r_formula inside{Formula_A, Formula_B, Formula_C, Formula_D, Formula_E, Formula_F, Formula_G, Formula_H};
        
        r_mode inside{Insensitive, Normal, Sensitive};

        r_month inside {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};

        if (r_month == 2) {
            r_day >= 1;  // February: 1 to 28
            r_day <= 28;
        } else if (r_month inside {4, 6, 9, 11}) {
            r_day >= 1;  // Months with 30 days
            r_day <= 30;
        } else {
            r_day >= 1;  // Months with 31 days
            r_day <= 31;
        }
        
        r_data_no >= 0;
        r_data_no <= 255;

        r_index1 >= 0;
        r_index1 <= 4095;
        r_index2 >= 0;
        r_index2 <= 4095;
        r_index3 >= 0;
        r_index3 <= 4095;
        r_index4 >= 0;
        r_index4 <= 4095;
    }
endclass

//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  

Gold G; // golden data
logic g_complete;
rand_pattern pat_gen = new(SEED, TESTING);

//================================================================
// clock
//================================================================
real CYCLE = `CYCLE_TIME;

//================================================================
// initial
//================================================================
initial begin
    // initialize DRAM
    $readmemh(DRAM_p_r, golden_DRAM);
    fout_debug = $fopen("debug.txt", "w");
    $fwrite(fout_debug, "<< Tip >> Searching for pattern N : Ctrl + f, then enter [N-here] \n\n");

    // Initialize signals
    reset_task;

    // Iterate through random pattern
    for(pat_count=0 ; pat_count<PAT_NUM ; pat_count=pat_count+1) begin
        pattern_gen_task;
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
// /* Check for invalid overlap */
// always@(*) begin
//     if ((inf.sel_action_valid || inf.formula_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.index_valid) && inf.out_valid) begin
// 		fail_task;
//         $display("************************************************************");  
//         $display("*                         FAIL!                            *");    
//         $display("*    The out_valid signal cannot overlap with in_valid.    *");
//         $display("************************************************************");
// 		#(CYCLE); $finish;            
//     end    
// end


task reset_task; begin
    // Initialize output signals
    inf.rst_n               = 1'b1;
    inf.sel_action_valid    = 1'b0;
    inf.formula_valid       = 1'b0;
    inf.mode_valid          = 1'b0;
    inf.date_valid          = 1'b0;
    inf.data_no_valid       = 1'b0;
    inf.index_valid         = 1'b0;
    inf.D                   = 'dx;
    total_latency           = 0;
    cnt2                    = 0;

    // Initialize pattern signals
    #(CYCLE); inf.rst_n = 1'b0;
    #(CYCLE); inf.rst_n = 1'b1;

    // Check initial conditions
    if((inf.out_valid !== 0) || (inf.warn_msg !== 0) || (inf.complete !== 0) || (inf.AR_VALID !== 0) || (inf.AR_ADDR !== 0) || (inf.R_READY !== 0) || (inf.AW_VALID !== 0) || (inf.AW_ADDR !== 0) || (inf.W_VALID !== 0) || (inf.W_DATA !== 0) || (inf.B_READY !== 0)) begin
        fail_task;
		$display ("--------------------------------------------------");
		$display ("                       FAIL                       ");
		$display ("        output signal should be 0 after reset     ");
		$display ("--------------------------------------------------");
        #(CYCLE); $finish;
    end

    #(CYCLE);
end endtask


task pattern_gen_task; begin
    // generate random pattern
    i = pat_gen.randomize();
    if(i == 0) begin
        $display("random paattern generate fail !!");
        $finish;
    end 

    if(pat_count < 5800) begin
        // action
        if(pat_count % 8 > 4) begin
            discard = $urandom_range(0, 1);
            if(discard == 0)    G.g_action = Update;
            else                G.g_action = Check_Valid_Date;
        end
        else begin
            G.g_action = Index_Check;
            cnt2 = cnt2 + 1;
        end                   

        // formula
        case ({cnt2 % 8})
            0: G.g_formula = Formula_A;
            1: G.g_formula = Formula_B;
            2: G.g_formula = Formula_C;
            3: G.g_formula = Formula_D;
            4: G.g_formula = Formula_E;
            5: G.g_formula = Formula_F;
            6: G.g_formula = Formula_G;
            7: G.g_formula = Formula_H;
        endcase

        // mode
        case ({cnt2 % 3})
            0: G.g_mode = Insensitive;
            1: G.g_mode = Normal;
            2: G.g_mode = Sensitive;
        endcase
    end
    else begin
        G.g_action  = pat_gen.r_action;
        G.g_mode    = pat_gen.r_mode;
        G.g_formula = pat_gen.r_formula;
    end
    
    G.g_date.M  = pat_gen.r_month;
    G.g_date.D  = pat_gen.r_day;
    G.g_data_no = pat_gen.r_data_no;
    G.g_index_A = pat_gen.r_index1;
    G.g_index_B = pat_gen.r_index2;
    G.g_index_C = pat_gen.r_index3;
    G.g_index_D = pat_gen.r_index4;

    // get DRAM data
    G.g_dram_date.D     = golden_DRAM[65536 + (8*G.g_data_no) + 0];
    G.g_dram_date.M     = golden_DRAM[65536 + (8*G.g_data_no) + 4];
    G.g_dram_index_A    = (golden_DRAM[65536 + (8*G.g_data_no) + 7] << 4) + (golden_DRAM[65536 + (8*G.g_data_no) + 6] >> 4);
    G.g_dram_index_B    = (golden_DRAM[65536 + (8*G.g_data_no) + 6] << 8) + (golden_DRAM[65536 + (8*G.g_data_no) + 5]);
    G.g_dram_index_C    = (golden_DRAM[65536 + (8*G.g_data_no) + 3] << 4) + (golden_DRAM[65536 + (8*G.g_data_no) + 2] >> 4);
    G.g_dram_index_D    = (golden_DRAM[65536 + (8*G.g_data_no) + 2] << 8) + (golden_DRAM[65536 + (8*G.g_data_no) + 1]);

    $fwrite(fout_debug, "// ==================== PATTERN %5d-here ==================== //\n\n", pat_count);
    $fwrite(fout_debug, "Action : %2d \n", G.g_action);
    case (G.g_action)
    
        Index_Check: begin
            // get threshold & result
            case (G.g_formula)
                Formula_A: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 2047;
                        Normal:         G.g_threshold = 1023;
                        Sensitive:      G.g_threshold = 511;
                    endcase

                    G.g_result = (G.g_dram_index_A + G.g_dram_index_B + G.g_dram_index_C + G.g_dram_index_D) / 4;
                end
                Formula_B: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 800;
                        Normal:         G.g_threshold = 400;
                        Sensitive:      G.g_threshold = 200;
                    endcase

                    tmp1 = (G.g_dram_index_A > G.g_dram_index_B)? G.g_dram_index_A:G.g_dram_index_B;
                    tmp2 = (G.g_dram_index_C > G.g_dram_index_D)? G.g_dram_index_C:G.g_dram_index_D;
                    tmp3 = (tmp1 > tmp2)? tmp1:tmp2;
                    tmp1 = (G.g_dram_index_A < G.g_dram_index_B)? G.g_dram_index_A:G.g_dram_index_B;
                    tmp2 = (G.g_dram_index_C < G.g_dram_index_D)? G.g_dram_index_C:G.g_dram_index_D;
                    tmp4 = (tmp1 < tmp2)? tmp1:tmp2;

                    G.g_result = tmp3 - tmp4;
                end
                Formula_C: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 2047;
                        Normal:         G.g_threshold = 1023;
                        Sensitive:      G.g_threshold = 511;
                    endcase

                    tmp1 = (G.g_dram_index_A < G.g_dram_index_B)? G.g_dram_index_A:G.g_dram_index_B;
                    tmp2 = (G.g_dram_index_C < G.g_dram_index_D)? G.g_dram_index_C:G.g_dram_index_D;
                    tmp4 = (tmp1 < tmp2)? tmp1:tmp2;

                    G.g_result = tmp4;
                end
                Formula_D: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 3;
                        Normal:         G.g_threshold = 2;
                        Sensitive:      G.g_threshold = 1;
                    endcase

                    tmp1 = (G.g_dram_index_A >= 2047)? 1:0;
                    tmp2 = (G.g_dram_index_B >= 2047)? 1:0;
                    tmp3 = (G.g_dram_index_C >= 2047)? 1:0;
                    tmp4 = (G.g_dram_index_D >= 2047)? 1:0;

                    G.g_result = tmp1 + tmp2 + tmp3 + tmp4;
                end
                Formula_E: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 3;
                        Normal:         G.g_threshold = 2;
                        Sensitive:      G.g_threshold = 1;
                    endcase

                    tmp1 = (G.g_dram_index_A >= G.g_index_A)? 1:0;
                    tmp2 = (G.g_dram_index_B >= G.g_index_B)? 1:0;
                    tmp3 = (G.g_dram_index_C >= G.g_index_C)? 1:0;
                    tmp4 = (G.g_dram_index_D >= G.g_index_D)? 1:0;

                    G.g_result = tmp1 + tmp2 + tmp3 + tmp4;
                end
                Formula_F: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 800;
                        Normal:         G.g_threshold = 400;
                        Sensitive:      G.g_threshold = 200;
                    endcase

                    tmp1 = (G.g_dram_index_A >= G.g_index_A)? G.g_dram_index_A - G.g_index_A:G.g_index_A - G.g_dram_index_A;
                    tmp2 = (G.g_dram_index_B >= G.g_index_B)? G.g_dram_index_B - G.g_index_B:G.g_index_B - G.g_dram_index_B;
                    tmp3 = (G.g_dram_index_C >= G.g_index_C)? G.g_dram_index_C - G.g_index_C:G.g_index_C - G.g_dram_index_C;
                    tmp4 = (G.g_dram_index_D >= G.g_index_D)? G.g_dram_index_D - G.g_index_D:G.g_index_D - G.g_dram_index_D;
                    tmp5 = (tmp1 > tmp2)? tmp1:tmp2;
                    tmp6 = (tmp3 > tmp4)? tmp3:tmp4;
                    tmp7 = (tmp5 > tmp6)? tmp5:tmp6;

                    G.g_result = (tmp1 + tmp2 + tmp3 + tmp4 - tmp7) / 3;
                end
                Formula_G: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 800;
                        Normal:         G.g_threshold = 400;
                        Sensitive:      G.g_threshold = 200;
                    endcase

                    tmp1 = (G.g_dram_index_A >= G.g_index_A)? G.g_dram_index_A - G.g_index_A:G.g_index_A - G.g_dram_index_A;
                    tmp2 = (G.g_dram_index_B >= G.g_index_B)? G.g_dram_index_B - G.g_index_B:G.g_index_B - G.g_dram_index_B;
                    tmp3 = (G.g_dram_index_C >= G.g_index_C)? G.g_dram_index_C - G.g_index_C:G.g_index_C - G.g_dram_index_C;
                    tmp4 = (G.g_dram_index_D >= G.g_index_D)? G.g_dram_index_D - G.g_index_D:G.g_index_D - G.g_dram_index_D;
                    tmp5 = (tmp1 > tmp2)? tmp1:tmp2;
                    tmp6 = (tmp3 > tmp4)? tmp3:tmp4;
                    tmp7 = (tmp5 > tmp6)? tmp5:tmp6;    // N3
                    tmp8 = (tmp5 > tmp6)? tmp6:tmp5;    // N2
                    tmp9 = (tmp1 > tmp2)? tmp2:tmp1;
                    tmp10 = (tmp3 > tmp4)? tmp4:tmp3;
                    tmp11 = (tmp9 > tmp10)? tmp9:tmp10; // N1
                    tmp12 = (tmp9 > tmp10)? tmp10:tmp9; // N0

                    G.g_result = (tmp12 / 2) + (tmp11 / 4) + (tmp8 / 4);
                end
                Formula_H: begin
                    case (G.g_mode)
                        Insensitive:    G.g_threshold = 800;
                        Normal:         G.g_threshold = 400;
                        Sensitive:      G.g_threshold = 200;
                    endcase

                    tmp1 = (G.g_dram_index_A >= G.g_index_A)? G.g_dram_index_A - G.g_index_A:G.g_index_A - G.g_dram_index_A;
                    tmp2 = (G.g_dram_index_B >= G.g_index_B)? G.g_dram_index_B - G.g_index_B:G.g_index_B - G.g_dram_index_B;
                    tmp3 = (G.g_dram_index_C >= G.g_index_C)? G.g_dram_index_C - G.g_index_C:G.g_index_C - G.g_dram_index_C;
                    tmp4 = (G.g_dram_index_D >= G.g_index_D)? G.g_dram_index_D - G.g_index_D:G.g_index_D - G.g_dram_index_D;

                    G.g_result = (tmp1 + tmp2 + tmp3 + tmp4) / 4;
                end
            endcase

            // get warn message
            if(G.g_date.M < G.g_dram_date.M)                                            G.g_warn = Date_Warn;
            else if((G.g_date.M == G.g_dram_date.M) && (G.g_date.D < G.g_dram_date.D))  G.g_warn = Date_Warn;
            else if(G.g_result >= G.g_threshold)                                        G.g_warn = Risk_Warn;
            else                                                                        G.g_warn = No_Warn;

            if(G.g_warn === No_Warn)    g_complete = 1;
            else                        g_complete = 0;

            $fwrite(fout_debug, "\n");
            $fwrite(fout_debug, "Input month : %2d, Input day : %2d \n", G.g_date.M, G.g_date.D);
            $fwrite(fout_debug, "Input index A : %4d \n", G.g_index_A);
            $fwrite(fout_debug, "Input index B : %4d \n", G.g_index_B);
            $fwrite(fout_debug, "Input index C : %4d \n", G.g_index_C);
            $fwrite(fout_debug, "Input index D : %4d \n", G.g_index_D);
            $fwrite(fout_debug, "--------------------\n");
            $fwrite(fout_debug, "Data no : %3d \n", G.g_data_no);
            $fwrite(fout_debug, "DRAM month : %2d, DRAM day : %2d \n", G.g_dram_date.M, G.g_dram_date.D);
            $fwrite(fout_debug, "DRAM index A : %4d \n", G.g_dram_index_A);
            $fwrite(fout_debug, "DRAM index B : %4d \n", G.g_dram_index_B);
            $fwrite(fout_debug, "DRAM index C : %4d \n", G.g_dram_index_C);
            $fwrite(fout_debug, "DRAM index D : %4d \n", G.g_dram_index_D);
            $fwrite(fout_debug, "--------------------\n");
            $fwrite(fout_debug, "Formula    : %4d \n", G.g_formula);
            $fwrite(fout_debug, "Mode       : %4d \n", G.g_mode);
            $fwrite(fout_debug, "Treshold   : %4d \n", G.g_threshold);
            $fwrite(fout_debug, "Result     : %4d \n", G.g_result);
            $fwrite(fout_debug, "--------------------\n");
            case (G.g_warn)
                No_Warn: $fwrite(fout_debug, "Warn message : No_Warn \n");
                Date_Warn: $fwrite(fout_debug, "Warn message : Date_Warn \n");
                Risk_Warn: $fwrite(fout_debug, "Warn message : Risk_Warn \n");
                Data_Warn: $fwrite(fout_debug, "Warn message : Data_Warn \n");
            endcase
            $fwrite(fout_debug, "Complete   : %1d \n", g_complete);
        end

        Update: begin
            // debug.txt
            $fwrite(fout_debug, "\n");
            $fwrite(fout_debug, "Data no : %3d \n", G.g_data_no);
            $fwrite(fout_debug, "Old month : %2d, Old day : %2d \n", G.g_dram_date.M, G.g_dram_date.D);
            $fwrite(fout_debug, "Old DRAM index A : %4d \n", G.g_dram_index_A);
            $fwrite(fout_debug, "Old DRAM index B : %4d \n", G.g_dram_index_B);
            $fwrite(fout_debug, "Old DRAM index C : %4d \n", G.g_dram_index_C);
            $fwrite(fout_debug, "Old DRAM index D : %4d \n", G.g_dram_index_D);

            // update the index
            G.g_warn = No_Warn;

            if($signed({1'b0, G.g_dram_index_A}) + $signed(G.g_index_A) > 4095) begin
                G.g_dram_index_A = 4095;
                G.g_warn = Data_Warn;
            end     
            else if($signed({1'b0, G.g_dram_index_A}) + $signed(G.g_index_A) < 0) begin
                G.g_dram_index_A = 0;
                G.g_warn = Data_Warn;
            end    
            else G.g_dram_index_A = $signed({1'b0, G.g_dram_index_A}) + $signed(G.g_index_A);

            if($signed({1'b0, G.g_dram_index_B}) + $signed(G.g_index_B) > 4095) begin
                G.g_dram_index_B = 4095;
                G.g_warn = Data_Warn;
            end     
            else if($signed({1'b0, G.g_dram_index_B}) + $signed(G.g_index_B) < 0) begin
                G.g_dram_index_B = 0;
                G.g_warn = Data_Warn;
            end    
            else G.g_dram_index_B = $signed({1'b0, G.g_dram_index_B}) + $signed(G.g_index_B);

            if($signed({1'b0, G.g_dram_index_C}) + $signed(G.g_index_C) > 4095) begin
                G.g_dram_index_C = 4095;
                G.g_warn = Data_Warn;
            end     
            else if($signed({1'b0, G.g_dram_index_C}) + $signed(G.g_index_C) < 0) begin
                G.g_dram_index_C = 0;
                G.g_warn = Data_Warn;
            end    
            else G.g_dram_index_C = $signed({1'b0, G.g_dram_index_C}) + $signed(G.g_index_C);

            if($signed({1'b0, G.g_dram_index_D}) + $signed(G.g_index_D) > 4095) begin
                G.g_dram_index_D = 4095;
                G.g_warn = Data_Warn;
            end     
            else if($signed({1'b0, G.g_dram_index_D}) + $signed(G.g_index_D) < 0) begin
                G.g_dram_index_D = 0;
                G.g_warn = Data_Warn;
            end    
            else G.g_dram_index_D = $signed({1'b0, G.g_dram_index_D}) + $signed(G.g_index_D);

            // update the date
            G.g_dram_date.M = G.g_date.M;
            G.g_dram_date.D = G.g_date.D;

            // update DRAM
            golden_DRAM[65536 + (8*G.g_data_no) + 0] = G.g_dram_date.D;
            golden_DRAM[65536 + (8*G.g_data_no) + 1] = G.g_dram_index_D;
            golden_DRAM[65536 + (8*G.g_data_no) + 2] = (G.g_dram_index_C << 4) + (G.g_dram_index_D >> 8);
            golden_DRAM[65536 + (8*G.g_data_no) + 3] = G.g_dram_index_C >> 4;
            golden_DRAM[65536 + (8*G.g_data_no) + 4] = G.g_dram_date.M;
            golden_DRAM[65536 + (8*G.g_data_no) + 5] = G.g_dram_index_B;
            golden_DRAM[65536 + (8*G.g_data_no) + 6] = (G.g_dram_index_A << 4) + (G.g_dram_index_B >> 8);
            golden_DRAM[65536 + (8*G.g_data_no) + 7] = G.g_dram_index_A >> 4;

            if(G.g_warn === No_Warn)    g_complete = 1;
            else                        g_complete = 0;

            // debug.txt
            $fwrite(fout_debug, "------------------------------------------------\n");
            $fwrite(fout_debug, "New month : %2d, New day : %2d \n", G.g_date.M, G.g_date.D);
            $fwrite(fout_debug, "Input variation A : %5d, New DRAM index A : %4d \n", $signed(G.g_index_A), G.g_dram_index_A);
            $fwrite(fout_debug, "Input variation B : %5d, New DRAM index B : %4d \n", $signed(G.g_index_B), G.g_dram_index_B);
            $fwrite(fout_debug, "Input variation C : %5d, New DRAM index C : %4d \n", $signed(G.g_index_C), G.g_dram_index_C);
            $fwrite(fout_debug, "Input variation D : %5d, New DRAM index D : %4d \n", $signed(G.g_index_D), G.g_dram_index_D);
            $fwrite(fout_debug, "------------------------------------------------\n");
            case (G.g_warn)
                No_Warn: $fwrite(fout_debug, "Warn message : No_Warn \n");
                Date_Warn: $fwrite(fout_debug, "Warn message : Date_Warn \n");
                Risk_Warn: $fwrite(fout_debug, "Warn message : Risk_Warn \n");
                Data_Warn: $fwrite(fout_debug, "Warn message : Data_Warn \n");
            endcase
            $fwrite(fout_debug, "Complete   : %1d \n", g_complete);
        end

        Check_Valid_Date: begin
            // get warn message
            if(G.g_date.M < G.g_dram_date.M)                                            G.g_warn = Date_Warn;
            else if((G.g_date.M == G.g_dram_date.M) && (G.g_date.D < G.g_dram_date.D))  G.g_warn = Date_Warn;
            else                                                                        G.g_warn = No_Warn;

            if(G.g_warn === No_Warn)    g_complete = 1;
            else                        g_complete = 0;

            // debug.txt
            $fwrite(fout_debug, "\n");
            $fwrite(fout_debug, "Input month : %2d, Input day : %2d \n", G.g_dram_date.M, G.g_dram_date.D);
            $fwrite(fout_debug, "DRAM  month : %2d, DRAM  day : %2d \n", G.g_date.M, G.g_date.D);
            $fwrite(fout_debug, "---------------------------------\n");
            case (G.g_warn)
                No_Warn: $fwrite(fout_debug, "Warn message : No_Warn \n");
                Date_Warn: $fwrite(fout_debug, "Warn message : Date_Warn \n");
                Risk_Warn: $fwrite(fout_debug, "Warn message : Risk_Warn \n");
                Data_Warn: $fwrite(fout_debug, "Warn message : Data_Warn \n");
            endcase
            $fwrite(fout_debug, "Complete   : %1d \n", g_complete);
        end

    endcase
end endtask


task pattern_input_task; begin
    // Wait for 1~3 cycles
	repeat($urandom_range(1, 4)) @(negedge clk);

    // pattern input 
    // action
    inf.sel_action_valid = 1'b1;
    inf.D.d_act[0] = G.g_action;
    @(negedge clk);
    inf.sel_action_valid = 1'b0;
    inf.D.d_act[0] = 2'hx;
    repeat($urandom_range(0, 3)) @(negedge clk);

    case (G.g_action)
        Index_Check: begin
            // formula
            inf.formula_valid = 1'b1;
            inf.D.d_formula[0] = G.g_formula;
            @(negedge clk);
            inf.formula_valid = 1'b0;
            inf.D.d_formula[0] = 3'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // mode
            inf.mode_valid = 1'b1;
            inf.D.d_mode[0] = G.g_mode;
            @(negedge clk);
            inf.mode_valid = 1'b0;
            inf.D.d_mode[0] = 2'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // date
            inf.date_valid = 1'b1;
            inf.D.d_date[0] = G.g_date;
            @(negedge clk);
            inf.date_valid = 1'b0;
            inf.D.d_date[0].M = 4'hx;
            inf.D.d_date[0].D = 5'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // data_no
            inf.data_no_valid = 1'b1;
            inf.D.d_data_no[0] = G.g_data_no;
            @(negedge clk);
            inf.data_no_valid = 1'b0;
            inf.D.d_data_no[0] = 7'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index A
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_A;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index B
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_B;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index C
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_C;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index D
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_D;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
        end
        Update: begin
            // date
            inf.date_valid = 1'b1;
            inf.D.d_date[0] = G.g_date;
            @(negedge clk);
            inf.date_valid = 1'b0;
            inf.D.d_date[0].M = 4'hx;
            inf.D.d_date[0].D = 5'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // data_no
            inf.data_no_valid = 1'b1;
            inf.D.d_data_no[0] = G.g_data_no;
            @(negedge clk);
            inf.data_no_valid = 1'b0;
            inf.D.d_data_no[0] = 7'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index A
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_A;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index B
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_B;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index C
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_C;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // index D
            inf.index_valid = 1'b1;
            inf.D.d_index[0] = G.g_index_D;
            @(negedge clk);
            inf.index_valid = 1'b0;
            inf.D.d_index[0] = 12'hx;
        end
        Check_Valid_Date: begin
            // date
            inf.date_valid = 1'b1;
            inf.D.d_date[0] = G.g_date;
            @(negedge clk);
            inf.date_valid = 1'b0;
            inf.D.d_date[0].M = 4'hx;
            inf.D.d_date[0].D = 5'hx;
            repeat($urandom_range(0, 3)) @(negedge clk);
            // data_no
            inf.data_no_valid = 1'b1;
            inf.D.d_data_no[0] = G.g_data_no;
            @(negedge clk);
            inf.data_no_valid = 1'b0;
            inf.D.d_data_no[0] = 7'hx;
        end
    endcase
end endtask


task check_ans_task; begin
    latency = 0;
    while(inf.out_valid !== 1)begin
		latency = latency + 1;
		if(latency > 1000) begin
			fail_task;
			$display ("-------------------------------------------------------");
			$display ("                         FAIL                          ");
			$display ("       excution latency is limited in 1000 cycles      ");
			$display ("-------------------------------------------------------");
			#(CYCLE); $finish;
		end

		// Wait a cycle
		@(negedge clk);
	end

    if((inf.warn_msg !== G.g_warn) || (inf.complete !== g_complete)) begin
        fail_task;
		$display ("-------------------------------------------------------");
		$display ("                         FAIL                          ");
		$display ("                     Wrong Answer                      ");
		$display ("-------------------------------------------------------");
		$display ("                     PATTERN %5d                       ", pat_count);
		$display ("    golden_warn_msg : %1d , your_warn_msg : %1d        ", G.g_warn, inf.warn_msg);
		$display ("    golden_complete : %1d , your_complete : %1d        ", g_complete, inf.complete);
		$display ("-------------------------------------------------------");
		#(CYCLE); $finish;
    end

    $display("\033[0;34mPASS PATTERN NO.%5d, \033[m \033[0;32mExecution Cycle: %3d\033[m", pat_count, latency);
	total_latency = total_latency + latency;
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

endprogram
