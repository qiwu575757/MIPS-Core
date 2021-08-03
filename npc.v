module npc(
	IF_PC, Imm, EPC, ret_addr, NPCOp,
	MEM1_eret_flush, MEM1_Exception,
	MEM1_TLBRill_Exc,WB_TLB_flush,MEM2_PC,
	PF_PC, WB_icache_valid_CI,Status_BEV,
	Status_EXL,Cause_IV,Interrupt,
	branch, target_addr, PF_Instr_Flush,

	NPC, Instr_Flush
	);

	input [31:0] 	IF_PC;
	input [31:0] 	PF_PC;
	input [31:0] 	ret_addr;
	input [31:0] 	EPC;
	input [25:0] 	Imm;
	input [1:0] 	NPCOp;
	input 			MEM1_eret_flush;
	input 			MEM1_Exception;
	input 			MEM1_TLBRill_Exc;
	input 			WB_TLB_flush;
	input [31:0] 	MEM2_PC;
	input			WB_icache_valid_CI;
	input 			Status_BEV;
	input 			Status_EXL;
	input 			Cause_IV;
	input 			Interrupt;
	input			branch;
	input [31:0]	target_addr;
	input			PF_Instr_Flush;

	output reg [31:0] 	NPC;
	output				Instr_Flush;	
	wire  branch_error;

	reg [31:0] NPC_temp;

	always@(*) begin
		if (MEM1_eret_flush)
			NPC = EPC;
		else if (MEM1_Exception)	//use the standard mips structure
		begin
			if ( Interrupt )
				case ({Status_BEV,Status_EXL,Cause_IV})
					3'b000:		NPC = 32'h8000_0180;
					3'b001:		NPC = 32'h8000_2000;
					3'b100:		NPC = 32'hBFC0_0380;
					3'b101:		NPC = 32'hBFC0_0400;
					3'b010,3'b011:
								NPC = 32'h8000_0180;
					default:	NPC = 32'hBFC0_0380;
				endcase
			else if ( MEM1_TLBRill_Exc )
				case ({Status_BEV,Status_EXL})
					2'b00:		NPC = 32'h8000_0000;
					2'b01:		NPC = 32'h8000_0180;
					2'b10:		NPC = 32'hBFC0_0200;
					2'b11:		NPC = 32'hBFC0_0380;
				endcase
			else
				if ( ~Status_BEV )
						NPC = 32'h8000_0180;
				else
						NPC = 32'hBFC0_0380;
		end
		else if (WB_TLB_flush | WB_icache_valid_CI)	//TLBWI TLBR clear up
			NPC = MEM2_PC;
		else if (branch_error)
			NPC = NPC_temp;
		else if (branch && !PF_Instr_Flush)
			NPC = target_addr;
		else
			NPC = PF_PC + 4;
	end

	always @(*) begin
		case (NPCOp)
			2'b00:	NPC_temp = IF_PC + 4;
			2'b01:	NPC_temp = IF_PC + {{14{Imm[15]}},Imm[15:0],2'b00};
			2'b10:	NPC_temp = { IF_PC[31:28],Imm[25:0],2'b00};
			default: NPC_temp = ret_addr;
		endcase
	end

	assign branch_error = (NPC_temp != PF_PC) && !PF_Instr_Flush;
	assign Instr_Flush = branch_error | MEM1_Exception | MEM1_eret_flush | WB_TLB_flush;

endmodule


module flush(
	MEM1_eret_flush, MEM1_Exception, can_go,

	PC_Flush,PF_Flush,IF_Flush,ID_Flush,
	EX_Flush,MEM1_Flush,MEM2_Flush
	);
	input 			MEM1_eret_flush;
	input 			MEM1_Exception;
	input 			can_go;

	output 			IF_Flush;
	output 			ID_Flush;
	output 			EX_Flush;
	output 			PC_Flush;
	output 			MEM1_Flush;
	output 			MEM2_Flush;
	output 			PF_Flush;

	assign IF_Flush =  (MEM1_eret_flush | MEM1_Exception) ;
	assign ID_Flush = (MEM1_eret_flush | MEM1_Exception) ;
	assign EX_Flush = (MEM1_eret_flush | MEM1_Exception) ;
	assign MEM1_Flush = (MEM1_eret_flush | MEM1_Exception) &can_go;
	assign PC_Flush = 1'b0 ;
	assign MEM2_Flush = 1'b0;
	assign PF_Flush = 1'b0 ;

endmodule