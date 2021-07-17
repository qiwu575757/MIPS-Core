module alu1(
	A, B, ALU1Op, ALU1Sel, Shamt, PC,
	
	C,Overflow, PC_8
	);
	input[31:0] A, B;
	input[3:0] ALU1Op;
	input[4:0] Shamt;
	input ALU1Sel;
	input[31:0] PC;
	
	output reg Overflow;
	output reg[31:0] C;
	output[31:0] PC_8;

	wire[4:0] temp;
	wire Less;
	
	assign temp = ALU1Sel ? Shamt : A[4:0];
	assign Less = ((ALU1Op == 4'b1001) && A[31]^B[31]) ? ~(A < B) : (A < B);
	assign PC_8 = PC + 8;

	always@(A, B, ALU1Op, Less, temp)
		/*if(ALU1Op == 4'b1000)begin					//arithmetical right shift
						C = B;
						if(temp[4]) C = {{16{B[31]}},C[31:16]};
						if(temp[3]) C = {{8{B[31]}},C[31:8]};
						if(temp[2]) C = {{4{B[31]}},C[31:4]};
						if(temp[1]) C = {{2{B[31]}},C[31:2]};
						if(temp[0]) C = {B[31],C[31:1]};*
					 end
		else begin*/
		case(ALU1Op)
			4'b0000:	C = A + B;			//add
			4'b1011:	C = A + B;			//addu
			4'b0001:	C = A - B;			//sub
			4'b1100:	C = A - B;			//subu
			4'b0010:	C = A | B;			//or
			4'b0011:	C = A & B;			//and
			4'b0100:	C = ~( A | B );		//nor
			4'b0101:	C = A ^ B;			//xor
			4'b0110:	C = B << temp;		//logical left shift
			4'b0111:	C = B >> temp;		//logical right shift
			4'b1000:	C = $signed(B) >>> temp;//arithmetical right shift
			default:	C = {31'h00000000,Less};//	signed/unsigned compare
		endcase
	
	always@(A,B,C,ALU1Op)
		if(ALU1Op == 4'b0000) begin
			if(A[31] == 1'b1 && B[31] == 1'b1 && C[31] == 1'b0)
				Overflow = 1'b1;
			else if(A[31] == 1'b0 && B[31] == 1'b0 && C[31] == 1'b1)
				Overflow = 1'b1;
			else
				Overflow = 1'b0;
		end
		else if(ALU1Op == 4'b0001) begin 
			if(A[31] == 1'b1 && B[31] == 1'b0 && C[31] == 1'b0)
				Overflow = 1'b1;
			else if(A[31] == 1'b0 && B[31] == 1'b1 && C[31] == 1'b1)
				Overflow = 1'b1;
			else
				Overflow = 1'b0;
		end
		else
			Overflow = 1'b0;

endmodule
