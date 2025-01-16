module Program(input clk, INF.Program_inf inf);
import usertype::*;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j, k;

typedef enum logic [2:0] { IDLE     = 3'b000,
                           ICHECK   = 3'b001,
                           CALC     = 3'b011,
                           UPDATE   = 3'b111,
                           VARY     = 3'b110,
                           DCHECK   = 3'b101,
                           OVER     = 3'b100
} state_t;

//---------------------------------------------------------------------
//   Logics
//---------------------------------------------------------------------
state_t cs, ns;
logic [2:0] idx_cnt_cs, idx_cnt_ns;
logic [2:0] cnt_cs, cnt_ns;
logic       over_cs, over_ns;
logic       wstart_cs, wstart_ns, rstart_cs, rstart_ns;
Warn_Msg    warn_cs, warn_ns;
logic [10:0] threshold_cs, threshold_ns;
logic [13:0] result_cs, result_ns;

// store input data
Formula_Type formula_cs, formula_ns;
Mode mode_cs, mode_ns;
logic [7:0] data_no_cs, data_no_ns;
Data_Dir d_input_cs, d_input_ns;
Data_Dir d_dram_cs, d_dram_ns;

// shared
logic [11:0] sub_a [0:3];
logic [11:0] sub_b [0:3];
logic [11:0] sub_out [0:3];
logic [12:0] add_a[0:1];
logic [12:0] add_b[0:1];
logic [13:0] add_out[0:1];
logic [13:0] tmp_cs [0:1];
logic [13:0] tmp_ns [0:1];
logic [11:0] cmp_in [0:3];
logic [11:0] cmp_out [0:3];
logic signed [12:0] variant [0:3];
logic [0:3] cmp_I_2047;
logic [0:3] cmp_I_TI;
logic signed [13:0] after_vari [0:3];
logic [12:0] div_out;

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                               SUBMODULES                             //
//======================================================================//
DRAM_WRITER DW_U0(
    // inputs
    .clk(clk), .rst_n(inf.rst_n), 
    .AW_READY(inf.AW_READY), .W_READY(inf.W_READY), .B_VALID(inf.B_VALID), 
    .start(wstart_cs), .data_no(data_no_cs), 
    // outputs
    .AW_VALID(inf.AW_VALID), .AW_ADDR(inf.AW_ADDR), .W_VALID(inf.W_VALID), .B_READY(inf.B_READY)
);

DRAM_READER DR_U0(
    // inputs
    .clk(clk), .rst_n(inf.rst_n),
    .AR_READY(inf.AR_READY), .R_VALID(inf.R_VALID),
    .start(rstart_cs), .data_no(data_no_cs),
    // outputs
    .AR_VALID(inf.AR_VALID), .AR_ADDR(inf.AR_ADDR), .R_READY(inf.R_READY)
);

ASCEND_SORT4 AS_U0(.clk(clk), .in(cmp_in), .sorted(cmp_out));

DIV3 D_U0(.clk(clk), .div_in(tmp_cs[0]), .div_out(div_out));

// shared
assign sub_out[0] = sub_a[0] - sub_b[0];
assign sub_out[1] = sub_a[1] - sub_b[1];
assign sub_out[2] = sub_a[2] - sub_b[2];
assign sub_out[3] = sub_a[3] - sub_b[3];

assign add_out[0] = add_a[0] + add_b[0];
assign add_out[1] = add_a[1] + add_b[1];

assign cmp_I_2047[0] = (d_dram_cs.Index_A >= 2047);
assign cmp_I_2047[1] = (d_dram_cs.Index_B >= 2047);
assign cmp_I_2047[2] = (d_dram_cs.Index_C >= 2047);
assign cmp_I_2047[3] = (d_dram_cs.Index_D >= 2047);
assign cmp_I_TI[0]   = (d_input_cs.Index_A < d_dram_cs.Index_A);
assign cmp_I_TI[1]   = (d_input_cs.Index_B < d_dram_cs.Index_B);
assign cmp_I_TI[2]   = (d_input_cs.Index_C < d_dram_cs.Index_C);
assign cmp_I_TI[3]   = (d_input_cs.Index_D < d_dram_cs.Index_D);

