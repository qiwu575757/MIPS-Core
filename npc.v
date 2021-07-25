module npc(
	IF_PC, Imm, EPC, ret_addr, NPCOp,
	MEM1_eret_flush, MEM1_Exception,
	MEM1_TLBRill_Exc,WB_TLB_flush,MEM2_PC,
	PF_PC, WB_icache_valid_CI,

	NPC
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

	output reg [31:0] NPC;

	always@(*) begin
		if (MEM1_eret_flush)
			NPC = EPC;
		else if (MEM1_Exception)		//TLB Rill and normal exception
			NPC = !MEM1_TLBRill_Exc ? 32'hBFC0_0380 : 32'hBFC0_0200;
		else if (WB_TLB_flush | WB_icache_valid_CI)	//TLBWI TLBR clear up
			NPC = MEM2_PC;
		else begin
			case(NPCOp)
				2'b00:	NPC = PF_PC + 4;								//sequential execution
				2'b01:	if(Imm[15])				//branch,use the delay slot PC 
							NPC = IF_PC + {14'h3fff,Imm[15:0],2'b00};
						else
							NPC = IF_PC + {14'h0000,Imm[15:0],2'b00};
				2'b10:	NPC = { IF_PC[31:28],Imm[25:0],2'b00};			//jump
				default:NPC = ret_addr;								//jump return
			endcase
		end
	end

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