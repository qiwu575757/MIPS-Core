module npc(
	PC, Imm, EPC, ret_addr, NPCOp, 
	MEM_eret_flush, MEM_ex, PCWr,
	MEM1_TLBRill_Exc,WB_TLB_flush,MEM2_PC,

	NPC, IF_Flush,ID_Flush, EX_Flush, 
	PC_Flush, MEM1_Flush, MEM2_Flush
	);

	input[31:0] PC, ret_addr, EPC;
	input[25:0] Imm;
	input[1:0] NPCOp;
	input PCWr;
	input MEM_eret_flush;
	input MEM_ex,MEM1_TLBRill_Exc,WB_TLB_flush,MEM2_PC;

	output reg[31:0] NPC;
	output IF_Flush;
	output ID_Flush;
	output EX_Flush;
	output PC_Flush;
	output MEM1_Flush;
	output MEM2_Flush;

	always@(PC,Imm,ret_addr,NPCOp, MEM_eret_flush, MEM_ex, EPC) begin
		if (MEM_eret_flush)
			NPC = EPC + 4;
		else if (MEM_ex)		//TLB Rill and normal exception
			NPC = !MEM1_TLBRill_Exc ? 32'hBFC0_0380 : 32'hBFC0_0200;
		else if (WB_TLB_flush)	//TLBWI TLBR clear up
			NPC = MEM2_PC;
		else begin
			case(NPCOp)
				2'b00:	NPC = PC + 4;									//sequential execution
				2'b01:	if(Imm[15])									//branch
							NPC = PC + {14'h3fff,Imm[15:0],2'b00};
						else
							NPC = PC + {14'h0000,Imm[15:0],2'b00};
				2'b10:	NPC = { PC[31:28],Imm[25:0],2'b00};				//jump
				default:NPC = ret_addr;									//jump return
			endcase
		end
	end

	assign IF_Flush =  (MEM_eret_flush || MEM_ex) ;
	assign ID_Flush = (MEM_eret_flush || MEM_ex) ;
	assign EX_Flush = (MEM_eret_flush || MEM_ex) ;
	assign MEM1_Flush = 1'b0;
	assign PC_Flush = (((NPCOp != 2'b00) && PCWr) || MEM_eret_flush || MEM_ex) ;
	assign MEM2_Flush = 1'b0;
	
endmodule