assign after_vari[0] = $signed(({1'b0, d_dram_cs.Index_A})) + $signed(d_input_cs.Index_A);
assign after_vari[1] = $signed(({1'b0, d_dram_cs.Index_B})) + $signed(d_input_cs.Index_B);
assign after_vari[2] = $signed(({1'b0, d_dram_cs.Index_C})) + $signed(d_input_cs.Index_C);
assign after_vari[3] = $signed(({1'b0, d_dram_cs.Index_D})) + $signed(d_input_cs.Index_D);
//======================================================================//
//                                  FSM                                 //
//======================================================================//
always_ff @( posedge clk or negedge inf.rst_n) begin : FSM_FF
    if(!inf.rst_n)  cs <= IDLE;
    else            cs <= ns;
end
always_comb begin : FSM_comb
    case (cs)

        IDLE: begin
            if(inf.sel_action_valid) begin
                case (inf.D.d_act[0])
                    Index_Check:        ns = ICHECK;
                    Update:             ns = UPDATE;
                    Check_Valid_Date:   ns = DCHECK;
                    default:            ns = cs;
                endcase
            end
            else ns = cs;
        end

        ICHECK: begin
            if((idx_cnt_cs == 4) && (d_dram_cs.M > 0)) begin
                if(over_cs) ns = OVER;
                else        ns = CALC;
            end
            else ns = cs;
        end
        
        CALC: begin
            if(over_cs) ns = OVER;
            else        ns = cs;
        end

        UPDATE: begin
            if((idx_cnt_cs == 4) && (d_dram_cs.M > 0))  ns = VARY;
            else                                        ns = cs;
        end

        VARY: begin
            if(over_cs) ns = OVER;
            else        ns = cs;
        end

        DCHECK: begin
            if((d_input_cs.M > 0) && (d_dram_cs.M > 0)) ns = OVER;
            else                                        ns = cs;
        end

        OVER: ns = IDLE;

        default: ns = cs;

    endcase
end

// ============================== counter ============================== //
// idx_cnt
always_ff @( posedge clk or negedge inf.rst_n) begin : idx_cnt_FF
    if(!inf.rst_n)  idx_cnt_cs <= 0;
    else            idx_cnt_cs <= idx_cnt_ns;
end
always_comb begin : idx_cnt_comb
    if(cs == OVER)              idx_cnt_ns = 0;
    else if(inf.index_valid)    idx_cnt_ns = idx_cnt_cs + 1;
    else                        idx_cnt_ns = idx_cnt_cs;
end

// cnt
always_ff @( posedge clk ) begin : cnt_FF
    cnt_cs <= cnt_ns;
end
always_comb begin : cnt_comb
    case (cs)

        CALC: cnt_ns = cnt_cs + 1;

        VARY: begin
            if(cnt_cs == 0) cnt_ns = cnt_cs + 1;
            else            cnt_ns = cnt_cs;
        end

        default: cnt_ns = 0;

    endcase                           
end

// ============================== storage ============================== //
// formula
always_ff @( posedge clk or negedge inf.rst_n) begin : formula_FF
    if(!inf.rst_n)  formula_cs <= Formula_A;
    else            formula_cs <= formula_ns;
end
always_comb begin : formula_comb
    if(inf.formula_valid)   formula_ns = inf.D.d_formula[0];
    else                    formula_ns = formula_cs;
end

// mode
always_ff @( posedge clk or negedge inf.rst_n) begin : mode_FF
    if(!inf.rst_n)  mode_cs <= Insensitive;
    else            mode_cs <= mode_ns;
end
always_comb begin : mode_comb
    if(inf.mode_valid)  mode_ns = inf.D.d_mode[0];
    else                mode_ns = mode_cs;
end

// data_no
always_ff @( posedge clk or negedge inf.rst_n) begin : data_no_FF
    if(!inf.rst_n)  data_no_cs <= 0;
    else            data_no_cs <= data_no_ns;
end
always_comb begin : data_no_comb
    if(inf.data_no_valid)   data_no_ns = inf.D.d_data_no[0];
    else                    data_no_ns = data_no_cs;
end

// d_input
always_ff @( posedge clk or negedge inf.rst_n) begin : d_input_FF
    if(!inf.rst_n) begin
        d_input_cs.Index_A  <= 0;
        d_input_cs.Index_B  <= 0;
        d_input_cs.Index_C  <= 0;
        d_input_cs.Index_D  <= 0;
        d_input_cs.M        <= 0;
        d_input_cs.D        <= 0;
    end
    else begin
        d_input_cs <= d_input_ns;
    end
end
always_comb begin : d_input_comb
    d_input_ns = d_input_cs;
    sub_a[0] = 0; sub_a[1] = 0; sub_a[2] = 0; sub_a[3] = 0; 
    sub_b[0] = 0; sub_b[1] = 0; sub_b[2] = 0; sub_b[3] = 0; 

    case (cs)

        ICHECK, UPDATE, DCHECK: begin
            if(inf.date_valid) begin
                d_input_ns.M = inf.D.d_date[0].M;
                d_input_ns.D = inf.D.d_date[0].D;
            end

            if(inf.index_valid) begin
                case (idx_cnt_cs)
                    0: d_input_ns.Index_A = inf.D.d_index[0];
                    1: d_input_ns.Index_B = inf.D.d_index[0];
                    2: d_input_ns.Index_C = inf.D.d_index[0];
                    3: d_input_ns.Index_D = inf.D.d_index[0];
                endcase
            end
        end

        CALC: begin     // make G
            if((cnt_cs == 0) && ((formula_cs == Formula_F) || (formula_cs == Formula_G) || (formula_cs == Formula_H))) begin
                sub_a[0] = (d_input_cs.Index_A > d_dram_cs.Index_A)? d_input_cs.Index_A:d_dram_cs.Index_A;
                sub_b[0] = (d_input_cs.Index_A > d_dram_cs.Index_A)? d_dram_cs.Index_A:d_input_cs.Index_A;
                sub_a[1] = (d_input_cs.Index_B > d_dram_cs.Index_B)? d_input_cs.Index_B:d_dram_cs.Index_B;
                sub_b[1] = (d_input_cs.Index_B > d_dram_cs.Index_B)? d_dram_cs.Index_B:d_input_cs.Index_B;
                sub_a[2] = (d_input_cs.Index_C > d_dram_cs.Index_C)? d_input_cs.Index_C:d_dram_cs.Index_C;
                sub_b[2] = (d_input_cs.Index_C > d_dram_cs.Index_C)? d_dram_cs.Index_C:d_input_cs.Index_C;
                sub_a[3] = (d_input_cs.Index_D > d_dram_cs.Index_D)? d_input_cs.Index_D:d_dram_cs.Index_D;
                sub_b[3] = (d_input_cs.Index_D > d_dram_cs.Index_D)? d_dram_cs.Index_D:d_input_cs.Index_D;
                d_input_ns.Index_A = sub_out[0];
                d_input_ns.Index_B = sub_out[1];
                d_input_ns.Index_C = sub_out[2];
                d_input_ns.Index_D = sub_out[3];
            end
        end

        OVER: begin
            d_input_ns.M = 0;
            d_input_ns.D = 0;
            d_input_ns.Index_A  = 0;
            d_input_ns.Index_B  = 0;
            d_input_ns.Index_C  = 0;
            d_input_ns.Index_D  = 0;
        end

    endcase
end

// d_dram
always_ff @( posedge clk or negedge inf.rst_n) begin : d_dram_FF
    if(!inf.rst_n) begin
        d_dram_cs.Index_A  <= 0;
        d_dram_cs.Index_B  <= 0;
        d_dram_cs.Index_C  <= 0;
        d_dram_cs.Index_D  <= 0;
        d_dram_cs.M        <= 0;
        d_dram_cs.D        <= 0;
    end
    else begin
        d_dram_cs <= d_dram_ns;
    end
end
always_comb begin : d_dram_comb
    case (cs)

        ICHECK, UPDATE, DCHECK: begin
            if(inf.R_VALID) begin
                d_dram_ns.Index_A = inf.R_DATA[63:52];
                d_dram_ns.Index_B = inf.R_DATA[51:40];
                d_dram_ns.M       = inf.R_DATA[39:32];
                d_dram_ns.Index_C = inf.R_DATA[31:20];
                d_dram_ns.Index_D = inf.R_DATA[19:8];
                d_dram_ns.D       = inf.R_DATA[7:0];
            end
            else d_dram_ns = d_dram_cs;
        end

        VARY: begin
            if(cnt_cs == 0) begin
                d_dram_ns.Index_A = variant[0];
                d_dram_ns.Index_B = variant[1];
                d_dram_ns.Index_C = variant[2];
                d_dram_ns.Index_D = variant[3];
                d_dram_ns.M       = d_input_cs.M;
                d_dram_ns.D       = d_input_cs.D;
            end
            else d_dram_ns = d_dram_cs;
        end

        OVER: begin
            d_dram_ns.Index_A = 0;
            d_dram_ns.Index_B = 0;
            d_dram_ns.M       = 0;
            d_dram_ns.Index_C = 0;
            d_dram_ns.Index_D = 0;
            d_dram_ns.D       = 0;
        end

        default: d_dram_ns = d_dram_cs;

    endcase
end

// threshold
always_ff @( posedge clk or negedge inf.rst_n) begin : threshold_FF
    if(!inf.rst_n)  threshold_cs <= 0;
    else            threshold_cs <= threshold_ns;
end
always_comb begin : threshold_comb
    if(inf.mode_valid) begin
        case (formula_cs)

            Formula_A, Formula_C: begin
                case (inf.D.d_mode[0])
                    Insensitive:    threshold_ns = 2047;
                    Normal:         threshold_ns = 1023;
                    Sensitive:      threshold_ns = 511;
                    default:        threshold_ns = 0;
                endcase
            end

            Formula_B, Formula_F, Formula_G, Formula_H: begin
                case (inf.D.d_mode[0])
                    Insensitive:    threshold_ns = 800;
                    Normal:         threshold_ns = 400;
                    Sensitive:      threshold_ns = 200;
                    default:        threshold_ns = 0;
                endcase
            end

            Formula_D, Formula_E: begin
                case (inf.D.d_mode[0])
                    Insensitive:    threshold_ns = 3;
                    Normal:         threshold_ns = 2;
                    Sensitive:      threshold_ns = 1;
                    default:        threshold_ns = 0;
                endcase
            end

            default: threshold_ns = 0;

        endcase
    end
    else threshold_ns = threshold_cs;
end

// ============================== control ============================== //
// starts
always_ff @( posedge clk or negedge inf.rst_n) begin : start_FF
    if(!inf.rst_n) begin
        wstart_cs <= 0;
        rstart_cs <= 0;
    end
    else begin
        wstart_cs <= wstart_ns;
        rstart_cs <= rstart_ns;
    end
end
always_comb begin : start_comb
    //write
    if((cs == VARY) && (cnt_cs == 0))   wstart_ns = 1;
    else                                wstart_ns = 0;

    // read
    if(inf.data_no_valid)   rstart_ns = 1;
    else                    rstart_ns = 0;
end

// tmp
always_ff @( posedge clk or negedge inf.rst_n ) begin : tmp_FF
    if(!inf.rst_n) begin
        tmp_cs[0] <= 0; tmp_cs[1] <= 0;
    end
    else begin
        tmp_cs[0] <= tmp_ns[0]; tmp_cs[1] <= tmp_ns[1]; 
    end
end
always_comb begin : cmp_in_comb
    if((formula_cs == Formula_B) || (formula_cs == Formula_C)) begin
        cmp_in[0] = d_dram_cs.Index_A;
        cmp_in[1] = d_dram_cs.Index_B;
        cmp_in[2] = d_dram_cs.Index_C;
        cmp_in[3] = d_dram_cs.Index_D;
    end
    else begin
        cmp_in[0] = d_input_cs.Index_A; 
        cmp_in[1] = d_input_cs.Index_B; 
        cmp_in[2] = d_input_cs.Index_C; 
        cmp_in[3] = d_input_cs.Index_D;
    end
end

// main function
always_ff @( posedge clk or negedge inf.rst_n) begin : main_FF
    if(!inf.rst_n) begin
        over_cs     <= 0;
        result_cs   <= 0;
        warn_cs     <= No_Warn;
    end
    else begin
        over_cs     <= over_ns;
        result_cs   <= result_ns;
        warn_cs     <= warn_ns;
    end
end
always_comb begin : main_comb
    add_a[0] = 0; add_b[0] = 0; add_a[1] = 0; add_b[1] = 0;
    tmp_ns[0] = 0; tmp_ns[1] = 0;
    variant[0] = 0; variant[1] = 0; variant[2] = 0; variant[3] = 0;

    over_ns = 0;
    result_ns = result_cs;
    warn_ns = warn_cs;

    case (cs)

        ICHECK: begin
            if((d_input_cs.M < d_dram_cs.M) || ((d_input_cs.M == d_dram_cs.M) && (d_input_cs.D < d_dram_cs.D))) begin
                over_ns = 1;
                warn_ns = Date_Warn;
            end
        end

        CALC: begin
            case (formula_cs)

                Formula_A: begin
                    result_ns = (tmp_cs[0] >> 2);

                    case (cnt_cs)
                        0:begin
                            add_a[0] = d_dram_cs.Index_A;
                            add_b[0] = d_dram_cs.Index_B;
                            add_a[1] = d_dram_cs.Index_C;
                            add_b[1] = d_dram_cs.Index_D;
                            tmp_ns[0] = add_out[0];
                            tmp_ns[1] = add_out[1];
                        end 
                        1:begin
                            add_a[0] = tmp_cs[0];
                            add_b[0] = tmp_cs[1];
                            tmp_ns[0] = add_out[0];       
                        end
                    endcase

                    if(cnt_cs == 2) over_ns = 1;
                end

                Formula_B: begin
                    result_ns = cmp_out[3] - cmp_out[0];

                    if(cnt_cs == 1) over_ns = 1;
                end

                Formula_C: begin
                    result_ns = cmp_out[0];

                    if(cnt_cs == 1) over_ns = 1;
                end

                Formula_D: begin
                    case (cmp_I_2047)
                        4'b0000: result_ns = 0;

                        4'b0001, 4'b0010, 4'b0100, 4'b1000: result_ns = 1;

                        4'b1001, 4'b1010, 4'b1100, 4'b0101, 4'b0110, 4'b0011: result_ns = 2;

                        4'b0111, 4'b1011, 4'b1101, 4'b1110: result_ns = 3;

                        4'b1111: result_ns = 4;
                    endcase

                    over_ns = 1;
                end

                Formula_E: begin
                    case (cmp_I_TI)
                        4'b0000: result_ns = 0;

                        4'b0001, 4'b0010, 4'b0100, 4'b1000: result_ns = 1;

                        4'b1001, 4'b1010, 4'b1100, 4'b0101, 4'b0110, 4'b0011: result_ns = 2;

                        4'b0111, 4'b1011, 4'b1101, 4'b1110: result_ns = 3;

                        4'b1111: result_ns = 4;
                    endcase

                    over_ns = 1;
                end

                Formula_F: begin
                    result_ns = div_out;

                    case (cnt_cs)
                        4: begin
                            add_a[0] = cmp_out[1];
                            add_b[0] = cmp_out[2];
                            tmp_ns[0] = add_out[0];
                        end
                        5: begin
                            add_a[0] = cmp_out[0];
                            add_b[0] = tmp_cs[0];
                            tmp_ns[0] = add_out[0];
                        end
                    endcase

                    if(cnt_cs == 7) over_ns = 1;
                end
                Formula_G: begin
                    tmp_ns[0] = add_out[0];
                    result_ns = add_out[0];

                    case (cnt_cs)
                        4: begin
                            add_a[0] = (cmp_out[2] >> 2);
                            add_b[0] = (cmp_out[1] >> 2);
                        end
                        5: begin
                            add_a[0] = (cmp_out[0] >> 1);
                            add_b[0] = tmp_cs[0];
                        end
                    endcase

                    if(cnt_cs == 5) over_ns = 1;
                end
                Formula_H: begin
                    result_ns = tmp_cs[0] >> 2;

                    case (cnt_cs)
                        1:begin
                            add_a[0] = d_input_cs.Index_A;
                            add_b[0] = d_input_cs.Index_B;
                            add_a[1] = d_input_cs.Index_C;
                            add_b[1] = d_input_cs.Index_D;
                            tmp_ns[0] = add_out[0];
                            tmp_ns[1] = add_out[1];
                        end 
                        2:begin
                            add_a[0] = tmp_cs[0];
                            add_b[0] = tmp_cs[1];
                            tmp_ns[0] = add_out[0];     
                        end
                    endcase

                    if(cnt_cs == 3) over_ns = 1;
                end
            endcase

            if(over_cs) begin
                if((d_input_cs.M < d_dram_cs.M) || ((d_input_cs.M == d_dram_cs.M) && (d_input_cs.D < d_dram_cs.D))) warn_ns = Date_Warn;
                else if(result_cs >= threshold_cs) warn_ns = Risk_Warn;
            end
        end

        // UPDATE: 

        VARY: begin
            if(cnt_cs == 0) begin
                if(after_vari[0] > 4095) begin
                    variant[0] = $signed(4095);
                    warn_ns = Data_Warn;
                end     
                else if(after_vari[0] < 0) begin
                    variant[0] = $signed(0);
                    warn_ns = Data_Warn;
                end  
                else variant[0] = after_vari[0];
                
                if(after_vari[1] > 4095) begin
                    variant[1] = $signed(4095);
                    warn_ns = Data_Warn;
                end     
                else if(after_vari[1] < 0) begin
                    variant[1] = $signed(0);
                    warn_ns = Data_Warn;
                end  
                else variant[1] = after_vari[1];

                if(after_vari[2] > 4095) begin
                    variant[2] = $signed(4095);
                    warn_ns = Data_Warn;
                end     
                else if(after_vari[2] < 0) begin
                    variant[2] = $signed(0);
                    warn_ns = Data_Warn;
                end  
                else variant[2] = after_vari[2];

                if(after_vari[3] > 4095) begin
                    variant[3] = $signed(4095);
                    warn_ns = Data_Warn;
                end     
                else if(after_vari[3] < 0) begin
                    variant[3] = $signed(0);
                    warn_ns = Data_Warn;
                end  
                else variant[3] = after_vari[3];
            end
            
            
            if(inf.B_VALID) over_ns = 1;
        end

        DCHECK: begin
            if((d_input_cs.M > 0) && (d_dram_cs.M > 0)) begin
                if((d_input_cs.M < d_dram_cs.M) || ((d_input_cs.M == d_dram_cs.M) && (d_input_cs.D < d_dram_cs.D))) warn_ns = Date_Warn;  
                else warn_ns = No_Warn;
            end
        end

        OVER: begin
            result_ns = 0;
            warn_ns = No_Warn;
        end
        
    endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always_comb begin : output_comb
    case (cs)

        VARY: begin
            inf.out_valid   = 0;
            inf.warn_msg    = No_Warn;
            inf.complete    = 0;
            inf.W_DATA[63:52]   = d_dram_cs.Index_A;
            inf.W_DATA[51:40]   = d_dram_cs.Index_B;
            inf.W_DATA[39:32]   = d_dram_cs.M;
            inf.W_DATA[31:20]   = d_dram_cs.Index_C;
            inf.W_DATA[19:8]    = d_dram_cs.Index_D;
            inf.W_DATA[7:0]     = d_dram_cs.D;
        end

        OVER: begin
            inf.out_valid   = 1;
            inf.warn_msg    = warn_cs;
            inf.complete    = (warn_cs == No_Warn)? 1:0;

            inf.W_DATA = 0;
        end

        default: begin
            inf.out_valid   = 0;
            inf.warn_msg    = No_Warn;
            inf.complete    = 0;

            inf.W_DATA = 0;
        end

    endcase
end
endmodule

// ==================================================================================================================== //
// ---------------------------------------------------- SUBMODULES ---------------------------------------------------- //
// ==================================================================================================================== //
module DRAM_WRITER(
    // input ports
    input clk,
    input rst_n,
    input AW_READY,
    input W_READY,
    input B_VALID,
    input start,
    input [7:0] data_no,
    // output ports
    output logic AW_VALID,
    output logic [16:0] AW_ADDR,
    output logic W_VALID,
    output logic B_READY
);

typedef enum logic [1:0] { IDLE    = 2'b00,
                            ADDR    = 2'b01,
                            WRITE   = 2'b11,
                            OVER    = 2'b10
} state_t;

//---------------------------------------------------------------------
//   Logics
//---------------------------------------------------------------------
state_t cs, ns;
logic [10:0] addr_cs, addr_ns;
logic [10:0] addr_wire;

//======================================================================//
//                                  FFs                                 //
//======================================================================//
always_ff @( posedge clk or negedge rst_n) begin : FF_block
    if(!rst_n) begin
        cs <= IDLE;
        addr_cs <= 0;
    end
    else begin
        cs <= ns;
        addr_cs <= addr_ns;
    end
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always_comb begin : FSM_comb
    case (cs)

        IDLE: begin
            if(start)   ns = ADDR;
            else        ns = cs;
        end

        ADDR: begin
            if(AW_READY)    ns = WRITE;
            else            ns = cs;
        end

        WRITE: begin
            if(W_READY) ns = OVER;
            else        ns = cs;
        end

        OVER: begin
            if(B_VALID) ns = IDLE;
            else        ns = cs;
        end

        default: ns = cs;

    endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
NUM_TO_ADDR NTA_U0(.index(data_no), .addr(addr_wire));

// addr_ns
always_comb begin : addr_ns_comb
    case (cs)

        IDLE: begin
            if(start)   addr_ns = addr_wire;
            else        addr_ns = 0;
        end

        ADDR: addr_ns = addr_cs;

        default: addr_ns = 0;

    endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always_comb begin : out_comb
    case (cs)

        IDLE: begin
            AW_ADDR     = 0;
            AW_VALID    = 0;
            W_VALID     = 0;
            B_READY     = 0;
        end

        ADDR: begin
            AW_ADDR     = {6'b100000, addr_cs};
            AW_VALID    = 1;
            W_VALID     = 0;
            B_READY     = 0;
        end

        WRITE: begin
            AW_ADDR     = 0;
            AW_VALID    = 0;
            W_VALID     = 1;
            B_READY     = 1;
        end

        OVER: begin
            AW_ADDR     = 0;
            AW_VALID    = 0;
            W_VALID     = 0;
            B_READY     = 1;
        end

        default: begin
            AW_ADDR     = 0;
            AW_VALID    = 0;
            W_VALID     = 0;
            B_READY     = 0;
        end

    endcase
end
    
endmodule


module DRAM_READER(
    // input ports
    input clk,
    input rst_n,
    input AR_READY, 
    input R_VALID,
    input start,
    input [7:0] data_no,
    // output ports
    output logic AR_VALID,
    output logic [16:0] AR_ADDR,
    output logic R_READY
);
typedef enum logic [1:0] { IDLE    = 2'b00,
                            ADDR    = 2'b01,
                            READ    = 2'b10
} state_t;

//---------------------------------------------------------------------
//   Logics
//---------------------------------------------------------------------
state_t cs, ns;
logic [10:0] addr_cs, addr_ns;
logic [10:0] addr_wire;

//======================================================================//
//                                  FFs                                 //
//======================================================================//
always_ff @( posedge clk or negedge rst_n) begin : FF_block
    if(!rst_n) begin
        cs <= IDLE;
        addr_cs <= 0;
    end
    else begin
        cs <= ns;
        addr_cs <= addr_ns;
    end
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always_comb begin : FSM_comb
    case (cs)

        IDLE: begin
            if(start)   ns = ADDR;
            else        ns = cs;
        end

        ADDR: begin
            if(AR_READY)    ns = READ;
            else            ns = cs;
        end

        READ: begin
            if(R_VALID) ns = IDLE;
            else        ns = cs;
        end

        default: ns = cs;

    endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
NUM_TO_ADDR NTA_U0(.index(data_no), .addr(addr_wire));

// addr_ns
always_comb begin : addr_ns_comb
    case (cs)

        IDLE: begin
            if(start)   addr_ns = addr_wire;
            else        addr_ns = 0;
        end

        ADDR: addr_ns = addr_cs;

        default: addr_ns = 0;

    endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always_comb begin : out_comb
    case (cs)

        IDLE: begin
            AR_VALID    = 0;
            AR_ADDR     = 0;
            R_READY     = 0;
        end

        ADDR: begin
            AR_VALID    = 1;
            AR_ADDR     = {6'b100000, addr_cs};
            R_READY     = 0;
        end

        READ: begin
            AR_VALID    = 0;
            AR_ADDR     = 0;
            R_READY     = 1;
        end

        default: begin
            AR_VALID    = 0;
            AR_ADDR     = 0;
            R_READY     = 0;
        end

    endcase
end
endmodule


module ASCEND_SORT4 (
    input clk,
    input [11:0] in [0:3],
    output logic [11:0] sorted [0:3]
);

logic [11:0] inter [0:3];
logic [11:0] inter2 [0:1];

always_ff @( posedge clk ) begin : sort_FF
    {inter[0], inter[1]} <= (in[0] > in[1])? {in[0], in[1]}:{in[1], in[0]};
    {inter[2], inter[3]} <= (in[2] > in[3])? {in[2], in[3]}:{in[3], in[2]};

    {sorted[3], inter2[0]} <= (inter[0] > inter[2])? {inter[0], inter[2]}:{inter[2], inter[0]};
    {inter2[1], sorted[0]} <= (inter[1] > inter[3])? {inter[1], inter[3]}:{inter[3], inter[1]};

    {sorted[2], sorted[1]} <= (inter2[0] > inter2[1])? {inter2[0], inter2[1]}: {inter2[1], inter2[0]};
end

// assign inter[0] = (in[0] > in[1])? in[0]:in[1];     // larger
// assign inter[1] = (in[0] > in[1])? in[1]:in[0];     // smaller
// assign inter[2] = (in[2] > in[3])? in[2]:in[3];     // larger
// assign inter[3] = (in[2] > in[3])? in[3]:in[2];     // smaller

// assign sorted[3] = (inter[0] > inter[2])? inter[0]:inter[2];    // largest
// assign inter2[0] = (inter[0] > inter[2])? inter[2]:inter[0];    
// assign inter2[1] = (inter[1] > inter[3])? inter[1]:inter[3];
// assign sorted[0] = (inter[1] > inter[3])? inter[3]:inter[1];    // smallest

// assign sorted[2] = (inter2[0] > inter2[1])? inter2[0]:inter2[1];
// assign sorted[1] = (inter2[0] > inter2[1])? inter2[1]:inter2[0];
    
endmodule


module DIV3 (
    input clk,
    input [13:0] div_in,
    output logic [12:0] div_out
);

always_ff @( posedge clk ) begin : div_FF
    div_out <= div_in / 3;
end
    
endmodule


module NUM_TO_ADDR(
    input [7:0] index,
    output logic [10:0] addr
);

always_comb begin : num_to_addr_comb
    case (index)
        0:   addr = 11'h0;
        1:   addr = 11'h8;
        2:   addr = 11'h10;
        3:   addr = 11'h18;
        4:   addr = 11'h20;
        5:   addr = 11'h28;
        6:   addr = 11'h30;
        7:   addr = 11'h38;
        8:   addr = 11'h40;
        9:   addr = 11'h48;
        10:  addr = 11'h50;
        11:  addr = 11'h58;
        12:  addr = 11'h60;
        13:  addr = 11'h68;
        14:  addr = 11'h70;
        15:  addr = 11'h78;
        16:  addr = 11'h80;
        17:  addr = 11'h88;
        18:  addr = 11'h90;
        19:  addr = 11'h98;
        20:  addr = 11'hA0;
        21:  addr = 11'hA8;
        22:  addr = 11'hB0;
        23:  addr = 11'hB8;
        24:  addr = 11'hC0;
        25:  addr = 11'hC8;
        26:  addr = 11'hD0;
        27:  addr = 11'hD8;
        28:  addr = 11'hE0;
        29:  addr = 11'hE8;
        30:  addr = 11'hF0;
        31:  addr = 11'hF8;
        32:  addr = 11'h100;
        33:  addr = 11'h108;
        34:  addr = 11'h110;
        35:  addr = 11'h118;
        36:  addr = 11'h120;
        37:  addr = 11'h128;
        38:  addr = 11'h130;
        39:  addr = 11'h138;
        40:  addr = 11'h140;
        41:  addr = 11'h148;
        42:  addr = 11'h150;
        43:  addr = 11'h158;
        44:  addr = 11'h160;
        45:  addr = 11'h168;
        46:  addr = 11'h170;
        47:  addr = 11'h178;
        48:  addr = 11'h180;
        49:  addr = 11'h188;
        50:  addr = 11'h190;
        51:  addr = 11'h198;
        52:  addr = 11'h1A0;
        53:  addr = 11'h1A8;
        54:  addr = 11'h1B0;
        55:  addr = 11'h1B8;
        56:  addr = 11'h1C0;
        57:  addr = 11'h1C8;
        58:  addr = 11'h1D0;
        59:  addr = 11'h1D8;
        60:  addr = 11'h1E0;
        61:  addr = 11'h1E8;
        62:  addr = 11'h1F0;
        63:  addr = 11'h1F8;
        64:  addr = 11'h200;
        65:  addr = 11'h208;
        66:  addr = 11'h210;
        67:  addr = 11'h218;
        68:  addr = 11'h220;
        69:  addr = 11'h228;
        70:  addr = 11'h230;
        71:  addr = 11'h238;
        72:  addr = 11'h240;
        73:  addr = 11'h248;
        74:  addr = 11'h250;
        75:  addr = 11'h258;
        76:  addr = 11'h260;
        77:  addr = 11'h268;
        78:  addr = 11'h270;
        79:  addr = 11'h278;
        80:  addr = 11'h280;
        81:  addr = 11'h288;
        82:  addr = 11'h290;
        83:  addr = 11'h298;
        84:  addr = 11'h2A0;
        85:  addr = 11'h2A8;
        86:  addr = 11'h2B0;
        87:  addr = 11'h2B8;
        88:  addr = 11'h2C0;
        89:  addr = 11'h2C8;
        90:  addr = 11'h2D0;
        91:  addr = 11'h2D8;
        92:  addr = 11'h2E0;
        93:  addr = 11'h2E8;
        94:  addr = 11'h2F0;
        95:  addr = 11'h2F8;
        96:  addr = 11'h300;
        97:  addr = 11'h308;
        98:  addr = 11'h310;
        99:  addr = 11'h318;
        100: addr = 11'h320;
        101: addr = 11'h328;
        102: addr = 11'h330;
        103: addr = 11'h338;
        104: addr = 11'h340;
        105: addr = 11'h348;
        106: addr = 11'h350;
        107: addr = 11'h358;
        108: addr = 11'h360;
        109: addr = 11'h368;
        110: addr = 11'h370;
        111: addr = 11'h378;
        112: addr = 11'h380;
        113: addr = 11'h388;
        114: addr = 11'h390;
        115: addr = 11'h398;
        116: addr = 11'h3A0;
        117: addr = 11'h3A8;
        118: addr = 11'h3B0;
        119: addr = 11'h3B8;
        120: addr = 11'h3C0;
        121: addr = 11'h3C8;
        122: addr = 11'h3D0;
        123: addr = 11'h3D8;
        124: addr = 11'h3E0;
        125: addr = 11'h3E8;
        126: addr = 11'h3F0;
        127: addr = 11'h3F8;
        128: addr = 11'h400;
        129: addr = 11'h408;
        130: addr = 11'h410;
        131: addr = 11'h418;
        132: addr = 11'h420;
        133: addr = 11'h428;
        134: addr = 11'h430;
        135: addr = 11'h438;
        136: addr = 11'h440;
        137: addr = 11'h448;
        138: addr = 11'h450;
        139: addr = 11'h458;
        140: addr = 11'h460;
        141: addr = 11'h468;
        142: addr = 11'h470;
        143: addr = 11'h478;
        144: addr = 11'h480;
        145: addr = 11'h488;
        146: addr = 11'h490;
        147: addr = 11'h498;
        148: addr = 11'h4A0;
        149: addr = 11'h4A8;
        150: addr = 11'h4B0;
        151: addr = 11'h4B8;
        152: addr = 11'h4C0;
        153: addr = 11'h4C8;
        154: addr = 11'h4D0;
        155: addr = 11'h4D8;
        156: addr = 11'h4E0;
        157: addr = 11'h4E8;
        158: addr = 11'h4F0;
        159: addr = 11'h4F8;
        160: addr = 11'h500;
        161: addr = 11'h508;
        162: addr = 11'h510;
        163: addr = 11'h518;
        164: addr = 11'h520;
        165: addr = 11'h528;
        166: addr = 11'h530;
        167: addr = 11'h538;
        168: addr = 11'h540;
        169: addr = 11'h548;
        170: addr = 11'h550;
        171: addr = 11'h558;
        172: addr = 11'h560;
        173: addr = 11'h568;
        174: addr = 11'h570;
        175: addr = 11'h578;
        176: addr = 11'h580;
        177: addr = 11'h588;
        178: addr = 11'h590;
        179: addr = 11'h598;
        180: addr = 11'h5A0;
        181: addr = 11'h5A8;
        182: addr = 11'h5B0;
        183: addr = 11'h5B8;
        184: addr = 11'h5C0;
        185: addr = 11'h5C8;
        186: addr = 11'h5D0;
        187: addr = 11'h5D8;
        188: addr = 11'h5E0;
        189: addr = 11'h5E8;
        190: addr = 11'h5F0;
        191: addr = 11'h5F8;
        192: addr = 11'h600;
        193: addr = 11'h608;
        194: addr = 11'h610;
        195: addr = 11'h618;
        196: addr = 11'h620;
        197: addr = 11'h628;
        198: addr = 11'h630;
        199: addr = 11'h638;
        200: addr = 11'h640;
        201: addr = 11'h648;
        202: addr = 11'h650;
        203: addr = 11'h658;
        204: addr = 11'h660;
        205: addr = 11'h668;
        206: addr = 11'h670;
        207: addr = 11'h678;
        208: addr = 11'h680;
        209: addr = 11'h688;
        210: addr = 11'h690;
        211: addr = 11'h698;
        212: addr = 11'h6A0;
        213: addr = 11'h6A8;
        214: addr = 11'h6B0;
        215: addr = 11'h6B8;
        216: addr = 11'h6C0;
        217: addr = 11'h6C8;
        218: addr = 11'h6D0;
        219: addr = 11'h6D8;
        220: addr = 11'h6E0;
        221: addr = 11'h6E8;
        222: addr = 11'h6F0;
        223: addr = 11'h6F8;
        224: addr = 11'h700;
        225: addr = 11'h708;
        226: addr = 11'h710;
        227: addr = 11'h718;
        228: addr = 11'h720;
        229: addr = 11'h728;
        230: addr = 11'h730;
        231: addr = 11'h738;
        232: addr = 11'h740;
        233: addr = 11'h748;
        234: addr = 11'h750;
        235: addr = 11'h758;
        236: addr = 11'h760;
        237: addr = 11'h768;
        238: addr = 11'h770;
        239: addr = 11'h778;
        240: addr = 11'h780;
        241: addr = 11'h788;
        242: addr = 11'h790;
        243: addr = 11'h798;
        244: addr = 11'h7A0;
        245: addr = 11'h7A8;
        246: addr = 11'h7B0;
        247: addr = 11'h7B8;
        248: addr = 11'h7C0;
        249: addr = 11'h7C8;
        250: addr = 11'h7D0;
        251: addr = 11'h7D8;
        252: addr = 11'h7E0;
        253: addr = 11'h7E8;
        254: addr = 11'h7F0;
        255: addr = 11'h7F8;

        default: addr = 0;
    endcase
end
    
endmodule