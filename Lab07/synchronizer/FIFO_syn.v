module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo;

output flag_fifo_to_clk1;
input flag_clk1_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg [6:0] waddr_cs, waddr_ns;
reg [6:0] raddr_cs, raddr_ns;
// reg rempty_ns;
wire write_en;
wire [6:0] wq2_rptr, rq2_wptr;
wire [7:0] dout;
wire [6:0] raddr_decode;
//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
// write clock domain
always @(posedge wclk or negedge rst_n) begin
    if(!rst_n) waddr_cs <= 0;
    else       waddr_cs <= waddr_ns;
end

// read clock domain
always @(posedge rclk or negedge rst_n) begin
    if(!rst_n) begin
        raddr_cs <= 0;
        rdata <= 0;
		// rempty <= 0;
    end 
    else begin
        raddr_cs <= raddr_ns;
        rdata <= rdata_q;
		// rempty <= rempty_ns;
    end
end

//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
// control FIFO write
assign write_en = (winc && !wfull);

// FIFO
DUAL_64X8X1BM1 u_dual_sram(
    .A0(waddr_cs[0]), .A1(waddr_cs[1]), .A2(waddr_cs[2]), .A3(waddr_cs[3]), .A4(waddr_cs[4]), .A5(waddr_cs[5]), 
    .B0(raddr_cs[0]), .B1(raddr_cs[1]), .B2(raddr_cs[2]), .B3(raddr_cs[3]), .B4(raddr_cs[4]), .B5(raddr_cs[5]), 
    // .DOA0(), .DOA1(), .DOA2(), .DOA3(), .DOA4(), .DOA5(), .DOA6(), .DOA7(),      // write port
    .DOB0(rdata_q[0]), .DOB1(rdata_q[1]), .DOB2(rdata_q[2]), .DOB3(rdata_q[3]), .DOB4(rdata_q[4]), .DOB5(rdata_q[5]), .DOB6(rdata_q[6]), .DOB7(rdata_q[7]),
    .DIA0(wdata[0]), .DIA1(wdata[1]), .DIA2(wdata[2]), .DIA3(wdata[3]), .DIA4(wdata[4]), .DIA5(wdata[5]), .DIA6(wdata[6]), .DIA7(wdata[7]),
    .DIB0(1'b0), .DIB1(1'b0), .DIB2(1'b0), .DIB3(1'b0), .DIB4(1'b0), .DIB5(1'b0), .DIB6(1'b0), .DIB7(1'b0),     // read port
    .WEAN(1'b0), .WEBN(1'b1), 
    .CKA(wclk), .CKB(rclk), 
    .CSA(write_en), .CSB(1'b1), 
    .OEA(1'b1), .OEB(1'b1)
);

// make wptr & rptr
GRAYCODE_ENCODER GE0(.addr(waddr_cs), .gray_addr(wptr));
GRAYCODE_ENCODER GE1(.addr(raddr_cs), .gray_addr(rptr));

GRAYCODE_DECODER GE(.gray_addr(wq2_rptr), .addr(raddr_decode));

// synchronizer for ptr
NDFF_BUS_syn #(7) NDFF0 (.D(wptr), .Q(rq2_wptr), .clk(rclk), .rst_n(rst_n));
NDFF_BUS_syn #(7) NDFF1 (.D(rptr), .Q(wq2_rptr), .clk(wclk), .rst_n(rst_n));

// modify
assign flag_fifo_to_clk2 = 0;
assign flag_fifo_to_clk1 = 0;


// wfull logic
always @(*) begin
    if({~waddr_cs[6], waddr_cs[5:0]} == raddr_decode) wfull = 1;
    else                                  wfull = 0;
end

// rempty logic
always @(*) begin
    if(rptr == rq2_wptr) rempty = 1;
    else                 rempty = 0;
end

// waddr_ns logic
always @(*) begin
    if(winc && !wfull) waddr_ns = waddr_cs + 1;
    else               waddr_ns = waddr_cs;
end

// raddr_ns logic
always @(*) begin
	if(rinc && !rempty)	raddr_ns = raddr_cs + 1;
    else               	raddr_ns = raddr_cs;
end

// // rdata logic
// always @(*) begin
//     rdata = dout;
// end

// user guide:
// write-
// if(!wfull) 	set winc and input store data
// else 		hold data
// ------------------------------------------
// read-
// if(!rempty)	set rinc and get output data after 2 cycle
// else			IDLE

endmodule


module GRAYCODE_ENCODER (
    // Input
    addr,
    // Output
    gray_addr
);
input [6:0] addr;
output reg [6:0] gray_addr;

always @(*) begin
	gray_addr = addr ^ (addr>>1);
end
    
endmodule


module GRAYCODE_DECODER (
    // Input
    gray_addr,
    // Output
    addr
);
input [6:0] gray_addr;
output reg [6:0] addr;

always @(*) begin
    case (gray_addr)
        7'b0000000: addr =  0;
        7'b0000001: addr =  1;
		7'b0000011: addr =  2;
		7'b0000010: addr =  3;
		7'b0000110: addr =  4;
		7'b0000111: addr =  5;
		7'b0000101: addr =  6;
		7'b0000100: addr =  7;
		7'b0001100: addr =  8;
		7'b0001101: addr =  9;
		7'b0001111: addr =  10;
		7'b0001110: addr =  11;
		7'b0001010: addr =  12;
		7'b0001011: addr =  13;
		7'b0001001: addr =  14;
		7'b0001000: addr =  15;
		7'b0011000: addr =  16;
		7'b0011001: addr =  17;
		7'b0011011: addr =  18;
		7'b0011010: addr =  19;
		7'b0011110: addr =  20;
		7'b0011111: addr =  21;
		7'b0011101: addr =  22;
		7'b0011100: addr =  23;
		7'b0010100: addr =  24;
		7'b0010101: addr =  25;
		7'b0010111: addr =  26;
		7'b0010110: addr =  27;
		7'b0010010: addr =  28;
		7'b0010011: addr =  29;
		7'b0010001: addr =  30;
		7'b0010000: addr =  31;
		7'b0110000: addr =  32;
		7'b0110001: addr =  33;
		7'b0110011: addr =  34;
		7'b0110010: addr =  35;
		7'b0110110: addr =  36;
		7'b0110111: addr =  37;
		7'b0110101: addr =  38;
		7'b0110100: addr =  39;
		7'b0111100: addr =  40;
		7'b0111101: addr =  41;
		7'b0111111: addr =  42;
		7'b0111110: addr =  43;
		7'b0111010: addr =  44;
		7'b0111011: addr =  45;
		7'b0111001: addr =  46;
		7'b0111000: addr =  47;
		7'b0101000: addr =  48;
		7'b0101001: addr =  49;
		7'b0101011: addr =  50;
		7'b0101010: addr =  51;
		7'b0101110: addr =  52;
		7'b0101111: addr =  53;
		7'b0101101: addr =  54;
		7'b0101100: addr =  55;
		7'b0100100: addr =  56;
		7'b0100101: addr =  57;
		7'b0100111: addr =  58;
		7'b0100110: addr =  59;
		7'b0100010: addr =  60;
		7'b0100011: addr =  61;
		7'b0100001: addr =  62;
		7'b0100000: addr =  63;
		7'b1100000: addr =  64;
		7'b1100001: addr =  65;
		7'b1100011: addr =  66;
		7'b1100010: addr =  67;
		7'b1100110: addr =  68;
		7'b1100111: addr =  69;
		7'b1100101: addr =  70;
		7'b1100100: addr =  71;
		7'b1101100: addr =  72;
		7'b1101101: addr =  73;
		7'b1101111: addr =  74;
		7'b1101110: addr =  75;
		7'b1101010: addr =  76;
		7'b1101011: addr =  77;
		7'b1101001: addr =  78;
		7'b1101000: addr =  79;
		7'b1111000: addr =  80;
		7'b1111001: addr =  81;
		7'b1111011: addr =  82;
		7'b1111010: addr =  83;
		7'b1111110: addr =  84;
		7'b1111111: addr =  85;
		7'b1111101: addr =  86;
		7'b1111100: addr =  87;
		7'b1110100: addr =  88;
		7'b1110101: addr =  89;
		7'b1110111: addr =  90;
		7'b1110110: addr =  91;
		7'b1110010: addr =  92;
		7'b1110011: addr =  93;
		7'b1110001: addr =  94;
		7'b1110000: addr =  95;
		7'b1010000: addr =  96;
		7'b1010001: addr =  97;
		7'b1010011: addr =  98;
		7'b1010010: addr =  99;
		7'b1010110: addr =  100;
		7'b1010111: addr =  101;
		7'b1010101: addr =  102;
		7'b1010100: addr =  103;
		7'b1011100: addr =  104;
		7'b1011101: addr =  105;
		7'b1011111: addr =  106;
		7'b1011110: addr =  107;
		7'b1011010: addr =  108;
		7'b1011011: addr =  109;
		7'b1011001: addr =  110;
		7'b1011000: addr =  111;
		7'b1001000: addr =  112;
		7'b1001001: addr =  113;
		7'b1001011: addr =  114;
		7'b1001010: addr =  115;
		7'b1001110: addr =  116;
		7'b1001111: addr =  117;
		7'b1001101: addr =  118;
		7'b1001100: addr =  119;
		7'b1000100: addr =  120;
		7'b1000101: addr =  121;
		7'b1000111: addr =  122;
		7'b1000110: addr =  123;
		7'b1000010: addr =  124;
		7'b1000011: addr =  125;
		7'b1000001: addr =  126;
		7'b1000000: addr =  127;
		default : addr = 0;
    endcase
end
    
endmodule