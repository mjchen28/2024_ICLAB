module Handshake_syn #(parameter WIDTH=8) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output reg sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output reg flag_handshake_to_clk1;
input flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------
reg             sreq_ns, dack_ns, dvalid_ns, sidle_ns;
reg [WIDTH-1:0] inter_data_cs, inter_data_ns;
reg [WIDTH-1:0] dout_ns;

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
//======================================================================//
//                                  FFs                                 //
//======================================================================//
// source clock domain
always @ (posedge sclk or negedge rst_n) begin  
	if(!rst_n) begin
        inter_data_cs <= 0;
        sreq <= 0;
        sidle <= 1;
    end 
	else begin 
		inter_data_cs <= inter_data_ns;
        sreq <= sreq_ns;
        sidle <= sidle_ns;
	end
end

// destination clock domain
always @ (posedge dclk or negedge rst_n) begin 
	if(!rst_n) begin
        dout <= 0;
        dvalid <= 0;
        dack <= 0;
    end
	else begin 
		dout <= dout_ns;
        dvalid <= dvalid_ns;
        dack <= dack_ns;
	end
end
//======================================================================//
//                              COMB LOGICS                             //
//======================================================================//
NDFF_syn NDFF0 (.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));
NDFF_syn NDFF1 (.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

// clock domain 1
// sidle_ns logic
always @(*) begin
    if(sready) sidle_ns = 0;
    else if(!sreq && !sack)       sidle_ns = 1;
    else                sidle_ns = sidle;
end

// sreq_ns logic
always @(*) begin
    if(sready)    sreq_ns = 1;
    else if(sack) sreq_ns = 0;
    else          sreq_ns = sreq;
end

// inter_data_ns logic
always @(*) begin
    if(sidle && sready) inter_data_ns = din;
    else                inter_data_ns = inter_data_cs;
end

// clock domain 2
// dack_ns logic
always @(*) begin
    if(dreq && dbusy)   dack_ns = 1;
    else if(!dreq)      dack_ns = 0;
    else                dack_ns = dack;
end

// dvalid logic
always @(*) begin
    if(dvalid == 1) dvalid_ns = 0;
    else if(dreq && !dbusy) dvalid_ns = 1;
    else dvalid_ns = 0;
end

// dout_ns logic
always @(*) begin
    if(dreq && !dack && !dbusy) dout_ns = inter_data_cs;
    else                        dout_ns = dout;
end

// modify
always @(*) begin
    flag_handshake_to_clk1 = 0;
end
assign flag_handshake_to_clk2 = dreq;

// user guide:
// if(sidle == 1) set sready=1 and input the transmitting data
// else           IDLE

endmodule