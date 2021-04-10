module alu1(A, B, C, ALU1Op, ALU1Sel, Shamt, Overflow);
	input[31:0] A, B;
	input[3:0] ALU1Op;
	input[4:0] Shamt;
	input ALU1Sel;
	wire Less;
	output reg Overflow;
	output reg[31:0] C;
	wire[4:0] temp;
	
	assign temp = ALU1Sel ? Shamt : A[4:0];
	assign Less = ((ALU1Op == 4'b1001) && A[31]^B[31]) ? ~(A < B) : (A < B);

	always@(A, B, ALU1Op, Less, temp)
		case(ALU1Op)
			4'b0000:	C = A + B;			//add
			4'b0001:	C = A - B;			//sub
			4'b0010:	C = A | B;			//or
			4'b0011:	C = A & B;			//and
			4'b0100:	C = ~( A | B );		//nor
			4'b0101:	C = A ^ B;			//xor
			4'b0110:	C = B << temp;		//logical left shift
			4'b0111:	C = B >> temp;		//logical right shift
			4'b1000:begin					//arithmetical right shift
						C = B;
						if(B[31]) begin
							if(temp[4]) C = {16'hffff,C[31:16]};
							if(temp[3]) C = {8'hff,C[31:8]};
							if(temp[2]) C = {4'hf,C[31:4]};
							if(temp[1]) C = {2'h3,C[31:2]};
							if(temp[0]) C = {1'h1,C[31:1]};
						end
						else begin
							if(temp[4]) C = {16'h0000,C[31:16]};
							if(temp[3]) C = {8'h00,C[31:8]};
							if(temp[2]) C = {4'h0,C[31:4]};
							if(temp[1]) C = {2'h0,C[31:2]};
							if(temp[0]) C = {1'h0,C[31:1]};
						end
					 end
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

module alu2(A, B, C, ALU2Op);
	input[31:0] A, B;
	input[1:0] ALU2Op;
	output reg[63:0] C;
	wire[31:0] Q1, R1, Q2, R2, oriA,oriB;
	wire[63:0] tempA, tempB;

	assign tempA = A[31] ? {32'hffffffff,A} : {32'h00000000,A};
	assign tempB = B[31] ? {32'hffffffff,B} : {32'h00000000,B};
	assign oriA = A[31] ? (~ A + 1) : A;
	assign oriB = B[31] ? (~ B + 1) : B;

	assign Q1 = A / B;
	assign R1 = A % B;
	assign Q2 = A[31]^B[31] ? (~(oriA / oriB) + 1) : (oriA / oriB);
	assign R2 = A[31] ? (~(oriA % oriB) + 1) : (oriA % oriB);

	always@(A, B, ALU2Op, tempA, tempB, R1, Q1, R2, Q2)
		case(ALU2Op)
			2'b00: C = A * B;
			2'b01: C = tempA * tempB;
			2'b10: C = {R1,Q1};
			2'b11: C = {R2,Q2};
			default: C = 32'hffffffff;
		endcase
endmodule
