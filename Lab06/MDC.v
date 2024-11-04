//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/9
//		Version		: v1.0
//   	File Name   : MDC.v
//   	Module Name : MDC
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "HAMMING_IP.v"
//synopsys translate_on

module MDC(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_data, 
	in_mode,
    // Output signals
    out_valid, 
	out_data
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [8:0] in_mode;
input [14:0] in_data;

output reg out_valid;
output reg [206:0] out_data;
//==================================================================
// parameter & integer
//==================================================================
parameter IDLE = 2'b00;
parameter IPUT = 2'b01;
parameter CALC = 2'b11;
parameter OPUT = 2'b10;

parameter IN_OVER = 4'd15;
parameter IP_BIT_1 = 5;
parameter IP_BIT_2 = 11;

integer i, j, k;

//==================================================================
// reg & wire
//==================================================================
reg [1:0] mode_cs, mode_ns;
reg [3:0] count_cs, count_ns;

reg [1:0] in_mode_cs, in_mode_ns;

reg signed [10:0] single_cs [0:1][0:3];
reg signed [10:0] single_ns [0:1][0:3];
reg signed [21:0] double_cs [0:2][0:3];
reg signed [21:0] double_ns [0:2][0:3];
reg signed [22:0] triple_cs [0:13];
reg signed [22:0] triple_ns [0:13];
reg signed [35:0] quadru_cs [0:5];
reg signed [35:0] quadru_ns [0:5];
reg signed [48:0] quintu_cs [0:1];
reg signed [48:0] quintu_ns [0:1];
reg signed [33:0] pre_qua_cs [0:5];
reg signed [33:0] pre_qua_ns [0:5];

wire signed [4:0]  ham_5b;
wire signed [10:0] ham_11b;

reg  signed [10:0] muls_a;
reg  signed [10:0] muls_b;
wire signed [21:0] muls_out;
reg  signed [11:0] mulm_a [0:2];
reg  signed [22:0] mulm_b [0:2];
wire signed [33:0] mulm_out [0:2];
reg  signed [11:0] mull_a;
reg  signed [35:0] mull_b;
wire signed [46:0] mull_out;

reg  signed [47:0] add_a [0:2];
reg  signed [47:0] add_b [0:2];
wire signed [48:0] add_out [0:2];

//==================================================================
// design
//==================================================================
//======================================================================//
//                                  FFs                                 //
//======================================================================//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        mode_cs <= IDLE;
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1) single_cs[i][j] <= 11'd0;
        for(i=0 ; i<3 ; i=i+1) for(j=0 ; j<4 ; j=j+1) double_cs[i][j] <= 22'd0;
        for(i=0 ; i<14 ; i=i+1) triple_cs[i] <= 23'd0;
        for(i=0 ; i<6 ; i=i+1)  quadru_cs[i] <= 36'd0;
        for(i=0 ; i<2 ; i=i+1)  quintu_cs[i] <= 49'd0;
    end
    else begin
        mode_cs <= mode_ns;
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1) single_cs[i][j] <= single_ns[i][j];
        for(i=0 ; i<3 ; i=i+1) for(j=0 ; j<4 ; j=j+1) double_cs[i][j] <= double_ns[i][j];
        for(i=0 ; i<14 ; i=i+1) triple_cs[i] <= triple_ns[i];
        for(i=0 ; i<6 ; i=i+1)  quadru_cs[i] <= quadru_ns[i];
        for(i=0 ; i<2 ; i=i+1)  quintu_cs[i] <= quintu_ns[i];
    end
end

always @(posedge clk) begin
    count_cs <= count_ns;
    in_mode_cs <= in_mode_ns;
    for(i=0 ; i<6 ; i=i+1) pre_qua_cs[i] <= pre_qua_ns[i];
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(in_valid) mode_ns = IPUT;
            else         mode_ns = mode_cs;
        end

        IPUT: begin
            if(count_cs == IN_OVER)begin
                if(in_mode_cs == 3) mode_ns = CALC;
                else                mode_ns = OPUT;
            end
            else                    mode_ns = mode_cs;

        end

        CALC: begin
            mode_ns = OPUT;
            // if(count_cs == 0) mode_ns = OPUT;
            // else              mode_ns = mode_cs;
        end

        OPUT: mode_ns = IDLE;

        default: mode_ns = mode_cs;
    endcase
end

