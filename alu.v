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
			4'b1011:	C = A + B;			//addu
			4'b0001:	C = A - B;			//sub
			4'b1100:	C = A - B;			//subu
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
