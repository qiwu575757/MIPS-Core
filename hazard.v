module bypass(
	ID_RS, ID_RT,
	MEM1_RD, MEM2_RD, WB_RD,
	MEM1_RFWr, MEM2_RFWr, WB_RFWr,
	BJOp, dcache_stall,ALU1Op,MEM1_SC_signal,
	EX_RFWr, EX_RD,

	MUX4Sel, MUX5Sel, MUX8Sel, MUX9Sel
	);
	input MEM1_RFWr, MEM2_RFWr, WB_RFWr, EX_RFWr, BJOp;
	input[4:0] ID_RS, ID_RT, MEM1_RD, MEM2_RD, WB_RD, EX_RD;
	input dcache_stall;
	input [4:0] ALU1Op;
	input MEM1_SC_signal;

	output reg[1:0] MUX4Sel, MUX5Sel;
	output reg[1:0] MUX8Sel, MUX9Sel;


	always@(EX_RFWr, MEM1_RFWr, MEM2_RFWr, ID_RS, MEM1_RD, MEM2_RD, EX_RD)
		if(EX_RFWr && (EX_RD == ID_RS))
			MUX4Sel = 2'b01;		//EX->ID/MEM1->EX for RS
		else if (MEM1_RFWr && (MEM1_RD == ID_RS))
			MUX4Sel = 2'b10;		//MEM1->ID/MEM2->EX for RS
		else if(MEM2_RFWr && (MEM2_RD == ID_RS))
			MUX4Sel = 2'b11;		//MEM2->ID/WB->EX for RS
		else
			MUX4Sel = 2'b00;		//NO bypass for RS

 	always@(EX_RFWr, MEM1_RFWr, MEM2_RFWr, ID_RT, MEM1_RD, MEM2_RD, EX_RD)
	 	if(EX_RFWr && (EX_RD == ID_RT))
			MUX5Sel = 2'b01;		//EX->ID/MEM1->EX for RT
		else if (MEM1_RFWr && (MEM1_RD == ID_RT))
			MUX5Sel = 2'b10;		//MEM1->ID/MEM2->EX for RT
		else if(MEM2_RFWr && (MEM2_RD == ID_RT))
			MUX5Sel = 2'b11;		//MEM2->ID/WB->EX for RT
		else
			MUX5Sel = 2'b00;		//NO bypass for RT

	always@(WB_RFWr, MEM1_RFWr, MEM2_RFWr, ID_RS, MEM1_RD, MEM2_RD, WB_RD)
		if (MEM1_RFWr && (MEM1_RD == ID_RS))
			MUX8Sel = 2'b10;		//MEM1->ID for RS
		else if(MEM2_RFWr && (MEM2_RD == ID_RS))
			MUX8Sel = 2'b11;		//MEM2->ID for RS
		else if(WB_RFWr && (WB_RD == ID_RS))
			MUX8Sel = 2'b01;		//WB->ID for RS
		else
			MUX8Sel = 2'b00;		//NO bypass for RS

 	always@(WB_RFWr, MEM1_RFWr, MEM2_RFWr, ID_RT, MEM1_RD, MEM2_RD, WB_RD)
		if (MEM1_RFWr && (MEM1_RD == ID_RT))
			MUX9Sel = 2'b10;		//MEM1->ID for RT
		else if(MEM2_RFWr && (MEM2_RD == ID_RT))
			MUX9Sel = 2'b11;		//MEM2->ID for RT
		else if(WB_RFWr && (WB_RD == ID_RT))
			MUX9Sel = 2'b01;		//WB->ID for RT
		else
			MUX9Sel = 2'b00;		//NO bypass for RT
endmodule

