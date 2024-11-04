//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/10
//		Version		: v1.0
//   	File Name   : HAMMING_IP.v
//   	Module Name : HAMMING_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module HAMMING_IP #(parameter IP_BIT = 8) (
    // Input signals
    IN_code,
    // Output signals
    OUT_code
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_BIT+4-1:0]  IN_code;

output reg [IP_BIT-1:0] OUT_code;

// ===============================================================
// wire & reg
// ===============================================================
wire [11-IP_BIT:0] padding;
wire [15:0]        full;
wire [3:0]         correct;
reg  [10:0]  decode;

// ===============================================================
// Design
// ===============================================================
assign padding = 0;
assign full = {IN_code, padding};

assign correct[0] = full[15] ^ full[13] ^ full[11] ^ full[9] ^ full[7] ^ full[5] ^ full[3] ^ full[1];
assign correct[1] = full[14] ^ full[13] ^ full[10] ^ full[9] ^ full[6] ^ full[5] ^ full[2] ^ full[1];
assign correct[2] = full[12] ^ full[11] ^ full[10] ^ full[9] ^ full[4] ^ full[3] ^ full[2] ^ full[1];
assign correct[3] = full[8]  ^ full[7]  ^ full[6]  ^ full[5] ^ full[4] ^ full[3] ^ full[2] ^ full[1];

always @(*) begin
    decode[0]  = full[1];
    decode[1]  = full[2];
    decode[2]  = full[3];
    decode[3]  = full[4];
    decode[4]  = full[5];
    decode[5]  = full[6];
    decode[6]  = full[7];
    decode[7]  = full[9];
    decode[8]  = full[10];
    decode[9]  = full[11];
    decode[10] = full[13];

    case (correct)
        4'd3: begin
            decode[10] = ~full[13];
        end
        4'd5: begin
            decode[9]  = ~full[11];
        end
        4'd6: begin
            decode[8]  = ~full[10];
        end
        4'd7: begin
            decode[7]  = ~full[9];
        end
        4'd9: begin
            decode[6]  = ~full[7];
        end
        4'd10: begin
            decode[5]  = ~full[6];
        end
        4'd11: begin
            decode[4]  = ~full[5];
        end
        4'd12: begin
            decode[3]  = ~full[4];
        end
        4'd13: begin
            decode[2]  = ~full[3];
        end
        4'd14: begin
            decode[1]  = ~full[2];
        end
        4'd15: begin
            decode[0]  = ~full[1];
        end
    endcase
end

assign OUT_code = (decode >> (11-IP_BIT));

endmodule