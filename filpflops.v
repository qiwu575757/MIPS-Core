module pc(clk, rst, wr, D, Q);
	input clk, rst, wr;
	input[31:0] D;
	output reg[31:0] Q;
	
	always@(posedge clk or posedge rst)
		if(rst)
			Q <= 32'h0000_3000;
		else if(wr)
			Q <= D;

endmodule

module IF_ID(clk, rst, IF_IDWr, IF_Flush, PC, Instr, out);
	input clk, rst, IF_IDWr, IF_Flush;
	input[31:0] PC, Instr;
	output reg[63:0] out;

	always@(posedge clk or posedge rst)
		if(rst || IF_Flush)
			out <= 64'h0000_0000_ffff_ffff;
		else if(IF_IDWr)
			out <= {PC, Instr};

endmodule

module ID_EX(clk, rst, RHLSel_Rd, PC, ALU1Op, ALU2Op, MUX1Sel, MUX3Sel, ALU1Sel, DMWr, DMSel, DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, RHLOut, GPR_RS, GPR_RT, RS, RT, RD, Imm32, shamt, out);
	input clk, rst, DMWr, DMRd, MUX3Sel, ALU1Sel, RFWr, RHLWr,RHLSel_Rd;
	input[1:0] ALU2Op, MUX1Sel, RHLSel_Wr;
	input[2:0] DMSel, MUX2Sel;
	input[3:0] ALU1Op;
	input[4:0] RS, RT, RD, shamt;
	input[31:0] PC, RHLOut, GPR_RS, GPR_RT, Imm32;
	output reg[202:0] out;

	always@(posedge clk or posedge rst)
		if(rst)
			out <= 203'd0;
		else
			out <= {RHLSel_Rd, PC, ALU1Op, ALU2Op, MUX1Sel, MUX3Sel, ALU1Sel, DMWr, DMSel, DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, RHLOut, GPR_RS, GPR_RT, RS, RT, RD, Imm32, shamt};

endmodule

module EX_MEM(clk, rst,Imm32, PC, DMWr, DMSel, DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, ALU2Out, RHLOut, GPR_RS, ALU1Out, GPR_RT, RD, out);
	input clk, rst, DMWr, DMRd, RFWr, RHLWr;
	input[1:0] RHLSel_Wr;
	input[2:0] DMSel, MUX2Sel;
	input[4:0] RD;
	input[31:0] PC, RHLOut, GPR_RS, ALU1Out, GPR_RT, Imm32;
	input[63:0] ALU2Out;
	output reg[272:0] out;

	always@(posedge clk or posedge rst)
		if(rst)
			out <= 273'd0;
		else
			out <= {Imm32, PC, DMWr, DMSel, DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, ALU2Out, RHLOut, GPR_RS, ALU1Out, GPR_RT, RD};

endmodule

module MEM_WB(clk, rst, PC, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, ALU2Out, RHLOut, GPR_RS, DMOut, ALU1Out, Imm32, RD, out);
	input clk, rst, RFWr, RHLWr;
	input[1:0] RHLSel_Wr;
	input[2:0] MUX2Sel;
	input[4:0] RD;
	input[31:0] PC, ALU1Out, DMOut, RHLOut, Imm32, GPR_RS;
	input[63:0] ALU2Out;
	output reg[267:0] out;

	always@(posedge clk or posedge rst)
		if(rst)
			out <= 268'd0;
		else
			out <= {PC, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, ALU2Out, RHLOut, GPR_RS, DMOut, ALU1Out, Imm32, RD};
endmodule

