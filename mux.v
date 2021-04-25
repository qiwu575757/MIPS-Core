module mux1(RT, RD, MUX1Sel, Addr3);
	input[4:0] RT, RD;
	input[1:0] MUX1Sel;
	output reg[4:0] Addr3;

	always@(RT, RD, MUX1Sel)
		case(MUX1Sel)
			2'b00:	Addr3 = RT;	//rt
			2'b01:	Addr3 = RD;	//rd
			default:Addr3 = 5'h1f;			//31
		endcase

endmodule

module mux2(ALU1Out, RHLOut, DMOut, PC, Imm32, CP0Out, MUX2Sel, WD);
	input[31:0] ALU1Out, RHLOut, DMOut, PC, Imm32, CP0Out;
	input[2:0] MUX2Sel;
	output reg[31:0] WD;

	always@(ALU1Out, RHLOut, DMOut, PC, Imm32, MUX2Sel)
		case(MUX2Sel)
			3'b000:	WD = RHLOut;
			3'b001:	WD = Imm32;
			3'b010:	WD = ALU1Out;
			3'b011:	WD = PC + 8;
			3'b101: WD = CP0Out;
			default:WD = DMOut;
		endcase

endmodule

module mux3(RD2, Imm32, MUX3Sel, B);
	input[31:0] RD2,Imm32;
	input MUX3Sel;
	output reg[31:0] B;

	always@(RD2, Imm32, MUX3Sel)
		case(MUX3Sel)
			1'b0:	B = RD2;
			default:B = Imm32;
		endcase	

endmodule

module mux4(GPR_RS, data_EX, data_MEM, MUX4Sel, out);
	input[31:0] GPR_RS, data_EX, data_MEM;
	input[1:0] MUX4Sel;
	output reg[31:0] out;

	always@(GPR_RS, data_EX, data_MEM, MUX4Sel)
		case(MUX4Sel)
			2'b00:	out = GPR_RS;
			2'b01:	out = data_EX;
			default:out = data_MEM;
		endcase

endmodule

module mux5(GPR_RT, data_EX, data_MEM, MUX5Sel, out);
	input[31:0] GPR_RT, data_EX, data_MEM;
	input[1:0] MUX5Sel;
	output reg[31:0] out;

	always@(GPR_RT, data_EX, data_MEM, MUX5Sel)
		case(MUX5Sel)
			2'b00:	out = GPR_RT;
			2'b01:	out = data_EX;
			default:out = data_MEM;
		endcase

endmodule

module mux6(RHLOut, ALU1Out, PC, Imm32, MUX6Sel, out);
	input[31:0] RHLOut, ALU1Out, PC, Imm32;
	input[1:0] MUX6Sel;
	output reg[31:0] out;
	
	always@(RHLOut, ALU1Out, PC, Imm32, MUX6Sel)
		case(MUX6Sel)
			2'b00:	out = RHLOut;
			2'b01:	out = Imm32;
			2'b10:	out = ALU1Out;
			default:out = PC + 4;
		endcase

endmodule

module mux7(WRSign, MUX7Sel, MUX7Out);
	input[2:0] WRSign;
	input MUX7Sel;
	output[2:0] MUX7Out;

	assign MUX7Out = MUX7Sel ? 3'b000 : WRSign;
 
endmodule

module mux8(GPR_RS, data_MEM, MUX8Sel, out);
	input[31:0] GPR_RS, data_MEM;
	input MUX8Sel;
	output[31:0] out;
	
	assign out = MUX8Sel ? data_MEM : GPR_RS;
endmodule 

module mux9(GPR_RT, data_MEM, MUX9Sel, out);
	input[31:0] GPR_RT, data_MEM;
	input MUX9Sel;
	output[31:0] out;
	
	assign out = MUX9Sel ? data_MEM : GPR_RT;
endmodule 

