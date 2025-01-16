module ISP(
    // Input Signals
    input clk,
    input rst_n,
    input in_valid,
    input [3:0] in_pic_no,
    input [1:0] in_mode,
    input [1:0] in_ratio_mode,

    // Output Signals
    output reg out_valid,
    output reg [7:0] out_data,
    
    // DRAM Signals
    // axi write address channel
    // src master
    output [3:0]  awid_s_inf,
    output [31:0] awaddr_s_inf,
    output [2:0]  awsize_s_inf,
    output [1:0]  awburst_s_inf,
    output [7:0]  awlen_s_inf,
    output        awvalid_s_inf,
    // src slave
    input         awready_s_inf,
    // -----------------------------
  
    // axi write data channel 
    // src master
    output reg [127:0] wdata_s_inf,
    output         wlast_s_inf,
    output         wvalid_s_inf,
    // src slave
    input          wready_s_inf,
  
    // axi write response channel 
    // src slave
    input [3:0]    bid_s_inf,
    input [1:0]    bresp_s_inf,
    input          bvalid_s_inf,
    // src master 
    output         bready_s_inf,
    // -----------------------------
  
    // axi read address channel 
    // src master
    output [3:0]   arid_s_inf,
    output [31:0]  araddr_s_inf,
    output [7:0]   arlen_s_inf,
    output [2:0]   arsize_s_inf,
    output [1:0]   arburst_s_inf,
    output         arvalid_s_inf,
    // src slave
    input          arready_s_inf,
    // -----------------------------
  
    // axi read data channel 
    // slave
    input [3:0]    rid_s_inf,
    input [127:0]  rdata_s_inf,
    input [1:0]    rresp_s_inf,
    input          rlast_s_inf,
    input          rvalid_s_inf,
    // master
    output         rready_s_inf
    
);

// Your Design
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j, k;
genvar ii;

parameter IDLE = 2'b00;
parameter CALC = 2'b01;
parameter WAIT = 2'b11;
parameter OPUT = 2'b10;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
// DRAM module signals
reg  wstart_cs, wstart_ns, rstart_cs, rstart_ns;
// circuit signals
reg [1:0]  mode_cs, mode_ns;
reg [7:0]  count_cs, count_ns;
reg [1:0]  in_mode_cs, in_mode_ns;
reg [3:0]  pic_no_cs, pic_no_ns;
reg [1:0]  ratio_mode_cs, ratio_mode_ns;

// regs
reg [7:0]  tmp_cs [0:3][0:15];
reg [7:0]  tmp_ns [0:3][0:15];
reg [7:0]  part1_cs [0:7];
reg [7:0]  part1_ns [0:7];
reg [8:0]  part2_cs [0:3];
reg [8:0]  part2_ns [0:3];
reg [9:0]  part3_cs [0:1];
reg [9:0]  part3_ns [0:1];
reg [10:0] part4_cs;
reg [10:0] part4_ns;
reg [18:0] part5_cs;
reg [18:0] part5_ns;
reg [7:0]  gray_cs  [0:5][0:5];
reg [7:0]  gray_ns  [0:5][0:5];
reg [7:0]  abs_cs   [0:1][0:1];
reg [7:0]  abs_ns   [0:1][0:1];
reg [7:0]  sub_cs   [0:1];
reg [7:0]  sub_ns   [0:1];
reg [8:0]  sub_sum_cs;
reg [8:0]  sub_sum_ns;
reg [13:0] dif_cs   [0:2];
reg [13:0] dif_ns   [0:2];
reg [3:0]  zero_cs  [0:15];
reg [3:0]  zero_ns  [0:15];
reg [1:0]  f_ans_cs [0:15];
reg [1:0]  f_ans_ns [0:15];
reg [7:0]  e_ans_cs [0:15];
reg [7:0]  e_ans_ns [0:15];
// new for final
reg [7:0]  cmp_reg1_ns [0:1][0:15];
reg [7:0]  cmp_reg1_cs [0:1][0:15];
reg [7:0]  cmp_reg2_ns [0:1][0:3];
reg [7:0]  cmp_reg2_cs [0:1][0:3];
reg [9:0]  cmp_reg3_ns [0:1];
reg [9:0]  cmp_reg3_cs [0:1];
reg [9:0]  cmp_reg4_ns [0:1];
reg [9:0]  cmp_reg4_cs [0:1];
reg [7:0]  mm_ans_ns   [0:15];
reg [7:0]  mm_ans_cs   [0:15];

