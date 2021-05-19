module bypass(
	EX_RS, EX_RT, ID_RS, ID_RT, 
	MEM_RD, WB_RD, MEM_RFWr, 
	WB_RFWr, BJOp, dcache_stall,
	
	MUX4Sel, MUX5Sel, MUX8Sel, MUX9Sel
	);
	input MEM_RFWr, WB_RFWr, BJOp;
	input[4:0] ID_RS, ID_RT, EX_RS, EX_RT, MEM_RD, WB_RD;
	input dcache_stall;

	output reg[1:0] MUX4Sel, MUX5Sel;
	output reg MUX8Sel, MUX9Sel;

	always@(MEM_RFWr, WB_RFWr, EX_RS, MEM_RD, WB_RD)
		if(MEM_RFWr && (MEM_RD != 5'd0) && (MEM_RD == EX_RS))
			MUX4Sel = 2'b01; 	// MEM bypath for RS
		else if((WB_RFWr ) && (WB_RD != 5'd0) && (WB_RD == EX_RS))
			MUX4Sel = 2'b10;	// WB bypath for RS
		else
			MUX4Sel = 2'b00;	// NO bypath for RS

	always@(MEM_RFWr, WB_RFWr, EX_RT, MEM_RD, WB_RD)
		if(MEM_RFWr && (MEM_RD != 5'd0) && (MEM_RD == EX_RT))
			MUX5Sel = 2'b01; 	// MEM bypath for RT
		else if((WB_RFWr ) && (WB_RD != 5'd0) && (WB_RD == EX_RT))
			MUX5Sel = 2'b10;	// WB bypath for RT
		else
			MUX5Sel = 2'b00;	// NO bypath for RT

	always@(MEM_RFWr, ID_RS, ID_RT, MEM_RD, BJOp)
		if (BJOp && MEM_RFWr && (MEM_RD != 5'd0) && (MEM_RD == ID_RS))
			MUX8Sel = 1;		//MEM bypath for RS
		else
			MUX8Sel = 0;		//NO bypath for RS

 	always@(MEM_RFWr, ID_RS, ID_RT, MEM_RD, BJOp)
		if (BJOp && MEM_RFWr && (MEM_RD != 5'd0) && (MEM_RD == ID_RT))
			MUX9Sel = 1;		//MEM bypath for RT
		else
			MUX9Sel = 0;		//NO bypath for RT


endmodule

module stall(
	clk,rst ,
	EX_RT, MEM_RT, ID_RS, ID_RT,
	EX_DMRd, ID_PC, EX_PC, MEM_DMRd, 
	BJOp, EX_RFWr,EX_CP0Rd, MEM_CP0Rd,
	rst_sign, MEM_ex, MEM_RFWr, 
	MEM_eret_flush,isbusy, RHL_visit,
	iCache_data_ok,dCache_data_ok,MEM_dCache_en,

	PCWr, IF_IDWr, MUX7Sel,inst_sram_en,isStall,
	dcache_stall
	);
	input clk,rst;
	input[4:0] EX_RT, MEM_RT, ID_RS, ID_RT;
	input [31:0] ID_PC, EX_PC;
	input EX_DMRd, MEM_DMRd, BJOp, EX_RFWr, MEM_RFWr;
	input EX_CP0Rd, MEM_CP0Rd, MEM_ex, MEM_eret_flush;
	input rst_sign;
	input isbusy, RHL_visit;
	input iCache_data_ok;
	input dCache_data_ok;
	input MEM_dCache_en;
	output reg PCWr, IF_IDWr, MUX7Sel, inst_sram_en;
	output isStall;
	output dcache_stall;

	reg c_state;
	reg n_state;

	parameter state_dcache_free = 1'b0;
	parameter state_dcache_busy = 1'b1;

	always @(posedge clk) begin
		if(!rst)
		begin
			c_state=1'b0;
		end
		else 
			c_state=n_state;
	end
	always @(MEM_dCache_en,dCache_data_ok,c_state) begin
		case (c_state)
		state_dcache_free:
		begin
			if(MEM_dCache_en & ~dCache_data_ok)
				n_state=state_dcache_busy;
			else
				n_state=state_dcache_free;
		end
		state_dcache_busy:
		begin
			if(dCache_data_ok)
				n_state = state_dcache_free;
			else
				n_state=state_dcache_busy;
		end
		endcase
	end
	assign dcache_stall = (~dCache_data_ok&MEM_dCache_en|~iCache_data_ok);
	assign isStall=~PCWr || dcache_stall ;

	always@(EX_RT, ID_RS, ID_RT, EX_DMRd, MEM_RT,MEM_DMRd, BJOp, EX_RFWr, MEM_RFWr, rst_sign,
	        MEM_ex, MEM_eret_flush, isbusy, RHL_visit, EX_CP0Rd, ID_PC, EX_PC, MEM_CP0Rd)
	    if(rst_sign) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(MEM_ex || MEM_eret_flush) begin
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
		else if((EX_DMRd || EX_CP0Rd) && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) && (ID_PC != EX_PC)) begin
		    inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if (BJOp && MEM_RFWr && (MEM_DMRd || MEM_CP0Rd) && ( (MEM_RT == ID_RS) || (MEM_RT == ID_RT) ) ) begin
			inst_sram_en = 1'b0;
			PCWr = 1'b0;
			IF_IDWr = 1'b0;
			MUX7Sel = 1'b1;
		end
		else if(BJOp && EX_RFWr && ( (EX_RT == ID_RS) || (EX_RT == ID_RT) ) ) begin
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