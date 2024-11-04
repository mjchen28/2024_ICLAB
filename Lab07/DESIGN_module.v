module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_row,
    in_kernel,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [17:0] in_row;
input [11:0] in_kernel;
input out_idle;
output reg handshake_sready;
output reg [29:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;

input fifo_empty;
input [7:0] fifo_rdata;
output reg fifo_rinc;
output reg out_valid;
output reg [7:0] out_data;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j, k;

parameter IDLE = 2'b00;
parameter IPUT = 2'b01;
parameter WAIT = 2'b11;
parameter OPUT = 2'b10;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg [1:0] mode_cs, mode_ns;
reg [4:0] countb_cs, countb_ns;
reg [2:0] counts_cs, counts_ns;
reg [1:0] counto_cs, counto_ns;

reg [29:0] in_cs [0:4];
reg [29:0] in_ns [0:4];
reg [7:0] out_cs, out_ns;

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
// Asynchronous reset
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_cs <= IDLE;
        countb_cs <= 5'd0;
        counts_cs <= 3'd0;
        counto_cs <= 2'd0;
        for(i=0 ; i<5 ; i=i+1) in_cs[i] <= 30'd0;
    end
    else begin
        mode_cs <= mode_ns;
        countb_cs <= countb_ns;
        counts_cs <= counts_ns;
        counto_cs <= counto_ns;
        for(i=0 ; i<5 ; i=i+1) in_cs[i] <= in_ns[i];
        
    end
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
            if(counts_cs >= 5) mode_ns = WAIT;
            else               mode_ns = mode_cs;
        end

        WAIT: begin
            if(!fifo_empty)         mode_ns = OPUT;
            else if(counts_cs >= 6) mode_ns = IDLE;
            else                    mode_ns = mode_cs;
        end

        OPUT: begin
            if((counts_cs >= 6) && (counto_cs == 1))    mode_ns = IDLE;
            else if(fifo_empty)                         mode_ns = WAIT;
            else                                        mode_ns = mode_cs;
        end

		default: begin
            mode_ns = mode_cs;
        end

	endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
assign flag_clk1_to_handshake = 0;
assign flag_clk1_to_fifo = (mode_cs == IDLE);

// counter logic
always @(*) begin
    
    case (mode_cs)

        IPUT: begin
            if(in_valid) countb_ns = countb_cs + 1;
            else         countb_ns = 0;

            if(counts_cs == 5)        counts_ns = 0;
            else if(handshake_sready) counts_ns = counts_cs + 1;
            else                      counts_ns = counts_cs;

            counto_ns = 0;
        end

        WAIT: begin
            if(!fifo_empty) begin
                if(countb_cs == 24) begin
                    countb_ns = 0;
                    counts_ns = counts_cs + 1;
                end 
                else begin
                   countb_ns = countb_cs + 1;
                   counts_ns = counts_cs;
                end
            end
            else begin
                countb_ns = countb_cs;
                counts_ns = counts_cs;
            end
            
            counto_ns = 0;
        end

        OPUT: begin
            if(counto_cs) begin
                if(countb_cs == 24) begin
                    countb_ns = 0;
                    counts_ns = counts_cs + 1;
                end 
                else begin
                   countb_ns = countb_cs + 1;
                   counts_ns = counts_cs;
                end
            end 
            else begin
                countb_ns = countb_cs;
                counts_ns = counts_cs;
            end 

            if(counto_cs == 0)  counto_ns = 1;
            else                counto_ns = counto_cs;
        end

		default: begin
            countb_ns = 0;
            counts_ns = 0;
            counto_ns = 0;
        end 

	endcase
end

// in_ns logic
always @(*) begin
    for(i=0 ; i<5 ; i=i+1) in_ns[i] = in_cs[i];

    if((mode_cs == IPUT) && (in_valid)) in_ns[countb_cs] = {in_row, in_kernel};
end

// handshake_syn logic
always @(*) begin
    case (mode_cs)

        IDLE: begin
            if(in_valid)begin
                handshake_sready = 1;
                handshake_din = {in_row, in_kernel};
            end
            else begin
                handshake_sready = 0;
                handshake_din = 0;
            end
        end

        IPUT: begin
            if(out_idle) begin
                handshake_sready = 1;
                handshake_din = in_cs[counts_cs];
            end
            else begin
                handshake_sready = 0;
                handshake_din = 0;
            end
        end

        default: begin
            handshake_sready = 0;
            handshake_din = 0;
        end

    endcase
end

// FIFO_syn logic
always @(*) begin
    if(((mode_cs == WAIT) || (mode_cs == OPUT)) && (!fifo_empty))   fifo_rinc = 1;
    else                                                            fifo_rinc = 0;
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

        WAIT: begin
            if(counto_cs == 1) begin
                out_valid = 1;
                out_data = fifo_rdata;
            end
            else begin
                out_valid = 0;
                out_data = 0;
            end
        end

        OPUT: begin
            if(counto_cs == 1) begin
                out_valid = 1;
                out_data = fifo_rdata;
            end
            else begin
                out_valid = 0;
                out_data = 0;
            end
        end

		default: begin
            out_valid = 0;
            out_data = 0;
        end

	endcase
end

endmodule

// ============================================ Seperate Line  ============================================ //

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_data,
    out_valid,
    out_data,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [29:0] in_data;
output reg out_valid;
output reg [7:0] out_data;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;
//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer i, j, k;

parameter IDLE = 2'b00;
parameter CALC = 2'b01;
parameter WAIT = 2'b11;
parameter OPUT = 2'b10;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg [1:0] mode_cs, mode_ns;
reg [2:0] countr_cs, countr_ns;
reg [2:0] countc_cs, countc_ns;
reg [2:0] countn_cs, countn_ns;
reg       sel_cs, sel_ns;
reg [2:0] in_cs [0:5][0:5];
reg [2:0] in_ns [0:5][0:5];
reg [2:0] kernel_cs [0:5][0:3];
reg [2:0] kernel_ns [0:5][0:3];
reg [5:0] inter_cs [0:3];
reg [5:0] inter_ns [0:3];
reg [7:0] out_cs;
reg [7:0] out_ns;
reg       busy_ns;

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
// Asynchronous reset
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mode_cs <= IDLE;
        countr_cs <= 3'd0;
        countc_cs <= 3'd0;
        countn_cs <= 3'd0;
        sel_cs <= 1'd0;
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) in_cs[i][j] <= 3'd0;
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<4 ; j=j+1) kernel_cs[i][j] <= 3'd0;
        for(i=0 ; i<4 ; i=i+1) inter_cs[i] <= 6'd0;
        out_cs <= 8'd0;
        busy <= 0;
    end
    else begin
        mode_cs <= mode_ns;
        countr_cs <= countr_ns;
        countc_cs <= countc_ns;
        countn_cs <= countn_ns;
        sel_cs <= sel_ns;
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) in_cs[i][j] <= in_ns[i][j];
        for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<4 ; j=j+1) kernel_cs[i][j] <= kernel_ns[i][j];
        for(i=0 ; i<4 ; i=i+1) inter_cs[i] <= inter_ns[i];
        out_cs <= out_ns;
        busy <= busy_ns;
    end