module stall(
	clk,rst ,EX_RT, MEM1_RT, MEM2_RT, ID_RS, ID_RT,
	EX_DMRd, ID_PC, EX_PC, MEM1_PC, MEM1_DMRd, MEM2_DMRd,
	BJOp, EX_RFWr,EX_CP0Rd, MEM1_CP0Rd, MEM2_CP0Rd,rst_sign,
	MEM1_ex, MEM1_RFWr, MEM2_RFWr,MEM1_eret_flush,isbusy, RHL_visit,
	iCache_data_ok,dCache_data_ok,MEM_dCache_en,MEM_dCache_addr_ok,
    MEM1_cache_sel,MEM1_dCache_en,ID_tlb_searchen,EX_CP0WrEn,MUL_sign,
	ALU2Op,EX_SC_signal,MEM1_SC_signal,MEM1_WAIT_OP,Interrupt,

	PCWr, IF_IDWr, MUX7Sel,icache_stall,isStall,data_ok,
	dcache_stall,ID_EXWr,EX_MEM1Wr,MEM1_MEM2Wr,MEM2_WBWr,PF_IFWr
);
	input 			clk;
	input 			rst;
	input [4:0] 	EX_RT;
	input [4:0] 	MEM1_RT;
	input [4:0] 	MEM2_RT;
	input [4:0] 	ID_RS;
	input [4:0] 	ID_RT;
	input [31:0] 	ID_PC;
	input [31:0] 	EX_PC;
	input [31:0] 	MEM1_PC;
	input 			EX_DMRd;
	input 			MEM1_DMRd;
	input 			MEM2_DMRd;
	input 			BJOp;
	input 			EX_RFWr;
	input 			MEM1_RFWr;
	input 			MEM2_RFWr;
	input 			EX_CP0Rd;
	input 			MEM1_CP0Rd;
	input 			MEM2_CP0Rd;
	input 			MEM1_ex;
	input 			MEM1_eret_flush;
	input 			rst_sign;
	input 			isbusy;
	input 			RHL_visit;
	input 			iCache_data_ok;
	input 			dCache_data_ok;
	input 			MEM_dCache_en;
	input 			MEM1_cache_sel;
	input 			MEM_dCache_addr_ok;
	input 			MEM1_dCache_en;
	input 			ID_tlb_searchen;
	input 			EX_CP0WrEn;
	input 			MUL_sign;
	input [3:0] 	ALU2Op;
	input 			EX_SC_signal;
	input 			MEM1_SC_signal;
	input 			MEM1_WAIT_OP;
	input 			Interrupt;

	output reg 		PCWr;
	output reg 		IF_IDWr;
	output reg 		MUX7Sel;
	output	 		icache_stall;
	output 			isStall;
	output 			dcache_stall;
	output reg 		ID_EXWr;
	output reg 		EX_MEM1Wr;
	output reg 		MEM1_MEM2Wr;
	output reg 		MEM2_WBWr;
	output reg 		PF_IFWr;
	output 			data_ok;

	wire 			addr_ok;
	wire 			stall_0;
	wire 			stall_1;
	wire 			stall_2;
	wire 			data_stall;
	wire 			WAIT;

	assign addr_ok = MEM1_cache_sel | MEM_dCache_addr_ok;
	assign dcache_stall = (~dCache_data_ok |~iCache_data_ok);
	assign isStall=~PCWr;
	assign data_ok = dCache_data_ok;
	assign icache_stall = ~dCache_data_ok | WAIT | (isbusy && RHL_visit) | MUL_sign | (ALU2Op==4'b1000 & isbusy)
							| (ID_tlb_searchen && EX_CP0WrEn) | data_stall;

	//assign stall_0 = (EX_DMRd || EX_CP0Rd || EX_SC_signal || BJOp || ALU2Op==5'b01011) && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) && (ID_PC != EX_PC);
	//assign stall_1 = (MEM1_DMRd || MEM1_CP0Rd || MEM1_SC_signal) && ( (MEM1_RT == ID_RS) || (MEM1_RT == ID_RT) ) && (ID_PC != MEM1_PC);
	//assign stall_2 = (BJOp || ALU2Op==5'b01011) && MEM2_RFWr && (MEM2_DMRd) && ( (MEM2_RT == ID_RS) || (MEM2_RT == ID_RT)  && (MEM2_RT != 5'b0));
	//assign stall_3 = (BJOp || ALU2Op==5'b01011) && EX_RFWr && !EX_SC_signal && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) && (EX_RT != 5'b0);

	assign stall_0 = (EX_DMRd | EX_CP0Rd | BJOp | EX_SC_signal) & ((EX_RT == ID_RS) | (EX_RT == ID_RT) ) & EX_RFWr;
	assign stall_1 = (MEM1_DMRd | BJOp&(MEM1_CP0Rd | MEM1_SC_signal)) & ((MEM1_RT == ID_RS) | (MEM1_RT == ID_RT) ) & MEM1_RFWr;
	assign stall_2 = (BJOp  & MEM2_DMRd ) & ((MEM2_RT == ID_RS) | (MEM2_RT == ID_RT)) & MEM2_RFWr;

	assign data_stall = stall_0 | stall_1 | stall_2;
	assign WAIT = MEM1_WAIT_OP & ~Interrupt;

	always@( * )
		if(MEM1_ex || MEM1_eret_flush) begin
			PF_IFWr = 1'b1;
			PCWr = 1'b1;
			IF_IDWr = 1'b1;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = data_ok;
			MEM2_WBWr = data_ok;
			MUX7Sel = 1'b0;
		end
		else if(dcache_stall || WAIT) begin
			PCWr = 1'b0;
			PF_IFWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b0;
			EX_MEM1Wr =1'b0;
			MEM1_MEM2Wr = 1'b0;
			MEM2_WBWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(isbusy && RHL_visit ) begin
			PCWr = 1'b0;
			PF_IFWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else if (MUL_sign || (ALU2Op==4'b1000 & isbusy)) begin
			PCWr = 1'b0;
			PF_IFWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b0;
			EX_MEM1Wr =1'b0;
			MEM1_MEM2Wr = 1'b0;
			MEM2_WBWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if (ID_tlb_searchen && EX_CP0WrEn) begin
			PCWr = 1'b0;
			PF_IFWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else if(data_stall) begin
			PCWr = 1'b0;
			PF_IFWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else begin
			PCWr = 1'b1;
			PF_IFWr = 1'b1;
			IF_IDWr = 1'b1;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b0;
		end

endmodule