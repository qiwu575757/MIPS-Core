module bypass(ID_EX_RS, ID_EX_RT, IF_ID_RS, IF_ID_RT, EX_MEM_RD, MEM_WB_RD, EX_MEM_RFWr, MEM_WB_RFWr, 
			BJOp, MUX4Sel, MUX5Sel, MUX8Sel, MUX9Sel);
	input EX_MEM_RFWr, MEM_WB_RFWr, BJOp;
	input[4:0] IF_ID_RS, IF_ID_RT, ID_EX_RS, ID_EX_RT, EX_MEM_RD, MEM_WB_RD;
	output reg[1:0] MUX4Sel, MUX5Sel;
	output reg MUX8Sel, MUX9Sel;

	always@(EX_MEM_RFWr, MEM_WB_RFWr, ID_EX_RS, EX_MEM_RD, MEM_WB_RD)
		if(EX_MEM_RFWr && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == ID_EX_RS))
			MUX4Sel = 2'b01; 	// EX_MEM bypath for RS
		else if(MEM_WB_RFWr && (MEM_WB_RD != 5'd0) && (MEM_WB_RD == ID_EX_RS))
			MUX4Sel = 2'b10;	// MEM_WB bypath for RS
		else
			MUX4Sel = 2'b00;	// NO bypath for RS

	always@(EX_MEM_RFWr, MEM_WB_RFWr, ID_EX_RT, EX_MEM_RD, MEM_WB_RD)
		if(EX_MEM_RFWr && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == ID_EX_RT))
			MUX5Sel = 2'b01; 	// EX_MEM bypath for RT
		else if(MEM_WB_RFWr && (MEM_WB_RD != 5'd0) && (MEM_WB_RD == ID_EX_RT))
			MUX5Sel = 2'b10;	// MEM_WB bypath for RT
		else
			MUX5Sel = 2'b00;	// NO bypath for RT

	always@(EX_MEM_RFWr, IF_ID_RS, IF_ID_RT, EX_MEM_RD, BJOp)
		if (BJOp && EX_MEM_RFWr && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == IF_ID_RS))
			MUX8Sel = 1;		//EX_MEM bypath for RS
		else
			MUX8Sel = 0;		//NO bypath for RS

 	always@(EX_MEM_RFWr, IF_ID_RS, IF_ID_RT, EX_MEM_RD, BJOp)
		if (BJOp && EX_MEM_RFWr && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == IF_ID_RT))
			MUX9Sel = 1;		//EX_MEM bypath for RT
		else
			MUX9Sel = 0;		//NO bypath for RT


endmodule

module stall(ID_EX_RT, EX_MEM_RT, IF_ID_RS, IF_ID_RT, ID_EX_DMRd, ID_PC, EX_PC, EX_MEM_DMRd, PCWr, IF_IDWr, MUX7Sel, BJOp, ID_EX_RFWr,
				ID_EX_CP0Rd, EX_MEM_CP0Rd, rst_sign, inst_sram_en, EX_MEM_ex, EX_MEM_RFWr, EX_MEM_eret_flush, isStall, isbusy, RHL_visit);
	input[4:0] ID_EX_RT, EX_MEM_RT, IF_ID_RS, IF_ID_RT;
	input [31:0] ID_PC, EX_PC;
	input ID_EX_DMRd, EX_MEM_DMRd, BJOp, ID_EX_RFWr, EX_MEM_RFWr;
	input ID_EX_CP0Rd, EX_MEM_CP0Rd, EX_MEM_ex, EX_MEM_eret_flush;
	input rst_sign;
	input isbusy, RHL_visit;
	output reg PCWr, IF_IDWr, MUX7Sel, inst_sram_en;
	output isStall;
	assign isStall=~PCWr;

	always@(ID_EX_RT, IF_ID_RS, IF_ID_RT, ID_EX_DMRd, EX_MEM_RT,EX_MEM_DMRd, BJOp, ID_EX_RFWr, EX_MEM_RFWr, rst_sign,
	        EX_MEM_ex, EX_MEM_eret_flush, isbusy, RHL_visit)
	    if(rst_sign) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(EX_MEM_ex || EX_MEM_eret_flush) begin
			inst_sram_en = 1'b1;
			PCWr = 1'b1;
			IF_IDWr = 1'b1;
			MUX7Sel = 1'b0;
		end
		else if(isbusy && RHL_visit) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if((ID_EX_DMRd || ID_EX_CP0Rd) && ( (ID_EX_RT == IF_ID_RS) || (ID_EX_RT == IF_ID_RT) ) &&(ID_PC != EX_PC)) begin
		    inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if (BJOp && EX_MEM_RFWr && (EX_MEM_DMRd || EX_MEM_CP0Rd) && ( (EX_MEM_RT == IF_ID_RS) || (EX_MEM_RT == IF_ID_RT) ) ) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(BJOp && ID_EX_RFWr && ( (ID_EX_RT == IF_ID_RS) || (ID_EX_RT == IF_ID_RT) ) ) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else begin
			inst_sram_en = 1'b1;
			PCWr = 1'b1;
			IF_IDWr = 1'b1;
			MUX7Sel = 1'b0;
		end

endmodule