end

//======================================================================//
//                                  FSM                                 //
//======================================================================//
always @(*) begin
	case (mode_cs)

		IDLE: begin
            if(countn_cs == 6) mode_ns = CALC;
            else               mode_ns = mode_cs;
        end

        CALC: begin
            if((sel_cs == 1)) begin
                if(!fifo_full) mode_ns = OPUT;
                else           mode_ns = WAIT;
            end
            else mode_ns = mode_cs;
        end

        WAIT: begin
            if(!fifo_full) mode_ns = OPUT;
            else           mode_ns = mode_cs;
        end

        OPUT: begin
            if(fifo_full) mode_ns = WAIT;
            else if(countn_cs >= 6) mode_ns = IDLE;
            else               mode_ns = CALC;
        end

		default: begin
            mode_ns = mode_cs;
        end

	endcase
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
assign flag_clk2_to_handshake = 0;
assign flag_clk2_to_fifo = 0;

// count_ns logic
always @(*) begin
    case (mode_cs)
        IDLE: begin
            if(countn_cs == 6) countn_ns = 0;
            else if(in_valid)  countn_ns = countn_cs + 1;
            else               countn_ns = countn_cs;

            countr_ns = 0;
            countc_ns = 0;
        end

        CALC: begin
            if(sel_cs == 0) begin
                if(countc_cs == 4) begin
                    countc_ns = 0;
                    if(countr_cs == 4) begin
                        countr_ns = 0;
                        countn_ns = countn_cs + 1;
                    end 
                    else begin
                        countr_ns = countr_cs + 1;
                        countn_ns = countn_cs;
                    end 
                end 
                else begin
                    countc_ns = countc_cs + 1;
                    countr_ns = countr_cs;
                    countn_ns = countn_cs;
                end
            end
            else begin
                countc_ns = countc_cs;
                countr_ns = countr_cs;
                countn_ns = countn_cs;
            end 
        end

        OPUT: begin
            countc_ns = countc_cs;
            countr_ns = countr_cs;

            if((countn_cs >= 6) && (!fifo_full)) countn_ns = 0;
            else               countn_ns = countn_cs;
        end

        default: begin
            countc_ns = countc_cs;
            countr_ns = countr_cs;
            countn_ns = countn_cs;
        end
    endcase                                 
