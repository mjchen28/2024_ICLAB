module TMIP(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    
    image,
    template,
    image_size,
	action,
	
    // output signals
    out_valid,
    out_value
    );

input            clk, rst_n;
input            in_valid, in_valid2;

input      [7:0] image;
input      [7:0] template;
input      [1:0] image_size;
input      [2:0] action;

output reg       out_valid;
output reg       out_value;

//==================================================================
// parameter & integer
//==================================================================
// FSM
parameter IDLE  = 3'b000;
parameter IMGIN = 3'b001;
parameter MIDLE = 3'b011;
parameter SETIN = 3'b010;
parameter ACTIN = 3'b110;
parameter OUTIN = 3'b100;

// ACTIONS
parameter GMAX = 3'b000;
parameter GAVG = 3'b001;
parameter GWEI = 3'b010;
parameter POOL = 3'b011;
parameter NEGA = 3'b100;
parameter FLIP = 3'b101;
parameter FILT = 3'b110;
parameter CROS = 3'b111;

integer i, j, k;

//==================================================================
// reg & wire
//==================================================================
// SRAM signals
wire       signal_high;
reg  [7:0] addr [7:0];      // Address of 8 words. SRAM0:0,1  SRAM1:2,3  SRAM2:4,5  SRAM:6,7
reg  [7:0] din  [7:0];
reg        rw   [7:0];
wire [7:0] dout [7:0];
// Divider signals
reg  [8:0] in;
wire [7:0] q;
wire [1:0] r;
reg  [1:0] r_cs, r_ns;
// Comparator signals
reg  [7:0] compare [7:0][3:0];
wire [7:0] max     [7:0];
// Image selector signals
wire [7:0] conv_img [8:0];
// Median finder signals
wire [7:0] unsort [15:0][8:0];
reg  [7:0] median_cs [15:0];
reg  [7:0] median_ns [15:0];

// FSM control
reg [2:0]  mode_cs, mode_ns;
reg [2:0]  act_cs, act_ns;
// counters
reg [7:0]  count_cs, count_ns; 
reg [4:0]  count2_cs, count2_ns; 
reg [2:0]  count_func_cs, count_func_ns;
// Flags
reg        end_flag;        // End of action or cross
// Store data
reg [7:0] template_cs [8:0];
reg [7:0] template_ns [8:0];
reg [1:0] size_cs, size_ns;         // size of image
reg [2:0] act_list_cs [7:0];        // action list
reg [2:0] act_list_ns [7:0];
// Processing data
reg [7:0] gray_tmp_cs [3:0];
reg [7:0] gray_tmp_ns [3:0];
reg [7:0] feature_cs [15:0][15:0];
reg [7:0] feature_ns [15:0][15:0];
reg [2:0] addr_idx [7:0];
reg [7:0] addr_bud;
reg [1:0] size_now_cs, size_now_ns;
reg [19:0] mult_cs, mult_ns;
// Output data
reg [19:0] out_cs, out_ns;

wire [4:0] c2_n;

//==================================================================
// design
//==================================================================
//======================================================================//
//                                  FFs                                 //
//======================================================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_cs     <= IDLE;
        act_cs      <= 3'd0;
        size_cs     <= 2'd0;
        size_now_cs <= 2'd0;
        out_cs      <= 20'd0;
        for(i=0 ; i<9 ; i=i+1) template_cs[i] <= 8'd0;
        for(i=0 ; i<8 ; i=i+1) act_list_cs[i] <= 3'd0;
        for(i=0 ; i<4 ; i=i+1) gray_tmp_cs[i] <= 8'd0;
        for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<16 ; j=j+1) feature_cs[i][j] <= 8'd0;
    end
    else begin
        mode_cs     <= mode_ns;
        act_cs      <= act_ns;
        size_cs     <= size_ns;
        size_now_cs <= size_now_ns;
        out_cs      <= out_ns;
        for(i=0 ; i<9 ; i=i+1) template_cs[i] <= template_ns[i];
        for(i=0 ; i<8 ; i=i+1) act_list_cs[i] <= act_list_ns[i];
        for(i=0 ; i<4 ; i=i+1) gray_tmp_cs[i] <= gray_tmp_ns[i];
        for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<16 ; j=j+1) feature_cs[i][j] <= feature_ns[i][j];
    end
end

always @(posedge clk) begin
    count_cs        <= count_ns;
    count2_cs       <= count2_ns;
    count_func_cs   <= count_func_ns;
    r_cs            <= r_ns;
    mult_cs         <= mult_ns;
    for(i=0 ; i<16 ; i=i+1) median_cs[i] <= median_ns[i];
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(*) begin
    case (mode_cs)

        IDLE: begin     // Wait for the input
            if(in_valid) mode_ns = IMGIN;
            else         mode_ns = mode_cs;
        end

        IMGIN: begin    // Image input
            if(!in_valid) mode_ns = MIDLE;
            else          mode_ns = mode_cs;
        end

        MIDLE: begin    // Wait for set input
            if(in_valid2) mode_ns = SETIN;
            else          mode_ns = mode_cs;
        end

        SETIN: begin    // Input action set & fill the register
            if(!in_valid2) begin
                case (size_cs)
                        2'b00: mode_ns = ACTIN;
                        2'b01: mode_ns = ACTIN;
                        2'b10: begin
                            if(count2_cs >= 31) mode_ns = ACTIN;
                            else                mode_ns = mode_cs;
                        end
                        default: mode_ns = mode_cs;
                    endcase 
            end
            else mode_ns = mode_cs; 
        end 

        ACTIN: begin    // Perform actions
            if((act_cs == 7) && (count2_cs == 4)) mode_ns = OUTIN;
            else                                  mode_ns = mode_cs;
        end

        OUTIN: begin    // Output
            if(end_flag) begin
                if(count_func_cs == 7) mode_ns = IDLE;
                else                   mode_ns = MIDLE;
            end                   
            else                       mode_ns = mode_cs;
        end

        default: mode_ns = mode_cs;

    endcase
end

// action FSM
always @(*) begin
    case (mode_cs)

        SETIN: begin
            if(mode_ns != mode_cs) act_ns = act_list_cs[1];
            else                   act_ns = 0;
        end 

        ACTIN: begin
            if(end_flag) act_ns = act_list_cs[count_cs+1];
            else         act_ns = act_cs;
        end

        default: act_ns = act_cs;
    endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
assign signal_high = 1'b1;
assign c2_n = count2_cs - 1;

DPSRAM SRAM0(.addr(addr), .din(din), .rw(rw), .clk(clk), .signal_high(signal_high), .dout(dout));

MUX_DIV MD0(.in(in), .q(q), .r(r));

MAXPOOL_UNIT MPU0(.compare(compare[0]), .max(max[0]));
MAXPOOL_UNIT MPU1(.compare(compare[1]), .max(max[1]));
MAXPOOL_UNIT MPU2(.compare(compare[2]), .max(max[2]));
MAXPOOL_UNIT MPU3(.compare(compare[3]), .max(max[3]));
MAXPOOL_UNIT MPU4(.compare(compare[4]), .max(max[4]));
MAXPOOL_UNIT MPU5(.compare(compare[5]), .max(max[5]));
MAXPOOL_UNIT MPU6(.compare(compare[6]), .max(max[6]));
MAXPOOL_UNIT MPU7(.compare(compare[7]), .max(max[7]));

CONV_IMG_SELECTOR CIS0(.feature(feature_cs), .size_now(size_now_cs), .count(count_cs), .conv_img(conv_img));

FIND_MEDIAN FM0(.unsort(unsort[0]), .median(median_ns[0]));
FIND_MEDIAN FM1(.unsort(unsort[1]), .median(median_ns[1]));
FIND_MEDIAN FM2(.unsort(unsort[2]), .median(median_ns[2]));
FIND_MEDIAN FM3(.unsort(unsort[3]), .median(median_ns[3]));
FIND_MEDIAN FM4(.unsort(unsort[4]), .median(median_ns[4]));
FIND_MEDIAN FM5(.unsort(unsort[5]), .median(median_ns[5]));
FIND_MEDIAN FM6(.unsort(unsort[6]), .median(median_ns[6]));
FIND_MEDIAN FM7(.unsort(unsort[7]), .median(median_ns[7]));
FIND_MEDIAN FM8(.unsort(unsort[8]), .median(median_ns[8]));
FIND_MEDIAN FM9(.unsort(unsort[9]), .median(median_ns[9]));
FIND_MEDIAN FM10(.unsort(unsort[10]), .median(median_ns[10]));
FIND_MEDIAN FM11(.unsort(unsort[11]), .median(median_ns[11]));
FIND_MEDIAN FM12(.unsort(unsort[12]), .median(median_ns[12]));
FIND_MEDIAN FM13(.unsort(unsort[13]), .median(median_ns[13]));
FIND_MEDIAN FM14(.unsort(unsort[14]), .median(median_ns[14]));
FIND_MEDIAN FM15(.unsort(unsort[15]), .median(median_ns[15]));

FIND_UNSORT_UNIT FUU0(.feature(feature_cs), .size_now(size_now_cs), .count(count2_cs[3:0]), .unsort(unsort));

// count_ns, count2_ns
always @(*) begin
    case (mode_cs)

        IDLE: begin
            count_ns = 0;
            count2_ns = 0;
        end

        IMGIN: begin
            if(count_func_cs == 2) begin
                case (size_cs)
                    2'b00: begin
                        if(count_cs == 3) begin
                            count_ns = 0;
                            count2_ns = count2_cs + 1;
                        end
                        else begin
                            count_ns = count_cs + 1;
                            count2_ns = count2_cs;
                        end
                    end
                    2'b01: begin
                        if(count_cs == 7) begin
                            count_ns = 0;
                            count2_ns = count2_cs + 1;
                        end
                        else begin
                            count_ns = count_cs + 1;
                            count2_ns = count2_cs;
                        end
                    end
                    2'b10: begin
                        if(count_cs == 15) begin
                            count_ns = 0;
                            count2_ns = count2_cs + 1;
                        end
                        else begin
                            count_ns = count_cs + 1;
                            count2_ns = count2_cs;
                        end
                    end
                    default: begin
                        count_ns = count_cs;
                        count2_ns = count2_cs;
                    end
                endcase
            end
            else begin
                count_ns = count_cs;
                count2_ns = count2_cs;
            end
            
        end

        MIDLE: begin
            if(in_valid2) begin
                count_ns = 1;
                count2_ns = 0;
            end 
            else begin
                count_ns = count_cs + 1;
                count2_ns = count2_cs + 1;
            end         
        end

        SETIN: begin
            if(mode_ns != mode_cs) begin
                count_ns = 1;
                count2_ns = 0;
            end
            else begin
                count_ns = count_cs + 1;
                count2_ns = count2_cs + 1;
            end
        end

        ACTIN: begin
            if(end_flag) begin
                if(mode_ns != mode_cs) begin
                    count_ns = 1; 
                    count2_ns = 0; 
                end
                else begin
                    count_ns = count_cs + 1;        // action index
                    count2_ns = 0;                  // count in action
                end
            end 
            else begin
                count_ns = count_cs;
                count2_ns = count2_cs + 1;
            end           
        end

        OUTIN: begin
            if(end_flag)             count_ns = 0;
            else if(count2_cs == 19) count_ns = count_cs + 1;
            else                     count_ns = count_cs;

            if(count2_cs == 19) count2_ns = 0;
            else                count2_ns = count2_cs + 1;
        end

        default: begin
            count_ns = count_cs;
            count2_ns = count2_cs;
        end

    endcase
end

// count_func_ns
always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(in_valid) count_func_ns = 1;
            else         count_func_ns = 0;
        end

        IMGIN: begin
            if(count_func_cs == 2 || (!in_valid)) count_func_ns = 0;
            else                                  count_func_ns = count_func_cs + 1;
        end

        OUTIN: begin
            if(end_flag) begin
                if(count_func_cs == 7) count_func_ns = 0;
                else                   count_func_ns = count_func_cs + 1;
            end                
            else                       count_func_ns = count_func_cs;
        end

        default: count_func_ns = count_func_cs;

    endcase
end

// template_ns & size_ns & size_now_ns logic
always @(*) begin
    // default
    for(i=0 ; i<9 ; i=i+1) template_ns[i] = template_cs[i];
    size_ns = size_cs;
    size_now_ns = size_now_cs;

    case (mode_cs)

        IDLE: begin
            if(in_valid) begin
                template_ns[0] = template;
                size_ns = image_size;
            end
        end

        IMGIN: if((count2_cs == 0) && (count_cs < 3)) template_ns[count_cs*3 + count_func_cs] = template;

        MIDLE: size_now_ns = size_cs;

        ACTIN: begin
            if(act_cs == POOL) begin
                case (size_now_cs)
                    2'd1: if(count2_cs == 1) size_now_ns = 0;
                    2'd2: if(count2_cs == 7) size_now_ns = 1;
                endcase
            end
        end

    endcase
end

// act_list_ns logic
always @(*) begin
    for(i=0 ; i<8 ; i=i+1) act_list_ns[i] = act_list_cs[i];

    case (mode_cs)

        MIDLE: begin
            if(in_valid2) act_list_ns[0] = action;
            else          for(i=0 ; i<8 ; i=i+1) act_list_ns[i] = 0;
        end 

        SETIN: if(in_valid2) act_list_ns[count_cs] = action;

    endcase
end

// gray_tmp_ns logic
always @(*) begin
    for(i=0 ; i<4 ; i=i+1) gray_tmp_ns[i] = gray_tmp_cs[i];
    in = 0; 
    r_ns = 0;

    case (mode_cs)

        IDLE: begin
            if(in_valid) begin
                // Max
                gray_tmp_ns[0] = image;  
                // Average
                in = image;
                gray_tmp_ns[1] = q;
                r_ns = r;
                // Weighted 
                gray_tmp_ns[2] = (image >> 2);
            end
        end

        IMGIN: begin
            if(in_valid) begin
                case (count_func_cs)
                    3'd0: begin
                        // Max
                        gray_tmp_ns[0] = image;  
                        // Average
                        in = image;
                        gray_tmp_ns[1] = q;
                        r_ns = r;
                        // Weighted 
                        gray_tmp_ns[2] = (image >> 2);
                    end
                    3'd1: begin
                        // Max
                        if(image > gray_tmp_cs[0]) gray_tmp_ns[0] = image;
                        // Average
                        in = image + r_cs;
                        gray_tmp_ns[1] = gray_tmp_cs[1] + q;
                        r_ns = r;
                        // Weighted
                        gray_tmp_ns[2] = gray_tmp_cs[2] + (image >> 1);
                    end
                    3'd2: begin
                        // Max
                        if(image > gray_tmp_cs[0]) gray_tmp_ns[0] = image;
                        // Average
                        in = image + r_cs;
                        gray_tmp_ns[1] = gray_tmp_cs[1] + q;
                        r_ns = 0;
                        // Weighted
                        gray_tmp_ns[2] = gray_tmp_cs[2] + (image >> 2);
                    end
                endcase
            end
            
        end

        // MIDLE: 

        // SETIN: 

        // OUTIN: 

    endcase
end

// end_flag
always @(*) begin
    end_flag = 0;

    case (mode_cs)

        ACTIN: begin
            case (act_cs)
                POOL: begin
                    case (size_now_cs)
                        0: end_flag = 1;
                        1: if(count2_cs == 1)  end_flag = 1;
                        2: if(count2_cs == 7) end_flag = 1;
                    endcase
                end

                NEGA: end_flag = 1;

                FLIP: end_flag = 1;

                FILT: begin
                    case (size_now_cs)
                        0: if(count2_cs == 1)  end_flag = 1;
                        1: if(count2_cs == 4)  end_flag = 1;
                        2: if(count2_cs == 16) end_flag = 1;
                    endcase
                end

                CROS: if(count2_cs == 4) end_flag = 1;
            endcase
        end

        OUTIN: begin
            case (size_now_cs)
                0: if((count_cs == 16) && (count2_cs == 19)) end_flag = 1;
                1: if((count_cs == 64) && (count2_cs == 19)) end_flag = 1;
                2: if((count_cs == 0) && (count2_cs == 19))  end_flag = 1;
            endcase
        end

    endcase
end

