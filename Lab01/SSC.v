//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Fall
//   Lab01 Exercise		: Snack Shopping Calculator
//   Author     		  : Yu-Hsiang Wang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SSC.v
//   Module Name : SSC
//   Release version : V1.0 (Release Date: 2024-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module SSC(
    // Input signals
    card_num,
    input_money,
    snack_num,
    price, 
    // Output signals
    out_valid,
    out_change
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [63:0] card_num;
input [8:0] input_money;
input [31:0] snack_num;
input [31:0] price;
output out_valid;
output [8:0] out_change;    

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment
wire credit_card_valid;
wire [7:0] total_price [7:0];
wire [7:0] sorted_price [7:0];
wire [11:0] change [7:0];
wire [10:0] partial_sum [7:0];
wire [7:0] select;

reg out_valid_reg;
reg [8:0] out_change_reg;

//================================================================
//    DESIGN
//================================================================
credit_card_checker ccc0(.card_num(card_num), .credit_card_valid(credit_card_valid));

Hash_Table_Mul htm0(.in1(snack_num[3:0]), .in2(price[3:0]), .out(total_price[0]));
Hash_Table_Mul htm1(.in1(snack_num[7:4]), .in2(price[7:4]), .out(total_price[1]));
Hash_Table_Mul htm2(.in1(snack_num[11:8]), .in2(price[11:8]), .out(total_price[2]));
Hash_Table_Mul htm3(.in1(snack_num[15:12]), .in2(price[15:12]), .out(total_price[3]));
Hash_Table_Mul htm4(.in1(snack_num[19:16]), .in2(price[19:16]), .out(total_price[4]));
Hash_Table_Mul htm5(.in1(snack_num[23:20]), .in2(price[23:20]), .out(total_price[5]));
Hash_Table_Mul htm6(.in1(snack_num[27:24]), .in2(price[27:24]), .out(total_price[6]));
Hash_Table_Mul htm7(.in1(snack_num[31:28]), .in2(price[31:28]), .out(total_price[7]));

// assign total_price[0] = snack_num[3:0] * price[3:0];
// assign total_price[1] = snack_num[7:4] * price[7:4];
// assign total_price[2] = snack_num[11:8] * price[11:8];
// assign total_price[3] = snack_num[15:12] * price[15:12];
// assign total_price[4] = snack_num[19:16] * price[19:16];
// assign total_price[5] = snack_num[23:20] * price[23:20];
// assign total_price[6] = snack_num[27:24] * price[27:24];
// assign total_price[7] = snack_num[31:28] * price[31:28];

merge_sort ms0(.in0(total_price[0]), .in1(total_price[1]), .in2(total_price[2]), .in3(total_price[3]), 
               .in4(total_price[4]), .in5(total_price[5]), .in6(total_price[6]), .in7(total_price[7]),
               .out0(sorted_price[0]), .out1(sorted_price[1]), .out2(sorted_price[2]), .out3(sorted_price[3]), 
               .out4(sorted_price[4]), .out5(sorted_price[5]), .out6(sorted_price[6]), .out7(sorted_price[7]));

assign partial_sum[0] = sorted_price[7] + sorted_price[6];
assign partial_sum[1] = partial_sum[0] + sorted_price[5];
assign partial_sum[2] = partial_sum[1] + sorted_price[4];
assign partial_sum[3] = partial_sum[2] + sorted_price[3];
assign partial_sum[4] = partial_sum[3] + sorted_price[2];
assign partial_sum[5] = partial_sum[4] + sorted_price[1];
assign partial_sum[6] = partial_sum[5] + sorted_price[0];

assign change[0] = input_money - sorted_price[7];
assign change[1] = input_money - partial_sum[0];
assign change[2] = input_money - partial_sum[1];
assign change[3] = input_money - partial_sum[2];
assign change[4] = input_money - partial_sum[3];
assign change[5] = input_money - partial_sum[4];
assign change[6] = input_money - partial_sum[5];
assign change[7] = input_money - partial_sum[6];

assign select = {change[0][11], change[1][11], change[2][11], change[3][11], change[4][11], change[5][11], change[6][11], change[7][11]};