end

// sel_ns logic
always @(*) begin
    if((mode_cs == CALC) && (sel_cs == 0)) sel_ns = 1;
    else sel_ns = 0;
end

// in_ns & kernel_ns logic
always @(*) begin
    for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<6 ; j=j+1) in_ns[i][j] = in_cs[i][j];
    for(i=0 ; i<6 ; i=i+1) for(j=0 ; j<4 ; j=j+1) kernel_ns[i][j] = kernel_cs[i][j];

    if((mode_cs == IDLE) && (in_valid)) begin
        in_ns[countn_cs][5] = in_data[29:27]; in_ns[countn_cs][4] = in_data[26:24]; in_ns[countn_cs][3] = in_data[23:21];
        in_ns[countn_cs][2] = in_data[20:18]; in_ns[countn_cs][1] = in_data[17:15]; in_ns[countn_cs][0] = in_data[14:12];

        kernel_ns[countn_cs][3] = in_data[11:9]; kernel_ns[countn_cs][2] = in_data[8:6];
        kernel_ns[countn_cs][1] = in_data[5:3];  kernel_ns[countn_cs][0] = in_data[2:0];
    end
end

// out_ns & inter_ns logic
always @(*) begin
    for(i=0 ; i<4 ; i=i+1) inter_ns[i] = 6'd0;
    
    if(mode_cs == CALC) begin
        if(!sel_cs) begin
            inter_ns[0] = kernel_cs[countn_cs][0] * in_cs[countr_cs][countc_cs];
            inter_ns[1] = kernel_cs[countn_cs][1] * in_cs[countr_cs][countc_cs+1];
            inter_ns[2] = kernel_cs[countn_cs][2] * in_cs[countr_cs+1][countc_cs];
            inter_ns[3] = kernel_cs[countn_cs][3] * in_cs[countr_cs+1][countc_cs+1];

            out_ns = 0;
        end
        else out_ns = inter_cs[0] + inter_cs[1] + inter_cs[2] + inter_cs[3];
    end
    else out_ns = out_cs;
end

// busy_ns logic
always @(*) begin
    if(in_valid)                     busy_ns = 1;
    else if(!flag_handshake_to_clk2) busy_ns = 0;
    else                             busy_ns = busy;
end

//======================================================================//
//                                 OUTPUT                               //
//======================================================================//
// out_valid & out_data logic
always @(*) begin
    if(mode_cs == OPUT) begin
        out_valid = 1;
        out_data = out_cs;
    end
    else begin
        out_valid = 0;
        out_data = 0;
    end
end


endmodule