//======================================================================//
//                                  IPs                                 //
//======================================================================//
HAMMING_IP #(IP_BIT_1) HI_5B ( .IN_code(in_mode), .OUT_code(ham_5b) );
HAMMING_IP #(IP_BIT_2) HI_11B ( .IN_code(in_data), .OUT_code(ham_11b) );

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
MULT_11B11B MU0( .a(muls_a),    .b(muls_b),    .out(muls_out) );
MULT_11B23B MU1( .a(mulm_a[0]), .b(mulm_b[0]), .out(mulm_out[0]) );
MULT_11B23B MU2( .a(mulm_a[1]), .b(mulm_b[1]), .out(mulm_out[1]) );
MULT_11B23B MU3( .a(mulm_a[2]), .b(mulm_b[2]), .out(mulm_out[2]) );
MULT_11B36B MU4( .a(mull_a),    .b(mull_b),    .out(mull_out) );

// SIGNED_ADD  SA0( .a(add_a[0]),  .b(add_b[0]),  .out(add_out[0]) );
// SIGNED_ADD  SA1( .a(add_a[1]),  .b(add_b[1]),  .out(add_out[1]) );
// SIGNED_ADD  SA2( .a(add_a[2]),  .b(add_b[2]),  .out(add_out[2]) );

// count_ns circuit
always @(*) begin
    case (mode_cs)
        IDLE: count_ns = 0;

        IPUT: begin
            if(count_cs == IN_OVER) count_ns = 0;
            else                    count_ns = count_cs + 1;
        end

        CALC: begin
            count_ns = count_cs + 1;
        end

        OPUT: count_ns = 0;
    endcase
end

// in_mode_ns circuit
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(in_valid) in_mode_ns = {ham_5b[4], ham_5b[1]};
            else         in_mode_ns = 0;
        end

        IPUT: in_mode_ns = in_mode_cs;

        CALC: in_mode_ns = in_mode_cs;

        OPUT: in_mode_ns = 0;
    endcase
end

// single_ns circuit
always @(*) begin
    for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1) single_ns[i][j] = single_cs[i][j];
    
    case (mode_cs)
        IDLE: if(in_valid) single_ns[0][0] = ham_11b;

        IPUT: begin
            case (count_cs)
                0: single_ns[0][1] = ham_11b;
                1: single_ns[0][2] = ham_11b;
                2: single_ns[0][3] = ham_11b;
                3: single_ns[1][0] = ham_11b;
                4: single_ns[1][1] = ham_11b;
                5: single_ns[1][2] = ham_11b;
                6: single_ns[1][3] = ham_11b;
                7: begin
                    single_ns[0][0] = single_cs[1][0];
                    single_ns[0][1] = single_cs[1][1];
                    single_ns[0][2] = single_cs[1][2];
                    single_ns[0][3] = single_cs[1][3];

                    single_ns[1][0] = ham_11b;
                end
                8: single_ns[1][1] = ham_11b;
                9: single_ns[1][2] = ham_11b;
                10: single_ns[1][3] = ham_11b;
                11: begin
                    single_ns[0][0] = single_cs[1][0];
                    single_ns[0][1] = single_cs[1][1];
                    single_ns[0][2] = single_cs[1][2];
                    single_ns[0][3] = single_cs[1][3];

                    single_ns[1][0] = ham_11b;
                end
                12: single_ns[1][1] = ham_11b;
                13: single_ns[1][2] = ham_11b;
                14: single_ns[1][3] = ham_11b;
            endcase
        end
        
        // CALC: 

        // OPUT: begin
        //     for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1) single_ns[i][j] = 0;
        // end
    endcase
end


// quadru_ns pipeline
always @(*) begin
    // if(mode_cs == IDLE) for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = 0;
    // else                for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = quadru_cs[i] + pre_qua_cs[i];
    case (mode_cs)
        IDLE: for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = 0;
        IPUT: for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = quadru_cs[i] + pre_qua_cs[i];
        CALC: for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = quadru_cs[i] + pre_qua_cs[i];
        OPUT: for(i=0 ; i<6 ; i=i+1)  quadru_ns[i] = quadru_cs[i] + pre_qua_cs[i];
    endcase
end

