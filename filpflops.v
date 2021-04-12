`include "MacroDef.v"

module pc(clk, rst, wr, D, Q, IF_AdEL, IF_IDWr);
	input clk, rst, wr, IF_IDWr;
	input[31:0] D;
	output reg [31:0] Q;
	output reg IF_AdEL;

	always @(posedge clk or posedge rst) begin
		if (rst)
			IF_AdEL <= 1'b0;
		else if (D[1:0] != 2'b00 && IF_IDWr) begin
			IF_AdEL <= 1'b1;
		end
	end
	
	always@(posedge clk or posedge rst)
		if(rst)
			Q <= 32'h0000_3000;
		else if(wr)
			Q <= D;

endmodule

module IF_ID(clk, rst, IF_IDWr, IF_Flush, PC, Instr, ID_PC, ID_Instr);
	input clk, rst, IF_IDWr, IF_Flush;
	input[31:0] PC, Instr;

	output reg [31:0] ID_PC;
	output reg [31:0] ID_Instr;

	always@(posedge clk or posedge rst)
		if(rst || IF_Flush) begin
			ID_PC <= 32'h0000_0000;
			ID_Instr <= 32'h3400_0000;
		end
		else if(IF_IDWr) begin
			ID_PC <= PC;
			ID_Instr <= Instr;
		end

endmodule

module ID_EX(clk, rst, ID_Flush, RHLSel_Rd, PC, ALU1Op, ALU2Op, MUX1Sel, MUX3Sel, ALU1Sel, DMWr, DMSel, 
			DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, RHLOut, GPR_RS, GPR_RT, RS, RT, RD, Imm32, shamt, 
			eret_flush, CP0WrEn, Exception, ExcCode, isBD, isBranch, CP0Addr, CP0Rd,
			EX_eret_flush, EX_CP0WrEn, EX_Exception, EX_ExcCode, EX_isBD, EX_isBranch, EX_RHLSel_Rd,
	 		EX_DMWr, EX_DMRd, EX_MUX3Sel, EX_ALU1Sel, EX_RFWr, EX_RHLWr, EX_ALU2Op, EX_MUX1Sel, EX_RHLSel_Wr,
	 		EX_DMSel, EX_MUX2Sel, EX_ALU1Op, EX_RS, EX_RT, EX_RD, EX_shamt, EX_PC, EX_RHLOut, EX_GPR_RS, EX_GPR_RT, 
			EX_Imm32, EX_CP0Addr, EX_CP0Rd);
	input clk, rst, ID_Flush, DMWr, DMRd, MUX3Sel, ALU1Sel, RFWr, RHLWr,RHLSel_Rd;
	input eret_flush;
	input CP0WrEn;
	input Exception;
	input [4:0] ExcCode;
	input isBD;
	input isBranch;
	input[1:0] ALU2Op, MUX1Sel, RHLSel_Wr;
	input[2:0] DMSel, MUX2Sel;
	input[3:0] ALU1Op;
	input[4:0] RS, RT, RD, shamt;
	input[31:0] PC, RHLOut, GPR_RS, GPR_RT, Imm32;
	input [7:0] CP0Addr;
	input CP0Rd;

	output reg EX_eret_flush;
	output reg EX_CP0WrEn;
	output reg EX_Exception;
	output reg [4:0] EX_ExcCode;
	output reg EX_isBD;
	output reg EX_isBranch;
	output reg EX_RHLSel_Rd;
	output reg EX_DMWr;
	output reg EX_DMRd;
	output reg EX_MUX3Sel;
	output reg EX_ALU1Sel;
	output reg EX_RFWr;
	output reg EX_RHLWr;
	output reg [1:0] EX_ALU2Op;
	output reg [1:0] EX_MUX1Sel;
	output reg [1:0] EX_RHLSel_Wr;
	output reg [2:0] EX_DMSel;
	output reg [2:0] EX_MUX2Sel;
	output reg [3:0] EX_ALU1Op;
	output reg [4:0] EX_RS;
	output reg [4:0] EX_RT;
	output reg [4:0] EX_RD;
	output reg [4:0] EX_shamt;
	output reg [31:0] EX_PC, EX_RHLOut, EX_GPR_RS, EX_GPR_RT, EX_Imm32;
	output reg [7:0] EX_CP0Addr;
	output reg EX_CP0Rd;
	
	always@(posedge clk or posedge rst)
		if(rst || ID_Flush) begin
			EX_eret_flush <= 1'b0;
			EX_CP0WrEn <= 1'b0;
			EX_Exception <= 1'b0;
			EX_ExcCode <= 5'd15;
			EX_isBD <= 1'b0;
			EX_isBranch <= 1'b0;
			EX_RHLSel_Rd <= 1'b0;
			EX_DMWr <= 1'b0;
			EX_DMRd <= 1'b0;
			EX_MUX3Sel <= 1'b0;
			EX_ALU1Sel <= 1'b0;
			EX_RFWr <= 1'b0;
			EX_RHLWr <= 1'b0;
			EX_ALU2Op <= 2'b00;
			EX_MUX1Sel <= 2'b00;
			EX_RHLSel_Wr <= 2'b00;
			EX_DMSel <= 3'b000;
			EX_MUX2Sel <= 3'b000;
			EX_ALU1Op <= 4'h0;
			EX_RS <= 5'd0;
			EX_RT <= 5'd0;
			EX_RD <= 5'd0;
			EX_shamt <= 5'd0;
			EX_PC <= 32'd0;
			EX_RHLOut <= 32'd0;
			EX_GPR_RS <= 32'd0;
			EX_GPR_RT <= 32'd0;
			EX_Imm32 <= 32'd0;
			EX_CP0Addr <= 32'd0;
			EX_CP0Rd <= 1'b0;
		end
		else begin
			EX_eret_flush <= eret_flush;
			EX_CP0WrEn <= CP0WrEn;
			EX_Exception <= Exception;
			EX_ExcCode <= ExcCode;
			EX_isBD <= isBD;
			EX_isBranch <= isBranch;
			EX_RHLSel_Rd <= RHLSel_Rd;
			EX_DMWr <= DMWr;
			EX_DMRd <= DMRd;
			EX_MUX3Sel <= MUX3Sel;
			EX_ALU1Sel <= ALU1Sel;
			EX_RFWr <= RFWr;
			EX_RHLWr <= RHLWr;
			EX_ALU2Op <= ALU2Op;
			EX_MUX1Sel <= MUX1Sel;
			EX_RHLSel_Wr <= RHLSel_Wr;
			EX_DMSel <= DMSel;
			EX_MUX2Sel <= MUX2Sel;
			EX_ALU1Op <= ALU1Op;
			EX_RS <= RS;
			EX_RT <= RT;
			EX_RD <= RD;
			EX_shamt <= shamt;
			EX_PC <= PC;
			EX_RHLOut <= RHLOut;
			EX_GPR_RS <= GPR_RS;
			EX_GPR_RT <= GPR_RT;
			EX_Imm32 <= Imm32;
			EX_CP0Addr <= CP0Addr;
			EX_CP0Rd <= CP0Rd;
		end
endmodule

module EX_MEM(clk, rst, EX_Flush, OverFlow, Imm32, PC, DMWr, DMSel, DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, 
			ALU2Out, RHLOut, GPR_RS, ALU1Out, GPR_RT, RD, eret_flush, CP0WrEn, Exception, ExcCode, isBD, CP0Addr,
			CP0Rd, 
			MEM_DMWr, MEM_RFWr, MEM_RHLWr, MEM_eret_flush, MEM_CP0WrEn, MEM_Exception, MEM_ExcCode, 
			MEM_isBD, MEM_DMRd, MEM_RHLSel_Wr, MEM_DMSel, MEM_MUX2Sel, MEM_RD, MEM_PC, MEM_RHLOut, MEM_GPR_RS, 
			MEM_ALU1Out, MEM_GPR_RT, MEM_Imm32, MEM_ALU2Out, badvaddr, MEM_CP0Addr, MEM_CP0Rd);
	input clk, rst, EX_Flush, DMWr, DMRd, RFWr, RHLWr;
	input OverFlow;
	input eret_flush;
	input CP0WrEn;
	input Exception;
	input [4:0] ExcCode;
	input isBD;
	input DMRd;
	input[1:0] RHLSel_Wr;
	input[2:0] DMSel, MUX2Sel;
	input[4:0] RD;
	input[31:0] PC, RHLOut, GPR_RS, ALU1Out, GPR_RT, Imm32;
	input[63:0] ALU2Out;
	input [7:0] CP0Addr;
	input CP0Rd;

	output reg MEM_DMWr, MEM_DMRd, MEM_RFWr, MEM_RHLWr;
	output reg  MEM_eret_flush;
	output reg MEM_CP0WrEn;
	output reg MEM_Exception;
	output reg [4:0] MEM_ExcCode;
	output reg MEM_isBD;
	output reg[1:0] MEM_RHLSel_Wr;
	output reg[2:0] MEM_DMSel, MEM_MUX2Sel;
	output reg[4:0] MEM_RD;
	output reg[31:0] MEM_PC, MEM_RHLOut, MEM_GPR_RS, MEM_ALU1Out, MEM_GPR_RT, MEM_Imm32;
	output reg[63:0] MEM_ALU2Out;
	output reg [31:0] badvaddr;
	output reg [7:0] MEM_CP0Addr;
	output reg MEM_CP0Rd;

	always @(posedge clk or posedge rst) begin
		if (rst || EX_Flush) begin
			MEM_ExcCode <= 5'd15;
			MEM_Exception <= 1'b0;
			badvaddr <= 32'd0;
		end
		else if (OverFlow  && !Exception) begin
			MEM_ExcCode <= `Ov;
			MEM_Exception <= 1'b1;
			badvaddr <= PC;
		end
		else if (DMWr && !Exception && (DMSel == 3'b010 && ALU1Out[1:0] != 2'b00 ||
				DMSel == 3'b001 && ALU1Out[0] != 1'b0) )begin
			MEM_ExcCode <= `AdES;
			MEM_Exception <= 1'b1;
			badvaddr <= ALU1Out;
		end
		else if (DMRd && !Exception && (DMSel == 3'b111 && ALU1Out[1:0] != 2'b00 ||
				(DMSel == 3'b101 || DMSel == 3'b110) && ALU1Out[0] != 1'b0) ) begin
			MEM_ExcCode <= `AdEL;
			MEM_Exception <= 1'b1;
			badvaddr <= ALU1Out;
		end
		else begin
			MEM_ExcCode <= ExcCode;
			MEM_Exception <= Exception;
			badvaddr <= PC;
		end
	end

	always@(posedge clk or posedge rst)
		if(rst || EX_Flush) begin
			MEM_DMWr <= 1'b0;
			MEM_DMRd <= 1'b0;
			MEM_RFWr <= 1'b0;
			MEM_RHLWr <= 1'b0;
			MEM_eret_flush <= 1'b0;
			MEM_CP0WrEn <= 1'b0;
			MEM_isBD <= 1'b0;
			MEM_DMRd <= 1'b0;
			MEM_RHLSel_Wr <= 2'd0;
			MEM_DMSel <= 3'd0;
			MEM_MUX2Sel <= 3'd0;
			MEM_RD <= 5'd0;
			MEM_PC <= 32'd0;
			MEM_RHLOut <= 32'd0;
			MEM_GPR_RS <= 32'd0;
			MEM_ALU1Out <= 32'd0;
			MEM_GPR_RT <= 32'd0;
			MEM_Imm32 <= 32'd0;
			MEM_ALU2Out <= 64'd0;
			MEM_CP0Addr <= 7'd0;
			MEM_CP0Rd <= 1'b0;
		end
		else begin
			MEM_DMWr <= DMWr;
			MEM_DMRd <= DMRd;
			MEM_RFWr <= RFWr;
			MEM_RHLWr <= RHLWr;
			MEM_eret_flush <= eret_flush;
			MEM_CP0WrEn <= CP0WrEn;
			MEM_isBD <= isBD;
			MEM_RHLSel_Wr <= RHLSel_Wr;
			MEM_DMSel <= DMSel;
			MEM_MUX2Sel <= MUX2Sel;
			MEM_RD <= RD;
			MEM_PC <= PC;
			MEM_RHLOut <= RHLOut;
			MEM_GPR_RS <= GPR_RS;
			MEM_ALU1Out <= ALU1Out;
			MEM_GPR_RT <= GPR_RT;
			MEM_Imm32 <= Imm32;
			MEM_ALU2Out <= ALU2Out;
			MEM_CP0Addr <= CP0Addr;
			MEM_CP0Rd <= CP0Rd;
		end

