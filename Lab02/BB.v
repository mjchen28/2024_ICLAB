module BB(
    //Input Ports
    input clk,
    input rst_n,
    input in_valid,
    input [1:0] inning,   // Current inning number
    input half,           // 0: top of the inning, 1: bottom of the inning
    input [2:0] action,   // Action code

    //Output Ports
    output reg out_valid,  // Result output valid
    output reg [7:0] score_A,  // Score of team A (guest team)
    output reg [7:0] score_B,  // Score of team B (home team)
    output reg [1:0] result    // 0: Team A wins, 1: Team B wins, 2: Darw
);

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter IDLE = 1'b1;
parameter PLAY = 1'b0;

// base state parameters
parameter BASE_0    = 3'b000;  
parameter BASE_1    = 3'b001;  
parameter BASE_2    = 3'b010;  
parameter BASE_3    = 3'b100;  
parameter BASE_12   = 3'b011; 
parameter BASE_23   = 3'b110; 
parameter BASE_13   = 3'b101; 
parameter BASE_123  = 3'b111;

//==============================================//
//                 reg declaration              //
//==============================================//
reg mode_cs, mode_ns;
reg [2:0] base_cs, base_ns;
reg [1:0] outs_cs, outs_ns;
reg [3:0] score_A_cs, score_A_ns;
reg [2:0] score_B_cs, score_B_ns;

reg [2:0] score_temp;
reg switch;
reg out_flag_cs, out_flag_ns;

wire many_outs;
wire zero_outs;

//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_cs     <= IDLE;
        outs_cs     <= 2'd0;
        score_A_cs  <= 4'd0;
        score_B_cs  <= 3'd0;
        out_flag_cs <= 1'b0;
    end
    else begin
        mode_cs     <= mode_ns;
        outs_cs     <= outs_ns;
        score_A_cs  <= score_A_ns;
        score_B_cs  <= score_B_ns;
        out_flag_cs <= out_flag_ns;
    end
end

always @(posedge clk) begin
    base_cs <= base_ns;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(in_valid) mode_ns = PLAY;
            else         mode_ns = mode_cs;
        end
        PLAY: begin
            if(!in_valid) mode_ns = IDLE;
            else          mode_ns = mode_cs;
        end
    endcase
end

//==============================================//
//             Base and Score Logic             //
//==============================================//

assign many_outs = outs_cs[1];
assign zero_outs = (outs_cs == 0) ? 0 : 1;