reg  [7:0] add_a [0:2];
reg  [6:0] add_b [0:2];
wire [7:0] add_out [0:2];
reg  [7:0] cmp_a [0:1];
reg  [7:0] cmp_b [0:1];
wire [7:0] cmp_outs [0:1];
wire [7:0] cmp_outl [0:1];
// new for final

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        mode_cs         <= IDLE;
        count_cs        <= 0;
        in_mode_cs      <= 0;
        pic_no_cs       <= 0;
        ratio_mode_cs   <= 0;
        wstart_cs       <= 0;
        rstart_cs       <= 0;
        for(i=0 ; i<4 ; i=i+1) for(j=0 ; j<16 ; j=j+1) tmp_cs[i][j] <= 0;
        for(i=0 ; i<8 ; i=i+1)  part1_cs[i] <= 0;
        for(i=0 ; i<4 ; i=i+1)  part2_cs[i] <= 0;
        for(i=0 ; i<2 ; i=i+1)  part3_cs[i] <= 0;
        part4_cs <= 0;
        part5_cs <= 0;
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) gray_cs[i][j] <= 0;
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<2 ; j=j+1) abs_cs[i][j]  <= 0;
        for(i=0 ; i<2 ; i=i+1) sub_cs[i] <= 0;
        sub_sum_cs <= 0;
        for(i=0 ; i<3 ; i=i+1)  dif_cs[i]    <= 0;
        for(i=0 ; i<16 ; i=i+1) zero_cs[i]   <= 0;
        for(i=0 ; i<16 ; i=i+1) f_ans_cs[i]  <= 2'd3;
        for(i=0 ; i<16 ; i=i+1) e_ans_cs[i]  <= 0;
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<16 ; j=j+1) cmp_reg1_cs[i][j] <= 0;
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1)  cmp_reg2_cs[i][j] <= 0;
        for(i=0 ; i<2 ; i=i+1) cmp_reg3_cs[i] <= 0;
        for(i=0 ; i<2 ; i=i+1) cmp_reg4_cs[i] <= 0;
        for(i=0 ; i<16 ; i=i+1) mm_ans_cs[i]  <= 0;
    end 
    else begin
        mode_cs         <= mode_ns;
        count_cs        <= count_ns;
        in_mode_cs      <= in_mode_ns;
        pic_no_cs       <= pic_no_ns;
        ratio_mode_cs   <= ratio_mode_ns;
        wstart_cs       <= wstart_ns;
        rstart_cs       <= rstart_ns;
        for(i=0 ; i<4 ; i=i+1) for(j=0 ; j<16 ; j=j+1) tmp_cs[i][j] <= tmp_ns[i][j];
        for(i=0 ; i<8 ; i=i+1)  part1_cs[i] <= part1_ns[i];
        for(i=0 ; i<4 ; i=i+1)  part2_cs[i] <= part2_ns[i];
        for(i=0 ; i<2 ; i=i+1)  part3_cs[i] <= part3_ns[i];
        part4_cs <= part4_ns;
        part5_cs <= part5_ns;
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) gray_cs[i][j] <= gray_ns[i][j];
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<2 ; j=j+1) abs_cs[i][j]  <= abs_ns[i][j];
        for(i=0 ; i<2 ; i=i+1) sub_cs[i] <= sub_ns[i];
        sub_sum_cs <= sub_sum_ns;
        for(i=0 ; i<3 ; i=i+1)  dif_cs[i]    <= dif_ns[i];
        for(i=0 ; i<16 ; i=i+1) zero_cs[i]   <= zero_ns[i];
        for(i=0 ; i<16 ; i=i+1) f_ans_cs[i]  <= f_ans_ns[i];
        for(i=0 ; i<16 ; i=i+1) e_ans_cs[i]  <= e_ans_ns[i];
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<16 ; j=j+1) cmp_reg1_cs[i][j] <= cmp_reg1_ns[i][j];
        for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<4 ; j=j+1)  cmp_reg2_cs[i][j] <= cmp_reg2_ns[i][j];
        for(i=0 ; i<2 ; i=i+1) cmp_reg3_cs[i] <= cmp_reg3_ns[i];
        for(i=0 ; i<2 ; i=i+1) cmp_reg4_cs[i] <= cmp_reg4_ns[i];
        for(i=0 ; i<16 ; i=i+1) mm_ans_cs[i]  <= mm_ans_ns[i];
    end       
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(in_valid) begin
                if(in_mode == 2'b01) begin
                    case (in_ratio_mode)
                        0: begin
                            if(zero_cs[in_pic_no] > 5)  mode_ns = WAIT;
                            else                        mode_ns = CALC;
                        end
                        1: begin
                            if(zero_cs[in_pic_no] > 6)  mode_ns = WAIT;
                            else                        mode_ns = CALC;
                        end
                        2: begin
                            if((zero_cs[in_pic_no] > 7) || (f_ans_cs[in_pic_no] != 2'd3))   mode_ns = WAIT;
                            else                                                            mode_ns = CALC;
                        end
                        3: begin
                            if(zero_cs[in_pic_no] > 7)  mode_ns = WAIT;
                            else                        mode_ns = CALC;
                        end
                        default: mode_ns = CALC;
                    endcase
                end
                else begin
                    if((zero_cs[in_pic_no] > 7) || (f_ans_cs[in_pic_no] != 2'd3))   mode_ns = WAIT;
                    else                                                            mode_ns = CALC;
                end
            end 
            else mode_ns = mode_cs;
        end

        CALC: begin
            if(count_cs == 198) mode_ns = OPUT;
            else                mode_ns = mode_cs;
        end

        WAIT: mode_ns = OPUT;

        OPUT: mode_ns = IDLE;

		default: mode_ns = mode_cs;

    endcase
end

//======================================================================//
//                               SUBMODULES                             //
//======================================================================//
DRAM_WRITER WRITER0( 
    // control signals
    .clk(clk), .rst_n(rst_n), .pic_no(pic_no_cs), .start(wstart_cs), .rvalid(rvalid_s_inf), .count(count_cs),
    // axi write address channel
    // src master
    .awid_s_inf(awid_s_inf), .awaddr_s_inf(awaddr_s_inf), .awsize_s_inf(awsize_s_inf), .awburst_s_inf(awburst_s_inf), .awlen_s_inf(awlen_s_inf), .awvalid_s_inf(awvalid_s_inf),
    // src slave
    .awready_s_inf(awready_s_inf),
    // axi write data channel 
    // src master
    .wlast_s_inf(wlast_s_inf), .wvalid_s_inf(wvalid_s_inf),
    // src slave
    .wready_s_inf(wready_s_inf),
    // axi write response channel 
    // src slave
    .bvalid_s_inf(bvalid_s_inf),
    // src master 
    .bready_s_inf(bready_s_inf)
);
DRAM_READER READER0(
    // control signals
    .clk(clk), .rst_n(rst_n), .pic_no(pic_no_cs), .start(rstart_cs), .count(count_cs),
    // axi read address channel 
    // src master
    .arid_s_inf(arid_s_inf), .araddr_s_inf(araddr_s_inf), .arlen_s_inf(arlen_s_inf), .arsize_s_inf(arsize_s_inf), .arburst_s_inf(arburst_s_inf), .arvalid_s_inf(arvalid_s_inf),
    // src slave
    .arready_s_inf(arready_s_inf),
    // axi read data channel 
    // slave
    .rlast_s_inf(rlast_s_inf), .rvalid_s_inf(rvalid_s_inf),
    // master
    .rready_s_inf(rready_s_inf)
);

//======================================================================//
//                              COMB CIRCUITS                           //
//======================================================================//
// in_mode_ns & pic_no_ns & ratio_mode_ns circuit
always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(in_valid)begin           // new input
                in_mode_ns = in_mode;
                pic_no_ns = in_pic_no;

                if(in_mode == 1)    ratio_mode_ns = in_ratio_mode;
                else                ratio_mode_ns = 2;
            end
            else begin
                in_mode_ns = in_mode_cs;
                pic_no_ns = pic_no_cs;
                ratio_mode_ns = ratio_mode_cs;
            end
        end

        default: begin          // hold value
            in_mode_ns = in_mode_cs;
            pic_no_ns = pic_no_cs;
            ratio_mode_ns = ratio_mode_cs;
        end

    endcase
end

// count_ns circuit
always @(*) begin
    case (mode_cs)

        CALC: begin
            if(rvalid_s_inf || (count_cs > 0))  count_ns = count_cs + 1;
            else                                count_ns = count_cs;
        end

        default: count_ns = 0;
    endcase
end

// start_ns signals
always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(mode_ns == CALC) begin
                wstart_ns = 1;
                rstart_ns = 1;
            end
            else begin
                wstart_ns = 0;
                rstart_ns = 0;
            end
        end

        CALC: begin
            if(awready_s_inf)   wstart_ns = 0;
            else                wstart_ns = wstart_cs;

            if(arready_s_inf)   rstart_ns = 0;
            else                rstart_ns = rstart_cs;
        end

        default: begin
            wstart_ns = 0;
            rstart_ns = 0;
        end

    endcase
end

// tmp_ns circuit
always @(*) begin
    for(i=0 ; i<4 ; i=i+1) for(j=0 ; j<16 ; j=j+1) tmp_ns[i][j] = tmp_cs[i][j];

    case (mode_cs)

        // IDLE: 

        CALC: begin
            // receive DRAM data
            if(rvalid_s_inf) begin
                tmp_ns[0][0]  = rdata_s_inf[7:0];
                tmp_ns[0][1]  = rdata_s_inf[15:8];
                tmp_ns[0][2]  = rdata_s_inf[23:16];
                tmp_ns[0][3]  = rdata_s_inf[31:24];
                tmp_ns[0][4]  = rdata_s_inf[39:32];
                tmp_ns[0][5]  = rdata_s_inf[47:40];
                tmp_ns[0][6]  = rdata_s_inf[55:48];
                tmp_ns[0][7]  = rdata_s_inf[63:56];
                tmp_ns[0][8]  = rdata_s_inf[71:64];
                tmp_ns[0][9]  = rdata_s_inf[79:72];
                tmp_ns[0][10] = rdata_s_inf[87:80];
                tmp_ns[0][11] = rdata_s_inf[95:88];
                tmp_ns[0][12] = rdata_s_inf[103:96];
                tmp_ns[0][13] = rdata_s_inf[111:104];
                tmp_ns[0][14] = rdata_s_inf[119:112];
                tmp_ns[0][15] = rdata_s_inf[127:120];
            end
            else for(i=0 ; i<16 ; i=i+1) tmp_ns[0][i] = 0;

            // exposure shift
            case (ratio_mode_cs)
                0: for(i=0 ; i<16 ; i=i+1) tmp_ns[1][i] = tmp_cs[0][i] >> 2;
                1: for(i=0 ; i<16 ; i=i+1) tmp_ns[1][i] = tmp_cs[0][i] >> 1;
                2: for(i=0 ; i<16 ; i=i+1) tmp_ns[1][i] = tmp_cs[0][i];
                3: begin
                    for(i=0 ; i<16 ; i=i+1) begin
                        if(tmp_cs[0][i][7] == 1)    tmp_ns[1][i] = 8'b11111111;
                        else                        tmp_ns[1][i] = tmp_cs[0][i] << 1;
                    end 
                end
            endcase

            // wait for write enable
            for(i=0 ; i<16 ; i=i+1) tmp_ns[2][i] = tmp_cs[1][i];
            for(i=0 ; i<16 ; i=i+1) tmp_ns[3][i] = tmp_cs[2][i];
        end

        // OPUT: 
        
    endcase
end

// partial sum circuit
always @(*) begin
    // exposure calculation : 
    // weighted
    if((count_cs > 65) && (count_cs < 130)) for(i=0 ; i<8 ; i=i+1) part1_ns[i] = (tmp_cs[1][2*i] >> 1) + (tmp_cs[1][2*i+1] >> 1);
    else                                    for(i=0 ; i<8 ; i=i+1) part1_ns[i] = (tmp_cs[1][2*i] >> 2) + (tmp_cs[1][2*i+1] >> 2);

    // sum
    // for(i=0 ; i<8 ; i=i+1) part1_ns[i] = tmp_cs[1][2*i] + tmp_cs[1][2*i+1];
    for(i=0 ; i<4 ; i=i+1) part2_ns[i] = part1_cs[2*i] + part1_cs[2*i+1];
    for(i=0 ; i<2 ; i=i+1) part3_ns[i] = part2_cs[2*i] + part2_cs[2*i+1];
    part4_ns = part3_cs[0] + part3_cs[1];

    // accumulated sum
    if(mode_cs == CALC) part5_ns = part5_cs + part4_cs;
    else                part5_ns = 0;
end

// write data for DRAM
always @(*) begin
    if(mode_cs == CALC) wdata_s_inf = {tmp_cs[3][15], tmp_cs[3][14], tmp_cs[3][13], tmp_cs[3][12], tmp_cs[3][11], tmp_cs[3][10], tmp_cs[3][9], tmp_cs[3][8], tmp_cs[3][7], tmp_cs[3][6], tmp_cs[3][5], tmp_cs[3][4], tmp_cs[3][3], tmp_cs[3][2], tmp_cs[3][1], tmp_cs[3][0]};
    else                wdata_s_inf = 0;
end

// gray_ns circuit
assign add_out[0] = add_a[0] + add_b[0];
assign add_out[1] = add_a[1] + add_b[1];
assign add_out[2] = add_a[2] + add_b[2];
always @(*) begin
    for(i=0 ; i<3 ; i=i+1)begin add_a[i] = 0;  add_b[i] = 0; end
    for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) gray_ns[i][j] = gray_cs[i][j];

    case (mode_cs)
        
        // IDLE: 

        CALC: begin
            case (count_cs)
                // R
                28: begin
                    gray_ns[0][0] = tmp_cs[1][13] >> 2;
                    gray_ns[0][1] = tmp_cs[1][14] >> 2;
                    gray_ns[0][2] = tmp_cs[1][15] >> 2;
                end 
                29: begin
                    gray_ns[0][3] = tmp_cs[1][0] >> 2;
                    gray_ns[0][4] = tmp_cs[1][1] >> 2;
                    gray_ns[0][5] = tmp_cs[1][2] >> 2;
                end 
                30: begin
                    gray_ns[1][0] = tmp_cs[1][13] >> 2;
                    gray_ns[1][1] = tmp_cs[1][14] >> 2;
                    gray_ns[1][2] = tmp_cs[1][15] >> 2;
                end 
                31: begin
                    gray_ns[1][3] = tmp_cs[1][0] >> 2;
                    gray_ns[1][4] = tmp_cs[1][1] >> 2;
                    gray_ns[1][5] = tmp_cs[1][2] >> 2;
                end 
                32: begin
                    gray_ns[2][0] = tmp_cs[1][13] >> 2;
                    gray_ns[2][1] = tmp_cs[1][14] >> 2;
                    gray_ns[2][2] = tmp_cs[1][15] >> 2;
                end 
                33: begin
                    gray_ns[2][3] = tmp_cs[1][0] >> 2;
                    gray_ns[2][4] = tmp_cs[1][1] >> 2;
                    gray_ns[2][5] = tmp_cs[1][2] >> 2;
                end 
                34: begin
                    gray_ns[3][0] = tmp_cs[1][13] >> 2;
                    gray_ns[3][1] = tmp_cs[1][14] >> 2;
                    gray_ns[3][2] = tmp_cs[1][15] >> 2;
                end 
                35: begin
                    gray_ns[3][3] = tmp_cs[1][0] >> 2;
                    gray_ns[3][4] = tmp_cs[1][1] >> 2;
                    gray_ns[3][5] = tmp_cs[1][2] >> 2;
                end 
                36: begin
                    gray_ns[4][0] = tmp_cs[1][13] >> 2;
                    gray_ns[4][1] = tmp_cs[1][14] >> 2;
                    gray_ns[4][2] = tmp_cs[1][15] >> 2;
                end 
                37: begin
                    gray_ns[4][3] = tmp_cs[1][0] >> 2;
                    gray_ns[4][4] = tmp_cs[1][1] >> 2;
                    gray_ns[4][5] = tmp_cs[1][2] >> 2;
                end 
                38: begin
                    gray_ns[5][0] = tmp_cs[1][13] >> 2;
                    gray_ns[5][1] = tmp_cs[1][14] >> 2;
                    gray_ns[5][2] = tmp_cs[1][15] >> 2;
                end 
                39: begin
                    gray_ns[5][3] = tmp_cs[1][0] >> 2;
                    gray_ns[5][4] = tmp_cs[1][1] >> 2;
                    gray_ns[5][5] = tmp_cs[1][2] >> 2;
                end 
                // G
                92: begin
                    add_a[0] = gray_cs[0][0]; add_b[0] = (tmp_cs[1][13] >> 1); gray_ns[0][0] = add_out[0];
                    add_a[1] = gray_cs[0][1]; add_b[1] = (tmp_cs[1][14] >> 1); gray_ns[0][1] = add_out[1];
                    add_a[2] = gray_cs[0][2]; add_b[2] = (tmp_cs[1][15] >> 1); gray_ns[0][2] = add_out[2];
                end 
                93: begin
                    gray_ns[0][3] = add_out[0]; add_a[0] = gray_cs[0][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[0][4] = add_out[1]; add_a[1] = gray_cs[0][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[0][5] = add_out[2]; add_a[2] = gray_cs[0][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                94: begin
                    gray_ns[1][0] = add_out[0]; add_a[0] = gray_cs[1][0]; add_b[0] = (tmp_cs[1][13] >> 1);
                    gray_ns[1][1] = add_out[1]; add_a[1] = gray_cs[1][1]; add_b[1] = (tmp_cs[1][14] >> 1);
                    gray_ns[1][2] = add_out[2]; add_a[2] = gray_cs[1][2]; add_b[2] = (tmp_cs[1][15] >> 1);
                end 
                95: begin
                    gray_ns[1][3] = add_out[0]; add_a[0] = gray_cs[1][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[1][4] = add_out[1]; add_a[1] = gray_cs[1][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[1][5] = add_out[2]; add_a[2] = gray_cs[1][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                96: begin
                    gray_ns[2][0] = add_out[0]; add_a[0] = gray_cs[2][0]; add_b[0] = (tmp_cs[1][13] >> 1);
                    gray_ns[2][1] = add_out[1]; add_a[1] = gray_cs[2][1]; add_b[1] = (tmp_cs[1][14] >> 1);
                    gray_ns[2][2] = add_out[2]; add_a[2] = gray_cs[2][2]; add_b[2] = (tmp_cs[1][15] >> 1);
                end 
                97: begin
                    gray_ns[2][3] = add_out[0]; add_a[0] = gray_cs[2][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[2][4] = add_out[1]; add_a[1] = gray_cs[2][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[2][5] = add_out[2]; add_a[2] = gray_cs[2][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                98: begin
                    gray_ns[3][0] = add_out[0]; add_a[0] = gray_cs[3][0]; add_b[0] = (tmp_cs[1][13] >> 1);
                    gray_ns[3][1] = add_out[1]; add_a[1] = gray_cs[3][1]; add_b[1] = (tmp_cs[1][14] >> 1);
                    gray_ns[3][2] = add_out[2]; add_a[2] = gray_cs[3][2]; add_b[2] = (tmp_cs[1][15] >> 1);
                end 
                99: begin
                    gray_ns[3][3] = add_out[0]; add_a[0] = gray_cs[3][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[3][4] = add_out[1]; add_a[1] = gray_cs[3][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[3][5] = add_out[2]; add_a[2] = gray_cs[3][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                100: begin
                    gray_ns[4][0] = add_out[0]; add_a[0] = gray_cs[4][0]; add_b[0] = (tmp_cs[1][13] >> 1);
                    gray_ns[4][1] = add_out[1]; add_a[1] = gray_cs[4][1]; add_b[1] = (tmp_cs[1][14] >> 1);
                    gray_ns[4][2] = add_out[2]; add_a[2] = gray_cs[4][2]; add_b[2] = (tmp_cs[1][15] >> 1);
                end 
                101: begin
                    gray_ns[4][3] = add_out[0]; add_a[0] = gray_cs[4][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[4][4] = add_out[1]; add_a[1] = gray_cs[4][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[4][5] = add_out[2]; add_a[2] = gray_cs[4][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                102: begin
                    gray_ns[5][0] = add_out[0]; add_a[0] = gray_cs[5][0]; add_b[0] = (tmp_cs[1][13] >> 1);
                    gray_ns[5][1] = add_out[1]; add_a[1] = gray_cs[5][1]; add_b[1] = (tmp_cs[1][14] >> 1);
                    gray_ns[5][2] = add_out[2]; add_a[2] = gray_cs[5][2]; add_b[2] = (tmp_cs[1][15] >> 1);
                end 
                103: begin
                    gray_ns[5][3] = add_out[0]; add_a[0] = gray_cs[5][3]; add_b[0] = (tmp_cs[1][0] >> 1);
                    gray_ns[5][4] = add_out[1]; add_a[1] = gray_cs[5][4]; add_b[1] = (tmp_cs[1][1] >> 1);
                    gray_ns[5][5] = add_out[2]; add_a[2] = gray_cs[5][5]; add_b[2] = (tmp_cs[1][2] >> 1);
                end 
                // B
                156: begin
                    gray_ns[0][0] = add_out[0]; add_a[0] = gray_cs[0][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[0][1] = add_out[1]; add_a[1] = gray_cs[0][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[0][2] = add_out[2]; add_a[2] = gray_cs[0][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                157: begin
                    gray_ns[0][3] = add_out[0]; add_a[0] = gray_cs[0][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[0][4] = add_out[1]; add_a[1] = gray_cs[0][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[0][5] = add_out[2]; add_a[2] = gray_cs[0][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
                158: begin
                    gray_ns[1][0] = add_out[0]; add_a[0] = gray_cs[1][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[1][1] = add_out[1]; add_a[1] = gray_cs[1][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[1][2] = add_out[2]; add_a[2] = gray_cs[1][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                159: begin
                    gray_ns[1][3] = add_out[0]; add_a[0] = gray_cs[1][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[1][4] = add_out[1]; add_a[1] = gray_cs[1][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[1][5] = add_out[2]; add_a[2] = gray_cs[1][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
                160: begin
                    gray_ns[2][0] = add_out[0]; add_a[0] = gray_cs[2][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[2][1] = add_out[1]; add_a[1] = gray_cs[2][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[2][2] = add_out[2]; add_a[2] = gray_cs[2][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                161: begin
                    gray_ns[2][3] = add_out[0]; add_a[0] = gray_cs[2][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[2][4] = add_out[1]; add_a[1] = gray_cs[2][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[2][5] = add_out[2]; add_a[2] = gray_cs[2][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
                162: begin
                    gray_ns[3][0] = add_out[0]; add_a[0] = gray_cs[3][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[3][1] = add_out[1]; add_a[1] = gray_cs[3][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[3][2] = add_out[2]; add_a[2] = gray_cs[3][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                163: begin
                    gray_ns[3][3] = add_out[0]; add_a[0] = gray_cs[3][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[3][4] = add_out[1]; add_a[1] = gray_cs[3][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[3][5] = add_out[2]; add_a[2] = gray_cs[3][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
                164: begin
                    gray_ns[4][0] = add_out[0]; add_a[0] = gray_cs[4][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[4][1] = add_out[1]; add_a[1] = gray_cs[4][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[4][2] = add_out[2]; add_a[2] = gray_cs[4][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                165: begin
                    gray_ns[4][3] = add_out[0]; add_a[0] = gray_cs[4][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[4][4] = add_out[1]; add_a[1] = gray_cs[4][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[4][5] = add_out[2]; add_a[2] = gray_cs[4][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
                166: begin
                    gray_ns[5][0] = add_out[0]; add_a[0] = gray_cs[5][0]; add_b[0] = (tmp_cs[1][13] >> 2);
                    gray_ns[5][1] = add_out[1]; add_a[1] = gray_cs[5][1]; add_b[1] = (tmp_cs[1][14] >> 2);
                    gray_ns[5][2] = add_out[2]; add_a[2] = gray_cs[5][2]; add_b[2] = (tmp_cs[1][15] >> 2);
                end 
                167: begin
                    gray_ns[5][3] = add_out[0]; add_a[0] = gray_cs[5][3]; add_b[0] = (tmp_cs[1][0] >> 2);
                    gray_ns[5][4] = add_out[1]; add_a[1] = gray_cs[5][4]; add_b[1] = (tmp_cs[1][1] >> 2);
                    gray_ns[5][5] = add_out[2]; add_a[2] = gray_cs[5][5]; add_b[2] = (tmp_cs[1][2] >> 2);
                end 
            endcase
        end

        OPUT: for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) gray_ns[i][j] = 0;

    endcase
end

// make absolute number
assign cmp_outl[0] = (cmp_a[0] > cmp_b[0])? cmp_a[0]:cmp_b[0];
assign cmp_outs[0] = (cmp_a[0] > cmp_b[0])? cmp_b[0]:cmp_a[0];
assign cmp_outl[1] = (cmp_a[1] > cmp_b[1])? cmp_a[1]:cmp_b[1];
assign cmp_outs[1] = (cmp_a[1] > cmp_b[1])? cmp_b[1]:cmp_a[1];
always @(*) begin
    for(i=0 ; i<2 ; i=i+1)begin cmp_a[i] = 0;  cmp_b[i] = 0; end
    abs_ns[0][0] = cmp_outl[0];
    abs_ns[0][1] = cmp_outs[0];
    abs_ns[1][0] = cmp_outl[1];
    abs_ns[1][1] = cmp_outs[1];

    case (count_cs)
        // row 0 & col 0
        163: begin
            cmp_a[0] = gray_cs[0][0]; cmp_b[0] = gray_cs[0][1];
            cmp_a[1] = gray_cs[0][0]; cmp_b[1] = gray_cs[1][0];
        end
        164: begin
            cmp_a[0] = gray_cs[0][1]; cmp_b[0] = gray_cs[0][2];
            cmp_a[1] = gray_cs[1][0]; cmp_b[1] = gray_cs[2][0];
        end
        165: begin
            cmp_a[0] = gray_cs[0][2]; cmp_b[0] = gray_cs[0][3];
            cmp_a[1] = gray_cs[2][0]; cmp_b[1] = gray_cs[3][0];
        end
        166: begin
            cmp_a[0] = gray_cs[0][3]; cmp_b[0] = gray_cs[0][4];
            cmp_a[1] = gray_cs[3][0]; cmp_b[1] = gray_cs[4][0];
        end
        167: begin
            cmp_a[0] = gray_cs[0][4]; cmp_b[0] = gray_cs[0][5];
            cmp_a[1] = gray_cs[4][0]; cmp_b[1] = gray_cs[5][0];
        end
        // row 1 & col 1
        168: begin
            cmp_a[0] = gray_cs[1][0]; cmp_b[0] = gray_cs[1][1];
            cmp_a[1] = gray_cs[0][1]; cmp_b[1] = gray_cs[1][1];
        end
        169: begin
            cmp_a[0] = gray_cs[1][1]; cmp_b[0] = gray_cs[1][2];
            cmp_a[1] = gray_cs[1][1]; cmp_b[1] = gray_cs[2][1];
        end
        170: begin
            cmp_a[0] = gray_cs[1][2]; cmp_b[0] = gray_cs[1][3];
            cmp_a[1] = gray_cs[2][1]; cmp_b[1] = gray_cs[3][1];
        end
        171: begin
            cmp_a[0] = gray_cs[1][3]; cmp_b[0] = gray_cs[1][4];
            cmp_a[1] = gray_cs[3][1]; cmp_b[1] = gray_cs[4][1];
        end
        172: begin
            cmp_a[0] = gray_cs[1][4]; cmp_b[0] = gray_cs[1][5];
            cmp_a[1] = gray_cs[4][1]; cmp_b[1] = gray_cs[5][1];
        end
        // row 2 & col 2
        173: begin
            cmp_a[0] = gray_cs[2][0]; cmp_b[0] = gray_cs[2][1];
            cmp_a[1] = gray_cs[0][2]; cmp_b[1] = gray_cs[1][2];
        end
        174: begin
            cmp_a[0] = gray_cs[2][1]; cmp_b[0] = gray_cs[2][2];
            cmp_a[1] = gray_cs[1][2]; cmp_b[1] = gray_cs[2][2];
        end
        175: begin
            cmp_a[0] = gray_cs[2][2]; cmp_b[0] = gray_cs[2][3];
            cmp_a[1] = gray_cs[2][2]; cmp_b[1] = gray_cs[3][2];
        end
        176: begin
            cmp_a[0] = gray_cs[2][3]; cmp_b[0] = gray_cs[2][4];
            cmp_a[1] = gray_cs[3][2]; cmp_b[1] = gray_cs[4][2];
        end
        177: begin
            cmp_a[0] = gray_cs[2][4]; cmp_b[0] = gray_cs[2][5];
            cmp_a[1] = gray_cs[4][2]; cmp_b[1] = gray_cs[5][2];
        end
        // row 3 & col 3
        178: begin
            cmp_a[0] = gray_cs[3][0]; cmp_b[0] = gray_cs[3][1];
            cmp_a[1] = gray_cs[0][3]; cmp_b[1] = gray_cs[1][3];
        end
        179: begin
            cmp_a[0] = gray_cs[3][1]; cmp_b[0] = gray_cs[3][2];
            cmp_a[1] = gray_cs[1][3]; cmp_b[1] = gray_cs[2][3];
        end
        180: begin
            cmp_a[0] = gray_cs[3][2]; cmp_b[0] = gray_cs[3][3];
            cmp_a[1] = gray_cs[2][3]; cmp_b[1] = gray_cs[3][3];
        end
        181: begin
            cmp_a[0] = gray_cs[3][3]; cmp_b[0] = gray_cs[3][4];
            cmp_a[1] = gray_cs[3][3]; cmp_b[1] = gray_cs[4][3];
        end
        182: begin
            cmp_a[0] = gray_cs[3][4]; cmp_b[0] = gray_cs[3][5];
            cmp_a[1] = gray_cs[4][3]; cmp_b[1] = gray_cs[5][3];
        end
        // row 4 & col 4
        183: begin
            cmp_a[0] = gray_cs[4][0]; cmp_b[0] = gray_cs[4][1];
            cmp_a[1] = gray_cs[0][4]; cmp_b[1] = gray_cs[1][4];
        end
        184: begin
            cmp_a[0] = gray_cs[4][1]; cmp_b[0] = gray_cs[4][2];
            cmp_a[1] = gray_cs[1][4]; cmp_b[1] = gray_cs[2][4];
        end
        185: begin
            cmp_a[0] = gray_cs[4][2]; cmp_b[0] = gray_cs[4][3];
            cmp_a[1] = gray_cs[2][4]; cmp_b[1] = gray_cs[3][4];
        end
        186: begin
            cmp_a[0] = gray_cs[4][3]; cmp_b[0] = gray_cs[4][4];
            cmp_a[1] = gray_cs[3][4]; cmp_b[1] = gray_cs[4][4];
        end
        187: begin
            cmp_a[0] = gray_cs[4][4]; cmp_b[0] = gray_cs[4][5];
            cmp_a[1] = gray_cs[4][4]; cmp_b[1] = gray_cs[5][4];
        end
        // row 5 & col 5
        188: begin
            cmp_a[0] = gray_cs[5][0]; cmp_b[0] = gray_cs[5][1];
            cmp_a[1] = gray_cs[0][5]; cmp_b[1] = gray_cs[1][5];
        end
        189: begin
            cmp_a[0] = gray_cs[5][1]; cmp_b[0] = gray_cs[5][2];
            cmp_a[1] = gray_cs[1][5]; cmp_b[1] = gray_cs[2][5];
        end
        190: begin
            cmp_a[0] = gray_cs[5][2]; cmp_b[0] = gray_cs[5][3];
            cmp_a[1] = gray_cs[2][5]; cmp_b[1] = gray_cs[3][5];
        end
        191: begin
            cmp_a[0] = gray_cs[5][3]; cmp_b[0] = gray_cs[5][4];
            cmp_a[1] = gray_cs[3][5]; cmp_b[1] = gray_cs[4][5];
        end
        192: begin
            cmp_a[0] = gray_cs[5][4]; cmp_b[0] = gray_cs[5][5];
            cmp_a[1] = gray_cs[4][5]; cmp_b[1] = gray_cs[5][5];
        end
    endcase
end

// dif_ns circuit
always @(*) begin
    for(i=0 ; i<3 ; i=i+1) dif_ns[i] = dif_cs[i];

    // sub pipeline
    sub_ns[0] = abs_cs[0][0] - abs_cs[0][1];
    sub_ns[1] = abs_cs[1][0] - abs_cs[1][1];
    sub_sum_ns = sub_cs[0] + sub_cs[1];

    case (count_cs)
        0: for(i=0 ; i<3 ; i=i+1) dif_ns[i] = 0;
        
        166, 167, 168, 169, 170, 171, 175, 176, 180, 181, 185, 186, 190, 191, 192, 193, 194, 195: begin
            dif_ns[2] = dif_cs[2] + sub_sum_cs;
        end
        172, 173, 174, 177, 179, 182, 184, 187, 188, 189: begin
            dif_ns[1] = dif_cs[1] + sub_sum_cs;
            dif_ns[2] = dif_cs[2] + sub_sum_cs;
        end
        178, 183: begin
            dif_ns[0] = dif_cs[0] + sub_sum_cs;
            dif_ns[1] = dif_cs[1] + sub_sum_cs;
            dif_ns[2] = dif_cs[2] + sub_sum_cs;
        end

        196: begin
            dif_ns[0] = dif_cs[0] >> 2;
            dif_ns[1] = dif_cs[1] >> 4;
            dif_ns[2] = dif_cs[2] >> 2;
        end
        197: begin
            dif_ns[2][11:0] = dif_cs[2][11:0] / 9;
        end
    endcase
end

// e_ans_ns
always @(*) begin
    for(i=0 ; i<16 ; i=i+1) e_ans_ns[i] = e_ans_cs[i];

    if(mode_cs == CALC)                                     e_ans_ns[pic_no_cs] = part5_cs[17:10];
    else if((mode_cs == WAIT) && (zero_cs[pic_no_cs] == 8)) e_ans_ns[pic_no_cs] = 0;
end

// f_ans_ns
always @(*) begin
    for(i=0 ; i<16 ; i=i+1) f_ans_ns[i] = f_ans_cs[i];

    if(mode_cs == CALC) f_ans_ns[pic_no_cs] = (dif_cs[0] >= dif_cs[1])? ((dif_cs[0] >= dif_cs[2])? 0:2):((dif_cs[1] >= dif_cs[2])? 1:2);
    else if((mode_cs == WAIT) && (zero_cs[pic_no_cs] == 8)) f_ans_ns[pic_no_cs] = 0;
end

// zero_ns
always @(*) begin
    for(i=0 ; i<16 ; i=i+1) zero_ns[i] = zero_cs[i];

    if(mode_cs == OPUT) begin
        case (ratio_mode_cs)
            0: begin
                if(zero_cs[pic_no_cs] > 5)  zero_ns[pic_no_cs] = 8;
                else                        zero_ns[pic_no_cs] = zero_cs[pic_no_cs] + 2;
            end 
            1: begin
                if(zero_cs[pic_no_cs] > 6)  zero_ns[pic_no_cs] = 8;
                else                        zero_ns[pic_no_cs] = zero_cs[pic_no_cs] + 1;
            end
            3: begin
                if(zero_cs[pic_no_cs] == 0)         zero_ns[pic_no_cs] = 0;
                else if(zero_cs[pic_no_cs] == 8)    zero_ns[pic_no_cs] = zero_cs[pic_no_cs];
                else                                zero_ns[pic_no_cs] = zero_cs[pic_no_cs] - 1;
            end 
        endcase
    end
end

// new for final
wire [7:0] cmp_tmp1 [0:1][0:7];
wire [7:0] cmp_tmp2 [0:1][0:1];
generate
    for(ii=0 ; ii<8 ; ii=ii+1) assign cmp_tmp1[0][ii] = (cmp_reg1_cs[0][2*ii] < cmp_reg1_cs[0][2*ii+1])? cmp_reg1_cs[0][2*ii]:cmp_reg1_cs[0][2*ii+1];
    for(ii=0 ; ii<8 ; ii=ii+1) assign cmp_tmp1[1][ii] = (cmp_reg1_cs[1][2*ii] > cmp_reg1_cs[1][2*ii+1])? cmp_reg1_cs[1][2*ii]:cmp_reg1_cs[1][2*ii+1];
endgenerate
generate
    for(ii=0 ; ii<2 ; ii=ii+1) assign cmp_tmp2[0][ii] = (cmp_reg2_cs[0][2*ii] < cmp_reg2_cs[0][2*ii+1])? cmp_reg2_cs[0][2*ii]:cmp_reg2_cs[0][2*ii+1];
    for(ii=0 ; ii<2 ; ii=ii+1) assign cmp_tmp2[1][ii] = (cmp_reg2_cs[1][2*ii] > cmp_reg2_cs[1][2*ii+1])? cmp_reg2_cs[1][2*ii]:cmp_reg2_cs[1][2*ii+1];
endgenerate


// cmp_reg_ns
always @(*) begin
    // cmp_reg1
    if((count_cs == 2) || (count_cs == 66) || (count_cs == 130)) for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<16 ; j=j+1) cmp_reg1_ns[i][j] = tmp_cs[1][j];      // load first one for comparison
    else if((count_cs > 1) && (count_cs < 194)) begin
        for(j=0 ; j<16 ; j=j+1) begin
            if(tmp_cs[1][j] < cmp_reg1_cs[0][j])    cmp_reg1_ns[0][j] = tmp_cs[1][j];
            else                                    cmp_reg1_ns[0][j] = cmp_reg1_cs[0][j];

            if(tmp_cs[1][j] > cmp_reg1_cs[1][j])    cmp_reg1_ns[1][j] = tmp_cs[1][j];
            else                                    cmp_reg1_ns[1][j] = cmp_reg1_cs[1][j];
        end
    end
    else for(i=0 ; i<2 ; i=i+1) for(j=0 ; j<16 ; j=j+1) cmp_reg1_ns[i][j] = 0;

    // cmp_reg2
    for(j=0 ; j<4 ; j=j+1) begin
        cmp_reg2_ns[0][j] = (cmp_tmp1[0][2*j] < cmp_tmp1[0][2*j+1])? cmp_tmp1[0][2*j]:cmp_tmp1[0][2*j+1];
        cmp_reg2_ns[1][j] = (cmp_tmp1[1][2*j] > cmp_tmp1[1][2*j+1])? cmp_tmp1[1][2*j]:cmp_tmp1[1][2*j+1];
    end

    // cmp_reg3
    cmp_reg3_ns[0] = (cmp_tmp2[0][0] < cmp_tmp2[0][1])? cmp_tmp2[0][0]:cmp_tmp2[0][1];
    cmp_reg3_ns[1] = (cmp_tmp2[1][0] > cmp_tmp2[1][1])? cmp_tmp2[1][0]:cmp_tmp2[1][1];

    // cmp_reg4
    case (count_cs)
        0: begin
            cmp_reg4_ns[0] = 0;
            cmp_reg4_ns[1] = 0;
        end
        68, 132, 196: begin
            cmp_reg4_ns[0] = cmp_reg4_cs[0] + cmp_reg3_cs[0];
            cmp_reg4_ns[1] = cmp_reg4_cs[1] + cmp_reg3_cs[1];
        end
        197: begin
            cmp_reg4_ns[0] = cmp_reg4_cs[0] / 3;
            cmp_reg4_ns[1] = cmp_reg4_cs[1] / 3;
        end
        default: begin
            cmp_reg4_ns[0] = cmp_reg4_cs[0];
            cmp_reg4_ns[1] = cmp_reg4_cs[1];
        end
    endcase
end

// mm_ans_ns
always @(*) begin
    for(i=0 ; i<16 ; i=i+1) mm_ans_ns[i] = mm_ans_cs[i];

    if(mode_cs == CALC)                                     mm_ans_ns[pic_no_cs] = (cmp_reg4_cs[0] + cmp_reg4_cs[1]) >> 1;
    else if((mode_cs == WAIT) && (zero_cs[pic_no_cs] == 8)) mm_ans_ns[pic_no_cs] = 0;
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

        CALC: begin
            out_valid = 0;
            out_data = 0;
        end

        OPUT: begin
            out_valid = 1;
            case (pic_no_cs)
                0:  begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[0];
                        2'b01: out_data = e_ans_cs[0];
                        2'b10: out_data = mm_ans_cs[0];
                        default: out_data = 0;
                    endcase       
                end
                1:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[1];
                        2'b01: out_data = e_ans_cs[1];
                        2'b10: out_data = mm_ans_cs[1];
                        default: out_data = 0;
                    endcase 
                end
                2:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[2];
                        2'b01: out_data = e_ans_cs[2];
                        2'b10: out_data = mm_ans_cs[2];
                        default: out_data = 0;
                    endcase 
                end
                3:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[3];
                        2'b01: out_data = e_ans_cs[3];
                        2'b10: out_data = mm_ans_cs[3];
                        default: out_data = 0;
                    endcase 
                end
                4:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[4];
                        2'b01: out_data = e_ans_cs[4];
                        2'b10: out_data = mm_ans_cs[4];
                        default: out_data = 0;
                    endcase 
                end
                5:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[5];
                        2'b01: out_data = e_ans_cs[5];
                        2'b10: out_data = mm_ans_cs[5];
                        default: out_data = 0;
                    endcase 
                end
                6:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[6];
                        2'b01: out_data = e_ans_cs[6];
                        2'b10: out_data = mm_ans_cs[6];
                        default: out_data = 0;
                    endcase 
                end
                7:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[7];
                        2'b01: out_data = e_ans_cs[7];
                        2'b10: out_data = mm_ans_cs[7];
                        default: out_data = 0;
                    endcase 
                end
                8:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[8];
                        2'b01: out_data = e_ans_cs[8];
                        2'b10: out_data = mm_ans_cs[8];
                        default: out_data = 0;
                    endcase 
                end
                9:  begin
                   case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[9];
                        2'b01: out_data = e_ans_cs[9];
                        2'b10: out_data = mm_ans_cs[9];
                        default: out_data = 0;
                    endcase 
                end
                10: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[10];
                        2'b01: out_data = e_ans_cs[10];
                        2'b10: out_data = mm_ans_cs[10];
                        default: out_data = 0;
                    endcase 
                end
                11: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[11];
                        2'b01: out_data = e_ans_cs[11];
                        2'b10: out_data = mm_ans_cs[11];
                        default: out_data = 0;
                    endcase 
                end
                12: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[12];
                        2'b01: out_data = e_ans_cs[12];
                        2'b10: out_data = mm_ans_cs[12];
                        default: out_data = 0;
                    endcase 
                end
                13: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[13];
                        2'b01: out_data = e_ans_cs[13];
                        2'b10: out_data = mm_ans_cs[13];
                        default: out_data = 0;
                    endcase 
                end
                14: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[14];
                        2'b01: out_data = e_ans_cs[14];
                        2'b10: out_data = mm_ans_cs[14];
                        default: out_data = 0;
                    endcase 
                end
                15: begin
                    case (in_mode_cs)
                        2'b00: out_data = f_ans_cs[15];
                        2'b01: out_data = e_ans_cs[15];
                        2'b10: out_data = mm_ans_cs[15];
                        default: out_data = 0;
                    endcase 
                end
                default: out_data = 0;
            endcase
        end

		default: begin
            out_valid = 0;
            out_data = 0;
        end

	endcase
end

endmodule


// ========================================================== SUBMODULES ========================================================== //
module DRAM_WRITER(
    // control signals
    input       clk,
    input       rst_n,
    input       start,
    input [7:0] count,
    input [3:0] pic_no,
    input       rvalid,
    // axi write address channel
    // master
    output [3:0]  awid_s_inf,
    output reg [31:0] awaddr_s_inf,
    output [2:0]  awsize_s_inf,
    output [1:0]  awburst_s_inf,
    output [7:0]  awlen_s_inf,
    output        awvalid_s_inf,
    // slave
    input         awready_s_inf,
  
    // axi write data channel 
    // master
    output         wlast_s_inf,
    output         wvalid_s_inf,
    // slave
    input          wready_s_inf,

    // axi write response channel 
    // slave
    input          bvalid_s_inf,
    // master 
    output         bready_s_inf
);
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter IDLE  = 2'b00;
parameter WAIT  = 2'b01;
parameter WRITE = 2'b11;
parameter OVER  = 2'b10;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg [1:0] mode_cs, mode_ns;
reg [5:0] addr_cs, addr_ns;
reg       wlast_cs, wlast_ns;
reg       wvalid_cs, wvalid_ns;

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)  mode_cs <= IDLE;
    else        mode_cs <= mode_ns;
end

always @(*) begin
	case (mode_cs)

		IDLE: begin
            if(start)           mode_ns = WAIT;
            else                mode_ns = mode_cs;
        end

        WAIT: begin
            if(awready_s_inf)   mode_ns = WRITE;
            else                mode_ns = mode_cs;
        end

        WRITE: begin
            if(wlast_cs)    mode_ns = OVER;
            else            mode_ns = mode_cs;
        end

        OVER: begin
            if(bvalid_s_inf)    mode_ns = IDLE;
            else                mode_ns = mode_cs;
        end

		default: mode_ns = mode_cs;

	endcase
end

//======================================================================//
//                                CIRCUITS                              //
//======================================================================//
// address circuit
always @(posedge clk) begin
    addr_cs <= addr_ns;
end

always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(start) begin
                case (pic_no)
                    0:          addr_ns = 6'b000000;    // 0
                    1:          addr_ns = 6'b000011;    // 3
                    2:          addr_ns = 6'b000110;    // 6
                    3:          addr_ns = 6'b001001;    // 9
                    4:          addr_ns = 6'b001100;    // 12
                    5:          addr_ns = 6'b001111;    // 15
                    6:          addr_ns = 6'b010010;    // 18
                    7:          addr_ns = 6'b010101;    // 21
                    8:          addr_ns = 6'b011000;    // 24
                    9:          addr_ns = 6'b011011;    // 27
                    10:         addr_ns = 6'b011110;    // 30
                    11:         addr_ns = 6'b100001;    // 33
                    12:         addr_ns = 6'b100100;    // 36
                    13:         addr_ns = 6'b100111;    // 39
                    14:         addr_ns = 6'b101010;    // 42
                    15:         addr_ns = 6'b101101;    // 45
                    default:    addr_ns = 6'b111111;    // debug
                endcase
            end
            else addr_ns = 6'b111111;
        end

        WAIT: addr_ns = addr_cs;

        default: addr_ns = 6'b111111;

    endcase
end

// wvalid
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  wvalid_cs <= 0;
    else        wvalid_cs <= wvalid_ns;
end

always @(*) begin
    if(mode_cs == WRITE) begin
        if(rvalid)              wvalid_ns = 1;
        else if(count == 195)   wvalid_ns = 0;
        else                    wvalid_ns = wvalid_cs;
    end
    else wvalid_ns = 0;
end

// wlast circuit
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  wlast_cs <= 0;
    else        wlast_cs <= wlast_ns;
    
end

always @(*) begin
    if(count == 194)    wlast_ns = 1;
    else                wlast_ns = 0;
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
assign awid_s_inf       = 4'd0;
assign awburst_s_inf    = ((mode_cs == IDLE) && (!start))? 0:2'b01;
assign awsize_s_inf     = ((mode_cs == IDLE) && (!start))? 0:3'b100;
assign awlen_s_inf      = ((mode_cs == IDLE) && (!start))? 0:8'd191;
assign awvalid_s_inf    = ((start) || (mode_cs == WAIT));
assign wlast_s_inf      = wlast_cs;
assign wvalid_s_inf     = wvalid_cs;
assign bready_s_inf     = ((mode_cs == WRITE) || (mode_cs == OVER));

always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(start)   awaddr_s_inf = {16'h1, addr_ns, 10'h0};
            else        awaddr_s_inf = 0;
        end

        WAIT: awaddr_s_inf = {16'h1, addr_cs, 10'h0};

        default: awaddr_s_inf = 0;
    endcase
end
    
endmodule


module DRAM_READER(
    // control signals
    input       clk,
    input       rst_n,
    input       start,
    input [3:0] pic_no,
    input [7:0] count,
    // axi read address channel 
    // src master
    output      [3:0]   arid_s_inf,
    output reg  [31:0]  araddr_s_inf,
    output      [7:0]   arlen_s_inf,
    output      [2:0]   arsize_s_inf,
    output      [1:0]   arburst_s_inf,
    output              arvalid_s_inf,
    // src slave
    input           arready_s_inf,
    // -----------------------------
  
    // axi read data channel 
    // slave
    input           rlast_s_inf,
    input           rvalid_s_inf,
    // master
    output          rready_s_inf
);
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter IDLE = 2'b00;
parameter WAIT = 2'b01;
parameter READ = 2'b10;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg [1:0] mode_cs, mode_ns;
reg [5:0] addr_cs, addr_ns;

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)  mode_cs <= IDLE;
    else        mode_cs <= mode_ns;
end

always @(*) begin
	case (mode_cs)

		IDLE: begin
            if(start)           mode_ns = WAIT;
            else                mode_ns = mode_cs;
        end

        WAIT: begin
            if(arready_s_inf)   mode_ns = READ;
            else                mode_ns = mode_cs;
        end

        READ: begin
            if(rlast_s_inf)     mode_ns = IDLE;
            else                mode_ns = mode_cs;
        end

		default:                mode_ns = mode_cs;

	endcase
end

//======================================================================//
//                                CIRCUITS                              //
//======================================================================//
// address circuit
always @(posedge clk) begin
    addr_cs <= addr_ns;
end

always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(start) begin
                case (pic_no)
                    0:          addr_ns = 6'b000000;    // 0
                    1:          addr_ns = 6'b000011;    // 3
                    2:          addr_ns = 6'b000110;    // 6
                    3:          addr_ns = 6'b001001;    // 9
                    4:          addr_ns = 6'b001100;    // 12
                    5:          addr_ns = 6'b001111;    // 15
                    6:          addr_ns = 6'b010010;    // 18
                    7:          addr_ns = 6'b010101;    // 21
                    8:          addr_ns = 6'b011000;    // 24
                    9:          addr_ns = 6'b011011;    // 27
                    10:         addr_ns = 6'b011110;    // 30
                    11:         addr_ns = 6'b100001;    // 33
                    12:         addr_ns = 6'b100100;    // 36
                    13:         addr_ns = 6'b100111;    // 39
                    14:         addr_ns = 6'b101010;    // 42
                    15:         addr_ns = 6'b101101;    // 45
                    default:    addr_ns = 6'b111111;    // debug
                endcase
            end
            else addr_ns = 6'b111111;
        end

        WAIT: addr_ns = addr_cs;

        default: addr_ns = 6'b111111;

    endcase
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
assign arid_s_inf       = 4'd0;
assign arburst_s_inf    = ((mode_cs == IDLE) && (!start))? 0:2'b01;
assign arsize_s_inf     = ((mode_cs == IDLE) && (!start))? 0:3'b100;
assign arlen_s_inf      = ((mode_cs == IDLE) && (!start))? 0:8'd191;
assign arvalid_s_inf    = ((start) || (mode_cs == WAIT));
assign rready_s_inf     = (mode_cs == READ);

always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(start)   araddr_s_inf = {16'h1, addr_ns, 10'h0};
            else        araddr_s_inf = 0;
        end

        WAIT: araddr_s_inf = {16'h1, addr_cs, 10'h0};

        default: araddr_s_inf = 0;
    endcase
end
    
endmodule