// double_ns, triple_ns, quadru_ns, quintu_ns circuit
always @(*) begin
    for(i=0 ; i<3 ; i=i+1) for(j=0 ; j<4 ; j=j+1) double_ns[i][j] = double_cs[i][j];
    for(i=0 ; i<14 ; i=i+1) triple_ns[i] = triple_cs[i];
    for(i=0 ; i<6 ; i=i+1)  pre_qua_ns[i] = 0;
    quintu_ns[0] = quintu_cs[0] + quintu_cs[1];
    quintu_ns[1] = 0;
    
    muls_a = 0; muls_b = 0;
    mulm_a[0] = 0; mulm_b[0] = 0; mulm_a[1] = 0; mulm_b[1] = 0; mulm_a[2] = 0; mulm_b[2] = 0;
    mull_a = 0; mull_b = 0;
    // for(i=0 ; i<3 ; i=i+1)  add_a[i]  = 0;
    // for(i=0 ; i<3 ; i=i+1)  add_b[i]  = 0;

    case (mode_cs)
        IDLE: begin
            for(i=0 ; i<3 ; i=i+1) for(j=0 ; j<4 ; j=j+1) double_ns[i][j] = 0;
            for(i=0 ; i<14 ; i=i+1) triple_ns[i] = 0;
            quintu_ns[0] = 0;
        end

        IPUT: begin
            case (count_cs)
                4: begin        // e
                    // double_ns[0][0] = single_cs[1][0] * single_cs[0][1];
                    // double_ns[1][0] = single_cs[1][0] * single_cs[0][2];
                    // double_ns[2][0] = single_cs[1][0] * single_cs[0][3];
                    muls_a    = single_cs[1][0]; muls_b    = single_cs[0][1];                              double_ns[0][0] = muls_out; // eb
                    mulm_a[2] = $signed({single_cs[1][0][10], single_cs[1][0]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[1][0] = mulm_out[2][21:0]; // ec
                    mull_a    = $signed({single_cs[1][0][10], single_cs[1][0]}); mull_b    = {{25{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][0] = mull_out; // ed
                end
                5: begin        // f
                    // double_ns[0][1] = single_cs[1][1] * single_cs[0][0];
                    // double_ns[1][1] = single_cs[1][1] * single_cs[0][2];
                    // double_ns[2][1] = single_cs[1][1] * single_cs[0][3];
                    muls_a    = single_cs[1][1]; muls_b    = single_cs[0][0];                              double_ns[0][1] = muls_out; // fa
                    mulm_a[2] = $signed({single_cs[1][1][10], single_cs[1][1]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[1][1] = mulm_out[2][21:0]; // fc
                    mull_a    = $signed({single_cs[1][1][10], single_cs[1][1]}); mull_b    = {{25{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][1] = mull_out; // fd
                end
                6: begin        // g
                    // double_ns[0][2] = single_cs[1][2] * single_cs[0][0];
                    // double_ns[1][2] = single_cs[1][2] * single_cs[0][1];
                    // double_ns[2][2] = single_cs[1][2] * single_cs[0][3];
                    muls_a    = single_cs[1][2]; muls_b    = single_cs[0][0];                              double_ns[0][2] = muls_out; // ga
                    mulm_a[2] = $signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[2] = {{12{single_cs[0][1][10]}}, single_cs[0][1]}; double_ns[1][2] = mulm_out[2][21:0]; // gb
                    mull_a    = $signed({single_cs[1][2][10], single_cs[1][2]}); mull_b    = {{25{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][2] = mull_out; // gd

                    triple_ns[0] = double_cs[0][1] - double_cs[0][0]; // af-be
                end
                7: begin        // h
                    // double_ns[0][3] = single_cs[1][3] * single_cs[0][0];
                    // double_ns[1][3] = single_cs[1][3] * single_cs[0][1];
                    // double_ns[2][3] = single_cs[1][3] * single_cs[0][2];
                    muls_a    = single_cs[1][3]; muls_b    = single_cs[0][0];                              double_ns[0][3] = muls_out; // ha
                    mulm_a[2] = $signed({single_cs[1][3][10], single_cs[1][3]}); mulm_b[2] = {{12{single_cs[0][1][10]}}, single_cs[0][1]}; double_ns[1][3] = mulm_out[2][21:0]; // hb
                    mull_a    =$signed( {single_cs[1][3][10], single_cs[1][3]}); mull_b    = {{25{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[2][3] = mull_out; // hc

                    triple_ns[1] = double_cs[0][2] - double_cs[1][0]; // ag-ce
                    triple_ns[2] = double_cs[1][2] - double_cs[1][1]; // bg-cf
                end

                8: begin        // i
                    // double_ns[0][0] = single_cs[1][0] * single_cs[0][1];
                    // double_ns[1][0] = single_cs[1][0] * single_cs[0][2];
                    muls_a    = $signed({single_cs[1][0][10], single_cs[1][0]}); muls_b    = single_cs[0][1];                              double_ns[0][0] = muls_out; // if
                    mulm_a[2] = $signed({single_cs[1][0][10], single_cs[1][0]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[1][0] = mulm_out[2][21:0]; // ig

                    triple_ns[3] = double_cs[0][3] - double_cs[2][0]; // ah-de
                    triple_ns[4] = double_cs[1][3] - double_cs[2][1]; // bh-df
                    triple_ns[5] = double_cs[2][3] - double_cs[2][2]; // ch-dg

                    // pre_qua_ns[0] = single_cs[1][0] * triple_cs[2];
                    mulm_a[0] = $signed({single_cs[1][0][10], single_cs[1][0]}); mulm_b[0] = triple_cs[2]; pre_qua_ns[0] = mulm_out[0]; // i*t2
                end
                9: begin        // j
                    // double_ns[0][1] = single_cs[1][1] * single_cs[0][0];
                    // double_ns[1][1] = single_cs[1][1] * single_cs[0][2];
                    // double_ns[2][1] = single_cs[1][1] * single_cs[0][3];
                    muls_a    = single_cs[1][1]; muls_b    = single_cs[0][0];                              double_ns[0][1] = muls_out; // je
                    mulm_a[2] = $signed({single_cs[1][1][10], single_cs[1][1]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[1][1] = mulm_out[2][21:0]; // jg
                    mull_a    = $signed({single_cs[1][1][10], single_cs[1][1]}); mull_b    = {{25{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][1] = mull_out; // jh

                    // pre_qua_ns[0] = (-single_cs[1][1]) * triple_cs[1]; // -j*t1 
                    // pre_qua_ns[1] = single_cs[1][1] * triple_cs[5]; // j*t5
                    // pre_qua_ns[4] = single_cs[1][0] * triple_cs[5]; // i*t5
                    // pre_qua_ns[5] = single_cs[1][0] * triple_cs[4]; // i*t4
                    mulm_a[0] = $signed({single_cs[1][0][10], single_cs[1][0]}); mulm_b[0] = triple_cs[5]; pre_qua_ns[4] = mulm_out[0]; // i*t5
                    mulm_a[1] = $signed({single_cs[1][1][10], single_cs[1][1]}); mulm_b[1] = triple_cs[5]; pre_qua_ns[1] = mulm_out[1]; // j*t5
                end
                10: begin        // k
                    // double_ns[0][2] = single_cs[1][2] * single_cs[0][0];
                    // double_ns[1][2] = single_cs[1][2] * single_cs[0][1];
                    // double_ns[2][2] = single_cs[1][2] * single_cs[0][3];
                    muls_a    = single_cs[1][2]; muls_b    = single_cs[0][0];                              double_ns[0][2] = muls_out; // ke
                    mulm_a[2] = $signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[2] = {{12{single_cs[0][1][10]}}, single_cs[0][1]}; double_ns[1][2] = mulm_out[2][21:0]; // kf
                    mull_a    = $signed({single_cs[1][2][10], single_cs[1][2]}); mull_b    = {{25{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][2] = mull_out; // kh

                    triple_ns[6] = double_cs[0][1] - double_cs[0][0];

                    // pre_qua_ns[0] = single_cs[1][2] * triple_cs[0]; // k*t0
                    // pre_qua_ns[1] = (-single_cs[1][2]) * triple_cs[4]; // -k*t4
                    // pre_qua_ns[4] = (-single_cs[1][2]) * triple_cs[3]; // -k*t3
                    // pre_qua_ns[5] = (-single_cs[1][1]) * triple_cs[3]; // -j*t3
                    mulm_a[0] = -$signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[0] = triple_cs[4]; pre_qua_ns[1] = mulm_out[0]; // -k*t4
                    mulm_a[1] = $signed({single_cs[1][0][10], single_cs[1][0]});    mulm_b[1] = triple_cs[4]; pre_qua_ns[5] = mulm_out[1]; // i*t4
                end
                11: begin        // l
                    // double_ns[1][3] = single_cs[1][3] * single_cs[0][1];
                    // double_ns[2][3] = single_cs[1][3] * single_cs[0][2];
                    muls_a    = single_cs[1][3]; muls_b    = single_cs[0][1];                              double_ns[1][3] = muls_out; // lf
                    mulm_a[2] = $signed({single_cs[1][3][10], single_cs[1][3]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[2][3] = mulm_out[2][21:0]; // lg

                    triple_ns[7] = double_cs[0][2] - double_cs[1][0];
                    triple_ns[8] = double_cs[1][2] - double_cs[1][1];

                    // pre_qua_ns[1] = single_cs[1][3] * triple_cs[2]; // l*t2
                    // pre_qua_ns[4] = single_cs[1][3] * triple_cs[1]; // l*t1
                    // pre_qua_ns[5] = single_cs[1][3] * triple_cs[0]; // l*t0
                    mulm_a[0] = $signed({single_cs[1][3][10], single_cs[1][3]});    mulm_b[0] = triple_cs[2]; pre_qua_ns[1] = mulm_out[0]; // l*t2
                    mulm_a[1] = -$signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[1] = triple_cs[3]; pre_qua_ns[4] = mulm_out[1]; // -k*t3
                    mull_a    = -$signed({single_cs[1][1][10], single_cs[1][1]}); mull_b    = {{13{triple_cs[3][22]}}, triple_cs[3]}; pre_qua_ns[5] = mull_out; // -j*t3
                end

                12: begin        // m
                    // double_ns[0][0] = single_cs[1][0] * single_cs[0][1];
                    muls_a = single_cs[1][0]; muls_b = single_cs[0][1]; double_ns[0][0] = muls_out; // mj

                    triple_ns[9] = double_cs[1][3] - double_cs[2][1];
                    triple_ns[10] = double_cs[2][3] - double_cs[2][2];

                    // pre_qua_ns[2] = single_cs[1][0] * triple_cs[8]; // m*t8
                    mulm_a[0] = $signed({single_cs[0][3][10], single_cs[0][3]});    mulm_b[0] = triple_cs[0]; pre_qua_ns[5] = mulm_out[0]; // l*t0
                    mulm_a[1] = -$signed({single_cs[0][1][10], single_cs[0][1]}); mulm_b[1] = triple_cs[1]; pre_qua_ns[0] = mulm_out[1]; // -j*t1
                    mulm_a[2] = $signed({single_cs[1][0][10], single_cs[1][0]});    mulm_b[2] = triple_cs[8]; pre_qua_ns[2] = mulm_out[2]; // m*t8
                    mull_a    = $signed({single_cs[0][3][10], single_cs[0][3]});    mull_b    = {{13{triple_cs[1][22]}}, triple_cs[1]}; pre_qua_ns[4] = mull_out; // l*t1
                end
                13: begin        // n
                    // double_ns[0][1] = single_cs[1][1] * single_cs[0][0];
                    // double_ns[1][1] = single_cs[1][1] * single_cs[0][2];
                    muls_a    = single_cs[1][1]; muls_b    = single_cs[0][0];                              double_ns[0][1] = muls_out; // ni
                    mulm_a[2] = $signed({single_cs[1][1][10], single_cs[1][1]}); mulm_b[2] = {{12{single_cs[0][2][10]}}, single_cs[0][2]}; double_ns[1][1] = mulm_out[2][21:0]; // nk

                    // pre_qua_ns[2] = (-single_cs[1][1]) * triple_cs[7]; // -n*t7
                    // pre_qua_ns[3] = single_cs[1][1] * triple_cs[10]; // n*t10
                    mulm_a[0] = $signed({single_cs[1][1][10], single_cs[1][1]});    mulm_b[0] = triple_cs[10]; pre_qua_ns[3] = mulm_out[0]; // n*t10
                    mulm_a[1] = -$signed({single_cs[1][1][10], single_cs[1][1]}); mulm_b[1] = triple_cs[7];  pre_qua_ns[2] = mulm_out[1]; // -n*t7

                    // quintu_ns[1] = (-single_cs[1][0]) * quadru_cs[1];
                    mull_a = -$signed({single_cs[1][0][10], single_cs[1][0]}); mull_b = quadru_cs[1]; quintu_ns[1] = {{2{mull_out[46]}}, mull_out}; // -m*q1
                end
                14: begin        // o
                    // double_ns[1][2] = single_cs[1][2] * single_cs[0][1];
                    // double_ns[2][2] = single_cs[1][2] * single_cs[0][3];
                    muls_a    = single_cs[1][2]; muls_b    = single_cs[0][1];                              double_ns[1][2] = muls_out; // oj
                    mulm_a[2] = $signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[2] = {{12{single_cs[0][3][10]}}, single_cs[0][3]}; double_ns[2][2] = mulm_out[2][21:0]; // ol

                    triple_ns[11] = double_cs[0][1] - double_cs[0][0];

                    // pre_qua_ns[2] = single_cs[1][2] * triple_cs[6]; // o*t6
                    // pre_qua_ns[3] = (-single_cs[1][2]) * triple_cs[9]; // -o*t9
                    mulm_a[0] = $signed({single_cs[0][2][10], single_cs[0][2]});    mulm_b[0] = triple_cs[0]; pre_qua_ns[0] = mulm_out[0]; // k*t0
                    mulm_a[1] = -$signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[1] = triple_cs[9]; pre_qua_ns[3] = mulm_out[1]; // -o*t9

                    // quintu_ns[1] = (single_cs[1][1]) * quadru_cs[4];
                    mull_a = $signed({single_cs[1][1][10], single_cs[1][1]}); mull_b = quadru_cs[4]; quintu_ns[1] = {{2{mull_out[46]}}, mull_out}; // n*q4
                end
                15: begin        // p
                    // double_ns[2][3] = single_cs[1][3] * single_cs[0][2];
                    muls_a = single_cs[1][3]; muls_b = single_cs[0][2]; double_ns[2][3] = muls_out; // pk

                    triple_ns[12] = double_cs[1][2] - double_cs[1][1];

                    // pre_qua_ns[3] = single_cs[1][3] * triple_cs[8]; // p*t8
                    mulm_a[0] = $signed({single_cs[1][3][10], single_cs[1][3]}); mulm_b[0] = triple_cs[8]; pre_qua_ns[3] = mulm_out[0]; // p*t8
                    mulm_a[1] = $signed({single_cs[1][2][10], single_cs[1][2]}); mulm_b[1] = triple_cs[6]; pre_qua_ns[2] = mulm_out[1]; // o*t6

                    // quintu_ns[1] = (-single_cs[1][2]) * quadru_cs[5];
                    mull_a = -$signed({single_cs[1][2][10], single_cs[1][2]}); mull_b = quadru_cs[5]; quintu_ns[1] = {{2{mull_out[46]}}, mull_out}; // -o*q5
                end
            endcase
        end

        CALC: begin
            // quintu_ns[1] = (single_cs[1][3]) * quadru_cs[0];
            mull_a = {single_cs[1][3][10], single_cs[1][3]}; mull_b = quadru_cs[0]; quintu_ns[1] = {{2{mull_out[46]}}, mull_out}; // p*q0
        end

        OPUT: begin
            triple_ns[13] = double_cs[2][3] - double_cs[2][2];
        end
    endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
always @(*) begin
    case (mode_cs)
        IDLE: begin
            out_valid = 0;
            out_data = 0;
        end

        IPUT: begin
            out_valid = 0;
            out_data = 0;
        end

        CALC: begin
            out_valid = 0;
            out_data = 0;
        end

        OPUT: begin
            out_valid = 1;

            case (in_mode_cs)
                2'b00: out_data = {triple_cs[0], triple_cs[2], triple_cs[5], triple_cs[6], triple_cs[8], triple_cs[10], triple_cs[11], triple_cs[12], triple_ns[13]};
                2'b01: out_data = {{3{1'b0}}, {15{quadru_cs[0][35]}}, quadru_cs[0], {15{quadru_cs[1][35]}}, quadru_cs[1], {15{quadru_ns[2][35]}}, quadru_ns[2], {15{quadru_ns[3][35]}}, quadru_ns[3]};
                2'b11: out_data = {{158{quintu_ns[0][48]}}, quintu_ns[0]};
                default: out_data = 0;
            endcase
        end
    endcase
end

endmodule


module MULT_11B11B(
    // Input
    input signed [10:0] a,
    input signed [10:0] b,
    // Output 
    output reg signed [21:0] out
);

assign out = a * b;
    
endmodule


module MULT_11B23B(
    // Input
    input signed [11:0] a,
    input signed [22:0] b,
    // Output 
    output reg signed [33:0] out
);

assign out = a * b;
    
endmodule


module MULT_11B36B(
    // Input
    input signed [11:0] a,
    input signed [35:0] b,
    // Output 
    output reg signed [46:0] out
);

assign out = a * b;
    
endmodule


module SIGNED_ADD(
    input signed [47:0] a,
    input signed [47:0] b,
    output reg signed [48:0] out
);

assign out = a + b;
    
endmodule