endmodule

module MEM_WB(clk, rst, PC, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, ALU2Out, RHLOut, CP0Out, GPR_RS, 
				DMOut, ALU1Out, Imm32, RD, 
				WB_RFWr, WB_RHLWr, WB_RHLSel_Wr, WB_MUX2Sel, WB_RD, WB_PC, WB_ALU1Out, WB_DMOut, 
				WB_RHLOut, WB_Imm32, WB_GPR_RS, WB_CP0Out, WB_ALU2Out);
	input clk, rst, RFWr, RHLWr;
	input[1:0] RHLSel_Wr;
	input[2:0] MUX2Sel;
	input[4:0] RD;
	input[31:0] PC, ALU1Out, DMOut, RHLOut, Imm32, GPR_RS, CP0Out;
	input[63:0] ALU2Out;

	output reg WB_RFWr, WB_RHLWr;
	output reg[1:0] WB_RHLSel_Wr;
	output reg[2:0] WB_MUX2Sel;
	output reg[4:0] WB_RD;
	output reg[31:0] WB_PC, WB_ALU1Out, WB_DMOut, WB_RHLOut, WB_Imm32, WB_GPR_RS, WB_CP0Out;
	output reg[63:0] WB_ALU2Out;
	always@(posedge clk or posedge rst)
		if(rst) begin
			WB_RFWr <= 1'b0;
			WB_RHLWr <= 1'b0;
			WB_RHLSel_Wr <= 2'd0;
			WB_MUX2Sel <= 3'd0;
			WB_RD <= 5'd0;
			WB_PC <= 32'd0;
			WB_ALU1Out <= 32'd0;
			WB_DMOut <= 32'd0;
			WB_RHLOut <= 32'd0;
			WB_Imm32 <= 32'd0;
			WB_GPR_RS <= 32'd0;
			WB_CP0Out <= 32'd0;
			WB_ALU2Out <= 64'd0;
		end
		else begin
			WB_RFWr <= RFWr;
			WB_RHLWr <= RHLWr;
			WB_RHLSel_Wr <= RHLSel_Wr;
			WB_MUX2Sel <= MUX2Sel;
			WB_RD <= RD;
			WB_PC <= PC;
			WB_ALU1Out <= ALU1Out;
			WB_DMOut <= DMOut;
			WB_RHLOut <= RHLOut;
			WB_Imm32 <= Imm32;
			WB_GPR_RS <= GPR_RS;
			WB_CP0Out <= CP0Out;
			WB_ALU2Out <= ALU2Out;
		end
endmodule