always @(*) begin
    if(credit_card_valid == 1'b0) begin
        out_valid_reg = 1'b0;
        out_change_reg = input_money;
    end
    else begin
        out_valid_reg = 1'b1;
        casez (select)
            8'b01??????: out_change_reg = change[0][8:0];
            8'b001?????: out_change_reg = change[1][8:0];
            8'b0001????: out_change_reg = change[2][8:0];
            8'b00001???: out_change_reg = change[3][8:0];
            8'b000001??: out_change_reg = change[4][8:0];
            8'b0000001?: out_change_reg = change[5][8:0];
            8'b00000001: out_change_reg = change[6][8:0];
            8'b00000000: out_change_reg = change[7][8:0];
            default: out_change_reg = input_money;
        endcase        
    end
end

assign out_change = out_change_reg;
assign out_valid = out_valid_reg;

endmodule


// +++++++++++++++++++++++++++++++ checker +++++++++++++++++++++++++++++ //
module credit_card_checker (
    // Input
    card_num,
    // Output
    credit_card_valid
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [63:0] card_num;
output credit_card_valid;

//================================================================
//    Wire & Registers 
//================================================================
wire [4:0] shift_one [7:0];
wire [4:0] minus_ten [7:0];
wire [3:0] processed [7:0];
wire [3:0] adder_in [15:0];
wire [7:0] sum;

reg credit_card_valid_reg;

//================================================================
//    DESIGN
//================================================================
card_num_indexer cni0(.card_num(card_num[7:4]), .processed_num(processed[0]));
card_num_indexer cni1(.card_num(card_num[15:12]), .processed_num(processed[1]));
card_num_indexer cni2(.card_num(card_num[23:20]), .processed_num(processed[2]));
card_num_indexer cni3(.card_num(card_num[31:28]), .processed_num(processed[3]));
card_num_indexer cni4(.card_num(card_num[39:36]), .processed_num(processed[4]));
card_num_indexer cni5(.card_num(card_num[47:44]), .processed_num(processed[5]));
card_num_indexer cni6(.card_num(card_num[55:52]), .processed_num(processed[6]));
card_num_indexer cni7(.card_num(card_num[63:60]), .processed_num(processed[7]));

assign adder_in = {processed[7], card_num[59:56], processed[6], card_num[51:48], processed[5], card_num[43:40], processed[4], card_num[35:32], processed[3], card_num[27:24], processed[2], card_num[19:16], processed[1], card_num[11:8], processed[0], card_num[3:0]};

// Sum the numbers
credit_card_adder ccd1(.adder_in(adder_in), .sum(sum));

always @(*) begin
    if(sum[0] == 1'b0) begin
        case (sum[7:1])
            7'd0: credit_card_valid_reg = 1'b1;
            7'd5: credit_card_valid_reg = 1'b1;
            7'd10: credit_card_valid_reg = 1'b1;
            7'd15: credit_card_valid_reg = 1'b1;
            7'd20: credit_card_valid_reg = 1'b1;
            7'd25: credit_card_valid_reg = 1'b1;
            7'd30: credit_card_valid_reg = 1'b1;
            7'd35: credit_card_valid_reg = 1'b1;
            7'd40: credit_card_valid_reg = 1'b1;
            7'd45: credit_card_valid_reg = 1'b1;
            7'd50: credit_card_valid_reg = 1'b1;
            7'd55: credit_card_valid_reg = 1'b1;
            7'd60: credit_card_valid_reg = 1'b1;
            7'd65: credit_card_valid_reg = 1'b1;
            7'd70: credit_card_valid_reg = 1'b1;

            default: credit_card_valid_reg = 1'b0;
        endcase
    end
    else begin
        credit_card_valid_reg = 1'b0;
    end
end

assign credit_card_valid = credit_card_valid_reg;

endmodule


module card_num_indexer (
    // Input
    card_num,
    // Output
    processed_num
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [3:0] card_num;
output [3:0] processed_num;

reg [3:0] processed_num_reg;

//================================================================
//    DESIGN
//================================================================
always @(*) begin
    case (card_num)
        4'd0: processed_num_reg = 4'd0;
        4'd1: processed_num_reg = 4'd2;
        4'd2: processed_num_reg = 4'd4;
        4'd3: processed_num_reg = 4'd6;
        4'd4: processed_num_reg = 4'd8;
        4'd5: processed_num_reg = 4'd1;
        4'd6: processed_num_reg = 4'd3;
        4'd7: processed_num_reg = 4'd5;
        4'd8: processed_num_reg = 4'd7;
        4'd9: processed_num_reg = 4'd9;
        default: processed_num_reg = 4'd0;
    endcase
end

assign processed_num = processed_num_reg;
endmodule


// +++++++++++++++++++++++++++++++ addder +++++++++++++++++++++++++++++ //
module credit_card_adder (
    // Input
    adder_in,
    // Output
    sum
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [3:0] adder_in [15:0];
output [7:0] sum;

//================================================================
//    DESIGN
//================================================================
assign sum = adder_in[0] + adder_in[1] + adder_in[2] + adder_in[3] + adder_in[4] + adder_in[5] + adder_in[6] + adder_in[7] + adder_in[8] + adder_in[9] + adder_in[10] + adder_in[11] + adder_in[12] + adder_in[13] + adder_in[14] + adder_in[15];
    
endmodule


// +++++++++++++++++++++++++++++++ comparator +++++++++++++++++++++++++++++ //
module comparator(
    // Input
    a,
    b,
    // Output
    min_out,
    max_out
);
//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [7:0] a, b;
output [7:0] min_out, max_out;

wire [8:0] compare;

//================================================================
//    DESIGN
//================================================================
// assign min_out = (a < b) ? a : b;  // Minimum element
// assign max_out = (a >= b) ? a : b; // Maximum element

assign compare = a - b;
assign min_out = (compare[8] == 1'b0) ? b : a;
assign max_out = (compare[8] == 1'b0) ? a : b;

endmodule


// +++++++++++++++++++++++++++++++ merge sort +++++++++++++++++++++++++++++ //
module merge_sort(
    // Input
    in0, in1, in2, in3, in4, in5, in6, in7,
    // Output
    out0, out1, out2, out3, out4, out5, out6, out7  // Small -> Large
);
//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [7:0] in0, in1, in2, in3, in4, in5, in6, in7;
output [7:0] out0, out1, out2, out3, out4, out5, out6, out7;

//================================================================
//    Wire & Registers 
//================================================================
wire [7:0] inter1 [7:0];
wire [7:0] inter2 [7:0];
wire [7:0] inter3 [3:0];
wire [7:0] inter4 [7:0];
wire [7:0] inter5 [3:0];
wire [7:0] inter6 [5:0];

// reg [7:0] inter [7:0];

//================================================================
//    DESIGN
//================================================================
comparator comp1_1(.a(in0), .b(in1), .min_out(inter1[0]), .max_out(inter1[1]));
comparator comp1_2(.a(in2), .b(in3), .min_out(inter1[2]), .max_out(inter1[3]));
comparator comp1_3(.a(in4), .b(in5), .min_out(inter1[4]), .max_out(inter1[5]));
comparator comp1_4(.a(in6), .b(in7), .min_out(inter1[6]), .max_out(inter1[7]));

comparator comp2_1(.a(inter1[0]), .b(inter1[2]), .min_out(inter2[0]), .max_out(inter2[1]));
comparator comp2_2(.a(inter1[1]), .b(inter1[3]), .min_out(inter2[2]), .max_out(inter2[3]));
comparator comp2_3(.a(inter1[4]), .b(inter1[6]), .min_out(inter2[4]), .max_out(inter2[5]));
comparator comp2_4(.a(inter1[5]), .b(inter1[7]), .min_out(inter2[6]), .max_out(inter2[7]));

comparator comp3_1(.a(inter2[1]), .b(inter2[2]), .min_out(inter3[0]), .max_out(inter3[1]));
comparator comp3_2(.a(inter2[5]), .b(inter2[6]), .min_out(inter3[2]), .max_out(inter3[3]));

comparator comp4_1(.a(inter2[0]), .b(inter2[4]), .min_out(inter4[0]), .max_out(inter4[4]));
comparator comp4_2(.a(inter3[0]), .b(inter3[2]), .min_out(inter4[1]), .max_out(inter4[5]));
comparator comp4_3(.a(inter3[1]), .b(inter3[3]), .min_out(inter4[2]), .max_out(inter4[6]));
comparator comp4_4(.a(inter2[3]), .b(inter2[7]), .min_out(inter4[3]), .max_out(inter4[7]));

comparator comp5_1(.a(inter4[2]), .b(inter4[4]), .min_out(inter5[0]), .max_out(inter5[2]));
comparator comp5_2(.a(inter4[3]), .b(inter4[5]), .min_out(inter5[1]), .max_out(inter5[3]));

comparator comp6_1(.a(inter4[1]), .b(inter5[0]), .min_out(inter6[0]), .max_out(inter6[1]));
comparator comp6_2(.a(inter5[1]), .b(inter5[2]), .min_out(inter6[2]), .max_out(inter6[3]));
comparator comp6_3(.a(inter5[3]), .b(inter4[6]), .min_out(inter6[4]), .max_out(inter6[5]));

// always @(*) begin
//     {inter[0], inter[1]} = (in0 < in1) ? {in0, in1} : {in1, in0};
//     {inter[2], inter[3]} = (in2 < in3) ? {in2, in3} : {in3, in2};
//     {inter[4], inter[5]} = (in4 < in5) ? {in4, in5} : {in5, in4};
//     {inter[6], inter[7]} = (in6 < in7) ? {in6, in7} : {in7, in6};

//     //stage 2
//     {inter[0], inter[2]} = (inter[0] < inter[2]) ? {inter[0], inter[2]} : {inter[2], inter[0]};
//     {inter[1], inter[3]} = (inter[1] < inter[3]) ? {inter[1], inter[3]} : {inter[3], inter[1]};
//     {inter[4], inter[6]} = (inter[4] < inter[6]) ? {inter[4], inter[6]} : {inter[6], inter[4]};
//     {inter[5], inter[7]} = (inter[5] < inter[7]) ? {inter[5], inter[7]} : {inter[7], inter[5]};

//     {inter[1], inter[2]} = (inter[1] < inter[2]) ? {inter[1], inter[2]} : {inter[2], inter[1]};
//     {inter[5], inter[6]} = (inter[5] < inter[6]) ? {inter[5], inter[6]} : {inter[6], inter[5]};

//     //stage 3
//     {inter[0], inter[4]} = (inter[0] < inter[4]) ? {inter[0], inter[4]} : {inter[4], inter[0]};
//     {inter[1], inter[5]} = (inter[1] < inter[5]) ? {inter[1], inter[5]} : {inter[5], inter[1]};
//     {inter[2], inter[6]} = (inter[2] < inter[6]) ? {inter[2], inter[6]} : {inter[6], inter[2]};
//     {inter[3], inter[7]} = (inter[3] < inter[7]) ? {inter[3], inter[7]} : {inter[7], inter[3]};

//     {inter[2], inter[4]} = (inter[2] < inter[4]) ? {inter[2], inter[4]} : {inter[4], inter[2]};
//     {inter[3], inter[5]} = (inter[3] < inter[5]) ? {inter[3], inter[5]} : {inter[5], inter[3]};

//     {inter[1], inter[2]} = (inter[1] < inter[2]) ? {inter[1], inter[2]} : {inter[2], inter[1]};
//     {inter[3], inter[4]} = (inter[3] < inter[4]) ? {inter[3], inter[4]} : {inter[4], inter[3]};
//     {inter[5], inter[6]} = (inter[5] < inter[6]) ? {inter[5], inter[6]} : {inter[6], inter[5]};
// end

assign out0 = inter4[0];
assign out1 = inter6[0];
assign out2 = inter6[1];
assign out3 = inter6[2];
assign out4 = inter6[3];
assign out5 = inter6[4];
assign out6 = inter6[5];
assign out7 = inter4[7];

// assign out0 = inter[0];
// assign out1 = inter[1];
// assign out2 = inter[2];
// assign out3 = inter[3];
// assign out4 = inter[4];
// assign out5 = inter[5];
// assign out6 = inter[6];
// assign out7 = inter[7];

endmodule

module Hash_Table_Mul (
    input [3:0] in1,
    input [3:0] in2,
    output reg [7:0] out
);

always @(*) begin
    case (in1)
        1: begin
            case (in2)
                1: out = 1;
                2: out = 2;
                3: out = 3;
                4: out = 4;
                5: out = 5;
                6: out = 6;
                7: out = 7;
                8: out = 8;
                9: out = 9;
                10: out = 10;
                11: out = 11;
                12: out = 12;
                13: out = 13;
                14: out = 14;
                15: out = 15;
                default: out = 0;
            endcase
        end
        2: begin
            case (in2)
                1: out = 2;
                2: out = 4;
                3: out = 6;
                4: out = 8;
                5: out = 10;
                6: out = 12;
                7: out = 14;
                8: out = 16;
                9: out = 18;
                10: out = 20;
                11: out = 22;
                12: out = 24;
                13: out = 26;
                14: out = 28;
                15: out = 30;
                default: out = 0;
            endcase
        end
        3: begin
            case (in2)
                1: out = 3;
                2: out = 6;
                3: out = 9;
                4: out = 12;
                5: out = 15;
                6: out = 18;
                7: out = 21;
                8: out = 24;
                9: out = 27;
                10: out = 30;
                11: out = 33;
                12: out = 36;
                13: out = 39;
                14: out = 42;
                15: out = 45;
                default: out = 0;
            endcase
        end
        4: begin
            case (in2)
                1: out = 4;
                2: out = 8;
                3: out = 12;
                4: out = 16;
                5: out = 20;
                6: out = 24;
                7: out = 28;
                8: out = 32;
                9: out = 36;
                10: out = 40;
                11: out = 44;
                12: out = 48;
                13: out = 52;
                14: out = 56;
                15: out = 60;
                default: out = 0;
            endcase
        end
        5: begin
            case (in2)
                1: out = 5;
                2: out = 10;
                3: out = 15;
                4: out = 20;
                5: out = 25;
                6: out = 30;
                7: out = 35;
                8: out = 40;
                9: out = 45;
                10: out = 50;
                11: out = 55;
                12: out = 60;
                13: out = 65;
                14: out = 70;
                15: out = 75;
                default: out = 0;
            endcase
        end
        6: begin
            case (in2)
                1: out = 6;
                2: out = 12;
                3: out = 18;
                4: out = 24;
                5: out = 30;
                6: out = 36;
                7: out = 42;
                8: out = 48;
                9: out = 54;
                10: out = 60;
                11: out = 66;
                12: out = 72;
                13: out = 78;
                14: out = 84;
                15: out = 90;
                default: out = 0;
            endcase
        end
        7: begin
            case (in2)
                1: out = 7;
                2: out = 14;
                3: out = 21;
                4: out = 28;
                5: out = 35;
                6: out = 42;
                7: out = 49;
                8: out = 56;
                9: out = 63;
                10: out = 70;
                11: out = 77;
                12: out = 84;
                13: out = 91;
                14: out = 98;
                15: out = 105;
                default: out = 0;
            endcase
        end
        8: begin
            case (in2)
                1: out = 8;
                2: out = 16;
                3: out = 24;
                4: out = 32;
                5: out = 40;
                6: out = 48;
                7: out = 56;
                8: out = 64;
                9: out = 72;
                10: out = 80;
                11: out = 88;
                12: out = 96;
                13: out = 104;
                14: out = 112;
                15: out = 120;
                default: out = 0;
            endcase
        end
        9: begin
            case (in2)
                1: out = 9;
                2: out = 18;
                3: out = 27;
                4: out = 36;
                5: out = 45;
                6: out = 54;
                7: out = 63;
                8: out = 72;
                9: out = 81;
                10: out = 90;
                11: out = 99;
                12: out = 108;
                13: out = 117;
                14: out = 126;
                15: out = 135;
                default: out = 0;
            endcase
        end
        10: begin
            case (in2)
                1: out = 10;
                2: out = 20;
                3: out = 30;
                4: out = 40;
                5: out = 50;
                6: out = 60;
                7: out = 70;
                8: out = 80;
                9: out = 90;
                10: out = 100;
                11: out = 110;
                12: out = 120;
                13: out = 130;
                14: out = 140;
                15: out = 150;
                default: out = 0;
            endcase
        end
        11: begin
            case (in2)
                1: out = 11;
                2: out = 22;
                3: out = 33;
                4: out = 44;
                5: out = 55;
                6: out = 66;
                7: out = 77;
                8: out = 88;
                9: out = 99;
                10: out = 110;
                11: out = 121;
                12: out = 132;
                13: out = 143;
                14: out = 154;
                15: out = 165;
                default: out = 0;
            endcase
        end
        12: begin
            case (in2)
                1: out = 12;
                2: out = 24;
                3: out = 36;
                4: out = 48;
                5: out = 60;
                6: out = 72;
                7: out = 84;
                8: out = 96;
                9: out = 108;
                10: out = 120;
                11: out = 132;
                12: out = 144;
                13: out = 156;
                14: out = 168;
                15: out = 180;
                default: out = 0;
            endcase
        end
        13: begin
            case (in2)
                1: out = 13;
                2: out = 26;
                3: out = 39;
                4: out = 52;
                5: out = 65;
                6: out = 78;
                7: out = 91;
                8: out = 104;
                9: out = 117;
                10: out = 130;
                11: out = 143;
                12: out = 156;
                13: out = 169;
                14: out = 182;
                15: out = 195;
                default: out = 0;
            endcase
        end
        14: begin
            case (in2)
                1: out = 14;
                2: out = 28;
                3: out = 42;
                4: out = 56;
                5: out = 70;
                6: out = 84;
                7: out = 98;
                8: out = 112;
                9: out = 126;
                10: out = 140;
                11: out = 154;
                12: out = 168;
                13: out = 182;
                14: out = 196;
                15: out = 210;
                default: out = 0;
            endcase
        end
        15: begin
            case (in2)
                1: out = 15;
                2: out = 30;
                3: out = 45;
                4: out = 60;
                5: out = 75;
                6: out = 90;
                7: out = 105;
                8: out = 120;
                9: out = 135;
                10: out = 150;
                11: out = 165;
                12: out = 180;
                13: out = 195;
                14: out = 210;
                15: out = 225;
                default: out = 0;
            endcase
        end
        default: out = 0;
    endcase
end

endmodule