module alu1(
	A, B, ALU1Op, ALU1Sel, Shamt,

	C,Overflow,Trap
	);
	input [31:0]    A;
    input [31:0]    B;
	input [4:0]     ALU1Op;
	input [4:0]     Shamt;
	input           ALU1Sel;

	output reg       Overflow;
	output reg [31:0]C;
    output reg       Trap;

	wire [4:0]      temp;
	wire            Less;
    wire            Trap_Equal;
    wire            Trap_Less;
    wire [31:0]     add_result;
    wire [31:0]     sub_result;
    wire [2:0]      add_overflow;
	wire [2:0]      sub_overflow;
	reg [5:0]       CLO_RESULT;
	reg [5:0]       CLZ_RESULT;

	assign temp = ALU1Sel ? Shamt : A[4:0];
	assign Less = ((ALU1Op == 5'b01001) && A[31]^B[31]) ? ~(A < B) : (A < B);
    
    /*for trap instruction*/
    assign Trap_Equal = A == B;
    assign Trap_Less =
    ( (ALU1Op == 5'b10010 || ALU1Op == 5'b10100) && A[31]^B[31]) ? ~(A < B) : (A < B);//signed/unsigned compare

    assign add_result = A + B;
	assign sub_result = A - B;

	always@(A, B, ALU1Op, Less, temp, CLO_RESULT, CLZ_RESULT)
		case(ALU1Op)
			5'b00000:	C = A + B;			//add
			5'b00001:	C = A - B;			//sub
			5'b00010:	C = A | B;			//or
			5'b00011:	C = A & B;			//and
			5'b00100:	C = ~( A | B );		//nor
			5'b00101:	C = A ^ B;			//xor
			5'b00110:	C = B << temp;		//logical left shift
			5'b00111:	C = B >> temp;		//logical right shift
			5'b01000:	C = $signed(B) >>> temp;//arithmetical right shift
            5'b01100:   C = A + B;			//addui addu
			5'b01011:	C = A;				//movn, movz
			5'b01101:	C = {26'd0,CLO_RESULT};//clo
			5'b01110:	C = {26'd0,CLZ_RESULT};//clz
            5'b10000:   C = A - B;			//subu
			default:	C = {31'h00000000,Less};//	signed/unsigned compare
		endcase

	assign add_overflow = {A[31],B[31],add_result[31]};
	assign sub_overflow = {A[31],B[31],sub_result[31]};

	always@(ALU1Op,add_overflow, sub_overflow)
		case(ALU1Op)
		5'b00000:
			case(add_overflow)
				3'b110, 3'b001:		Overflow = 1'b1;
				default:			Overflow = 1'b0;
			endcase
		5'b00001:
			case(sub_overflow)
				3'b100, 3'b011:		Overflow = 1'b1;
				default:			Overflow = 1'b0;
			endcase
		default:	Overflow = 1'b0;
		endcase


    always @(Trap_Equal,Trap_Less,ALU1Op) begin
        case (ALU1Op)
            5'b10001://teq,teqi
                if (Trap_Equal)
                    Trap = 1'b1;
                else
                    Trap = 1'b0;
            5'b10010,5'b10011://tge,tgei,tgeu,tgeiu
                if (~Trap_Less)
                    Trap = 1'b1;
                else
                    Trap = 1'b0;
            5'b10100,5'b10101://tlt,tlti,tltu,tltiu
                if (Trap_Less)
                    Trap = 1'b1;
                else
                    Trap = 1'b0;
            5'b10110://tne,tnei
                if (~Trap_Equal)
                    Trap = 1'b1;
                else
                    Trap = 1'b0;

            default:Trap = 1'b0;
        endcase
    end

    always@(A) begin
        casez (A)
            32'b0zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd0;
            32'b10zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd1;
            32'b110zzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd2;
            32'b1110zzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd3;
            32'b11110zzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd4;
            32'b111110zzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd5;
            32'b1111110zzzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd6;
            32'b11111110zzzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd7;
            32'b111111110zzzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd8;
            32'b1111111110zzzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd9;
            32'b11111111110zzzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd10;
            32'b111111111110zzzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd11;
            32'b1111111111110zzzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd12;
            32'b11111111111110zzzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd13;
            32'b111111111111110zzzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd14;
            32'b1111111111111110zzzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd15;
            32'b11111111111111110zzzzzzzzzzzzzzz:
                CLO_RESULT = 6'd16;
            32'b111111111111111110zzzzzzzzzzzzzz:
                CLO_RESULT = 6'd17;
            32'b1111111111111111110zzzzzzzzzzzzz:
                CLO_RESULT = 6'd18;
            32'b11111111111111111110zzzzzzzzzzzz:
                CLO_RESULT = 6'd19;
            32'b111111111111111111110zzzzzzzzzzz:
                CLO_RESULT = 6'd20;
            32'b1111111111111111111110zzzzzzzzzz:
                CLO_RESULT = 6'd21;
            32'b11111111111111111111110zzzzzzzzz:
                CLO_RESULT = 6'd22;
            32'b111111111111111111111110zzzzzzzz:
                CLO_RESULT = 6'd23;
            32'b1111111111111111111111110zzzzzzz:
                CLO_RESULT = 6'd24;
            32'b11111111111111111111111110zzzzzz:
                CLO_RESULT = 6'd25;
            32'b111111111111111111111111110zzzzz:
                CLO_RESULT = 6'd26;
            32'b1111111111111111111111111110zzzz:
                CLO_RESULT = 6'd27;
            32'b11111111111111111111111111110zzz:
                CLO_RESULT = 6'd28;
            32'b111111111111111111111111111110zz:
                CLO_RESULT = 6'd29;
            32'b1111111111111111111111111111110z:
                CLO_RESULT = 6'd30;
            32'b11111111111111111111111111111110:
                CLO_RESULT = 6'd31;
            32'b11111111111111111111111111111111:
                CLO_RESULT = 6'd32;
            default:
                CLO_RESULT = 6'd0;
        endcase
    end

    always@(A) begin
        casez (A)
            32'b1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd0;
            32'b01zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd1;
            32'b001zzzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd2;
            32'b0001zzzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd3;
            32'b00001zzzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd4;
            32'b000001zzzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd5;
            32'b0000001zzzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd6;
            32'b00000001zzzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd7;
            32'b000000001zzzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd8;
            32'b0000000001zzzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd9;
            32'b00000000001zzzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd10;
            32'b000000000001zzzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd11;
            32'b0000000000001zzzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd12;
            32'b00000000000001zzzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd13;
            32'b000000000000001zzzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd14;
            32'b0000000000000001zzzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd15;
            32'b00000000000000001zzzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd16;
            32'b000000000000000001zzzzzzzzzzzzzz:
                CLZ_RESULT = 6'd17;
            32'b0000000000000000001zzzzzzzzzzzzz:
                CLZ_RESULT = 6'd18;
            32'b00000000000000000001zzzzzzzzzzzz:
                CLZ_RESULT = 6'd19;
            32'b000000000000000000001zzzzzzzzzzz:
                CLZ_RESULT = 6'd20;
            32'b0000000000000000000001zzzzzzzzzz:
                CLZ_RESULT = 6'd21;
            32'b00000000000000000000001zzzzzzzzz:
                CLZ_RESULT = 6'd22;
            32'b000000000000000000000001zzzzzzzz:
                CLZ_RESULT = 6'd23;
            32'b0000000000000000000000001zzzzzzz:
                CLZ_RESULT = 6'd24;
            32'b00000000000000000000000001zzzzzz:
                CLZ_RESULT = 6'd25;
            32'b000000000000000000000000001zzzzz:
                CLZ_RESULT = 6'd26;
            32'b0000000000000000000000000001zzzz:
                CLZ_RESULT = 6'd27;
            32'b00000000000000000000000000001zzz:
                CLZ_RESULT = 6'd28;
            32'b000000000000000000000000000001zz:
                CLZ_RESULT = 6'd29;
            32'b0000000000000000000000000000001z:
                CLZ_RESULT = 6'd30;
            32'b00000000000000000000000000000001:
                CLZ_RESULT = 6'd31;
            32'b00000000000000000000000000000000:
                CLZ_RESULT = 6'd32;
            default:
                CLZ_RESULT = 6'd0;
        endcase
    end

endmodule