// base state & score circuit
always @(*) begin
    base_ns = BASE_0;
    score_temp = 3'd0;
    outs_ns = outs_cs;
    switch = 1'b0;

    if(in_valid) begin
        case ({base_cs, action})
            6'b000000: begin
                base_ns = BASE_1;
            end
            6'b000001: begin
                base_ns = BASE_1;
            end
            6'b000010: begin
                base_ns = BASE_2;
            end
            6'b000011: begin
                base_ns = BASE_3;
            end
            6'b000100: begin
                score_temp = 1;
            end
            6'b000101: begin
                if(many_outs) begin
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b000110: begin
                if(many_outs) begin
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end  
            end
            6'b000111: begin
                if(many_outs) begin
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end  
            end
            6'b001000: begin
                base_ns = BASE_12;
            end
            6'b001001: begin
                if(many_outs) base_ns = BASE_13;
                else          base_ns = BASE_12;
            end
            6'b001010: begin
                if(many_outs) begin
                    base_ns = BASE_2;
                    score_temp = 1;
                end 
                else begin
                    base_ns = BASE_23;
                end
            end
            6'b001011: begin
                base_ns = BASE_3;
                score_temp = 1;
            end
            6'b001100: begin
                score_temp = 2;
            end
            6'b001101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_2;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b001110: begin
                if(zero_outs) begin
                    outs_ns = 0;
                    switch = 1;
                end
                else begin
                    outs_ns = 2;
                    switch = 0;
                end 
            end
            6'b001111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b010000: begin
                base_ns = BASE_12;
            end
            6'b010001: begin
                if(many_outs) begin
                    base_ns = BASE_1;
                    score_temp = 1;
                end 
                else begin
                    base_ns = BASE_13;
                end
            end
            6'b010010: begin
                base_ns = BASE_2;
                score_temp = 1;
            end
            6'b010011: begin
                base_ns = BASE_3;
                score_temp = 1;
            end
            6'b010100: begin
                score_temp = 2;
            end
            6'b010101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_3;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b010110: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_3;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end
            end
            6'b010111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_2;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b011000: begin
                base_ns = BASE_123;
            end
            6'b011001: begin
                if(many_outs) begin
                    base_ns = BASE_13;
                    score_temp = 1;
                end 
                else begin
                    base_ns = BASE_123;
                end
            end
            6'b011010: begin
                if(many_outs) begin
                    base_ns = BASE_2;
                    score_temp = 2;
                end 
                else begin
                    base_ns = BASE_23;
                    score_temp = 1;
                end
            end
            6'b011011: begin
                base_ns = BASE_3;
                score_temp = 2;
            end
            6'b011100: begin
                score_temp = 3;
            end
            6'b011101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_23;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b011110: begin
                if(zero_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end
                else begin
                    base_ns = BASE_3;
                    outs_ns = 2;
                    switch = 0;
                end 
            end
            6'b011111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_12;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b100000: begin
                base_ns = BASE_13;
            end
            6'b100001: begin
                base_ns = BASE_1;
                score_temp = 1;
            end
            6'b100010: begin
                base_ns = BASE_2;
                score_temp = 1;
            end
            6'b100011: begin
                base_ns = BASE_3;
                score_temp = 1;
            end
            6'b100100: begin
                score_temp = 2;
            end
            6'b100101: begin
                if(many_outs) begin
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b100110: begin
                if(many_outs) begin
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b100111: begin
                if(many_outs) begin
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end
            end
            6'b101000: begin
                base_ns = BASE_123;
            end
            6'b101001: begin
                if(many_outs) base_ns = BASE_13;
                else          base_ns = BASE_12;
                score_temp = 1;
            end
            6'b101010: begin
                if(many_outs) begin
                    base_ns = BASE_2;
                    score_temp = 2;
                end 
                else begin
                    base_ns = BASE_23;
                    score_temp = 1;
                end
            end
            6'b101011: begin
                base_ns = BASE_3;
                score_temp = 2;
            end
            6'b101100: begin
                score_temp = 3;
            end
            6'b101101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_2;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b101110: begin
                if(zero_outs) begin
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end
                else begin
                    score_temp = 1;
                    outs_ns = 2;
                    switch = 0;
                end 
            end
            6'b101111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_1;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b110000: begin
                base_ns = BASE_123;
            end
            6'b110001: begin
                if(many_outs) begin
                    base_ns = BASE_1;
                    score_temp = 2;
                end 
                else begin
                    base_ns = BASE_13;
                    score_temp = 1;
                end
            end
            6'b110010: begin
                base_ns = BASE_2;
                                score_temp = 2;
            end
            6'b110011: begin
                base_ns = BASE_3;
                score_temp = 2;
            end
            6'b110100: begin
                score_temp = 3;
            end
            6'b110101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_3;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b110110: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_3;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end  
            end
            6'b110111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_2;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b111000: begin
                base_ns = BASE_123;
                score_temp = 1;
            end
            6'b111001: begin
                if(many_outs) begin
                    base_ns = BASE_13;
                    score_temp = 2;
                end 
                else begin
                    base_ns = BASE_123;
                    score_temp = 1;
                end
            end
            6'b111010: begin
                if(many_outs) begin
                    base_ns = BASE_2;
                    score_temp = 3;
                end 
                else begin
                    base_ns = BASE_23;
                    score_temp = 2;
                end
            end
            6'b111011: begin
                base_ns = BASE_3;
                score_temp = 3;
            end
            6'b111100: begin
                score_temp = 4;
            end
            6'b111101: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_23;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
            6'b111110: begin
                if(zero_outs) begin
                    outs_ns = 0;
                    switch = 1;
                end                
                else begin
                    base_ns = BASE_3;
                    score_temp = 1;
                    outs_ns = 2;
                    switch = 0;
                end 
            end
            6'b111111: begin
                if(many_outs) begin
                    base_ns = BASE_0;
                    score_temp = 0;
                    outs_ns = 0;
                    switch = 1;
                end 
                else begin
                    base_ns = BASE_12;
                    score_temp = 1;
                    outs_ns = outs_cs + 1;
                    switch = 0;
                end 
            end
        endcase
    end
    else begin
        base_ns = BASE_0;
        score_temp = 0;
        outs_ns = 0;
        switch = 0;
    end
end

// assign score to team 
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(out_flag_cs) begin
                score_A_ns = 0;
                score_B_ns = 0;
            end
            else begin
                score_A_ns = score_temp;
                score_B_ns = 0;
            end
        end
        PLAY: begin
            if(out_flag_cs) begin
                score_A_ns = score_A_cs;
                score_B_ns = score_B_cs;
            end
            else begin
                if (half) begin
                    score_A_ns = score_A_cs;
                    score_B_ns = score_B_cs + score_temp;
                end
                else begin
                    score_A_ns = score_A_cs + score_temp;
                    score_B_ns = score_B_cs;
                end
            end
        end
    endcase
end

//==============================================//
//                Output Block                  //
//==============================================//
assign score_A = score_A_cs;
assign score_B = score_B_cs;

// out_flag circuit
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(out_flag_cs) out_flag_ns = 0;
            else            out_flag_ns = out_flag_cs;
        end
        PLAY: begin
            if(!in_valid) out_flag_ns = 1;
            else if((inning == 2'd3) & (!half) & (switch == 1'b1) & (score_A_cs < score_B_cs)) out_flag_ns = 1;
            else out_flag_ns = out_flag_cs;
        end
    endcase
end

always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(out_flag_cs) out_valid = 1;
            else            out_valid = 0;
        end
        PLAY: out_valid = 1'b0;
    endcase
    
end

always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(out_flag_cs) begin
                if(score_A_cs > score_B_cs) result = 2'd0;
                else if(score_A_cs < score_B_cs) result = 2'd1;
                else result = 2'd2;
            end
            else result = 2'd0;
        end
        PLAY: result = 2'd0;
    endcase    
end

endmodule