//======================================================================//
//                                  SRAM                                //
//======================================================================//
// image SRAM logic
always @(*) begin
    for(i=0 ; i<4 ; i=i+1) begin addr[2*i] = 0; addr[2*i+1] = 1; end 
    for(i=0 ; i<8 ; i=i+1) din [i] = 0;
    for(i=0 ; i<8 ; i=i+1) rw  [i] = 1;
    for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<16 ; j=j+1) feature_ns[i][j] = feature_cs[i][j];
    for(i=0 ; i<8 ; i=i+1) addr_idx[i] = 0;
    addr_bud = 0;
    for(i=0 ; i<8 ; i=i+1) for(j=0 ; j<4 ; j=j+1) compare[i][j] = 0;

    case (mode_cs)

        IDLE: for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<16 ; j=j+1) feature_ns[i][j] = 0;

        IMGIN: begin        //  when(func count_cs == 0), save gray_tmp_cs into SRAM
            if(count_func_cs == 0)begin
                case (size_cs)
                    2'b00: begin            // 4x4
                        case (count2_cs)
                            5'd0: begin
                                feature_ns[0][count_cs+7] = gray_tmp_cs[0];
                                feature_ns[8][count_cs-1] = gray_tmp_cs[1];
                                feature_ns[8][count_cs+7] = gray_tmp_cs[2];
                            end
                            5'd1: begin
                                if(count_cs == 0) begin
                                    feature_ns[0][11] = gray_tmp_cs[0];
                                    feature_ns[8][3]  = gray_tmp_cs[1];
                                    feature_ns[8][11] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[1][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[9][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[9][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd2: begin
                                if(count_cs == 0) begin
                                    feature_ns[1][11] = gray_tmp_cs[0];
                                    feature_ns[9][3]  = gray_tmp_cs[1];
                                    feature_ns[9][11] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[2][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[10][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[10][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd3: begin
                                if(count_cs == 0) begin
                                    feature_ns[2][11] = gray_tmp_cs[0];
                                    feature_ns[10][3] = gray_tmp_cs[1];
                                    feature_ns[10][11] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[3][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[11][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[11][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                        endcase
                    end
                    2'b01: begin            // 8x8
                        case (count2_cs)
                            5'd0: begin
                                feature_ns[0][count_cs+7] = gray_tmp_cs[0];
                                feature_ns[8][count_cs-1] = gray_tmp_cs[1];
                                feature_ns[8][count_cs+7] = gray_tmp_cs[2];
                            end
                            5'd1: begin
                                if(count_cs == 0) begin
                                    feature_ns[0][15] = gray_tmp_cs[0];
                                    feature_ns[8][7] = gray_tmp_cs[1];
                                    feature_ns[8][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[1][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[9][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[9][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd2: begin
                                if(count_cs == 0) begin
                                    feature_ns[1][15] = gray_tmp_cs[0];
                                    feature_ns[9][7] = gray_tmp_cs[1];
                                    feature_ns[9][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[2][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[10][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[10][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd3: begin
                                if(count_cs == 0) begin
                                    feature_ns[2][15] = gray_tmp_cs[0];
                                    feature_ns[10][7] = gray_tmp_cs[1];
                                    feature_ns[10][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[3][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[11][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[11][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd4: begin
                                if(count_cs == 0) begin
                                    feature_ns[3][15] = gray_tmp_cs[0];
                                    feature_ns[11][7] = gray_tmp_cs[1];
                                    feature_ns[11][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[4][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[12][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[12][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd5: begin
                                if(count_cs == 0) begin
                                    feature_ns[4][15] = gray_tmp_cs[0];
                                    feature_ns[12][7] = gray_tmp_cs[1];
                                    feature_ns[12][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[5][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[13][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[13][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd6: begin
                                if(count_cs == 0) begin
                                    feature_ns[5][15] = gray_tmp_cs[0];
                                    feature_ns[13][7] = gray_tmp_cs[1];
                                    feature_ns[13][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[6][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[14][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[14][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                            5'd7: begin
                                if(count_cs == 0) begin
                                    feature_ns[6][15] = gray_tmp_cs[0];
                                    feature_ns[14][7] = gray_tmp_cs[1];
                                    feature_ns[14][15] = gray_tmp_cs[2];
                                end
                                else begin
                                    feature_ns[7][count_cs+7] = gray_tmp_cs[0];
                                    feature_ns[15][count_cs-1] = gray_tmp_cs[1];
                                    feature_ns[15][count_cs+7] = gray_tmp_cs[2];
                                end
                            end
                        endcase
                    end
                    2'b10: begin            // 16x16
                        case (count2_cs)
                            5'd0: begin
                                rw[0] = 0; addr[0] = (count_cs - 1);   din[0] = gray_tmp_cs[0];
                                rw[2] = 0; addr[2] = (count_cs + 63);  din[2] = gray_tmp_cs[1];
                                rw[4] = 0; addr[4] = (count_cs + 127); din[4] = gray_tmp_cs[2];
                            end
                            5'd1: begin
                               if(count_cs == 0) begin
                                    rw[0] = 0; addr[0] = 15;  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = 79;  din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = 143; din[4] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[2] = 0; addr[2] = (count_cs - 1);   din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = (count_cs + 63);  din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = (count_cs + 127); din[6] = gray_tmp_cs[2];
                                end 
                            end
                            5'd2: begin
                                if(count_cs == 0) begin
                                    rw[2] = 0; addr[2] = 15;  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = 79;  din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = 143; din[6] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[4] = 0; addr[4] = (count_cs - 1);   din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = (count_cs + 63);  din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = (count_cs + 127); din[0] = gray_tmp_cs[2];
                                end
                            end
                            5'd3: begin
                                if(count_cs == 0) begin
                                    rw[4] = 0; addr[4] = 15;  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = 79;  din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = 143; din[0] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[6] = 0; addr[6] = (count_cs - 1);   din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = (count_cs + 63);  din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = (count_cs + 127); din[2] = gray_tmp_cs[2];
                                end
                            end
                            5'd4: begin
                                if(count_cs == 0) begin
                                    rw[6] = 0; addr[6] = 15;  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = 79;  din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = 143; din[2] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[0] = 0; addr[0] = (count_cs + 15);  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = (count_cs + 79);  din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = (count_cs + 143); din[4] = gray_tmp_cs[2];
                                end
                            end
                            5'd5: begin
                                if(count_cs == 0) begin
                                    rw[0] = 0; addr[0] = 31;  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = 95;  din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = 159; din[4] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[2] = 0; addr[2] = (count_cs + 15);  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = (count_cs + 79);  din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = (count_cs + 143); din[6] = gray_tmp_cs[2];
                                end 
                            end
                            5'd6: begin
                                if(count_cs == 0) begin
                                    rw[2] = 0; addr[2] = 31;  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = 95;  din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = 159; din[6] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[4] = 0; addr[4] = (count_cs + 15);  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = (count_cs + 79);  din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = (count_cs + 143); din[0] = gray_tmp_cs[2];
                                end
                            end
                            5'd7: begin
                                if(count_cs == 0) begin
                                    rw[4] = 0; addr[4] = 31;  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = 95;  din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = 159; din[0] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[6] = 0; addr[6] = (count_cs + 15);  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = (count_cs + 79);  din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = (count_cs + 143); din[2] = gray_tmp_cs[2];
                                end
                            end
                            5'd8: begin
                                if(count_cs == 0) begin
                                    rw[6] = 0; addr[6] = 31;  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = 95;  din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = 159; din[2] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[0] = 0; addr[0] = (count_cs + 31);  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = (count_cs + 95);  din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = (count_cs + 159); din[4] = gray_tmp_cs[2];
                                end
                            end
                            5'd9: begin
                                if(count_cs == 0) begin
                                    rw[0] = 0; addr[0] = 47;  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = 111; din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = 175; din[4] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[2] = 0; addr[2] = (count_cs + 31);  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = (count_cs + 95);  din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = (count_cs + 159); din[6] = gray_tmp_cs[2];
                                end
                            end
                            5'd10: begin
                                if(count_cs == 0) begin
                                    rw[2] = 0; addr[2] = 47;  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = 111; din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = 175; din[6] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[4] = 0; addr[4] = (count_cs + 31);  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = (count_cs + 95);  din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = (count_cs + 159); din[0] = gray_tmp_cs[2];
                                end
                            end
                            5'd11: begin
                                if(count_cs == 0) begin
                                    rw[4] = 0; addr[4] = 47;  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = 111; din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = 175; din[0] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[6] = 0; addr[6] = (count_cs + 31);  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = (count_cs + 95);  din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = (count_cs + 159); din[2] = gray_tmp_cs[2];
                                end
                            end
                            5'd12: begin
                                if(count_cs == 0) begin
                                    rw[6] = 0; addr[6] = 47;  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = 111; din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = 175; din[2] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[0] = 0; addr[0] = (count_cs + 47);  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = (count_cs + 111); din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = (count_cs + 175); din[4] = gray_tmp_cs[2];
                                end
                            end
                            5'd13: begin
                                if(count_cs == 0) begin
                                    rw[0] = 0; addr[0] = 63;  din[0] = gray_tmp_cs[0];
                                    rw[2] = 0; addr[2] = 127; din[2] = gray_tmp_cs[1];
                                    rw[4] = 0; addr[4] = 191; din[4] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[2] = 0; addr[2] = (count_cs + 47);  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = (count_cs + 111); din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = (count_cs + 175); din[6] = gray_tmp_cs[2];
                                end
                            end
                            5'd14: begin
                                if(count_cs == 0) begin
                                    rw[2] = 0; addr[2] = 63;  din[2] = gray_tmp_cs[0];
                                    rw[4] = 0; addr[4] = 127; din[4] = gray_tmp_cs[1];
                                    rw[6] = 0; addr[6] = 191; din[6] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[4] = 0; addr[4] = (count_cs + 47);  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = (count_cs + 111); din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = (count_cs + 175); din[0] = gray_tmp_cs[2];
                                end
                            end
                            5'd15: begin
                                if(count_cs == 0) begin
                                    rw[4] = 0; addr[4] = 63;  din[4] = gray_tmp_cs[0];
                                    rw[6] = 0; addr[6] = 127; din[6] = gray_tmp_cs[1];
                                    rw[0] = 0; addr[0] = 191; din[0] = gray_tmp_cs[2];
                                end
                                else begin
                                    rw[6] = 0; addr[6] = (count_cs + 47);  din[6] = gray_tmp_cs[0];
                                    rw[0] = 0; addr[0] = (count_cs + 111); din[0] = gray_tmp_cs[1];
                                    rw[2] = 0; addr[2] = (count_cs + 175); din[2] = gray_tmp_cs[2];
                                end
                            end
                        endcase
                    end
                endcase
            end
        end

        MIDLE: begin
            if(in_valid2) begin
                case (action)
                    3'b000: begin
                        addr_idx[0] = 0; addr_idx[1] = 1; addr_idx[2] = 2; addr_idx[3] = 3; addr_idx[4] = 4; addr_idx[5] = 5; addr_idx[6] = 6; addr_idx[7] = 7;
                        addr_bud = 0;
                    end
                    3'b001: begin
                        addr_idx[0] = 2; addr_idx[1] = 3; addr_idx[2] = 4; addr_idx[3] = 5; addr_idx[4] = 6; addr_idx[5] = 7; addr_idx[6] = 0; addr_idx[7] = 1;
                        addr_bud = 64;
                    end
                    3'b010: begin
                        addr_idx[0] = 4; addr_idx[1] = 5; addr_idx[2] = 6; addr_idx[3] = 7; addr_idx[4] = 0; addr_idx[5] = 1; addr_idx[6] = 2; addr_idx[7] = 3;
                        addr_bud = 128;
                    end
                endcase

                addr[addr_idx[0]] = addr_bud + 0;
                addr[addr_idx[1]] = addr_bud + 1;
                addr[addr_idx[2]] = addr_bud + 0;
                addr[addr_idx[3]] = addr_bud + 1;
                addr[addr_idx[4]] = addr_bud + 0;
                addr[addr_idx[5]] = addr_bud + 1;
                addr[addr_idx[6]] = addr_bud + 0;
                addr[addr_idx[7]] = addr_bud + 1;
            end
            else begin
                case (size_cs)
                    2'b00: begin
                        feature_ns[3][11] = gray_tmp_cs[0];
                        feature_ns[11][3] = gray_tmp_cs[1];
                        feature_ns[11][11] = gray_tmp_cs[2];
                    end
                    2'b01: begin
                        feature_ns[7][15] = gray_tmp_cs[0];
                        feature_ns[15][7] = gray_tmp_cs[1];
                        feature_ns[15][15] = gray_tmp_cs[2];
                    end
                    2'b10: begin
                        rw[6] = 0; addr[6] = 63;  din[6] = gray_tmp_cs[0];
                        rw[0] = 0; addr[0] = 127; din[0] = gray_tmp_cs[1];
                        rw[2] = 0; addr[2] = 191; din[2] = gray_tmp_cs[2];
                    end
                endcase
            end
        end

        SETIN: begin
            case (act_list_cs[0])
                3'b000: begin
                    addr_idx[0] = 0; addr_idx[1] = 1; addr_idx[2] = 2; addr_idx[3] = 3; addr_idx[4] = 4; addr_idx[5] = 5; addr_idx[6] = 6; addr_idx[7] = 7;
                    addr_bud = 0;
                end
                3'b001: begin
                    addr_idx[0] = 2; addr_idx[1] = 3; addr_idx[2] = 4; addr_idx[3] = 5; addr_idx[4] = 6; addr_idx[5] = 7; addr_idx[6] = 0; addr_idx[7] = 1;
                    addr_bud = 64;
                end
                3'b010: begin
                    addr_idx[0] = 4; addr_idx[1] = 5; addr_idx[2] = 6; addr_idx[3] = 7; addr_idx[4] = 0; addr_idx[5] = 1; addr_idx[6] = 2; addr_idx[7] = 3;
                    addr_bud = 128;
                end
            endcase
            
            case (size_cs)
                0: begin
                    if(count2_cs == 0) begin
                        case (act_list_cs[0])
                            0: begin
                                feature_ns[0][0] = feature_cs[0][8];
                                feature_ns[0][1] = feature_cs[0][9];
                                feature_ns[0][2] = feature_cs[0][10];
                                feature_ns[0][3] = feature_cs[0][11];
                                feature_ns[1][0] = feature_cs[1][8];
                                feature_ns[1][1] = feature_cs[1][9];
                                feature_ns[1][2] = feature_cs[1][10];
                                feature_ns[1][3] = feature_cs[1][11];
                                feature_ns[2][0] = feature_cs[2][8];
                                feature_ns[2][1] = feature_cs[2][9];
                                feature_ns[2][2] = feature_cs[2][10];
                                feature_ns[2][3] = feature_cs[2][11];
                                feature_ns[3][0] = feature_cs[3][8];
                                feature_ns[3][1] = feature_cs[3][9];
                                feature_ns[3][2] = feature_cs[3][10];
                                feature_ns[3][3] = feature_cs[3][11];
                            end 
                            1: begin
                                feature_ns[0][0] = feature_cs[8][0];
                                feature_ns[0][1] = feature_cs[8][1];
                                feature_ns[0][2] = feature_cs[8][2];
                                feature_ns[0][3] = feature_cs[8][3];
                                feature_ns[1][0] = feature_cs[9][0];
                                feature_ns[1][1] = feature_cs[9][1];
                                feature_ns[1][2] = feature_cs[9][2];
                                feature_ns[1][3] = feature_cs[9][3];
                                feature_ns[2][0] = feature_cs[10][0];
                                feature_ns[2][1] = feature_cs[10][1];
                                feature_ns[2][2] = feature_cs[10][2];
                                feature_ns[2][3] = feature_cs[10][3];
                                feature_ns[3][0] = feature_cs[11][0];
                                feature_ns[3][1] = feature_cs[11][1];
                                feature_ns[3][2] = feature_cs[11][2];
                                feature_ns[3][3] = feature_cs[11][3];
                            end 
                            2: begin
                                feature_ns[0][0] = feature_cs[8][8];
                                feature_ns[0][1] = feature_cs[8][9];
                                feature_ns[0][2] = feature_cs[8][10];
                                feature_ns[0][3] = feature_cs[8][11];
                                feature_ns[1][0] = feature_cs[9][8];
                                feature_ns[1][1] = feature_cs[9][9];
                                feature_ns[1][2] = feature_cs[9][10];
                                feature_ns[1][3] = feature_cs[9][11];
                                feature_ns[2][0] = feature_cs[10][8];
                                feature_ns[2][1] = feature_cs[10][9];
                                feature_ns[2][2] = feature_cs[10][10];
                                feature_ns[2][3] = feature_cs[10][11];
                                feature_ns[3][0] = feature_cs[11][8];
                                feature_ns[3][1] = feature_cs[11][9];
                                feature_ns[3][2] = feature_cs[11][10];
                                feature_ns[3][3] = feature_cs[11][11];
                            end 
                        endcase
                    end
                end
                1: begin
                    if(count2_cs == 0) begin
                        case(act_list_cs[0])
                            0: begin
                                feature_ns[0][0] = feature_cs[0][8];
                                feature_ns[0][1] = feature_cs[0][9];
                                feature_ns[0][2] = feature_cs[0][10];
                                feature_ns[0][3] = feature_cs[0][11];
                                feature_ns[0][4] = feature_cs[0][12];
                                feature_ns[0][5] = feature_cs[0][13];
                                feature_ns[0][6] = feature_cs[0][14];
                                feature_ns[0][7] = feature_cs[0][15];
                                feature_ns[1][0] = feature_cs[1][8];
                                feature_ns[1][1] = feature_cs[1][9];
                                feature_ns[1][2] = feature_cs[1][10];
                                feature_ns[1][3] = feature_cs[1][11];
                                feature_ns[1][4] = feature_cs[1][12];
                                feature_ns[1][5] = feature_cs[1][13];
                                feature_ns[1][6] = feature_cs[1][14];
                                feature_ns[1][7] = feature_cs[1][15];
                                feature_ns[2][0] = feature_cs[2][8];
                                feature_ns[2][1] = feature_cs[2][9];
                                feature_ns[2][2] = feature_cs[2][10];
                                feature_ns[2][3] = feature_cs[2][11];
                                feature_ns[2][4] = feature_cs[2][12];
                                feature_ns[2][5] = feature_cs[2][13];
                                feature_ns[2][6] = feature_cs[2][14];
                                feature_ns[2][7] = feature_cs[2][15];
                                feature_ns[3][0] = feature_cs[3][8];
                                feature_ns[3][1] = feature_cs[3][9];
                                feature_ns[3][2] = feature_cs[3][10];
                                feature_ns[3][3] = feature_cs[3][11];
                                feature_ns[3][4] = feature_cs[3][12];
                                feature_ns[3][5] = feature_cs[3][13];
                                feature_ns[3][6] = feature_cs[3][14];
                                feature_ns[3][7] = feature_cs[3][15];
                                feature_ns[4][0] = feature_cs[4][8];
                                feature_ns[4][1] = feature_cs[4][9];
                                feature_ns[4][2] = feature_cs[4][10];
                                feature_ns[4][3] = feature_cs[4][11];
                                feature_ns[4][4] = feature_cs[4][12];
                                feature_ns[4][5] = feature_cs[4][13];
                                feature_ns[4][6] = feature_cs[4][14];
                                feature_ns[4][7] = feature_cs[4][15];
                                feature_ns[5][0] = feature_cs[5][8];
                                feature_ns[5][1] = feature_cs[5][9];
                                feature_ns[5][2] = feature_cs[5][10];
                                feature_ns[5][3] = feature_cs[5][11];
                                feature_ns[5][4] = feature_cs[5][12];
                                feature_ns[5][5] = feature_cs[5][13];
                                feature_ns[5][6] = feature_cs[5][14];
                                feature_ns[5][7] = feature_cs[5][15];
                                feature_ns[6][0] = feature_cs[6][8];
                                feature_ns[6][1] = feature_cs[6][9];
                                feature_ns[6][2] = feature_cs[6][10];
                                feature_ns[6][3] = feature_cs[6][11];
                                feature_ns[6][4] = feature_cs[6][12];
                                feature_ns[6][5] = feature_cs[6][13];
                                feature_ns[6][6] = feature_cs[6][14];
                                feature_ns[6][7] = feature_cs[6][15];
                                feature_ns[7][0] = feature_cs[7][8];
                                feature_ns[7][1] = feature_cs[7][9];
                                feature_ns[7][2] = feature_cs[7][10];
                                feature_ns[7][3] = feature_cs[7][11];
                                feature_ns[7][4] = feature_cs[7][12];
                                feature_ns[7][5] = feature_cs[7][13];
                                feature_ns[7][6] = feature_cs[7][14];
                                feature_ns[7][7] = feature_cs[7][15];
                            end  
                            1: begin
                                feature_ns[0][0] = feature_cs[8][0];
                                feature_ns[0][1] = feature_cs[8][1];
                                feature_ns[0][2] = feature_cs[8][2];
                                feature_ns[0][3] = feature_cs[8][3];
                                feature_ns[0][4] = feature_cs[8][4];
                                feature_ns[0][5] = feature_cs[8][5];
                                feature_ns[0][6] = feature_cs[8][6];
                                feature_ns[0][7] = feature_cs[8][7];
                                feature_ns[1][0] = feature_cs[9][0];
                                feature_ns[1][1] = feature_cs[9][1];
                                feature_ns[1][2] = feature_cs[9][2];
                                feature_ns[1][3] = feature_cs[9][3];
                                feature_ns[1][4] = feature_cs[9][4];
                                feature_ns[1][5] = feature_cs[9][5];
                                feature_ns[1][6] = feature_cs[9][6];
                                feature_ns[1][7] = feature_cs[9][7];
                                feature_ns[2][0] = feature_cs[10][0];
                                feature_ns[2][1] = feature_cs[10][1];
                                feature_ns[2][2] = feature_cs[10][2];
                                feature_ns[2][3] = feature_cs[10][3];
                                feature_ns[2][4] = feature_cs[10][4];
                                feature_ns[2][5] = feature_cs[10][5];
                                feature_ns[2][6] = feature_cs[10][6];
                                feature_ns[2][7] = feature_cs[10][7];
                                feature_ns[3][0] = feature_cs[11][0];
                                feature_ns[3][1] = feature_cs[11][1];
                                feature_ns[3][2] = feature_cs[11][2];
                                feature_ns[3][3] = feature_cs[11][3];
                                feature_ns[3][4] = feature_cs[11][4];
                                feature_ns[3][5] = feature_cs[11][5];
                                feature_ns[3][6] = feature_cs[11][6];
                                feature_ns[3][7] = feature_cs[11][7];
                                feature_ns[4][0] = feature_cs[12][0];
                                feature_ns[4][1] = feature_cs[12][1];
                                feature_ns[4][2] = feature_cs[12][2];
                                feature_ns[4][3] = feature_cs[12][3];
                                feature_ns[4][4] = feature_cs[12][4];
                                feature_ns[4][5] = feature_cs[12][5];
                                feature_ns[4][6] = feature_cs[12][6];
                                feature_ns[4][7] = feature_cs[12][7];
                                feature_ns[5][0] = feature_cs[13][0];
                                feature_ns[5][1] = feature_cs[13][1];
                                feature_ns[5][2] = feature_cs[13][2];
                                feature_ns[5][3] = feature_cs[13][3];
                                feature_ns[5][4] = feature_cs[13][4];
                                feature_ns[5][5] = feature_cs[13][5];
                                feature_ns[5][6] = feature_cs[13][6];
                                feature_ns[5][7] = feature_cs[13][7];
                                feature_ns[6][0] = feature_cs[14][0];
                                feature_ns[6][1] = feature_cs[14][1];
                                feature_ns[6][2] = feature_cs[14][2];
                                feature_ns[6][3] = feature_cs[14][3];
                                feature_ns[6][4] = feature_cs[14][4];
                                feature_ns[6][5] = feature_cs[14][5];
                                feature_ns[6][6] = feature_cs[14][6];
                                feature_ns[6][7] = feature_cs[14][7];
                                feature_ns[7][0] = feature_cs[15][0];
                                feature_ns[7][1] = feature_cs[15][1];
                                feature_ns[7][2] = feature_cs[15][2];
                                feature_ns[7][3] = feature_cs[15][3];
                                feature_ns[7][4] = feature_cs[15][4];
                                feature_ns[7][5] = feature_cs[15][5];
                                feature_ns[7][6] = feature_cs[15][6];
                                feature_ns[7][7] = feature_cs[15][7];
                            end 
                            2: begin
                                feature_ns[0][0] = feature_cs[8][8];
                                feature_ns[0][1] = feature_cs[8][9];
                                feature_ns[0][2] = feature_cs[8][10];
                                feature_ns[0][3] = feature_cs[8][11];
                                feature_ns[0][4] = feature_cs[8][12];
                                feature_ns[0][5] = feature_cs[8][13];
                                feature_ns[0][6] = feature_cs[8][14];
                                feature_ns[0][7] = feature_cs[8][15];
                                feature_ns[1][0] = feature_cs[9][8];
                                feature_ns[1][1] = feature_cs[9][9];
                                feature_ns[1][2] = feature_cs[9][10];
                                feature_ns[1][3] = feature_cs[9][11];
                                feature_ns[1][4] = feature_cs[9][12];
                                feature_ns[1][5] = feature_cs[9][13];
                                feature_ns[1][6] = feature_cs[9][14];
                                feature_ns[1][7] = feature_cs[9][15];
                                feature_ns[2][0] = feature_cs[10][8];
                                feature_ns[2][1] = feature_cs[10][9];
                                feature_ns[2][2] = feature_cs[10][10];
                                feature_ns[2][3] = feature_cs[10][11];
                                feature_ns[2][4] = feature_cs[10][12];
                                feature_ns[2][5] = feature_cs[10][13];
                                feature_ns[2][6] = feature_cs[10][14];
                                feature_ns[2][7] = feature_cs[10][15];
                                feature_ns[3][0] = feature_cs[11][8];
                                feature_ns[3][1] = feature_cs[11][9];
                                feature_ns[3][2] = feature_cs[11][10];
                                feature_ns[3][3] = feature_cs[11][11];
                                feature_ns[3][4] = feature_cs[11][12];
                                feature_ns[3][5] = feature_cs[11][13];
                                feature_ns[3][6] = feature_cs[11][14];
                                feature_ns[3][7] = feature_cs[11][15];
                                feature_ns[4][0] = feature_cs[12][8];
                                feature_ns[4][1] = feature_cs[12][9];
                                feature_ns[4][2] = feature_cs[12][10];
                                feature_ns[4][3] = feature_cs[12][11];
                                feature_ns[4][4] = feature_cs[12][12];
                                feature_ns[4][5] = feature_cs[12][13];
                                feature_ns[4][6] = feature_cs[12][14];
                                feature_ns[4][7] = feature_cs[12][15];
                                feature_ns[5][0] = feature_cs[13][8];
                                feature_ns[5][1] = feature_cs[13][9];
                                feature_ns[5][2] = feature_cs[13][10];
                                feature_ns[5][3] = feature_cs[13][11];
                                feature_ns[5][4] = feature_cs[13][12];
                                feature_ns[5][5] = feature_cs[13][13];
                                feature_ns[5][6] = feature_cs[13][14];
                                feature_ns[5][7] = feature_cs[13][15];
                                feature_ns[6][0] = feature_cs[14][8];
                                feature_ns[6][1] = feature_cs[14][9];
                                feature_ns[6][2] = feature_cs[14][10];
                                feature_ns[6][3] = feature_cs[14][11];
                                feature_ns[6][4] = feature_cs[14][12];
                                feature_ns[6][5] = feature_cs[14][13];
                                feature_ns[6][6] = feature_cs[14][14];
                                feature_ns[6][7] = feature_cs[14][15];
                                feature_ns[7][0] = feature_cs[15][8];
                                feature_ns[7][1] = feature_cs[15][9];
                                feature_ns[7][2] = feature_cs[15][10];
                                feature_ns[7][3] = feature_cs[15][11];
                                feature_ns[7][4] = feature_cs[15][12];
                                feature_ns[7][5] = feature_cs[15][13];
                                feature_ns[7][6] = feature_cs[15][14];
                                feature_ns[7][7] = feature_cs[15][15];
                            end 
                        endcase
                    end
                end
                2: begin
                    case(count2_cs)
                        0: begin 
                            addr[addr_idx[0]] = addr_bud + 2; feature_ns[0][0]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 3; feature_ns[0][1]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 2; feature_ns[1][0]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 3; feature_ns[1][1]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 2; feature_ns[2][0]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 3; feature_ns[2][1]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 2; feature_ns[3][0]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 3; feature_ns[3][1]  = dout[addr_idx[7]]; 
                        end 

                        1: begin 
                            addr[addr_idx[0]] = addr_bud + 4; feature_ns[0][2]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 5; feature_ns[0][3]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 4; feature_ns[1][2]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 5; feature_ns[1][3]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 4; feature_ns[2][2]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 5; feature_ns[2][3]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 4; feature_ns[3][2]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 5; feature_ns[3][3]  = dout[addr_idx[7]]; 
                        end 

                        2: begin 
                            addr[addr_idx[0]] = addr_bud + 6; feature_ns[0][4]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 7; feature_ns[0][5]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 6; feature_ns[1][4]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 7; feature_ns[1][5]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 6; feature_ns[2][4]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 7; feature_ns[2][5]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 6; feature_ns[3][4]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 7; feature_ns[3][5]  = dout[addr_idx[7]]; 
                        end 

                        3: begin 
                            addr[addr_idx[0]] = addr_bud + 8; feature_ns[0][6]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 9; feature_ns[0][7]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 8; feature_ns[1][6]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 9; feature_ns[1][7]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 8; feature_ns[2][6]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 9; feature_ns[2][7]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 8; feature_ns[3][6]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 9; feature_ns[3][7]  = dout[addr_idx[7]]; 
                        end 

                        4: begin 
                            addr[addr_idx[0]] = addr_bud + 10; feature_ns[0][8]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 11; feature_ns[0][9]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 10; feature_ns[1][8]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 11; feature_ns[1][9]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 10; feature_ns[2][8]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 11; feature_ns[2][9]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 10; feature_ns[3][8]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 11; feature_ns[3][9]  = dout[addr_idx[7]]; 
                        end 

                        5: begin 
                            addr[addr_idx[0]] = addr_bud + 12; feature_ns[0][10]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 13; feature_ns[0][11]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 12; feature_ns[1][10]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 13; feature_ns[1][11]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 12; feature_ns[2][10]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 13; feature_ns[2][11]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 12; feature_ns[3][10]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 13; feature_ns[3][11]  = dout[addr_idx[7]]; 
                        end 

                        6: begin 
                            addr[addr_idx[0]] = addr_bud + 14; feature_ns[0][12]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 15; feature_ns[0][13]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 14; feature_ns[1][12]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 15; feature_ns[1][13]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 14; feature_ns[2][12]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 15; feature_ns[2][13]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 14; feature_ns[3][12]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 15; feature_ns[3][13]  = dout[addr_idx[7]]; 
                        end 

                        7: begin 
                            addr[addr_idx[0]] = addr_bud + 16; feature_ns[0][14]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 17; feature_ns[0][15]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 16; feature_ns[1][14]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 17; feature_ns[1][15]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 16; feature_ns[2][14]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 17; feature_ns[2][15]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 16; feature_ns[3][14]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 17; feature_ns[3][15]  = dout[addr_idx[7]]; 
                        end 
                        8: begin 
                            addr[addr_idx[0]] = addr_bud + 18; feature_ns[4][0]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 19; feature_ns[4][1]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 18; feature_ns[5][0]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 19; feature_ns[5][1]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 18; feature_ns[6][0]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 19; feature_ns[6][1]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 18; feature_ns[7][0]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 19; feature_ns[7][1]  = dout[addr_idx[7]]; 
                        end 

                        9: begin 
                            addr[addr_idx[0]] = addr_bud + 20; feature_ns[4][2]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 21; feature_ns[4][3]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 20; feature_ns[5][2]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 21; feature_ns[5][3]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 20; feature_ns[6][2]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 21; feature_ns[6][3]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 20; feature_ns[7][2]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 21; feature_ns[7][3]  = dout[addr_idx[7]]; 
                        end 

                        10: begin 
                            addr[addr_idx[0]] = addr_bud + 22; feature_ns[4][4]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 23; feature_ns[4][5]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 22; feature_ns[5][4]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 23; feature_ns[5][5]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 22; feature_ns[6][4]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 23; feature_ns[6][5]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 22; feature_ns[7][4]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 23; feature_ns[7][5]  = dout[addr_idx[7]]; 
                        end 

                        11: begin 
                            addr[addr_idx[0]] = addr_bud + 24; feature_ns[4][6]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 25; feature_ns[4][7]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 24; feature_ns[5][6]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 25; feature_ns[5][7]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 24; feature_ns[6][6]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 25; feature_ns[6][7]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 24; feature_ns[7][6]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 25; feature_ns[7][7]  = dout[addr_idx[7]]; 
                        end 

                        12: begin 
                            addr[addr_idx[0]] = addr_bud + 26; feature_ns[4][8]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 27; feature_ns[4][9]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 26; feature_ns[5][8]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 27; feature_ns[5][9]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 26; feature_ns[6][8]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 27; feature_ns[6][9]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 26; feature_ns[7][8]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 27; feature_ns[7][9]  = dout[addr_idx[7]]; 
                        end 

                        13: begin 
                            addr[addr_idx[0]] = addr_bud + 28; feature_ns[4][10]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 29; feature_ns[4][11]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 28; feature_ns[5][10]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 29; feature_ns[5][11]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 28; feature_ns[6][10]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 29; feature_ns[6][11]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 28; feature_ns[7][10]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 29; feature_ns[7][11]  = dout[addr_idx[7]]; 
                        end 

                        14: begin 
                            addr[addr_idx[0]] = addr_bud + 30; feature_ns[4][12]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 31; feature_ns[4][13]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 30; feature_ns[5][12]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 31; feature_ns[5][13]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 30; feature_ns[6][12]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 31; feature_ns[6][13]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 30; feature_ns[7][12]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 31; feature_ns[7][13]  = dout[addr_idx[7]]; 
                        end 

                        15: begin 
                            addr[addr_idx[0]] = addr_bud + 32; feature_ns[4][14]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 33; feature_ns[4][15]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 32; feature_ns[5][14]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 33; feature_ns[5][15]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 32; feature_ns[6][14]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 33; feature_ns[6][15]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 32; feature_ns[7][14]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 33; feature_ns[7][15]  = dout[addr_idx[7]]; 
                        end 
                        16: begin 
                            addr[addr_idx[0]] = addr_bud + 34; feature_ns[8][0]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 35; feature_ns[8][1]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 34; feature_ns[9][0]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 35; feature_ns[9][1]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 34; feature_ns[10][0]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 35; feature_ns[10][1]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 34; feature_ns[11][0]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 35; feature_ns[11][1]  = dout[addr_idx[7]]; 
                        end 

                        17: begin 
                            addr[addr_idx[0]] = addr_bud + 36; feature_ns[8][2]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 37; feature_ns[8][3]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 36; feature_ns[9][2]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 37; feature_ns[9][3]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 36; feature_ns[10][2]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 37; feature_ns[10][3]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 36; feature_ns[11][2]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 37; feature_ns[11][3]  = dout[addr_idx[7]]; 
                        end 

                        18: begin 
                            addr[addr_idx[0]] = addr_bud + 38; feature_ns[8][4]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 39; feature_ns[8][5]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 38; feature_ns[9][4]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 39; feature_ns[9][5]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 38; feature_ns[10][4]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 39; feature_ns[10][5]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 38; feature_ns[11][4]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 39; feature_ns[11][5]  = dout[addr_idx[7]]; 
                        end 

                        19: begin 
                            addr[addr_idx[0]] = addr_bud + 40; feature_ns[8][6]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 41; feature_ns[8][7]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 40; feature_ns[9][6]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 41; feature_ns[9][7]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 40; feature_ns[10][6]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 41; feature_ns[10][7]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 40; feature_ns[11][6]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 41; feature_ns[11][7]  = dout[addr_idx[7]]; 
                        end 

                        20: begin 
                            addr[addr_idx[0]] = addr_bud + 42; feature_ns[8][8]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 43; feature_ns[8][9]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 42; feature_ns[9][8]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 43; feature_ns[9][9]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 42; feature_ns[10][8]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 43; feature_ns[10][9]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 42; feature_ns[11][8]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 43; feature_ns[11][9]  = dout[addr_idx[7]]; 
                        end 

                        21: begin 
                            addr[addr_idx[0]] = addr_bud + 44; feature_ns[8][10]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 45; feature_ns[8][11]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 44; feature_ns[9][10]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 45; feature_ns[9][11]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 44; feature_ns[10][10]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 45; feature_ns[10][11]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 44; feature_ns[11][10]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 45; feature_ns[11][11]  = dout[addr_idx[7]]; 
                        end 

                        22: begin 
                            addr[addr_idx[0]] = addr_bud + 46; feature_ns[8][12]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 47; feature_ns[8][13]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 46; feature_ns[9][12]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 47; feature_ns[9][13]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 46; feature_ns[10][12]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 47; feature_ns[10][13]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 46; feature_ns[11][12]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 47; feature_ns[11][13]  = dout[addr_idx[7]]; 
                        end 

                        23: begin 
                            addr[addr_idx[0]] = addr_bud + 48; feature_ns[8][14]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 49; feature_ns[8][15]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 48; feature_ns[9][14]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 49; feature_ns[9][15]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 48; feature_ns[10][14]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 49; feature_ns[10][15]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 48; feature_ns[11][14]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 49; feature_ns[11][15]  = dout[addr_idx[7]]; 
                        end 
                        24: begin 
                            addr[addr_idx[0]] = addr_bud + 50; feature_ns[12][0]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 51; feature_ns[12][1]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 50; feature_ns[13][0]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 51; feature_ns[13][1]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 50; feature_ns[14][0]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 51; feature_ns[14][1]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 50; feature_ns[15][0]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 51; feature_ns[15][1]  = dout[addr_idx[7]]; 
                        end 

                        25: begin 
                            addr[addr_idx[0]] = addr_bud + 52; feature_ns[12][2]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 53; feature_ns[12][3]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 52; feature_ns[13][2]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 53; feature_ns[13][3]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 52; feature_ns[14][2]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 53; feature_ns[14][3]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 52; feature_ns[15][2]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 53; feature_ns[15][3]  = dout[addr_idx[7]]; 
                        end 

                        26: begin 
                            addr[addr_idx[0]] = addr_bud + 54; feature_ns[12][4]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 55; feature_ns[12][5]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 54; feature_ns[13][4]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 55; feature_ns[13][5]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 54; feature_ns[14][4]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 55; feature_ns[14][5]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 54; feature_ns[15][4]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 55; feature_ns[15][5]  = dout[addr_idx[7]]; 
                        end 

                        27: begin 
                            addr[addr_idx[0]] = addr_bud + 56; feature_ns[12][6]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 57; feature_ns[12][7]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 56; feature_ns[13][6]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 57; feature_ns[13][7]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 56; feature_ns[14][6]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 57; feature_ns[14][7]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 56; feature_ns[15][6]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 57; feature_ns[15][7]  = dout[addr_idx[7]]; 
                        end 

                        28: begin 
                            addr[addr_idx[0]] = addr_bud + 58; feature_ns[12][8]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 59; feature_ns[12][9]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 58; feature_ns[13][8]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 59; feature_ns[13][9]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 58; feature_ns[14][8]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 59; feature_ns[14][9]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 58; feature_ns[15][8]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 59; feature_ns[15][9]  = dout[addr_idx[7]]; 
                        end 

                        29: begin 
                            addr[addr_idx[0]] = addr_bud + 60; feature_ns[12][10]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 61; feature_ns[12][11]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 60; feature_ns[13][10]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 61; feature_ns[13][11]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 60; feature_ns[14][10]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 61; feature_ns[14][11]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 60; feature_ns[15][10]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 61; feature_ns[15][11]  = dout[addr_idx[7]]; 
                        end 

                        30: begin 
                            addr[addr_idx[0]] = addr_bud + 62; feature_ns[12][12]  = dout[addr_idx[0]]; 
                            addr[addr_idx[1]] = addr_bud + 63; feature_ns[12][13]  = dout[addr_idx[1]]; 
                            addr[addr_idx[2]] = addr_bud + 62; feature_ns[13][12]  = dout[addr_idx[2]]; 
                            addr[addr_idx[3]] = addr_bud + 63; feature_ns[13][13]  = dout[addr_idx[3]]; 
                            addr[addr_idx[4]] = addr_bud + 62; feature_ns[14][12]  = dout[addr_idx[4]]; 
                            addr[addr_idx[5]] = addr_bud + 63; feature_ns[14][13]  = dout[addr_idx[5]]; 
                            addr[addr_idx[6]] = addr_bud + 62; feature_ns[15][12]  = dout[addr_idx[6]]; 
                            addr[addr_idx[7]] = addr_bud + 63; feature_ns[15][13]  = dout[addr_idx[7]]; 
                        end
                        
                        31: begin
                            feature_ns[12][((count2_cs-24) << 1)]   = dout[addr_idx[0]];
                            feature_ns[12][((count2_cs-24) << 1)+1] = dout[addr_idx[1]];
                            feature_ns[13][((count2_cs-24) << 1)]   = dout[addr_idx[2]];
                            feature_ns[13][((count2_cs-24) << 1)+1] = dout[addr_idx[3]];
                            feature_ns[14][((count2_cs-24) << 1)]   = dout[addr_idx[4]];
                            feature_ns[14][((count2_cs-24) << 1)+1] = dout[addr_idx[5]];
                            feature_ns[15][((count2_cs-24) << 1)]   = dout[addr_idx[6]];
                            feature_ns[15][((count2_cs-24) << 1)+1] = dout[addr_idx[7]];
                        end
                    endcase
                end
            endcase
        end

        ACTIN: begin
            case (act_cs)

                POOL: begin
                    case (size_now_cs)
                        2'b01: begin        // 8x8
                            case (count2_cs[1:0])
                                0: begin
                                    compare[0][0] = feature_cs[0][0];
                                    compare[0][1] = feature_cs[0][1];
                                    compare[0][2] = feature_cs[1][0];
                                    compare[0][3] = feature_cs[1][1];
                                    feature_ns[0][0] = max[0];

                                    compare[1][0] = feature_cs[0][2];
                                    compare[1][1] = feature_cs[0][3];
                                    compare[1][2] = feature_cs[1][2];
                                    compare[1][3] = feature_cs[1][3];
                                    feature_ns[0][1] = max[1];

                                    compare[2][0] = feature_cs[0][4];
                                    compare[2][1] = feature_cs[0][5];
                                    compare[2][2] = feature_cs[1][4];
                                    compare[2][3] = feature_cs[1][5];
                                    feature_ns[0][2] = max[2];

                                    compare[3][0] = feature_cs[0][6];
                                    compare[3][1] = feature_cs[0][7];
                                    compare[3][2] = feature_cs[1][6];
                                    compare[3][3] = feature_cs[1][7];
                                    feature_ns[0][3] = max[3];

                                    compare[4][0] = feature_cs[2][0];
                                    compare[4][1] = feature_cs[2][1];
                                    compare[4][2] = feature_cs[3][0];
                                    compare[4][3] = feature_cs[3][1];
                                    feature_ns[1][0] = max[4];

                                    compare[5][0] = feature_cs[2][2];
                                    compare[5][1] = feature_cs[2][3];
                                    compare[5][2] = feature_cs[3][2];
                                    compare[5][3] = feature_cs[3][3];
                                    feature_ns[1][1] = max[5];

                                    compare[6][0] = feature_cs[2][4];
                                    compare[6][1] = feature_cs[2][5];
                                    compare[6][2] = feature_cs[3][4];
                                    compare[6][3] = feature_cs[3][5];
                                    feature_ns[1][2] = max[6];

                                    compare[7][0] = feature_cs[2][6];
                                    compare[7][1] = feature_cs[2][7];
                                    compare[7][2] = feature_cs[3][6];
                                    compare[7][3] = feature_cs[3][7];
                                    feature_ns[1][3] = max[7];
                                end
                                1: begin
                                    compare[0][0] = feature_cs[4][0];
                                    compare[0][1] = feature_cs[4][1];
                                    compare[0][2] = feature_cs[5][0];
                                    compare[0][3] = feature_cs[5][1];
                                    feature_ns[2][0] = max[0];

                                    compare[1][0] = feature_cs[4][2];
                                    compare[1][1] = feature_cs[4][3];
                                    compare[1][2] = feature_cs[5][2];
                                    compare[1][3] = feature_cs[5][3];
                                    feature_ns[2][1] = max[1];

                                    compare[2][0] = feature_cs[4][4];
                                    compare[2][1] = feature_cs[4][5];
                                    compare[2][2] = feature_cs[5][4];
                                    compare[2][3] = feature_cs[5][5];
                                    feature_ns[2][2] = max[2];

                                    compare[3][0] = feature_cs[4][6];
                                    compare[3][1] = feature_cs[4][7];
                                    compare[3][2] = feature_cs[5][6];
                                    compare[3][3] = feature_cs[5][7];
                                    feature_ns[2][3] = max[3];

                                    compare[4][0] = feature_cs[6][0];
                                    compare[4][1] = feature_cs[6][1];
                                    compare[4][2] = feature_cs[7][0];
                                    compare[4][3] = feature_cs[7][1];
                                    feature_ns[3][0] = max[4];

                                    compare[5][0] = feature_cs[6][2];
                                    compare[5][1] = feature_cs[6][3];
                                    compare[5][2] = feature_cs[7][2];
                                    compare[5][3] = feature_cs[7][3];
                                    feature_ns[3][1] = max[5];

                                    compare[6][0] = feature_cs[6][4];
                                    compare[6][1] = feature_cs[6][5];
                                    compare[6][2] = feature_cs[7][4];
                                    compare[6][3] = feature_cs[7][5];
                                    feature_ns[3][2] = max[6];

                                    compare[7][0] = feature_cs[6][6];
                                    compare[7][1] = feature_cs[6][7];
                                    compare[7][2] = feature_cs[7][6];
                                    compare[7][3] = feature_cs[7][7];
                                    feature_ns[3][3] = max[7];
                                end
                            endcase
                        end
                        2'b10: begin
                            case (count2_cs[2:0])
                                0: begin
                                    compare[0][0] = feature_cs[0][0];
                                    compare[0][1] = feature_cs[0][1];
                                    compare[0][2] = feature_cs[1][0];
                                    compare[0][3] = feature_cs[1][1];
                                    feature_ns[0][0] = max[0];

                                    compare[1][0] = feature_cs[0][2];
                                    compare[1][1] = feature_cs[0][3];
                                    compare[1][2] = feature_cs[1][2];
                                    compare[1][3] = feature_cs[1][3];
                                    feature_ns[0][1] = max[1];

                                    compare[2][0] = feature_cs[0][4];
                                    compare[2][1] = feature_cs[0][5];
                                    compare[2][2] = feature_cs[1][4];
                                    compare[2][3] = feature_cs[1][5];
                                    feature_ns[0][2] = max[2];

                                    compare[3][0] = feature_cs[0][6];
                                    compare[3][1] = feature_cs[0][7];
                                    compare[3][2] = feature_cs[1][6];
                                    compare[3][3] = feature_cs[1][7];
                                    feature_ns[0][3] = max[3];

                                    compare[4][0] = feature_cs[0][8];
                                    compare[4][1] = feature_cs[0][9];
                                    compare[4][2] = feature_cs[1][8];
                                    compare[4][3] = feature_cs[1][9];
                                    feature_ns[0][4] = max[4];

                                    compare[5][0] = feature_cs[0][10];
                                    compare[5][1] = feature_cs[0][11];
                                    compare[5][2] = feature_cs[1][10];
                                    compare[5][3] = feature_cs[1][11];
                                    feature_ns[0][5] = max[5];

                                    compare[6][0] = feature_cs[0][12];
                                    compare[6][1] = feature_cs[0][13];
                                    compare[6][2] = feature_cs[1][12];
                                    compare[6][3] = feature_cs[1][13];
                                    feature_ns[0][6] = max[6];

                                    compare[7][0] = feature_cs[0][14];
                                    compare[7][1] = feature_cs[0][15];
                                    compare[7][2] = feature_cs[1][14];
                                    compare[7][3] = feature_cs[1][15];
                                    feature_ns[0][7] = max[7];
                                end
                                1: begin
                                    compare[0][0] = feature_cs[2][0];
                                    compare[0][1] = feature_cs[2][1];
                                    compare[0][2] = feature_cs[3][0];
                                    compare[0][3] = feature_cs[3][1];
                                    feature_ns[1][0] = max[0];

                                    compare[1][0] = feature_cs[2][2];
                                    compare[1][1] = feature_cs[2][3];
                                    compare[1][2] = feature_cs[3][2];
                                    compare[1][3] = feature_cs[3][3];
                                    feature_ns[1][1] = max[1];

                                    compare[2][0] = feature_cs[2][4];
                                    compare[2][1] = feature_cs[2][5];
                                    compare[2][2] = feature_cs[3][4];
                                    compare[2][3] = feature_cs[3][5];
                                    feature_ns[1][2] = max[2];

                                    compare[3][0] = feature_cs[2][6];
                                    compare[3][1] = feature_cs[2][7];
                                    compare[3][2] = feature_cs[3][6];
                                    compare[3][3] = feature_cs[3][7];
                                    feature_ns[1][3] = max[3];

                                    compare[4][0] = feature_cs[2][8];
                                    compare[4][1] = feature_cs[2][9];
                                    compare[4][2] = feature_cs[3][8];
                                    compare[4][3] = feature_cs[3][9];
                                    feature_ns[1][4] = max[4];

                                    compare[5][0] = feature_cs[2][10];
                                    compare[5][1] = feature_cs[2][11];
                                    compare[5][2] = feature_cs[3][10];
                                    compare[5][3] = feature_cs[3][11];
                                    feature_ns[1][5] = max[5];

                                    compare[6][0] = feature_cs[2][12];
                                    compare[6][1] = feature_cs[2][13];
                                    compare[6][2] = feature_cs[3][12];
                                    compare[6][3] = feature_cs[3][13];
                                    feature_ns[1][6] = max[6];

                                    compare[7][0] = feature_cs[2][14];
                                    compare[7][1] = feature_cs[2][15];
                                    compare[7][2] = feature_cs[3][14];
                                    compare[7][3] = feature_cs[3][15];
                                    feature_ns[1][7] = max[7];
                                end
                                2: begin
                                    compare[0][0] = feature_cs[4][0];
                                    compare[0][1] = feature_cs[4][1];
                                    compare[0][2] = feature_cs[5][0];
                                    compare[0][3] = feature_cs[5][1];
                                    feature_ns[2][0] = max[0];

                                    compare[1][0] = feature_cs[4][2];
                                    compare[1][1] = feature_cs[4][3];
                                    compare[1][2] = feature_cs[5][2];
                                    compare[1][3] = feature_cs[5][3];
                                    feature_ns[2][1] = max[1];

                                    compare[2][0] = feature_cs[4][4];
                                    compare[2][1] = feature_cs[4][5];
                                    compare[2][2] = feature_cs[5][4];
                                    compare[2][3] = feature_cs[5][5];
                                    feature_ns[2][2] = max[2];

                                    compare[3][0] = feature_cs[4][6];
                                    compare[3][1] = feature_cs[4][7];
                                    compare[3][2] = feature_cs[5][6];
                                    compare[3][3] = feature_cs[5][7];
                                    feature_ns[2][3] = max[3];

                                    compare[4][0] = feature_cs[4][8];
                                    compare[4][1] = feature_cs[4][9];
                                    compare[4][2] = feature_cs[5][8];
                                    compare[4][3] = feature_cs[5][9];
                                    feature_ns[2][4] = max[4];

                                    compare[5][0] = feature_cs[4][10];
                                    compare[5][1] = feature_cs[4][11];
                                    compare[5][2] = feature_cs[5][10];
                                    compare[5][3] = feature_cs[5][11];
                                    feature_ns[2][5] = max[5];

                                    compare[6][0] = feature_cs[4][12];
                                    compare[6][1] = feature_cs[4][13];
                                    compare[6][2] = feature_cs[5][12];
                                    compare[6][3] = feature_cs[5][13];
                                    feature_ns[2][6] = max[6];

                                    compare[7][0] = feature_cs[4][14];
                                    compare[7][1] = feature_cs[4][15];
                                    compare[7][2] = feature_cs[5][14];
                                    compare[7][3] = feature_cs[5][15];
                                    feature_ns[2][7] = max[7];
                                end
                                3: begin
                                    compare[0][0] = feature_cs[6][0];
                                    compare[0][1] = feature_cs[6][1];
                                    compare[0][2] = feature_cs[7][0];
                                    compare[0][3] = feature_cs[7][1];
                                    feature_ns[3][0] = max[0];

                                    compare[1][0] = feature_cs[6][2];
                                    compare[1][1] = feature_cs[6][3];
                                    compare[1][2] = feature_cs[7][2];
                                    compare[1][3] = feature_cs[7][3];
                                    feature_ns[3][1] = max[1];

                                    compare[2][0] = feature_cs[6][4];
                                    compare[2][1] = feature_cs[6][5];
                                    compare[2][2] = feature_cs[7][4];
                                    compare[2][3] = feature_cs[7][5];
                                    feature_ns[3][2] = max[2];

                                    compare[3][0] = feature_cs[6][6];
                                    compare[3][1] = feature_cs[6][7];
                                    compare[3][2] = feature_cs[7][6];
                                    compare[3][3] = feature_cs[7][7];
                                    feature_ns[3][3] = max[3];

                                    compare[4][0] = feature_cs[6][8];
                                    compare[4][1] = feature_cs[6][9];
                                    compare[4][2] = feature_cs[7][8];
                                    compare[4][3] = feature_cs[7][9];
                                    feature_ns[3][4] = max[4];

                                    compare[5][0] = feature_cs[6][10];
                                    compare[5][1] = feature_cs[6][11];
                                    compare[5][2] = feature_cs[7][10];
                                    compare[5][3] = feature_cs[7][11];
                                    feature_ns[3][5] = max[5];

                                    compare[6][0] = feature_cs[6][12];
                                    compare[6][1] = feature_cs[6][13];
                                    compare[6][2] = feature_cs[7][12];
                                    compare[6][3] = feature_cs[7][13];
                                    feature_ns[3][6] = max[6];

                                    compare[7][0] = feature_cs[6][14];
                                    compare[7][1] = feature_cs[6][15];
                                    compare[7][2] = feature_cs[7][14];
                                    compare[7][3] = feature_cs[7][15];
                                    feature_ns[3][7] = max[7];
                                end
                                4: begin
                                    compare[0][0] = feature_cs[8][0];
                                    compare[0][1] = feature_cs[8][1];
                                    compare[0][2] = feature_cs[9][0];
                                    compare[0][3] = feature_cs[9][1];
                                    feature_ns[4][0] = max[0];

                                    compare[1][0] = feature_cs[8][2];
                                    compare[1][1] = feature_cs[8][3];
                                    compare[1][2] = feature_cs[9][2];
                                    compare[1][3] = feature_cs[9][3];
                                    feature_ns[4][1] = max[1];

                                    compare[2][0] = feature_cs[8][4];
                                    compare[2][1] = feature_cs[8][5];
                                    compare[2][2] = feature_cs[9][4];
                                    compare[2][3] = feature_cs[9][5];
                                    feature_ns[4][2] = max[2];

                                    compare[3][0] = feature_cs[8][6];
                                    compare[3][1] = feature_cs[8][7];
                                    compare[3][2] = feature_cs[9][6];
                                    compare[3][3] = feature_cs[9][7];
                                    feature_ns[4][3] = max[3];

                                    compare[4][0] = feature_cs[8][8];
                                    compare[4][1] = feature_cs[8][9];
                                    compare[4][2] = feature_cs[9][8];
                                    compare[4][3] = feature_cs[9][9];
                                    feature_ns[4][4] = max[4];

                                    compare[5][0] = feature_cs[8][10];
                                    compare[5][1] = feature_cs[8][11];
                                    compare[5][2] = feature_cs[9][10];
                                    compare[5][3] = feature_cs[9][11];
                                    feature_ns[4][5] = max[5];

                                    compare[6][0] = feature_cs[8][12];
                                    compare[6][1] = feature_cs[8][13];
                                    compare[6][2] = feature_cs[9][12];
                                    compare[6][3] = feature_cs[9][13];
                                    feature_ns[4][6] = max[6];

                                    compare[7][0] = feature_cs[8][14];
                                    compare[7][1] = feature_cs[8][15];
                                    compare[7][2] = feature_cs[9][14];
                                    compare[7][3] = feature_cs[9][15];
                                    feature_ns[4][7] = max[7];
                                end
                                5: begin
                                    compare[0][0] = feature_cs[10][0];
                                    compare[0][1] = feature_cs[10][1];
                                    compare[0][2] = feature_cs[11][0];
                                    compare[0][3] = feature_cs[11][1];
                                    feature_ns[5][0] = max[0];

                                    compare[1][0] = feature_cs[10][2];
                                    compare[1][1] = feature_cs[10][3];
                                    compare[1][2] = feature_cs[11][2];
                                    compare[1][3] = feature_cs[11][3];
                                    feature_ns[5][1] = max[1];

                                    compare[2][0] = feature_cs[10][4];
                                    compare[2][1] = feature_cs[10][5];
                                    compare[2][2] = feature_cs[11][4];
                                    compare[2][3] = feature_cs[11][5];
                                    feature_ns[5][2] = max[2];

                                    compare[3][0] = feature_cs[10][6];
                                    compare[3][1] = feature_cs[10][7];
                                    compare[3][2] = feature_cs[11][6];
                                    compare[3][3] = feature_cs[11][7];
                                    feature_ns[5][3] = max[3];

                                    compare[4][0] = feature_cs[10][8];
                                    compare[4][1] = feature_cs[10][9];
                                    compare[4][2] = feature_cs[11][8];
                                    compare[4][3] = feature_cs[11][9];
                                    feature_ns[5][4] = max[4];

                                    compare[5][0] = feature_cs[10][10];
                                    compare[5][1] = feature_cs[10][11];
                                    compare[5][2] = feature_cs[11][10];
                                    compare[5][3] = feature_cs[11][11];
                                    feature_ns[5][5] = max[5];

                                    compare[6][0] = feature_cs[10][12];
                                    compare[6][1] = feature_cs[10][13];
                                    compare[6][2] = feature_cs[11][12];
                                    compare[6][3] = feature_cs[11][13];
                                    feature_ns[5][6] = max[6];

                                    compare[7][0] = feature_cs[10][14];
                                    compare[7][1] = feature_cs[10][15];
                                    compare[7][2] = feature_cs[11][14];
                                    compare[7][3] = feature_cs[11][15];
                                    feature_ns[5][7] = max[7];
                                end
                                6: begin
                                    compare[0][0] = feature_cs[12][0];
                                    compare[0][1] = feature_cs[12][1];
                                    compare[0][2] = feature_cs[13][0];
                                    compare[0][3] = feature_cs[13][1];
                                    feature_ns[6][0] = max[0];

                                    compare[1][0] = feature_cs[12][2];
                                    compare[1][1] = feature_cs[12][3];
                                    compare[1][2] = feature_cs[13][2];
                                    compare[1][3] = feature_cs[13][3];
                                    feature_ns[6][1] = max[1];

                                    compare[2][0] = feature_cs[12][4];
                                    compare[2][1] = feature_cs[12][5];
                                    compare[2][2] = feature_cs[13][4];
                                    compare[2][3] = feature_cs[13][5];
                                    feature_ns[6][2] = max[2];

                                    compare[3][0] = feature_cs[12][6];
                                    compare[3][1] = feature_cs[12][7];
                                    compare[3][2] = feature_cs[13][6];
                                    compare[3][3] = feature_cs[13][7];
                                    feature_ns[6][3] = max[3];

                                    compare[4][0] = feature_cs[12][8];
                                    compare[4][1] = feature_cs[12][9];
                                    compare[4][2] = feature_cs[13][8];
                                    compare[4][3] = feature_cs[13][9];
                                    feature_ns[6][4] = max[4];

                                    compare[5][0] = feature_cs[12][10];
                                    compare[5][1] = feature_cs[12][11];
                                    compare[5][2] = feature_cs[13][10];
                                    compare[5][3] = feature_cs[13][11];
                                    feature_ns[6][5] = max[5];

                                    compare[6][0] = feature_cs[12][12];
                                    compare[6][1] = feature_cs[12][13];
                                    compare[6][2] = feature_cs[13][12];
                                    compare[6][3] = feature_cs[13][13];
                                    feature_ns[6][6] = max[6];

                                    compare[7][0] = feature_cs[12][14];
                                    compare[7][1] = feature_cs[12][15];
                                    compare[7][2] = feature_cs[13][14];
                                    compare[7][3] = feature_cs[13][15];
                                    feature_ns[6][7] = max[7];
                                end
                                7: begin
                                    compare[0][0] = feature_cs[14][0];
                                    compare[0][1] = feature_cs[14][1];
                                    compare[0][2] = feature_cs[15][0];
                                    compare[0][3] = feature_cs[15][1];
                                    feature_ns[7][0] = max[0];

                                    compare[1][0] = feature_cs[14][2];
                                    compare[1][1] = feature_cs[14][3];
                                    compare[1][2] = feature_cs[15][2];
                                    compare[1][3] = feature_cs[15][3];
                                    feature_ns[7][1] = max[1];

                                    compare[2][0] = feature_cs[14][4];
                                    compare[2][1] = feature_cs[14][5];
                                    compare[2][2] = feature_cs[15][4];
                                    compare[2][3] = feature_cs[15][5];
                                    feature_ns[7][2] = max[2];

                                    compare[3][0] = feature_cs[14][6];
                                    compare[3][1] = feature_cs[14][7];
                                    compare[3][2] = feature_cs[15][6];
                                    compare[3][3] = feature_cs[15][7];
                                    feature_ns[7][3] = max[3];

                                    compare[4][0] = feature_cs[14][8];
                                    compare[4][1] = feature_cs[14][9];
                                    compare[4][2] = feature_cs[15][8];
                                    compare[4][3] = feature_cs[15][9];
                                    feature_ns[7][4] = max[4];

                                    compare[5][0] = feature_cs[14][10];
                                    compare[5][1] = feature_cs[14][11];
                                    compare[5][2] = feature_cs[15][10];
                                    compare[5][3] = feature_cs[15][11];
                                    feature_ns[7][5] = max[5];

                                    compare[6][0] = feature_cs[14][12];
                                    compare[6][1] = feature_cs[14][13];
                                    compare[6][2] = feature_cs[15][12];
                                    compare[6][3] = feature_cs[15][13];
                                    feature_ns[7][6] = max[6];

                                    compare[7][0] = feature_cs[14][14];
                                    compare[7][1] = feature_cs[14][15];
                                    compare[7][2] = feature_cs[15][14];
                                    compare[7][3] = feature_cs[15][15];
                                    feature_ns[7][7] = max[7];
                                end
                            endcase
                        end
                    endcase
                end

                NEGA: begin
                    case (size_now_cs)
                        0: for(i=0 ; i<4 ; i=i+1)  for(j=0 ; j<4 ; j=j+1)  feature_ns[i][j] = 255 - feature_ns[i][j];
                        1: for(i=0 ; i<8 ; i=i+1)  for(j=0 ; j<8 ; j=j+1)  feature_ns[i][j] = 255 - feature_ns[i][j];
                        2: for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<16 ; j=j+1) feature_ns[i][j] = 255 - feature_ns[i][j];
                    endcase
                end

                FLIP: begin
                    case (size_now_cs)
                        0: begin
                            feature_ns[0][0] = feature_cs[0][3];
                            feature_ns[0][1] = feature_cs[0][2];
                            feature_ns[0][2] = feature_cs[0][1];
                            feature_ns[0][3] = feature_cs[0][0];
                            feature_ns[1][0] = feature_cs[1][3];
                            feature_ns[1][1] = feature_cs[1][2];
                            feature_ns[1][2] = feature_cs[1][1];
                            feature_ns[1][3] = feature_cs[1][0];
                            feature_ns[2][0] = feature_cs[2][3];
                            feature_ns[2][1] = feature_cs[2][2];
                            feature_ns[2][2] = feature_cs[2][1];
                            feature_ns[2][3] = feature_cs[2][0];
                            feature_ns[3][0] = feature_cs[3][3];
                            feature_ns[3][1] = feature_cs[3][2];
                            feature_ns[3][2] = feature_cs[3][1];
                            feature_ns[3][3] = feature_cs[3][0];
                        end 
                        1: begin
                            feature_ns[0][0] = feature_cs[0][7];
                            feature_ns[0][1] = feature_cs[0][6];
                            feature_ns[0][2] = feature_cs[0][5];
                            feature_ns[0][3] = feature_cs[0][4];
                            feature_ns[0][4] = feature_cs[0][3];
                            feature_ns[0][5] = feature_cs[0][2];
                            feature_ns[0][6] = feature_cs[0][1];
                            feature_ns[0][7] = feature_cs[0][0];
                            feature_ns[1][0] = feature_cs[1][7];
                            feature_ns[1][1] = feature_cs[1][6];
                            feature_ns[1][2] = feature_cs[1][5];
                            feature_ns[1][3] = feature_cs[1][4];
                            feature_ns[1][4] = feature_cs[1][3];
                            feature_ns[1][5] = feature_cs[1][2];
                            feature_ns[1][6] = feature_cs[1][1];
                            feature_ns[1][7] = feature_cs[1][0];
                            feature_ns[2][0] = feature_cs[2][7];
                            feature_ns[2][1] = feature_cs[2][6];
                            feature_ns[2][2] = feature_cs[2][5];
                            feature_ns[2][3] = feature_cs[2][4];
                            feature_ns[2][4] = feature_cs[2][3];
                            feature_ns[2][5] = feature_cs[2][2];
                            feature_ns[2][6] = feature_cs[2][1];
                            feature_ns[2][7] = feature_cs[2][0];
                            feature_ns[3][0] = feature_cs[3][7];
                            feature_ns[3][1] = feature_cs[3][6];
                            feature_ns[3][2] = feature_cs[3][5];
                            feature_ns[3][3] = feature_cs[3][4];
                            feature_ns[3][4] = feature_cs[3][3];
                            feature_ns[3][5] = feature_cs[3][2];
                            feature_ns[3][6] = feature_cs[3][1];
                            feature_ns[3][7] = feature_cs[3][0];
                            feature_ns[4][0] = feature_cs[4][7];
                            feature_ns[4][1] = feature_cs[4][6];
                            feature_ns[4][2] = feature_cs[4][5];
                            feature_ns[4][3] = feature_cs[4][4];
                            feature_ns[4][4] = feature_cs[4][3];
                            feature_ns[4][5] = feature_cs[4][2];
                            feature_ns[4][6] = feature_cs[4][1];
                            feature_ns[4][7] = feature_cs[4][0];
                            feature_ns[5][0] = feature_cs[5][7];
                            feature_ns[5][1] = feature_cs[5][6];
                            feature_ns[5][2] = feature_cs[5][5];
                            feature_ns[5][3] = feature_cs[5][4];
                            feature_ns[5][4] = feature_cs[5][3];
                            feature_ns[5][5] = feature_cs[5][2];
                            feature_ns[5][6] = feature_cs[5][1];
                            feature_ns[5][7] = feature_cs[5][0];
                            feature_ns[6][0] = feature_cs[6][7];
                            feature_ns[6][1] = feature_cs[6][6];
                            feature_ns[6][2] = feature_cs[6][5];
                            feature_ns[6][3] = feature_cs[6][4];
                            feature_ns[6][4] = feature_cs[6][3];
                            feature_ns[6][5] = feature_cs[6][2];
                            feature_ns[6][6] = feature_cs[6][1];
                            feature_ns[6][7] = feature_cs[6][0];
                            feature_ns[7][0] = feature_cs[7][7];
                            feature_ns[7][1] = feature_cs[7][6];
                            feature_ns[7][2] = feature_cs[7][5];
                            feature_ns[7][3] = feature_cs[7][4];
                            feature_ns[7][4] = feature_cs[7][3];
                            feature_ns[7][5] = feature_cs[7][2];
                            feature_ns[7][6] = feature_cs[7][1];
                            feature_ns[7][7] = feature_cs[7][0];
                        end 
                        2: begin
                            feature_ns[0][0] = feature_cs[0][15];
                            feature_ns[0][1] = feature_cs[0][14];
                            feature_ns[0][2] = feature_cs[0][13];
                            feature_ns[0][3] = feature_cs[0][12];
                            feature_ns[0][4] = feature_cs[0][11];
                            feature_ns[0][5] = feature_cs[0][10];
                            feature_ns[0][6] = feature_cs[0][9];
                            feature_ns[0][7] = feature_cs[0][8];
                            feature_ns[0][8] = feature_cs[0][7];
                            feature_ns[0][9] = feature_cs[0][6];
                            feature_ns[0][10] = feature_cs[0][5];
                            feature_ns[0][11] = feature_cs[0][4];
                            feature_ns[0][12] = feature_cs[0][3];
                            feature_ns[0][13] = feature_cs[0][2];
                            feature_ns[0][14] = feature_cs[0][1];
                            feature_ns[0][15] = feature_cs[0][0];
                            feature_ns[1][0] = feature_cs[1][15];
                            feature_ns[1][1] = feature_cs[1][14];
                            feature_ns[1][2] = feature_cs[1][13];
                            feature_ns[1][3] = feature_cs[1][12];
                            feature_ns[1][4] = feature_cs[1][11];
                            feature_ns[1][5] = feature_cs[1][10];
                            feature_ns[1][6] = feature_cs[1][9];
                            feature_ns[1][7] = feature_cs[1][8];
                            feature_ns[1][8] = feature_cs[1][7];
                            feature_ns[1][9] = feature_cs[1][6];
                            feature_ns[1][10] = feature_cs[1][5];
                            feature_ns[1][11] = feature_cs[1][4];
                            feature_ns[1][12] = feature_cs[1][3];
                            feature_ns[1][13] = feature_cs[1][2];
                            feature_ns[1][14] = feature_cs[1][1];
                            feature_ns[1][15] = feature_cs[1][0];
                            feature_ns[2][0] = feature_cs[2][15];
                            feature_ns[2][1] = feature_cs[2][14];
                            feature_ns[2][2] = feature_cs[2][13];
                            feature_ns[2][3] = feature_cs[2][12];
                            feature_ns[2][4] = feature_cs[2][11];
                            feature_ns[2][5] = feature_cs[2][10];
                            feature_ns[2][6] = feature_cs[2][9];
                            feature_ns[2][7] = feature_cs[2][8];
                            feature_ns[2][8] = feature_cs[2][7];
                            feature_ns[2][9] = feature_cs[2][6];
                            feature_ns[2][10] = feature_cs[2][5];
                            feature_ns[2][11] = feature_cs[2][4];
                            feature_ns[2][12] = feature_cs[2][3];
                            feature_ns[2][13] = feature_cs[2][2];
                            feature_ns[2][14] = feature_cs[2][1];
                            feature_ns[2][15] = feature_cs[2][0];
                            feature_ns[3][0] = feature_cs[3][15];
                            feature_ns[3][1] = feature_cs[3][14];
                            feature_ns[3][2] = feature_cs[3][13];
                            feature_ns[3][3] = feature_cs[3][12];
                            feature_ns[3][4] = feature_cs[3][11];
                            feature_ns[3][5] = feature_cs[3][10];
                            feature_ns[3][6] = feature_cs[3][9];
                            feature_ns[3][7] = feature_cs[3][8];
                            feature_ns[3][8] = feature_cs[3][7];
                            feature_ns[3][9] = feature_cs[3][6];
                            feature_ns[3][10] = feature_cs[3][5];
                            feature_ns[3][11] = feature_cs[3][4];
                            feature_ns[3][12] = feature_cs[3][3];
                            feature_ns[3][13] = feature_cs[3][2];
                            feature_ns[3][14] = feature_cs[3][1];
                            feature_ns[3][15] = feature_cs[3][0];
                            feature_ns[4][0] = feature_cs[4][15];
                            feature_ns[4][1] = feature_cs[4][14];
                            feature_ns[4][2] = feature_cs[4][13];
                            feature_ns[4][3] = feature_cs[4][12];
                            feature_ns[4][4] = feature_cs[4][11];
                            feature_ns[4][5] = feature_cs[4][10];
                            feature_ns[4][6] = feature_cs[4][9];
                            feature_ns[4][7] = feature_cs[4][8];
                            feature_ns[4][8] = feature_cs[4][7];
                            feature_ns[4][9] = feature_cs[4][6];
                            feature_ns[4][10] = feature_cs[4][5];
                            feature_ns[4][11] = feature_cs[4][4];
                            feature_ns[4][12] = feature_cs[4][3];
                            feature_ns[4][13] = feature_cs[4][2];
                            feature_ns[4][14] = feature_cs[4][1];
                            feature_ns[4][15] = feature_cs[4][0];
                            feature_ns[5][0] = feature_cs[5][15];
                            feature_ns[5][1] = feature_cs[5][14];
                            feature_ns[5][2] = feature_cs[5][13];
                            feature_ns[5][3] = feature_cs[5][12];
                            feature_ns[5][4] = feature_cs[5][11];
                            feature_ns[5][5] = feature_cs[5][10];
                            feature_ns[5][6] = feature_cs[5][9];
                            feature_ns[5][7] = feature_cs[5][8];
                            feature_ns[5][8] = feature_cs[5][7];
                            feature_ns[5][9] = feature_cs[5][6];
                            feature_ns[5][10] = feature_cs[5][5];
                            feature_ns[5][11] = feature_cs[5][4];
                            feature_ns[5][12] = feature_cs[5][3];
                            feature_ns[5][13] = feature_cs[5][2];
                            feature_ns[5][14] = feature_cs[5][1];
                            feature_ns[5][15] = feature_cs[5][0];
                            feature_ns[6][0] = feature_cs[6][15];
                            feature_ns[6][1] = feature_cs[6][14];
                            feature_ns[6][2] = feature_cs[6][13];
                            feature_ns[6][3] = feature_cs[6][12];
                            feature_ns[6][4] = feature_cs[6][11];
                            feature_ns[6][5] = feature_cs[6][10];
                            feature_ns[6][6] = feature_cs[6][9];
                            feature_ns[6][7] = feature_cs[6][8];
                            feature_ns[6][8] = feature_cs[6][7];
                            feature_ns[6][9] = feature_cs[6][6];
                            feature_ns[6][10] = feature_cs[6][5];
                            feature_ns[6][11] = feature_cs[6][4];
                            feature_ns[6][12] = feature_cs[6][3];
                            feature_ns[6][13] = feature_cs[6][2];
                            feature_ns[6][14] = feature_cs[6][1];
                            feature_ns[6][15] = feature_cs[6][0];
                            feature_ns[7][0] = feature_cs[7][15];
                            feature_ns[7][1] = feature_cs[7][14];
                            feature_ns[7][2] = feature_cs[7][13];
                            feature_ns[7][3] = feature_cs[7][12];
                            feature_ns[7][4] = feature_cs[7][11];
                            feature_ns[7][5] = feature_cs[7][10];
                            feature_ns[7][6] = feature_cs[7][9];
                            feature_ns[7][7] = feature_cs[7][8];
                            feature_ns[7][8] = feature_cs[7][7];
                            feature_ns[7][9] = feature_cs[7][6];
                            feature_ns[7][10] = feature_cs[7][5];
                            feature_ns[7][11] = feature_cs[7][4];
                            feature_ns[7][12] = feature_cs[7][3];
                            feature_ns[7][13] = feature_cs[7][2];
                            feature_ns[7][14] = feature_cs[7][1];
                            feature_ns[7][15] = feature_cs[7][0];
                            feature_ns[8][0] = feature_cs[8][15];
                            feature_ns[8][1] = feature_cs[8][14];
                            feature_ns[8][2] = feature_cs[8][13];
                            feature_ns[8][3] = feature_cs[8][12];
                            feature_ns[8][4] = feature_cs[8][11];
                            feature_ns[8][5] = feature_cs[8][10];
                            feature_ns[8][6] = feature_cs[8][9];
                            feature_ns[8][7] = feature_cs[8][8];
                            feature_ns[8][8] = feature_cs[8][7];
                            feature_ns[8][9] = feature_cs[8][6];
                            feature_ns[8][10] = feature_cs[8][5];
                            feature_ns[8][11] = feature_cs[8][4];
                            feature_ns[8][12] = feature_cs[8][3];
                            feature_ns[8][13] = feature_cs[8][2];
                            feature_ns[8][14] = feature_cs[8][1];
                            feature_ns[8][15] = feature_cs[8][0];
                            feature_ns[9][0] = feature_cs[9][15];
                            feature_ns[9][1] = feature_cs[9][14];
                            feature_ns[9][2] = feature_cs[9][13];
                            feature_ns[9][3] = feature_cs[9][12];
                            feature_ns[9][4] = feature_cs[9][11];
                            feature_ns[9][5] = feature_cs[9][10];
                            feature_ns[9][6] = feature_cs[9][9];
                            feature_ns[9][7] = feature_cs[9][8];
                            feature_ns[9][8] = feature_cs[9][7];
                            feature_ns[9][9] = feature_cs[9][6];
                            feature_ns[9][10] = feature_cs[9][5];
                            feature_ns[9][11] = feature_cs[9][4];
                            feature_ns[9][12] = feature_cs[9][3];
                            feature_ns[9][13] = feature_cs[9][2];
                            feature_ns[9][14] = feature_cs[9][1];
                            feature_ns[9][15] = feature_cs[9][0];
                            feature_ns[10][0] = feature_cs[10][15];
                            feature_ns[10][1] = feature_cs[10][14];
                            feature_ns[10][2] = feature_cs[10][13];
                            feature_ns[10][3] = feature_cs[10][12];
                            feature_ns[10][4] = feature_cs[10][11];
                            feature_ns[10][5] = feature_cs[10][10];
                            feature_ns[10][6] = feature_cs[10][9];
                            feature_ns[10][7] = feature_cs[10][8];
                            feature_ns[10][8] = feature_cs[10][7];
                            feature_ns[10][9] = feature_cs[10][6];
                            feature_ns[10][10] = feature_cs[10][5];
                            feature_ns[10][11] = feature_cs[10][4];
                            feature_ns[10][12] = feature_cs[10][3];
                            feature_ns[10][13] = feature_cs[10][2];
                            feature_ns[10][14] = feature_cs[10][1];
                            feature_ns[10][15] = feature_cs[10][0];
                            feature_ns[11][0] = feature_cs[11][15];
                            feature_ns[11][1] = feature_cs[11][14];
                            feature_ns[11][2] = feature_cs[11][13];
                            feature_ns[11][3] = feature_cs[11][12];
                            feature_ns[11][4] = feature_cs[11][11];
                            feature_ns[11][5] = feature_cs[11][10];
                            feature_ns[11][6] = feature_cs[11][9];
                            feature_ns[11][7] = feature_cs[11][8];
                            feature_ns[11][8] = feature_cs[11][7];
                            feature_ns[11][9] = feature_cs[11][6];
                            feature_ns[11][10] = feature_cs[11][5];
                            feature_ns[11][11] = feature_cs[11][4];
                            feature_ns[11][12] = feature_cs[11][3];
                            feature_ns[11][13] = feature_cs[11][2];
                            feature_ns[11][14] = feature_cs[11][1];
                            feature_ns[11][15] = feature_cs[11][0];
                            feature_ns[12][0] = feature_cs[12][15];
                            feature_ns[12][1] = feature_cs[12][14];
                            feature_ns[12][2] = feature_cs[12][13];
                            feature_ns[12][3] = feature_cs[12][12];
                            feature_ns[12][4] = feature_cs[12][11];
                            feature_ns[12][5] = feature_cs[12][10];
                            feature_ns[12][6] = feature_cs[12][9];
                            feature_ns[12][7] = feature_cs[12][8];
                            feature_ns[12][8] = feature_cs[12][7];
                            feature_ns[12][9] = feature_cs[12][6];
                            feature_ns[12][10] = feature_cs[12][5];
                            feature_ns[12][11] = feature_cs[12][4];
                            feature_ns[12][12] = feature_cs[12][3];
                            feature_ns[12][13] = feature_cs[12][2];
                            feature_ns[12][14] = feature_cs[12][1];
                            feature_ns[12][15] = feature_cs[12][0];
                            feature_ns[13][0] = feature_cs[13][15];
                            feature_ns[13][1] = feature_cs[13][14];
                            feature_ns[13][2] = feature_cs[13][13];
                            feature_ns[13][3] = feature_cs[13][12];
                            feature_ns[13][4] = feature_cs[13][11];
                            feature_ns[13][5] = feature_cs[13][10];
                            feature_ns[13][6] = feature_cs[13][9];
                            feature_ns[13][7] = feature_cs[13][8];
                            feature_ns[13][8] = feature_cs[13][7];
                            feature_ns[13][9] = feature_cs[13][6];
                            feature_ns[13][10] = feature_cs[13][5];
                            feature_ns[13][11] = feature_cs[13][4];
                            feature_ns[13][12] = feature_cs[13][3];
                            feature_ns[13][13] = feature_cs[13][2];
                            feature_ns[13][14] = feature_cs[13][1];
                            feature_ns[13][15] = feature_cs[13][0];
                            feature_ns[14][0] = feature_cs[14][15];
                            feature_ns[14][1] = feature_cs[14][14];
                            feature_ns[14][2] = feature_cs[14][13];
                            feature_ns[14][3] = feature_cs[14][12];
                            feature_ns[14][4] = feature_cs[14][11];
                            feature_ns[14][5] = feature_cs[14][10];
                            feature_ns[14][6] = feature_cs[14][9];
                            feature_ns[14][7] = feature_cs[14][8];
                            feature_ns[14][8] = feature_cs[14][7];
                            feature_ns[14][9] = feature_cs[14][6];
                            feature_ns[14][10] = feature_cs[14][5];
                            feature_ns[14][11] = feature_cs[14][4];
                            feature_ns[14][12] = feature_cs[14][3];
                            feature_ns[14][13] = feature_cs[14][2];
                            feature_ns[14][14] = feature_cs[14][1];
                            feature_ns[14][15] = feature_cs[14][0];
                            feature_ns[15][0] = feature_cs[15][15];
                            feature_ns[15][1] = feature_cs[15][14];
                            feature_ns[15][2] = feature_cs[15][13];
                            feature_ns[15][3] = feature_cs[15][12];
                            feature_ns[15][4] = feature_cs[15][11];
                            feature_ns[15][5] = feature_cs[15][10];
                            feature_ns[15][6] = feature_cs[15][9];
                            feature_ns[15][7] = feature_cs[15][8];
                            feature_ns[15][8] = feature_cs[15][7];
                            feature_ns[15][9] = feature_cs[15][6];
                            feature_ns[15][10] = feature_cs[15][5];
                            feature_ns[15][11] = feature_cs[15][4];
                            feature_ns[15][12] = feature_cs[15][3];
                            feature_ns[15][13] = feature_cs[15][2];
                            feature_ns[15][14] = feature_cs[15][1];
                            feature_ns[15][15] = feature_cs[15][0];
                        end 
                    endcase
                end

                FILT: begin
                    case (size_now_cs)

                        0: begin
                            if(count2_cs == 1) begin
                                feature_ns[0][0] = median_cs[0];  feature_ns[1][0] = median_cs[1];  feature_ns[2][0] = median_cs[2];  feature_ns[3][0] = median_cs[3];
                                feature_ns[0][1] = median_cs[4];  feature_ns[1][1] = median_cs[5];  feature_ns[2][1] = median_cs[6];  feature_ns[3][1] = median_cs[7];
                                feature_ns[0][2] = median_cs[8];  feature_ns[1][2] = median_cs[9];  feature_ns[2][2] = median_cs[10]; feature_ns[3][2] = median_cs[11];
                                feature_ns[0][3] = median_cs[12]; feature_ns[1][3] = median_cs[13]; feature_ns[2][3] = median_cs[14]; feature_ns[3][3] = median_cs[15];
                            end
                        end

                        1: begin
                            if((count2_cs > 0) && (count2_cs < 5)) begin
                                feature_ns[0][c2_n<<1] = median_cs[0];      feature_ns[1][c2_n<<1] = median_cs[1];      feature_ns[2][c2_n<<1] = median_cs[2];      feature_ns[3][c2_n<<1] = median_cs[3];
                                feature_ns[4][c2_n<<1] = median_cs[4];      feature_ns[5][c2_n<<1] = median_cs[5];      feature_ns[6][c2_n<<1] = median_cs[6];      feature_ns[7][c2_n<<1] = median_cs[7];
                                feature_ns[0][(c2_n<<1)+1] = median_cs[8];  feature_ns[1][(c2_n<<1)+1] = median_cs[9];  feature_ns[2][(c2_n<<1)+1] = median_cs[10]; feature_ns[3][(c2_n<<1)+1] = median_cs[11];
                                feature_ns[4][(c2_n<<1)+1] = median_cs[12]; feature_ns[5][(c2_n<<1)+1] = median_cs[13]; feature_ns[6][(c2_n<<1)+1] = median_cs[14]; feature_ns[7][(c2_n<<1)+1] = median_cs[15];
                            end
                        end

                        2: begin
                            if(count2_cs > 0) for(i=0 ; i<16 ; i=i+1) feature_ns[i][c2_n] = median_cs[i];
                        end

                    endcase
                end
            endcase
        end

        // OUTIN: 

        default: begin
            
        end

    endcase

    // Ensure don't access same address
    for(i=0 ; i<4 ; i=i+1) if(addr[2*i] == addr[2*i+1]) addr[2*i+1] = addr[2*i+1] + 1;
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
// out_ns logic
always @(*) begin
    out_ns = out_cs;
    mult_ns = 0;

    case (mode_cs)
        MIDLE: out_ns = 0;

        ACTIN: begin
            if(act_cs == CROS) begin
                out_ns = out_cs + mult_cs;

                case (count2_cs)
                    5'd0: mult_ns = feature_cs[0][0] * template_cs[4];
                    5'd1: mult_ns = feature_cs[0][1] * template_cs[5];
                    5'd2: mult_ns = feature_cs[1][0] * template_cs[7];
                    5'd3: mult_ns = feature_cs[1][1] * template_cs[8];
                endcase
            end
        end

        OUTIN: begin
            out_ns = {out_cs[18:0], 1'b0};

            case (count2_cs)
                10: mult_ns = conv_img[0] * template_cs[0];
                11: mult_ns = mult_cs + (conv_img[1] * template_cs[1]);
                12: mult_ns = mult_cs + (conv_img[2] * template_cs[2]);
                13: mult_ns = mult_cs + (conv_img[3] * template_cs[3]);
                14: mult_ns = mult_cs + (conv_img[4] * template_cs[4]);
                15: mult_ns = mult_cs + (conv_img[5] * template_cs[5]);
                16: mult_ns = mult_cs + (conv_img[6] * template_cs[6]);
                17: mult_ns = mult_cs + (conv_img[7] * template_cs[7]);
                18: mult_ns = mult_cs + (conv_img[8] * template_cs[8]);
                19: out_ns = mult_cs;
            endcase
        end
    endcase
end

always @(*) begin
    case (mode_cs)

        IDLE: begin
            out_valid = 0;
            out_value = 0;
        end

        IMGIN: begin
            out_valid = 0;
            out_value = 0;
        end

        MIDLE: begin
            out_valid = 0;
            out_value = 0;
        end

        SETIN: begin
            out_valid = 0;
            out_value = 0;
        end

        ACTIN: begin
            out_valid = 0;
            out_value = 0;
        end

        OUTIN: begin
            out_valid = 1;
            out_value = out_cs[19];
        end

        default: begin
            out_valid = 0;
            out_value = 0;
        end

    endcase
end
  
endmodule


module DPSRAM (
    // Input 
    addr, din, rw, clk, signal_high,
    // Output
    dout
);
input [7:0] addr [7:0];     // Address of 8 words. SRAM0:0,1  SRAM1:2,3  SRAM2:4,5  SRAM:6,7
input [7:0] din  [7:0];
input       rw   [7:0];
input       clk;
input       signal_high;

output reg [7:0] dout [7:0];

//==================================================================
// design
//==================================================================
DPRAM_192W SRAM0(
    .A0(addr[0][0]), .A1(addr[0][1]), .A2(addr[0][2]), .A3(addr[0][3]), .A4(addr[0][4]), .A5(addr[0][5]), .A6(addr[0][6]), .A7(addr[0][7]), 
    .B0(addr[1][0]), .B1(addr[1][1]), .B2(addr[1][2]), .B3(addr[1][3]), .B4(addr[1][4]), .B5(addr[1][5]), .B6(addr[1][6]), .B7(addr[1][7]), 
    .DOA0(dout[0][0]), .DOA1(dout[0][1]), .DOA2(dout[0][2]), .DOA3(dout[0][3]), .DOA4(dout[0][4]), .DOA5(dout[0][5]), .DOA6(dout[0][6]), .DOA7(dout[0][7]), 
    .DOB0(dout[1][0]), .DOB1(dout[1][1]), .DOB2(dout[1][2]), .DOB3(dout[1][3]), .DOB4(dout[1][4]), .DOB5(dout[1][5]), .DOB6(dout[1][6]), .DOB7(dout[1][7]),
    .DIA0(din[0][0]), .DIA1(din[0][1]), .DIA2(din[0][2]), .DIA3(din[0][3]), .DIA4(din[0][4]), .DIA5(din[0][5]), .DIA6(din[0][6]), .DIA7(din[0][7]),
    .DIB0(din[1][0]), .DIB1(din[1][1]), .DIB2(din[1][2]), .DIB3(din[1][3]), .DIB4(din[1][4]), .DIB5(din[1][5]), .DIB6(din[1][6]), .DIB7(din[1][7]),
    .WEAN(rw[0]), .WEBN(rw[1]), .CKA(clk), .CKB(clk), .CSA(signal_high), .CSB(signal_high), .OEA(signal_high), .OEB(signal_high));


DPRAM_192W SRAM1(
    .A0(addr[2][0]), .A1(addr[2][1]), .A2(addr[2][2]), .A3(addr[2][3]), .A4(addr[2][4]), .A5(addr[2][5]), .A6(addr[2][6]), .A7(addr[2][7]), 
    .B0(addr[3][0]), .B1(addr[3][1]), .B2(addr[3][2]), .B3(addr[3][3]), .B4(addr[3][4]), .B5(addr[3][5]), .B6(addr[3][6]), .B7(addr[3][7]), 
    .DOA0(dout[2][0]), .DOA1(dout[2][1]), .DOA2(dout[2][2]), .DOA3(dout[2][3]), .DOA4(dout[2][4]), .DOA5(dout[2][5]), .DOA6(dout[2][6]), .DOA7(dout[2][7]), 
    .DOB0(dout[3][0]), .DOB1(dout[3][1]), .DOB2(dout[3][2]), .DOB3(dout[3][3]), .DOB4(dout[3][4]), .DOB5(dout[3][5]), .DOB6(dout[3][6]), .DOB7(dout[3][7]),
    .DIA0(din[2][0]), .DIA1(din[2][1]), .DIA2(din[2][2]), .DIA3(din[2][3]), .DIA4(din[2][4]), .DIA5(din[2][5]), .DIA6(din[2][6]), .DIA7(din[2][7]),
    .DIB0(din[3][0]), .DIB1(din[3][1]), .DIB2(din[3][2]), .DIB3(din[3][3]), .DIB4(din[3][4]), .DIB5(din[3][5]), .DIB6(din[3][6]), .DIB7(din[3][7]),
    .WEAN(rw[2]), .WEBN(rw[3]), .CKA(clk), .CKB(clk), .CSA(signal_high), .CSB(signal_high), .OEA(signal_high), .OEB(signal_high));

DPRAM_192W SRAM2(
    .A0(addr[4][0]), .A1(addr[4][1]), .A2(addr[4][2]), .A3(addr[4][3]), .A4(addr[4][4]), .A5(addr[4][5]), .A6(addr[4][6]), .A7(addr[4][7]), 
    .B0(addr[5][0]), .B1(addr[5][1]), .B2(addr[5][2]), .B3(addr[5][3]), .B4(addr[5][4]), .B5(addr[5][5]), .B6(addr[5][6]), .B7(addr[5][7]), 
    .DOA0(dout[4][0]), .DOA1(dout[4][1]), .DOA2(dout[4][2]), .DOA3(dout[4][3]), .DOA4(dout[4][4]), .DOA5(dout[4][5]), .DOA6(dout[4][6]), .DOA7(dout[4][7]), 
    .DOB0(dout[5][0]), .DOB1(dout[5][1]), .DOB2(dout[5][2]), .DOB3(dout[5][3]), .DOB4(dout[5][4]), .DOB5(dout[5][5]), .DOB6(dout[5][6]), .DOB7(dout[5][7]),
    .DIA0(din[4][0]), .DIA1(din[4][1]), .DIA2(din[4][2]), .DIA3(din[4][3]), .DIA4(din[4][4]), .DIA5(din[4][5]), .DIA6(din[4][6]), .DIA7(din[4][7]),
    .DIB0(din[5][0]), .DIB1(din[5][1]), .DIB2(din[5][2]), .DIB3(din[5][3]), .DIB4(din[5][4]), .DIB5(din[5][5]), .DIB6(din[5][6]), .DIB7(din[5][7]),
    .WEAN(rw[4]), .WEBN(rw[5]), .CKA(clk), .CKB(clk), .CSA(signal_high), .CSB(signal_high), .OEA(signal_high), .OEB(signal_high));

DPRAM_192W SRAM3(
    .A0(addr[6][0]), .A1(addr[6][1]), .A2(addr[6][2]), .A3(addr[6][3]), .A4(addr[6][4]), .A5(addr[6][5]), .A6(addr[6][6]), .A7(addr[6][7]), 
    .B0(addr[7][0]), .B1(addr[7][1]), .B2(addr[7][2]), .B3(addr[7][3]), .B4(addr[7][4]), .B5(addr[7][5]), .B6(addr[7][6]), .B7(addr[7][7]), 
    .DOA0(dout[6][0]), .DOA1(dout[6][1]), .DOA2(dout[6][2]), .DOA3(dout[6][3]), .DOA4(dout[6][4]), .DOA5(dout[6][5]), .DOA6(dout[6][6]), .DOA7(dout[6][7]), 
    .DOB0(dout[7][0]), .DOB1(dout[7][1]), .DOB2(dout[7][2]), .DOB3(dout[7][3]), .DOB4(dout[7][4]), .DOB5(dout[7][5]), .DOB6(dout[7][6]), .DOB7(dout[7][7]),
    .DIA0(din[6][0]), .DIA1(din[6][1]), .DIA2(din[6][2]), .DIA3(din[6][3]), .DIA4(din[6][4]), .DIA5(din[6][5]), .DIA6(din[6][6]), .DIA7(din[6][7]),
    .DIB0(din[7][0]), .DIB1(din[7][1]), .DIB2(din[7][2]), .DIB3(din[7][3]), .DIB4(din[7][4]), .DIB5(din[7][5]), .DIB6(din[7][6]), .DIB7(din[7][7]),
    .WEAN(rw[6]), .WEBN(rw[7]), .CKA(clk), .CKB(clk), .CSA(signal_high), .CSB(signal_high), .OEA(signal_high), .OEB(signal_high));
    
endmodule


module MUX_DIV (
    // Input
    input [8:0] in, 
    // Output
    output reg [7:0] q, 
    output reg [1:0] r
);

always @(*) begin
    case (in)
        9'd0: begin q = 0; r = 0; end
        9'd1: begin q = 0; r = 1; end
        9'd2: begin q = 0; r = 2; end
        9'd3: begin q = 1; r = 0; end
        9'd4: begin q = 1; r = 1; end
        9'd5: begin q = 1; r = 2; end
        9'd6: begin q = 2; r = 0; end
        9'd7: begin q = 2; r = 1; end
        9'd8: begin q = 2; r = 2; end
        9'd9: begin q = 3; r = 0; end
        9'd10: begin q = 3; r = 1; end
        9'd11: begin q = 3; r = 2; end
        9'd12: begin q = 4; r = 0; end
        9'd13: begin q = 4; r = 1; end
        9'd14: begin q = 4; r = 2; end
        9'd15: begin q = 5; r = 0; end
        9'd16: begin q = 5; r = 1; end
        9'd17: begin q = 5; r = 2; end
        9'd18: begin q = 6; r = 0; end
        9'd19: begin q = 6; r = 1; end
        9'd20: begin q = 6; r = 2; end
        9'd21: begin q = 7; r = 0; end
        9'd22: begin q = 7; r = 1; end
        9'd23: begin q = 7; r = 2; end
        9'd24: begin q = 8; r = 0; end
        9'd25: begin q = 8; r = 1; end
        9'd26: begin q = 8; r = 2; end
        9'd27: begin q = 9; r = 0; end
        9'd28: begin q = 9; r = 1; end
        9'd29: begin q = 9; r = 2; end
        9'd30: begin q = 10; r = 0; end
        9'd31: begin q = 10; r = 1; end
        9'd32: begin q = 10; r = 2; end
        9'd33: begin q = 11; r = 0; end
        9'd34: begin q = 11; r = 1; end
        9'd35: begin q = 11; r = 2; end
        9'd36: begin q = 12; r = 0; end
        9'd37: begin q = 12; r = 1; end
        9'd38: begin q = 12; r = 2; end
        9'd39: begin q = 13; r = 0; end
        9'd40: begin q = 13; r = 1; end
        9'd41: begin q = 13; r = 2; end
        9'd42: begin q = 14; r = 0; end
        9'd43: begin q = 14; r = 1; end
        9'd44: begin q = 14; r = 2; end
        9'd45: begin q = 15; r = 0; end
        9'd46: begin q = 15; r = 1; end
        9'd47: begin q = 15; r = 2; end
        9'd48: begin q = 16; r = 0; end
        9'd49: begin q = 16; r = 1; end
        9'd50: begin q = 16; r = 2; end
        9'd51: begin q = 17; r = 0; end
        9'd52: begin q = 17; r = 1; end
        9'd53: begin q = 17; r = 2; end
        9'd54: begin q = 18; r = 0; end
        9'd55: begin q = 18; r = 1; end
        9'd56: begin q = 18; r = 2; end
        9'd57: begin q = 19; r = 0; end
        9'd58: begin q = 19; r = 1; end
        9'd59: begin q = 19; r = 2; end
        9'd60: begin q = 20; r = 0; end
        9'd61: begin q = 20; r = 1; end
        9'd62: begin q = 20; r = 2; end
        9'd63: begin q = 21; r = 0; end
        9'd64: begin q = 21; r = 1; end
        9'd65: begin q = 21; r = 2; end
        9'd66: begin q = 22; r = 0; end
        9'd67: begin q = 22; r = 1; end
        9'd68: begin q = 22; r = 2; end
        9'd69: begin q = 23; r = 0; end
        9'd70: begin q = 23; r = 1; end
        9'd71: begin q = 23; r = 2; end
        9'd72: begin q = 24; r = 0; end
        9'd73: begin q = 24; r = 1; end
        9'd74: begin q = 24; r = 2; end
        9'd75: begin q = 25; r = 0; end
        9'd76: begin q = 25; r = 1; end
        9'd77: begin q = 25; r = 2; end
        9'd78: begin q = 26; r = 0; end
        9'd79: begin q = 26; r = 1; end
        9'd80: begin q = 26; r = 2; end
        9'd81: begin q = 27; r = 0; end
        9'd82: begin q = 27; r = 1; end
        9'd83: begin q = 27; r = 2; end
        9'd84: begin q = 28; r = 0; end
        9'd85: begin q = 28; r = 1; end
        9'd86: begin q = 28; r = 2; end
        9'd87: begin q = 29; r = 0; end
        9'd88: begin q = 29; r = 1; end
        9'd89: begin q = 29; r = 2; end
        9'd90: begin q = 30; r = 0; end
        9'd91: begin q = 30; r = 1; end
        9'd92: begin q = 30; r = 2; end
        9'd93: begin q = 31; r = 0; end
        9'd94: begin q = 31; r = 1; end
        9'd95: begin q = 31; r = 2; end
        9'd96: begin q = 32; r = 0; end
        9'd97: begin q = 32; r = 1; end
        9'd98: begin q = 32; r = 2; end
        9'd99: begin q = 33; r = 0; end
        9'd100: begin q = 33; r = 1; end
        9'd101: begin q = 33; r = 2; end
        9'd102: begin q = 34; r = 0; end
        9'd103: begin q = 34; r = 1; end
        9'd104: begin q = 34; r = 2; end
        9'd105: begin q = 35; r = 0; end
        9'd106: begin q = 35; r = 1; end
        9'd107: begin q = 35; r = 2; end
        9'd108: begin q = 36; r = 0; end
        9'd109: begin q = 36; r = 1; end
        9'd110: begin q = 36; r = 2; end
        9'd111: begin q = 37; r = 0; end
        9'd112: begin q = 37; r = 1; end
        9'd113: begin q = 37; r = 2; end
        9'd114: begin q = 38; r = 0; end
        9'd115: begin q = 38; r = 1; end
        9'd116: begin q = 38; r = 2; end
        9'd117: begin q = 39; r = 0; end
        9'd118: begin q = 39; r = 1; end
        9'd119: begin q = 39; r = 2; end
        9'd120: begin q = 40; r = 0; end
        9'd121: begin q = 40; r = 1; end
        9'd122: begin q = 40; r = 2; end
        9'd123: begin q = 41; r = 0; end
        9'd124: begin q = 41; r = 1; end
        9'd125: begin q = 41; r = 2; end
        9'd126: begin q = 42; r = 0; end
        9'd127: begin q = 42; r = 1; end
        9'd128: begin q = 42; r = 2; end
        9'd129: begin q = 43; r = 0; end
        9'd130: begin q = 43; r = 1; end
        9'd131: begin q = 43; r = 2; end
        9'd132: begin q = 44; r = 0; end
        9'd133: begin q = 44; r = 1; end
        9'd134: begin q = 44; r = 2; end
        9'd135: begin q = 45; r = 0; end
        9'd136: begin q = 45; r = 1; end
        9'd137: begin q = 45; r = 2; end
        9'd138: begin q = 46; r = 0; end
        9'd139: begin q = 46; r = 1; end
        9'd140: begin q = 46; r = 2; end
        9'd141: begin q = 47; r = 0; end
        9'd142: begin q = 47; r = 1; end
        9'd143: begin q = 47; r = 2; end
        9'd144: begin q = 48; r = 0; end
        9'd145: begin q = 48; r = 1; end
        9'd146: begin q = 48; r = 2; end
        9'd147: begin q = 49; r = 0; end
        9'd148: begin q = 49; r = 1; end
        9'd149: begin q = 49; r = 2; end
        9'd150: begin q = 50; r = 0; end
        9'd151: begin q = 50; r = 1; end
        9'd152: begin q = 50; r = 2; end
        9'd153: begin q = 51; r = 0; end
        9'd154: begin q = 51; r = 1; end
        9'd155: begin q = 51; r = 2; end
        9'd156: begin q = 52; r = 0; end
        9'd157: begin q = 52; r = 1; end
        9'd158: begin q = 52; r = 2; end
        9'd159: begin q = 53; r = 0; end
        9'd160: begin q = 53; r = 1; end
        9'd161: begin q = 53; r = 2; end
        9'd162: begin q = 54; r = 0; end
        9'd163: begin q = 54; r = 1; end
        9'd164: begin q = 54; r = 2; end
        9'd165: begin q = 55; r = 0; end
        9'd166: begin q = 55; r = 1; end
        9'd167: begin q = 55; r = 2; end
        9'd168: begin q = 56; r = 0; end
        9'd169: begin q = 56; r = 1; end
        9'd170: begin q = 56; r = 2; end
        9'd171: begin q = 57; r = 0; end
        9'd172: begin q = 57; r = 1; end
        9'd173: begin q = 57; r = 2; end
        9'd174: begin q = 58; r = 0; end
        9'd175: begin q = 58; r = 1; end
        9'd176: begin q = 58; r = 2; end
        9'd177: begin q = 59; r = 0; end
        9'd178: begin q = 59; r = 1; end
        9'd179: begin q = 59; r = 2; end
        9'd180: begin q = 60; r = 0; end
        9'd181: begin q = 60; r = 1; end
        9'd182: begin q = 60; r = 2; end
        9'd183: begin q = 61; r = 0; end
        9'd184: begin q = 61; r = 1; end
        9'd185: begin q = 61; r = 2; end
        9'd186: begin q = 62; r = 0; end
        9'd187: begin q = 62; r = 1; end
        9'd188: begin q = 62; r = 2; end
        9'd189: begin q = 63; r = 0; end
        9'd190: begin q = 63; r = 1; end
        9'd191: begin q = 63; r = 2; end
        9'd192: begin q = 64; r = 0; end
        9'd193: begin q = 64; r = 1; end
        9'd194: begin q = 64; r = 2; end
        9'd195: begin q = 65; r = 0; end
        9'd196: begin q = 65; r = 1; end
        9'd197: begin q = 65; r = 2; end
        9'd198: begin q = 66; r = 0; end
        9'd199: begin q = 66; r = 1; end
        9'd200: begin q = 66; r = 2; end
        9'd201: begin q = 67; r = 0; end
        9'd202: begin q = 67; r = 1; end
        9'd203: begin q = 67; r = 2; end
        9'd204: begin q = 68; r = 0; end
        9'd205: begin q = 68; r = 1; end
        9'd206: begin q = 68; r = 2; end
        9'd207: begin q = 69; r = 0; end
        9'd208: begin q = 69; r = 1; end
        9'd209: begin q = 69; r = 2; end
        9'd210: begin q = 70; r = 0; end
        9'd211: begin q = 70; r = 1; end
        9'd212: begin q = 70; r = 2; end
        9'd213: begin q = 71; r = 0; end
        9'd214: begin q = 71; r = 1; end
        9'd215: begin q = 71; r = 2; end
        9'd216: begin q = 72; r = 0; end
        9'd217: begin q = 72; r = 1; end
        9'd218: begin q = 72; r = 2; end
        9'd219: begin q = 73; r = 0; end
        9'd220: begin q = 73; r = 1; end
        9'd221: begin q = 73; r = 2; end
        9'd222: begin q = 74; r = 0; end
        9'd223: begin q = 74; r = 1; end
        9'd224: begin q = 74; r = 2; end
        9'd225: begin q = 75; r = 0; end
        9'd226: begin q = 75; r = 1; end
        9'd227: begin q = 75; r = 2; end
        9'd228: begin q = 76; r = 0; end
        9'd229: begin q = 76; r = 1; end
        9'd230: begin q = 76; r = 2; end
        9'd231: begin q = 77; r = 0; end
        9'd232: begin q = 77; r = 1; end
        9'd233: begin q = 77; r = 2; end
        9'd234: begin q = 78; r = 0; end
        9'd235: begin q = 78; r = 1; end
        9'd236: begin q = 78; r = 2; end
        9'd237: begin q = 79; r = 0; end
        9'd238: begin q = 79; r = 1; end
        9'd239: begin q = 79; r = 2; end
        9'd240: begin q = 80; r = 0; end
        9'd241: begin q = 80; r = 1; end
        9'd242: begin q = 80; r = 2; end
        9'd243: begin q = 81; r = 0; end
        9'd244: begin q = 81; r = 1; end
        9'd245: begin q = 81; r = 2; end
        9'd246: begin q = 82; r = 0; end
        9'd247: begin q = 82; r = 1; end
        9'd248: begin q = 82; r = 2; end
        9'd249: begin q = 83; r = 0; end
        9'd250: begin q = 83; r = 1; end
        9'd251: begin q = 83; r = 2; end
        9'd252: begin q = 84; r = 0; end
        9'd253: begin q = 84; r = 1; end
        9'd254: begin q = 84; r = 2; end
        9'd255: begin q = 85; r = 0; end
        9'd256: begin q = 85; r = 1; end
        9'd257: begin q = 85; r = 2; end
        default: begin q = 0; r = 0; end
    endcase
end
    
endmodule


module MAXPOOL_UNIT (
    // Input
    input [7:0] compare [3:0],
    // Output
    output reg [7:0] max
);
wire [7:0] mid [1:0];

assign mid[0] = compare[0]>compare[1]? compare[0]:compare[1];
assign mid[1] = compare[2]>compare[3]? compare[2]:compare[3];

assign max    = mid[0]>mid[1]? mid[0]:mid[1];
    
endmodule


module CONV_IMG_SELECTOR (
    // Input
    input [7:0] feature [15:0][15:0],
    input [1:0] size_now,
    input [7:0] count,
    // Output
    output reg [7:0] conv_img [8:0]
);
integer i, j;

always @(*) begin
    for(i=0 ; i<9 ; i=i+1) conv_img[i] = 0;

    case (size_now)
        0: begin
            case (count)
                0: begin
                    conv_img[4] = feature[0][0]; conv_img[5] = feature[0][1];
                    conv_img[7] = feature[1][0]; conv_img[8] = feature[1][1];
                end
                1, 2: begin
                    conv_img[3] = feature[0][count-1]; conv_img[4] = feature[0][count]; conv_img[5] = feature[0][count+1];
                    conv_img[6] = feature[1][count-1]; conv_img[7] = feature[1][count]; conv_img[8] = feature[1][count+1];
                end
                3: begin
                    conv_img[3] = feature[0][2]; conv_img[4] = feature[0][3];
                    conv_img[6] = feature[1][2]; conv_img[7] = feature[1][3];
                end
                4, 8: begin
                    conv_img[1] = feature[(count[7:2])-1][0]; conv_img[2] = feature[(count[7:2])-1][1];
                    conv_img[4] = feature[(count[7:2])][0];   conv_img[5] = feature[(count[7:2])][1];
                    conv_img[7] = feature[(count[7:2])+1][0]; conv_img[8] = feature[(count[7:2])+1][1];
                end
                5, 6, 9, 10: begin
                    conv_img[0] = feature[(count[7:2])-1][count[1:0]-1]; conv_img[1] = feature[(count[7:2])-1][count[1:0]]; conv_img[2] = feature[(count[7:2])-1][count[1:0]+1];
                    conv_img[3] = feature[(count[7:2])][count[1:0]-1];   conv_img[4] = feature[(count[7:2])][count[1:0]];   conv_img[5] = feature[(count[7:2])][count[1:0]+1];
                    conv_img[6] = feature[(count[7:2])+1][count[1:0]-1]; conv_img[7] = feature[(count[7:2])+1][count[1:0]]; conv_img[8] = feature[(count[7:2])+1][count[1:0]+1];
                end
                7, 11: begin
                    conv_img[0] = feature[(count[7:2])-1][2]; conv_img[1] = feature[(count[7:2])-1][3]; 
                    conv_img[3] = feature[(count[7:2])][2];   conv_img[4] = feature[(count[7:2])][3];   
                    conv_img[6] = feature[(count[7:2])+1][2]; conv_img[7] = feature[(count[7:2])+1][3]; 
                end
                12: begin
                    conv_img[1] = feature[2][0]; conv_img[2] = feature[2][1];
                    conv_img[4] = feature[3][0]; conv_img[5] = feature[3][1];
                end
                13, 14: begin
                    conv_img[0] = feature[2][count[1:0]-1]; conv_img[1] = feature[2][count[1:0]]; conv_img[2] = feature[2][count[1:0]+1];
                    conv_img[3] = feature[3][count[1:0]-1]; conv_img[4] = feature[3][count[1:0]]; conv_img[5] = feature[3][count[1:0]+1];
                end
                15: begin
                    conv_img[0] = feature[2][2]; conv_img[1] = feature[2][3];
                    conv_img[3] = feature[3][2]; conv_img[4] = feature[3][3];
                end
            endcase
        end

        1: begin
            case (count)
                0: begin
                    conv_img[4] = feature[0][0]; conv_img[5] = feature[0][1];
                    conv_img[7] = feature[1][0]; conv_img[8] = feature[1][1];
                end
                1, 2, 3, 4, 5, 6: begin
                    conv_img[3] = feature[0][count-1]; conv_img[4] = feature[0][count]; conv_img[5] = feature[0][count+1];
                    conv_img[6] = feature[1][count-1]; conv_img[7] = feature[1][count]; conv_img[8] = feature[1][count+1];
                end
                7: begin
                    conv_img[3] = feature[0][6]; conv_img[4] = feature[0][7];
                    conv_img[6] = feature[1][6]; conv_img[7] = feature[1][7];
                end
                8, 16, 24, 32, 40, 48: begin
                    conv_img[1] = feature[(count[7:3])-1][0]; conv_img[2] = feature[(count[7:3])-1][1];
                    conv_img[4] = feature[(count[7:3])][0];   conv_img[5] = feature[(count[7:3])][1];
                    conv_img[7] = feature[(count[7:3])+1][0]; conv_img[8] = feature[(count[7:3])+1][1];
                end
                9, 10, 11, 12, 13, 14, 17, 18, 19, 20, 21, 22, 25, 26, 27, 28, 29, 30, 33, 34, 35, 36, 37, 38, 41, 42, 43, 44, 45, 46, 49, 50, 51, 52, 53, 54: begin
                    conv_img[0] = feature[(count[7:3])-1][count[2:0]-1]; conv_img[1] = feature[(count[7:3])-1][count[2:0]]; conv_img[2] = feature[(count[7:3])-1][count[2:0]+1];
                    conv_img[3] = feature[(count[7:3])][count[2:0]-1];   conv_img[4] = feature[(count[7:3])][count[2:0]];   conv_img[5] = feature[(count[7:3])][count[2:0]+1];
                    conv_img[6] = feature[(count[7:3])+1][count[2:0]-1]; conv_img[7] = feature[(count[7:3])+1][count[2:0]]; conv_img[8] = feature[(count[7:3])+1][count[2:0]+1];
                end
                15, 23, 31, 39, 47, 55: begin
                    conv_img[0] = feature[(count[7:3])-1][6]; conv_img[1] = feature[(count[7:3])-1][7]; 
                    conv_img[3] = feature[(count[7:3])][6];   conv_img[4] = feature[(count[7:3])][7];   
                    conv_img[6] = feature[(count[7:3])+1][6]; conv_img[7] = feature[(count[7:3])+1][7]; 
                end
                56: begin
                    conv_img[1] = feature[6][0]; conv_img[2] = feature[6][1];
                    conv_img[4] = feature[7][0]; conv_img[5] = feature[7][1];
                end
                57, 58, 59, 60, 61, 62: begin
                    conv_img[0] = feature[6][count[2:0]-1]; conv_img[1] = feature[6][count[2:0]]; conv_img[2] = feature[6][count[2:0]+1];
                    conv_img[3] = feature[7][count[2:0]-1]; conv_img[4] = feature[7][count[2:0]]; conv_img[5] = feature[7][count[2:0]+1];
                end
                63: begin
                    conv_img[0] = feature[6][6]; conv_img[1] = feature[6][7];
                    conv_img[3] = feature[7][6]; conv_img[4] = feature[7][7];
                end
            endcase
        end

        2: begin
            case (count)
                0: begin
                    conv_img[4] = feature[0][0]; conv_img[5] = feature[0][1];
                    conv_img[7] = feature[1][0]; conv_img[8] = feature[1][1];
                end
                1,2,3,4,5,6,7,8,9,10,11,12,13,14: begin
                    conv_img[3] = feature[0][count-1]; conv_img[4] = feature[0][count]; conv_img[5] = feature[0][count+1];
                    conv_img[6] = feature[1][count-1]; conv_img[7] = feature[1][count]; conv_img[8] = feature[1][count+1];
                end
                15: begin
                    conv_img[3] = feature[0][14]; conv_img[4] = feature[0][15];
                    conv_img[6] = feature[1][14]; conv_img[7] = feature[1][15];
                end
                16,32,48,64,80,96,112,128,144,160,176,192,208,224: begin
                    conv_img[1] = feature[(count[7:4])-1][0]; conv_img[2] = feature[(count[7:4])-1][1];
                    conv_img[4] = feature[(count[7:4])][0];   conv_img[5] = feature[(count[7:4])][1];
                    conv_img[7] = feature[(count[7:4])+1][0]; conv_img[8] = feature[(count[7:4])+1][1];
                end
                
                31,47,63,79,95,111,127,143,159,175,191,207,223,239: begin
                    conv_img[0] = feature[(count[7:4])-1][14]; conv_img[1] = feature[(count[7:4])-1][15]; 
                    conv_img[3] = feature[(count[7:4])][14];   conv_img[4] = feature[(count[7:4])][15];   
                    conv_img[6] = feature[(count[7:4])+1][14]; conv_img[7] = feature[(count[7:4])+1][15]; 
                end
                240: begin
                    conv_img[1] = feature[14][0]; conv_img[2] = feature[14][1];
                    conv_img[4] = feature[15][0]; conv_img[5] = feature[15][1];
                end
                241,242,243,244,245,246,247,248,249,250,251,252,253,254: begin
                    conv_img[0] = feature[14][count[3:0]-1]; conv_img[1] = feature[14][count[3:0]]; conv_img[2] = feature[14][count[3:0]+1];
                    conv_img[3] = feature[15][count[3:0]-1]; conv_img[4] = feature[15][count[3:0]]; conv_img[5] = feature[15][count[3:0]+1];
                end
                255: begin
                    conv_img[0] = feature[14][14]; conv_img[1] = feature[14][15];
                    conv_img[3] = feature[15][14]; conv_img[4] = feature[15][15];
                end
                default: begin
                    conv_img[0] = feature[(count[7:4])-1][count[3:0]-1]; conv_img[1] = feature[(count[7:4])-1][count[3:0]]; conv_img[2] = feature[(count[7:4])-1][count[3:0]+1];
                    conv_img[3] = feature[(count[7:4])][count[3:0]-1];   conv_img[4] = feature[(count[7:4])][count[3:0]];   conv_img[5] = feature[(count[7:4])][count[3:0]+1];
                    conv_img[6] = feature[(count[7:4])+1][count[3:0]-1]; conv_img[7] = feature[(count[7:4])+1][count[3:0]]; conv_img[8] = feature[(count[7:4])+1][count[3:0]+1];
                end
            endcase
        end
    endcase
end
    
endmodule


module FIND_UNSORT_UNIT (
    // Input 
    input [7:0] feature [15:0][15:0],
    input [1:0] size_now,
    input [3:0] count,
    // Output 
    output reg [7:0] unsort [15:0][8:0]
);

integer i, j;
reg [3:0] idx [5:0];

always @(*) begin
    for(i=0 ; i<16 ; i=i+1) for(j=0 ; j<9 ; j=j+1) unsort[i][j] = 0;
    for(i=0 ; i<6 ; i=i+1) idx[i] = 0;

    case (size_now)

        0: begin        // 4x4
            unsort[0][0] = feature[0][0]; unsort[0][1] = feature[0][0]; unsort[0][2] = feature[0][1];
            unsort[0][3] = feature[0][0]; unsort[0][4] = feature[0][0]; unsort[0][5] = feature[0][1];
            unsort[0][6] = feature[1][0]; unsort[0][7] = feature[1][0]; unsort[0][8] = feature[1][1];

            unsort[1][0] = feature[0][0]; unsort[1][1] = feature[0][0]; unsort[1][2] = feature[0][1];
            unsort[1][3] = feature[1][0]; unsort[1][4] = feature[1][0]; unsort[1][5] = feature[1][1];
            unsort[1][6] = feature[2][0]; unsort[1][7] = feature[2][0]; unsort[1][8] = feature[2][1];

            unsort[2][0] = feature[1][0]; unsort[2][1] = feature[1][0]; unsort[2][2] = feature[1][1];
            unsort[2][3] = feature[2][0]; unsort[2][4] = feature[2][0]; unsort[2][5] = feature[2][1];
            unsort[2][6] = feature[3][0]; unsort[2][7] = feature[3][0]; unsort[2][8] = feature[3][1];

            unsort[3][0] = feature[2][0]; unsort[3][1] = feature[2][0]; unsort[3][2] = feature[2][1];
            unsort[3][3] = feature[3][0]; unsort[3][4] = feature[3][0]; unsort[3][5] = feature[3][1];
            unsort[3][6] = feature[3][0]; unsort[3][7] = feature[3][0]; unsort[3][8] = feature[3][1];

            unsort[4][0] = feature[0][0]; unsort[4][1] = feature[0][1]; unsort[4][2] = feature[0][2];
            unsort[4][3] = feature[0][0]; unsort[4][4] = feature[0][1]; unsort[4][5] = feature[0][2];
            unsort[4][6] = feature[1][0]; unsort[4][7] = feature[1][1]; unsort[4][8] = feature[1][2];

            unsort[5][0] = feature[0][0]; unsort[5][1] = feature[0][1]; unsort[5][2] = feature[0][2];
            unsort[5][3] = feature[1][0]; unsort[5][4] = feature[1][1]; unsort[5][5] = feature[1][2];
            unsort[5][6] = feature[2][0]; unsort[5][7] = feature[2][1]; unsort[5][8] = feature[2][2];

            unsort[6][0] = feature[1][0]; unsort[6][1] = feature[1][1]; unsort[6][2] = feature[1][2];
            unsort[6][3] = feature[2][0]; unsort[6][4] = feature[2][1]; unsort[6][5] = feature[2][2];
            unsort[6][6] = feature[3][0]; unsort[6][7] = feature[3][1]; unsort[6][8] = feature[3][2];

            unsort[7][0] = feature[2][0]; unsort[7][1] = feature[2][1]; unsort[7][2] = feature[2][2];
            unsort[7][3] = feature[3][0]; unsort[7][4] = feature[3][1]; unsort[7][5] = feature[3][2];
            unsort[7][6] = feature[3][0]; unsort[7][7] = feature[3][1]; unsort[7][8] = feature[3][2];

            unsort[8][0] = feature[0][1]; unsort[8][1] = feature[0][2]; unsort[8][2] = feature[0][3];
            unsort[8][3] = feature[0][1]; unsort[8][4] = feature[0][2]; unsort[8][5] = feature[0][3];
            unsort[8][6] = feature[1][1]; unsort[8][7] = feature[1][2]; unsort[8][8] = feature[1][3];

            unsort[9][0] = feature[0][1]; unsort[9][1] = feature[0][2]; unsort[9][2] = feature[0][3];
            unsort[9][3] = feature[1][1]; unsort[9][4] = feature[1][2]; unsort[9][5] = feature[1][3];
            unsort[9][6] = feature[2][1]; unsort[9][7] = feature[2][2]; unsort[9][8] = feature[2][3];

            unsort[10][0] = feature[1][1]; unsort[10][1] = feature[1][2]; unsort[10][2] = feature[1][3];
            unsort[10][3] = feature[2][1]; unsort[10][4] = feature[2][2]; unsort[10][5] = feature[2][3];
            unsort[10][6] = feature[3][1]; unsort[10][7] = feature[3][2]; unsort[10][8] = feature[3][3];

            unsort[11][0] = feature[2][1]; unsort[11][1] = feature[2][2]; unsort[11][2] = feature[2][3];
            unsort[11][3] = feature[3][1]; unsort[11][4] = feature[3][2]; unsort[11][5] = feature[3][3];
            unsort[11][6] = feature[3][1]; unsort[11][7] = feature[3][2]; unsort[11][8] = feature[3][3];

            unsort[12][0] = feature[0][2]; unsort[12][1] = feature[0][3]; unsort[12][2] = feature[0][3];
            unsort[12][3] = feature[0][2]; unsort[12][4] = feature[0][3]; unsort[12][5] = feature[0][3];
            unsort[12][6] = feature[1][2]; unsort[12][7] = feature[1][3]; unsort[12][8] = feature[1][3];

            unsort[13][0] = feature[0][2]; unsort[13][1] = feature[0][3]; unsort[13][2] = feature[0][3];
            unsort[13][3] = feature[1][2]; unsort[13][4] = feature[1][3]; unsort[13][5] = feature[1][3];
            unsort[13][6] = feature[2][2]; unsort[13][7] = feature[2][3]; unsort[13][8] = feature[2][3];

            unsort[14][0] = feature[1][2]; unsort[14][1] = feature[1][3]; unsort[14][2] = feature[1][3];
            unsort[14][3] = feature[2][2]; unsort[14][4] = feature[2][3]; unsort[14][5] = feature[2][3];
            unsort[14][6] = feature[3][2]; unsort[14][7] = feature[3][3]; unsort[14][8] = feature[3][3];

            unsort[15][0] = feature[2][2]; unsort[15][1] = feature[2][3]; unsort[15][2] = feature[2][3];
            unsort[15][3] = feature[3][2]; unsort[15][4] = feature[3][3]; unsort[15][5] = feature[3][3];
            unsort[15][6] = feature[3][2]; unsort[15][7] = feature[3][3]; unsort[15][8] = feature[3][3];
        end

        1: begin        // 8x8
            case (count)
                0: begin
                    idx[0] = 0; idx[1] = 0; idx[2] = 1;
                    idx[3] = 0; idx[4] = 1; idx[5] = 2;
                end
                1: begin
                    idx[0] = 1; idx[1] = 2; idx[2] = 3;
                    idx[3] = 2; idx[4] = 3; idx[5] = 4;
                end
                2: begin
                    idx[0] = 3; idx[1] = 4; idx[2] = 5;
                    idx[3] = 4; idx[4] = 5; idx[5] = 6;
                end
                3: begin
                    idx[0] = 5; idx[1] = 6; idx[2] = 7;
                    idx[3] = 6; idx[4] = 7; idx[5] = 7;
                end
            endcase

            unsort[0][0] = feature[0][idx[0]]; unsort[0][1] = feature[0][idx[1]]; unsort[0][2] = feature[0][idx[2]]; 
            unsort[0][3] = feature[0][idx[0]]; unsort[0][4] = feature[0][idx[1]]; unsort[0][5] = feature[0][idx[2]]; 
            unsort[0][6] = feature[1][idx[0]]; unsort[0][7] = feature[1][idx[1]]; unsort[0][8] = feature[1][idx[2]]; 

            unsort[1][0] = feature[0][idx[0]]; unsort[1][1] = feature[0][idx[1]]; unsort[1][2] = feature[0][idx[2]]; 
            unsort[1][3] = feature[1][idx[0]]; unsort[1][4] = feature[1][idx[1]]; unsort[1][5] = feature[1][idx[2]]; 
            unsort[1][6] = feature[2][idx[0]]; unsort[1][7] = feature[2][idx[1]]; unsort[1][8] = feature[2][idx[2]]; 

            unsort[2][0] = feature[1][idx[0]]; unsort[2][1] = feature[1][idx[1]]; unsort[2][2] = feature[1][idx[2]]; 
            unsort[2][3] = feature[2][idx[0]]; unsort[2][4] = feature[2][idx[1]]; unsort[2][5] = feature[2][idx[2]]; 
            unsort[2][6] = feature[3][idx[0]]; unsort[2][7] = feature[3][idx[1]]; unsort[2][8] = feature[3][idx[2]]; 

            unsort[3][0] = feature[2][idx[0]]; unsort[3][1] = feature[2][idx[1]]; unsort[3][2] = feature[2][idx[2]]; 
            unsort[3][3] = feature[3][idx[0]]; unsort[3][4] = feature[3][idx[1]]; unsort[3][5] = feature[3][idx[2]]; 
            unsort[3][6] = feature[4][idx[0]]; unsort[3][7] = feature[4][idx[1]]; unsort[3][8] = feature[4][idx[2]]; 

            unsort[4][0] = feature[3][idx[0]]; unsort[4][1] = feature[3][idx[1]]; unsort[4][2] = feature[3][idx[2]]; 
            unsort[4][3] = feature[4][idx[0]]; unsort[4][4] = feature[4][idx[1]]; unsort[4][5] = feature[4][idx[2]]; 
            unsort[4][6] = feature[5][idx[0]]; unsort[4][7] = feature[5][idx[1]]; unsort[4][8] = feature[5][idx[2]]; 

            unsort[5][0] = feature[4][idx[0]]; unsort[5][1] = feature[4][idx[1]]; unsort[5][2] = feature[4][idx[2]]; 
            unsort[5][3] = feature[5][idx[0]]; unsort[5][4] = feature[5][idx[1]]; unsort[5][5] = feature[5][idx[2]]; 
            unsort[5][6] = feature[6][idx[0]]; unsort[5][7] = feature[6][idx[1]]; unsort[5][8] = feature[6][idx[2]]; 

            unsort[6][0] = feature[5][idx[0]]; unsort[6][1] = feature[5][idx[1]]; unsort[6][2] = feature[5][idx[2]]; 
            unsort[6][3] = feature[6][idx[0]]; unsort[6][4] = feature[6][idx[1]]; unsort[6][5] = feature[6][idx[2]]; 
            unsort[6][6] = feature[7][idx[0]]; unsort[6][7] = feature[7][idx[1]]; unsort[6][8] = feature[7][idx[2]]; 

            unsort[7][0] = feature[6][idx[0]]; unsort[7][1] = feature[6][idx[1]]; unsort[7][2] = feature[6][idx[2]]; 
            unsort[7][3] = feature[7][idx[0]]; unsort[7][4] = feature[7][idx[1]]; unsort[7][5] = feature[7][idx[2]]; 
            unsort[7][6] = feature[7][idx[0]]; unsort[7][7] = feature[7][idx[1]]; unsort[7][8] = feature[7][idx[2]];
            // 
            unsort[8][0] = feature[0][idx[3]]; unsort[8][1] = feature[0][idx[4]]; unsort[8][2] = feature[0][idx[5]]; 
            unsort[8][3] = feature[0][idx[3]]; unsort[8][4] = feature[0][idx[4]]; unsort[8][5] = feature[0][idx[5]]; 
            unsort[8][6] = feature[1][idx[3]]; unsort[8][7] = feature[1][idx[4]]; unsort[8][8] = feature[1][idx[5]]; 

            unsort[9][0] = feature[0][idx[3]]; unsort[9][1] = feature[0][idx[4]]; unsort[9][2] = feature[0][idx[5]]; 
            unsort[9][3] = feature[1][idx[3]]; unsort[9][4] = feature[1][idx[4]]; unsort[9][5] = feature[1][idx[5]]; 
            unsort[9][6] = feature[2][idx[3]]; unsort[9][7] = feature[2][idx[4]]; unsort[9][8] = feature[2][idx[5]]; 

            unsort[10][0] = feature[1][idx[3]]; unsort[10][1] = feature[1][idx[4]]; unsort[10][2] = feature[1][idx[5]]; 
            unsort[10][3] = feature[2][idx[3]]; unsort[10][4] = feature[2][idx[4]]; unsort[10][5] = feature[2][idx[5]]; 
            unsort[10][6] = feature[3][idx[3]]; unsort[10][7] = feature[3][idx[4]]; unsort[10][8] = feature[3][idx[5]]; 

            unsort[11][0] = feature[2][idx[3]]; unsort[11][1] = feature[2][idx[4]]; unsort[11][2] = feature[2][idx[5]]; 
            unsort[11][3] = feature[3][idx[3]]; unsort[11][4] = feature[3][idx[4]]; unsort[11][5] = feature[3][idx[5]]; 
            unsort[11][6] = feature[4][idx[3]]; unsort[11][7] = feature[4][idx[4]]; unsort[11][8] = feature[4][idx[5]]; 

            unsort[12][0] = feature[3][idx[3]]; unsort[12][1] = feature[3][idx[4]]; unsort[12][2] = feature[3][idx[5]]; 
            unsort[12][3] = feature[4][idx[3]]; unsort[12][4] = feature[4][idx[4]]; unsort[12][5] = feature[4][idx[5]]; 
            unsort[12][6] = feature[5][idx[3]]; unsort[12][7] = feature[5][idx[4]]; unsort[12][8] = feature[5][idx[5]]; 

            unsort[13][0] = feature[4][idx[3]]; unsort[13][1] = feature[4][idx[4]]; unsort[13][2] = feature[4][idx[5]]; 
            unsort[13][3] = feature[5][idx[3]]; unsort[13][4] = feature[5][idx[4]]; unsort[13][5] = feature[5][idx[5]]; 
            unsort[13][6] = feature[6][idx[3]]; unsort[13][7] = feature[6][idx[4]]; unsort[13][8] = feature[6][idx[5]]; 

            unsort[14][0] = feature[5][idx[3]]; unsort[14][1] = feature[5][idx[4]]; unsort[14][2] = feature[5][idx[5]]; 
            unsort[14][3] = feature[6][idx[3]]; unsort[14][4] = feature[6][idx[4]]; unsort[14][5] = feature[6][idx[5]]; 
            unsort[14][6] = feature[7][idx[3]]; unsort[14][7] = feature[7][idx[4]]; unsort[14][8] = feature[7][idx[5]]; 

            unsort[15][0] = feature[6][idx[3]]; unsort[15][1] = feature[6][idx[4]]; unsort[15][2] = feature[6][idx[5]]; 
            unsort[15][3] = feature[7][idx[3]]; unsort[15][4] = feature[7][idx[4]]; unsort[15][5] = feature[7][idx[5]]; 
            unsort[15][6] = feature[7][idx[3]]; unsort[15][7] = feature[7][idx[4]]; unsort[15][8] = feature[7][idx[5]]; 
        end

        2: begin        // 16x16
            case (count)
                0: begin
                    idx[0] = 0;
                    idx[1] = 0;
                    idx[2] = 1;
                end
                15: begin
                    idx[0] = 14;
                    idx[1] = 15;
                    idx[2] = 15;
                end
                default: begin
                    idx[0] = count - 1;
                    idx[1] = count;
                    idx[2] = count + 1;
                end
            endcase

            unsort[0][0] = feature[0][idx[0]]; unsort[0][1] = feature[0][idx[1]]; unsort[0][2] = feature[0][idx[2]]; 
            unsort[0][3] = feature[0][idx[0]]; unsort[0][4] = feature[0][idx[1]]; unsort[0][5] = feature[0][idx[2]]; 
            unsort[0][6] = feature[1][idx[0]]; unsort[0][7] = feature[1][idx[1]]; unsort[0][8] = feature[1][idx[2]]; 

            unsort[1][0] = feature[0][idx[0]]; unsort[1][1] = feature[0][idx[1]]; unsort[1][2] = feature[0][idx[2]]; 
            unsort[1][3] = feature[1][idx[0]]; unsort[1][4] = feature[1][idx[1]]; unsort[1][5] = feature[1][idx[2]]; 
            unsort[1][6] = feature[2][idx[0]]; unsort[1][7] = feature[2][idx[1]]; unsort[1][8] = feature[2][idx[2]]; 

            unsort[2][0] = feature[1][idx[0]]; unsort[2][1] = feature[1][idx[1]]; unsort[2][2] = feature[1][idx[2]]; 
            unsort[2][3] = feature[2][idx[0]]; unsort[2][4] = feature[2][idx[1]]; unsort[2][5] = feature[2][idx[2]]; 
            unsort[2][6] = feature[3][idx[0]]; unsort[2][7] = feature[3][idx[1]]; unsort[2][8] = feature[3][idx[2]]; 

            unsort[3][0] = feature[2][idx[0]]; unsort[3][1] = feature[2][idx[1]]; unsort[3][2] = feature[2][idx[2]]; 
            unsort[3][3] = feature[3][idx[0]]; unsort[3][4] = feature[3][idx[1]]; unsort[3][5] = feature[3][idx[2]]; 
            unsort[3][6] = feature[4][idx[0]]; unsort[3][7] = feature[4][idx[1]]; unsort[3][8] = feature[4][idx[2]]; 

            unsort[4][0] = feature[3][idx[0]]; unsort[4][1] = feature[3][idx[1]]; unsort[4][2] = feature[3][idx[2]]; 
            unsort[4][3] = feature[4][idx[0]]; unsort[4][4] = feature[4][idx[1]]; unsort[4][5] = feature[4][idx[2]]; 
            unsort[4][6] = feature[5][idx[0]]; unsort[4][7] = feature[5][idx[1]]; unsort[4][8] = feature[5][idx[2]]; 

            unsort[5][0] = feature[4][idx[0]]; unsort[5][1] = feature[4][idx[1]]; unsort[5][2] = feature[4][idx[2]]; 
            unsort[5][3] = feature[5][idx[0]]; unsort[5][4] = feature[5][idx[1]]; unsort[5][5] = feature[5][idx[2]]; 
            unsort[5][6] = feature[6][idx[0]]; unsort[5][7] = feature[6][idx[1]]; unsort[5][8] = feature[6][idx[2]]; 

            unsort[6][0] = feature[5][idx[0]]; unsort[6][1] = feature[5][idx[1]]; unsort[6][2] = feature[5][idx[2]]; 
            unsort[6][3] = feature[6][idx[0]]; unsort[6][4] = feature[6][idx[1]]; unsort[6][5] = feature[6][idx[2]]; 
            unsort[6][6] = feature[7][idx[0]]; unsort[6][7] = feature[7][idx[1]]; unsort[6][8] = feature[7][idx[2]]; 

            unsort[7][0] = feature[6][idx[0]]; unsort[7][1] = feature[6][idx[1]]; unsort[7][2] = feature[6][idx[2]]; 
            unsort[7][3] = feature[7][idx[0]]; unsort[7][4] = feature[7][idx[1]]; unsort[7][5] = feature[7][idx[2]]; 
            unsort[7][6] = feature[8][idx[0]]; unsort[7][7] = feature[8][idx[1]]; unsort[7][8] = feature[8][idx[2]]; 

            unsort[8][0] = feature[7][idx[0]]; unsort[8][1] = feature[7][idx[1]]; unsort[8][2] = feature[7][idx[2]]; 
            unsort[8][3] = feature[8][idx[0]]; unsort[8][4] = feature[8][idx[1]]; unsort[8][5] = feature[8][idx[2]]; 
            unsort[8][6] = feature[9][idx[0]]; unsort[8][7] = feature[9][idx[1]]; unsort[8][8] = feature[9][idx[2]]; 

            unsort[9][0] = feature[8][idx[0]]; unsort[9][1] = feature[8][idx[1]]; unsort[9][2] = feature[8][idx[2]]; 
            unsort[9][3] = feature[9][idx[0]]; unsort[9][4] = feature[9][idx[1]]; unsort[9][5] = feature[9][idx[2]]; 
            unsort[9][6] = feature[10][idx[0]]; unsort[9][7] = feature[10][idx[1]]; unsort[9][8] = feature[10][idx[2]]; 

            unsort[10][0] = feature[9][idx[0]]; unsort[10][1] = feature[9][idx[1]]; unsort[10][2] = feature[9][idx[2]]; 
            unsort[10][3] = feature[10][idx[0]]; unsort[10][4] = feature[10][idx[1]]; unsort[10][5] = feature[10][idx[2]]; 
            unsort[10][6] = feature[11][idx[0]]; unsort[10][7] = feature[11][idx[1]]; unsort[10][8] = feature[11][idx[2]]; 

            unsort[11][0] = feature[10][idx[0]]; unsort[11][1] = feature[10][idx[1]]; unsort[11][2] = feature[10][idx[2]]; 
            unsort[11][3] = feature[11][idx[0]]; unsort[11][4] = feature[11][idx[1]]; unsort[11][5] = feature[11][idx[2]]; 
            unsort[11][6] = feature[12][idx[0]]; unsort[11][7] = feature[12][idx[1]]; unsort[11][8] = feature[12][idx[2]]; 

            unsort[12][0] = feature[11][idx[0]]; unsort[12][1] = feature[11][idx[1]]; unsort[12][2] = feature[11][idx[2]]; 
            unsort[12][3] = feature[12][idx[0]]; unsort[12][4] = feature[12][idx[1]]; unsort[12][5] = feature[12][idx[2]]; 
            unsort[12][6] = feature[13][idx[0]]; unsort[12][7] = feature[13][idx[1]]; unsort[12][8] = feature[13][idx[2]]; 

            unsort[13][0] = feature[12][idx[0]]; unsort[13][1] = feature[12][idx[1]]; unsort[13][2] = feature[12][idx[2]]; 
            unsort[13][3] = feature[13][idx[0]]; unsort[13][4] = feature[13][idx[1]]; unsort[13][5] = feature[13][idx[2]]; 
            unsort[13][6] = feature[14][idx[0]]; unsort[13][7] = feature[14][idx[1]]; unsort[13][8] = feature[14][idx[2]]; 

            unsort[14][0] = feature[13][idx[0]]; unsort[14][1] = feature[13][idx[1]]; unsort[14][2] = feature[13][idx[2]]; 
            unsort[14][3] = feature[14][idx[0]]; unsort[14][4] = feature[14][idx[1]]; unsort[14][5] = feature[14][idx[2]]; 
            unsort[14][6] = feature[15][idx[0]]; unsort[14][7] = feature[15][idx[1]]; unsort[14][8] = feature[15][idx[2]]; 

            unsort[15][0] = feature[14][idx[0]]; unsort[15][1] = feature[14][idx[1]]; unsort[15][2] = feature[14][idx[2]]; 
            unsort[15][3] = feature[15][idx[0]]; unsort[15][4] = feature[15][idx[1]]; unsort[15][5] = feature[15][idx[2]]; 
            unsort[15][6] = feature[15][idx[0]]; unsort[15][7] = feature[15][idx[1]]; unsort[15][8] = feature[15][idx[2]]; 
        end

    endcase
end
    
endmodule


module FIND_MEDIAN (
    input [7:0] unsort [8:0],
    output reg [7:0] median
);
    
wire [7:0] max [0:2];
wire [7:0] mid [0:2];
wire [7:0] min [0:2];

wire [7:0] min_max, mid_mid, max_min;

Sort Sort0 (.in(unsort[2:0]), .max(max[0]), .mid(mid[0]), .min(min[0]));
Sort Sort1 (.in(unsort[5:3]), .max(max[1]), .mid(mid[1]), .min(min[1]));
Sort Sort2 (.in(unsort[8:6]), .max(max[2]), .mid(mid[2]), .min(min[2]));

Sort Sort3 (.in(max), .max(), .mid(), .min(min_max));
Sort Sort4 (.in(mid), .max(), .mid(mid_mid), .min());
Sort Sort5 (.in(min), .max(max_min), .mid(), .min());

Sort Sort7 (.in({max_min, mid_mid, min_max}), .max(), .mid(median), .min());

endmodule

module Sort (
    input [7:0] in [0:2],
    output reg [7:0] max,
    output reg [7:0] mid,
    output reg [7:0] min
);

reg flag0, flag1, flag2;

assign flag0 = (in[0] > in[1]);
assign flag1 = (in[1] > in[2]);
assign flag2 = (in[2] > in[0]);

always @(*) begin
    case ({flag0, flag1, flag2})
        3'b000: {max, mid, min} = {in[0], in[1], in[2]};
        3'b001: {max, mid, min} = {in[2], in[1], in[0]};
        3'b010: {max, mid, min} = {in[1], in[0], in[2]};
        3'b011: {max, mid, min} = {in[1], in[2], in[0]};
        3'b100: {max, mid, min} = {in[0], in[2], in[1]};
        3'b101: {max, mid, min} = {in[2], in[0], in[1]};
        3'b110: {max, mid, min} = {in[0], in[1], in[2]};
        3'b111: {max, mid, min} = {0, 0, 0};
    endcase
end
    
endmodule