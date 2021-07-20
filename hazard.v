module bypass(
	EX_RS, EX_RT, ID_RS, ID_RT, 
	MEM1_RD, MEM2_RD, WB_RD,
	MEM1_RFWr, MEM2_RFWr, WB_RFWr,
	BJOp, dcache_stall,
	
	MUX4Sel, MUX5Sel, MUX8Sel, MUX9Sel
	);
	input MEM1_RFWr, MEM2_RFWr, WB_RFWr, BJOp;
	input[4:0] ID_RS, ID_RT, EX_RS, EX_RT, MEM1_RD, MEM2_RD, WB_RD;
	input dcache_stall;

	output reg[1:0] MUX4Sel, MUX5Sel;
	output reg[1:0] MUX8Sel, MUX9Sel;

	always@(MEM1_RFWr, MEM2_RFWr, WB_RFWr, EX_RS, MEM1_RD, MEM2_RD, WB_RD)
		if(MEM1_RFWr && (MEM1_RD != 5'd0) && (MEM1_RD == EX_RS))
			MUX4Sel = 2'b01; 	// MEM bypath for RS
		else if((MEM2_RFWr ) && (MEM2_RD != 5'd0) && (MEM2_RD == EX_RS))
			MUX4Sel = 2'b10;	// WB bypath for RS
		else if((WB_RFWr ) && (WB_RD != 5'd0) && (WB_RD == EX_RS))
			MUX4Sel = 2'b11;
		else
			MUX4Sel = 2'b00;	// NO bypath for RS

	always@(MEM1_RFWr, MEM2_RFWr, WB_RFWr, EX_RT, MEM1_RD, MEM2_RD, WB_RD)
		if(MEM1_RFWr && (MEM1_RD != 5'd0) && (MEM1_RD == EX_RT))
			MUX5Sel = 2'b01; 	// MEM bypath for RT
		else if((MEM2_RFWr ) && (MEM2_RD != 5'd0) && (MEM2_RD == EX_RT))
			MUX5Sel = 2'b10;	// WB bypath for RT
		else if((WB_RFWr ) && (WB_RD != 5'd0) && (WB_RD == EX_RT))
			MUX5Sel = 2'b11;
		else
			MUX5Sel = 2'b00;	// NO bypath for RT

	always@(MEM1_RFWr, MEM2_RFWr, ID_RS, ID_RT, MEM1_RD, MEM2_RD, BJOp)
		if (BJOp && MEM1_RFWr && (MEM1_RD != 5'd0) && (MEM1_RD == ID_RS))
			MUX8Sel = 2'b01;		//MEM bypath for RS
		else if(BJOp && MEM2_RFWr && (MEM2_RD != 5'd0) && (MEM2_RD == ID_RS))
			MUX8Sel = 2'b10;
		else
			MUX8Sel = 2'b00;		//NO bypath for RS

 	always@(MEM1_RFWr, MEM2_RFWr, ID_RS, ID_RT, MEM1_RD, MEM2_RD, BJOp)
		if (BJOp && MEM1_RFWr && (MEM1_RD != 5'd0) && (MEM1_RD == ID_RT))
			MUX9Sel = 2'B01;		//MEM bypath for RT
		else if(BJOp && MEM2_RFWr && (MEM2_RD != 5'd0) && (MEM2_RD == ID_RT))
			MUX9Sel = 2'b10;
		else
			MUX9Sel = 0;		//NO bypath for RT


endmodule

module stall(
	clk,rst ,EX_RT, MEM1_RT, MEM2_RT, ID_RS, ID_RT,
	EX_DMRd, ID_PC, EX_PC, MEM1_PC, MEM1_DMRd, MEM2_DMRd, 
	BJOp, EX_RFWr,EX_CP0Rd, MEM1_CP0Rd, MEM2_CP0Rd,rst_sign, 
	MEM1_ex, MEM1_RFWr, MEM2_RFWr,MEM1_eret_flush,isbusy, RHL_visit,
	iCache_data_ok,dCache_data_ok,MEM_dCache_en,MEM_dCache_addr_ok,
    MEM1_cache_sel,MEM1_dCache_en,,ID_tlb_searchen,EX_CP0WrEn,MUL_sign,
	ALU2Op,
	PCWr, IF_IDWr, MUX7Sel,inst_sram_en,isStall,data_ok,
	dcache_stall, ID_EXWr, EX_MEM1Wr, MEM1_MEM2Wr, MEM2_WBWr
);
	input clk,rst;
	input[4:0] EX_RT, MEM1_RT,MEM2_RT, ID_RS, ID_RT;
	input [31:0] ID_PC, EX_PC, MEM1_PC;
	input EX_DMRd, MEM1_DMRd, MEM2_DMRd, BJOp, EX_RFWr, MEM1_RFWr, MEM2_RFWr;
	input EX_CP0Rd, MEM1_CP0Rd, MEM2_CP0Rd, MEM1_ex, MEM1_eret_flush;
	input rst_sign;
	input isbusy, RHL_visit;
	input iCache_data_ok;
	input dCache_data_ok;
	input MEM_dCache_en;
	input MEM1_cache_sel;
	input MEM_dCache_addr_ok;
	input MEM1_dCache_en,ID_tlb_searchen,EX_CP0WrEn;
	input MUL_sign;
	input [3:0] ALU2Op;

	output reg PCWr, IF_IDWr, MUX7Sel, inst_sram_en;
	output isStall;
	output dcache_stall;
	output reg ID_EXWr,EX_MEM1Wr,MEM1_MEM2Wr,MEM2_WBWr;
	output data_ok;

	wire addr_ok;
	wire stall_0, stall_1, stall_2, stall_3;
	wire data_stall;

	assign addr_ok = MEM1_cache_sel | MEM_dCache_addr_ok;
	assign dcache_stall = ((~dCache_data_ok &MEM_dCache_en) | (~addr_ok &MEM1_dCache_en) |~iCache_data_ok);
	assign isStall=~PCWr;
	assign data_ok = dCache_data_ok | ~MEM_dCache_en;

	assign stall_0 = (EX_DMRd || EX_CP0Rd) && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) && (ID_PC != EX_PC);
	assign stall_1 = (MEM1_DMRd || MEM1_CP0Rd) && ( (MEM1_RT == ID_RS) || (MEM1_RT == ID_RT) ) && (ID_PC != MEM1_PC);
	assign stall_2 = BJOp && MEM2_RFWr && (MEM2_DMRd || MEM2_CP0Rd) && ( (MEM2_RT == ID_RS) || (MEM2_RT == ID_RT) );
	assign stall_3 = BJOp && EX_RFWr && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) ;
	assign data_stall = stall_0 | stall_1 | stall_2 | stall_3;

	always@(
		rst_sign,MEM1_ex,MEM1_eret_flush,dcache_stall,isbusy,RHL_visit,
		MUL_sign,ALU2Op,ID_tlb_searchen,EX_CP0WrEn,data_stall
	)
	    if(rst_sign) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else if(MEM1_ex || MEM1_eret_flush) begin
			inst_sram_en = 1'b1;
			PCWr = 1'b1;
			IF_IDWr = 1'b1;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = data_ok;
			MEM2_WBWr = data_ok;
			MUX7Sel = 1'b0;
		end
		else if(dcache_stall) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b0;
			EX_MEM1Wr =1'b0;
			MEM1_MEM2Wr = 1'b0;
			MEM2_WBWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(isbusy && RHL_visit ) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else if (MUL_sign || (ALU2Op==4'b1000 & isbusy)) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b0;
			EX_MEM1Wr =1'b0;
			MEM1_MEM2Wr = 1'b0;
			MEM2_WBWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if (ID_tlb_searchen && EX_CP0WrEn)
		begin
		    inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else if(data_stall) begin
		    inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b1;
		end
		else begin
			inst_sram_en = 1'b1;
			PCWr = 1'b1;
			IF_IDWr = 1'b1;
			ID_EXWr = 1'b1;
			EX_MEM1Wr =1'b1;
			MEM1_MEM2Wr = 1'b1;
			MEM2_WBWr = 1'b1;
			MUX7Sel = 1'b0;
		end

endmodule