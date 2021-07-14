`include "MacroDef.v"

module PC(clk, rst, wr, flush, NPC, PC);
	input clk,rst,wr,flush;
	input[31:0] NPC;

	output reg[31:0] PC;

	always@(posedge clk)
		if(!rst || flush)
			PC <= 32'hbfc0_0000;
		else if(wr)
			PC <= NPC;
endmodule


module PF_IF(
	clk, rst, wr, flush,
	NPC,PF_Exception,PF_ExcCode, PF_icache_valid,

	PC,IF_Exception,IF_ExcCode, flush_signal, IF_icache_valid
);
	input clk, rst, wr,flush;
	input PF_Exception;
	input [4:0] PF_ExcCode;
	input[31:0] NPC;
	input PF_icache_valid;

	output reg [31:0] PC;
	output reg IF_Exception;
	output reg [4:0] IF_ExcCode;
	output reg flush_signal;
	output reg IF_icache_valid;


    always@(posedge clk)
		if(!rst || flush)
		begin
			IF_ExcCode <= 5'b0;
			IF_Exception <= 1'b0;
			PC <= 32'd0;
			IF_icache_valid <= 1'b0;
			flush_signal <= 1'b1;
		end
		else if(wr)
		begin
			IF_ExcCode <= PF_ExcCode;
			IF_Exception <= PF_Exception;
			PC <= NPC;
			IF_icache_valid <= PF_icache_valid;
			flush_signal <= 1'b0;
		end

endmodule


module IF_ID(
	clk, rst,IF_IDWr, IF_Flush, 
	PC, Instr, IF_Exception, IF_ExcCode,

	ID_PC, ID_Instr, Temp_ID_Excetion,Temp_ID_ExcCode
);
	input clk, rst,IF_IDWr, IF_Flush, IF_Exception;
	input[31:0] PC, Instr;
	input [4:0] IF_ExcCode;

	output reg [31:0] ID_PC;
	output reg [31:0] ID_Instr;
	output reg Temp_ID_Excetion;
	output reg [4:0] Temp_ID_ExcCode;

	always@(posedge clk)
		if(!rst || IF_Flush) begin
			ID_PC <= 32'h0000_0000;
			ID_Instr <= 32'h0000_0000;
			Temp_ID_Excetion <= 1'b0;
			Temp_ID_ExcCode <= 5'b0;
		end
		else if(IF_IDWr) begin
			ID_PC <= PC;
			ID_Instr <= Instr;
			Temp_ID_Excetion <= IF_Exception;
			Temp_ID_ExcCode <= IF_ExcCode;
		end

endmodule

module ID_EX(
	clk, rst, ID_EXWr,ID_Flush, RHLSel_Rd, PC, ALU1Op, ALU2Op, MUX1Sel, MUX3Sel, ALU1Sel, DMWr, DMSel, 
	DMRd, RFWr, RHLWr, RHLSel_Wr, MUX2Sel, GPR_RS, GPR_RT, RS, RT, RD, Imm32, shamt, 
	eret_flush, CP0WrEn, Exception, ExcCode, isBD, isBranch, CP0Addr, CP0Rd, start,ID_dcache_en,
	MUX8Sel, MUX9Sel,

	EX_eret_flush, EX_CP0WrEn, EX_Exception, EX_ExcCode, EX_isBD, EX_isBranch, EX_RHLSel_Rd,
	EX_DMWr, EX_DMRd, EX_MUX3Sel, EX_ALU1Sel, EX_RFWr, EX_RHLWr, EX_ALU2Op, EX_MUX1Sel, EX_RHLSel_Wr,
	EX_DMSel, EX_MUX2Sel, EX_ALU1Op, EX_RS, EX_RT, EX_RD, EX_shamt, EX_PC, EX_GPR_RS, EX_GPR_RT, 
	EX_Imm32, EX_CP0Addr, EX_CP0Rd, EX_start,EX_dcache_en,
	MUX4Sel, MUX5Sel
);
	input clk, rst, ID_EXWr,ID_Flush, DMWr, DMRd, MUX3Sel, ALU1Sel, RFWr, RHLWr,RHLSel_Rd;
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
	input[31:0] PC, GPR_RS, GPR_RT, Imm32;
	input [7:0] CP0Addr;
	input CP0Rd;
	input start;
	input ID_dcache_en;
	input[1:0] MUX8Sel, MUX9Sel;

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
	output reg [31:0] EX_PC, EX_GPR_RS, EX_GPR_RT, EX_Imm32;
	output reg [7:0] EX_CP0Addr;
	output reg EX_CP0Rd;
	output reg EX_start;
	output reg EX_dcache_en;
	output reg[1:0] MUX4Sel,MUX5Sel;

	always@(posedge clk)
		if(!rst || ID_Flush) begin
			EX_eret_flush <= 1'b0;
			EX_CP0WrEn <= 1'b0;
			EX_Exception <= 1'b0;
			EX_ExcCode <= 5'd0;
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
			EX_GPR_RS <= 32'd0;
			EX_GPR_RT <= 32'd0;
			EX_Imm32 <= 32'd0;
			EX_CP0Addr <= 32'd0;
			EX_CP0Rd <= 1'b0;
			EX_start <= 1'b0;
			EX_dcache_en<=1'b0;
			MUX4Sel <= 2'b00;
			MUX5Sel <= 2'b00;
		end
		else if(ID_EXWr) 
		begin
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
			EX_GPR_RS <= GPR_RS;
			EX_GPR_RT <= GPR_RT;
			EX_Imm32 <= Imm32;
			EX_CP0Addr <= CP0Addr;
			EX_CP0Rd <= CP0Rd;
			EX_start <= start;
			EX_dcache_en <= ID_dcache_en;
			MUX4Sel <= MUX8Sel;
			MUX5Sel <= MUX9Sel;
		end
endmodule

module EX_MEM1(
		clk, rst, EX_MEM1Wr, Imm32, EX_PC, DMWr, DMSel, DMRd, RFWr, MUX2Sel,RHLOut, 
        ALU1Out, GPR_RT, RD, EX_Flush, eret_flush, CP0WrEn, Exception, ExcCode, isBD,
        CP0Addr, CP0Rd, EX_dcache_en, Overflow,

		MEM1_DMWr, MEM1_DMRd, MEM1_RFWr,MEM1_eret_flush, MEM1_CP0WrEn, MEM1_Exception, MEM1_ExcCode, 
        MEM1_isBD, MEM1_DMSel, MEM1_MUX2Sel, MEM1_RD, MEM1_PC, MEM1_RHLOut, MEM1_ALU1Out, MEM1_GPR_RT, 
        MEM1_Imm32, MEM1_CP0Addr, MEM1_CP0Rd, MEM1_dcache_en, MEM1_Overflow
	);
	input clk, rst, EX_MEM1Wr,EX_Flush, DMWr, DMRd, RFWr;
	input Overflow;
	input eret_flush;
	input CP0WrEn;
	input Exception;
	input [4:0] ExcCode;
	input isBD;
	input[2:0] DMSel, MUX2Sel;
	input[4:0] RD;
	input[31:0] EX_PC, RHLOut,ALU1Out, GPR_RT, Imm32;
	input [7:0] CP0Addr;
	input CP0Rd;
	input EX_dcache_en;

	output reg MEM1_DMWr, MEM1_DMRd, MEM1_RFWr;
	output reg MEM1_eret_flush;
	output reg MEM1_CP0WrEn;
	output reg MEM1_Exception;
	output reg [4:0] MEM1_ExcCode;
	output reg MEM1_isBD;
	output reg[2:0] MEM1_DMSel, MEM1_MUX2Sel;
	output reg[4:0] MEM1_RD;
	output reg[31:0] MEM1_PC, MEM1_RHLOut,MEM1_ALU1Out, MEM1_GPR_RT, MEM1_Imm32;
	output reg [7:0] MEM1_CP0Addr;
	output reg MEM1_CP0Rd;
	output reg MEM1_dcache_en;
	output reg MEM1_Overflow;

	always@(posedge clk)
		if(!rst || EX_Flush) begin
			MEM1_DMWr <= 1'b0;
			MEM1_DMRd <= 1'b0;
			MEM1_RFWr <= 1'b0;
			MEM1_eret_flush <= 1'b0;
			MEM1_CP0WrEn <= 1'b0;
			MEM1_isBD <= 1'b0;
			MEM1_DMSel <= 3'd0;
			MEM1_MUX2Sel <= 3'd0;
			MEM1_RD <= 5'd0;
			MEM1_PC <= 32'd0;
			MEM1_RHLOut <= 32'd0;
			MEM1_ALU1Out <= 32'd0;
			MEM1_GPR_RT <= 32'd0;
			MEM1_Imm32 <= 32'd0;
			MEM1_CP0Addr <= 7'd0;
			MEM1_CP0Rd <= 1'b0;
			MEM1_dcache_en<=1'b0;
			MEM1_ExcCode <= 5'd0;
			MEM1_Exception <= 1'b0;
			MEM1_Overflow <= 1'b0;
		end
		else if (EX_MEM1Wr) begin
			MEM1_DMWr <= DMWr;
			MEM1_DMRd <= DMRd;
			MEM1_RFWr <= RFWr;
			MEM1_eret_flush <= eret_flush;
			MEM1_CP0WrEn <= CP0WrEn;
			MEM1_isBD <= isBD;
			MEM1_DMSel <= DMSel;
			MEM1_MUX2Sel <= MUX2Sel;
			MEM1_RD <= RD;
			MEM1_PC <= EX_PC;
			MEM1_RHLOut <= RHLOut;
			MEM1_ALU1Out <= ALU1Out;
			MEM1_GPR_RT <= GPR_RT;
			MEM1_Imm32 <= Imm32;
			MEM1_CP0Addr <= CP0Addr;
			MEM1_CP0Rd <= CP0Rd;
			MEM1_dcache_en <= EX_dcache_en;
			MEM1_ExcCode <= ExcCode;
			MEM1_Exception <= Exception;
			MEM1_Overflow <= Overflow;
		end

endmodule

module MEM1_MEM2(clk, rst, PC, RFWr,MUX2Sel, MUX6Out, ALU1Out, RD, 
        MEM1_Flush, CP0Out, MEM1_MEM2Wr, DMSel, cache_sel, DMWen, Exception,
        eret_flush, uncache_valid, DMen, Paddr, MEM1_dCache_wstrb, GPR_RT, DMRd, CP0Rd,

		MEM2_RFWr,MEM2_MUX2Sel, MEM2_RD, MEM2_PC, MEM2_ALU1Out, MEM2_MUX6Out, MEM2_CP0Out,
        MEM2_DMSel, MEM2_cache_sel, MEM2_DMWen, MEM2_Exception, MEM2_eret_flush,
		MEM2_uncache_valid, MEM2_DMen,
        MEM2_Paddr, MEM2_unCache_wstrb, MEM2_GPR_RT, MEM2_DMRd, MEM2_CP0Rd
		);
	input clk;
	input rst;
	input MEM1_Flush;
	input MEM1_MEM2Wr;

	input[31:0] PC;
	input RFWr;
	input[2:0] MUX2Sel;
	input[31:0] MUX6Out;
	input[31:0] ALU1Out;
	input[4:0] RD;
	input[31:0] CP0Out;
	input[2:0] DMSel;
	input cache_sel;
	input DMWen;
	input Exception;
	input eret_flush;
	input uncache_valid;
	input DMen;
	input[31:0] Paddr;
	input[3:0] MEM1_dCache_wstrb;
	input[31:0] GPR_RT;
	input DMRd;
	input CP0Rd;

	output reg[31:0] MEM2_PC;
	output reg MEM2_RFWr;
	output reg[2:0] MEM2_MUX2Sel;
	output reg[31:0] MEM2_MUX6Out;
	output reg[31:0] MEM2_ALU1Out;	
	output reg[4:0] MEM2_RD;
	output reg[31:0] MEM2_CP0Out;
	output reg[2:0] MEM2_DMSel;
	output reg MEM2_cache_sel;
	output reg MEM2_DMWen;
	output reg MEM2_Exception;
	output reg MEM2_eret_flush;
	output reg MEM2_uncache_valid;
	output reg MEM2_DMen;
	output reg[31:0] MEM2_Paddr;
	output reg[3:0] MEM2_unCache_wstrb;
	output reg[31:0] MEM2_GPR_RT;
	output reg MEM2_DMRd;
	output reg MEM2_CP0Rd;

	always@(posedge clk)
		if(!rst || MEM1_Flush) begin
			MEM2_PC <= 32'd0;
			MEM2_RFWr <= 1'b0;
			MEM2_MUX2Sel <= 3'd0;
			MEM2_MUX6Out <= 32'd0;
			MEM2_ALU1Out <= 32'd0;
			MEM2_RD <= 5'd0;
			MEM2_CP0Out <= 32'd0;
			MEM2_DMSel <= 3'd0;
			MEM2_cache_sel <= 1'b0;
			MEM2_DMWen <= 1'b0;
			MEM2_Exception <= 1'b0;
			MEM2_eret_flush <= 1'b0;
			MEM2_uncache_valid <= 1'b0;
			MEM2_DMen <= 1'b0;
			MEM2_Paddr <= 32'd0;
			MEM2_unCache_wstrb <= 4'd0;
			MEM2_GPR_RT <= 32'd0;
			MEM2_DMRd <= 1'b0;
			MEM2_CP0Rd <= 1'b0;
		end
		else if(MEM1_MEM2Wr) begin
			MEM2_PC <= PC;
			MEM2_RFWr <= RFWr;
			MEM2_MUX2Sel <= MUX2Sel;
			MEM2_MUX6Out <= MUX6Out;
			MEM2_ALU1Out <= ALU1Out;	
			MEM2_RD <= RD;
			MEM2_CP0Out <= CP0Out;
			MEM2_DMSel <= DMSel;
			MEM2_cache_sel <= cache_sel;
			MEM2_DMWen <= DMWen;
			MEM2_Exception <= Exception;
			MEM2_eret_flush <= eret_flush;
			MEM2_uncache_valid <= uncache_valid;
			MEM2_DMen <= DMen;
			MEM2_Paddr <= Paddr;
			MEM2_unCache_wstrb <= MEM1_dCache_wstrb;
			MEM2_GPR_RT <= GPR_RT;
			MEM2_DMRd <= DMRd;
			MEM2_CP0Rd <= CP0Rd;
		end
endmodule

module MEM2_WB(
	clk, rst,MEM2_WBWr, MEM2_Flush,
	PC, MUX2Out, MUX2Sel, RD, RFWr, DMOut,

	WB_PC, WB_MUX2Out, WB_MUX2Sel, WB_RD, WB_RFWr, WB_DMOut
	);
	input clk;
	input rst;
	input MEM2_WBWr;
	input MEM2_Flush;


	input[31:0] PC;
	input[31:0] MUX2Out;
	input[2:0] MUX2Sel;
	input[4:0] RD;
	input RFWr;
	input[31:0] DMOut;

	output reg[31:0] WB_PC;
	output reg[31:0] WB_MUX2Out;
	output reg[2:0] WB_MUX2Sel;
	output reg[4:0] WB_RD;
	output reg WB_RFWr;
	output reg[31:0] WB_DMOut;

	always@(posedge clk)
		if(!rst || MEM2_Flush) begin
			WB_PC <= 32'd0;
			WB_MUX2Out <= 32'd0;
			WB_MUX2Sel <= 3'd0;
			WB_RD <= 5'd0;
			WB_RFWr <= 1'b0;
			WB_DMOut <= 32'd0;
		end
		else if(MEM2_WBWr) begin
			WB_PC <= PC;
			WB_MUX2Out <= MUX2Out;
			WB_MUX2Sel <= MUX2Sel;
			WB_RD <= RD;
			WB_RFWr <= RFWr;
			WB_DMOut <= DMOut;
		end

endmodule