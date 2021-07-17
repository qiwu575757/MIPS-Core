module npc(
	IF_PC, PF_PC, Imm, EPC, ret_addr, NPCOp, 
	MEM_eret_flush, MEM_ex,

	NPC
	);

	input[31:0] IF_PC, ret_addr, EPC, PF_PC;
	input[25:0] Imm;
	input[1:0] NPCOp;
	input MEM_eret_flush;
	input MEM_ex;

	output reg[31:0] NPC;

	always@(IF_PC,PF_PC, Imm,ret_addr,NPCOp, MEM_eret_flush, MEM_ex, EPC) begin
		if (MEM_eret_flush)
			NPC = EPC;
		else if (MEM_ex)		//TLB Rill and normal exception
			NPC = 32'hBFC0_0380 ;
		else begin
			case(NPCOp)
				2'b00:	NPC = PF_PC + 4;							//sequential execution
				2'b01:	if(Imm[15])									//branch
							NPC = IF_PC + {14'h3fff,Imm[15:0],2'b00};
						else
							NPC = IF_PC + {14'h0000,Imm[15:0],2'b00};
				2'b10:	NPC = { IF_PC[31:28],Imm[25:0],2'b00};				//jump
				default:NPC = ret_addr;									//jump return
			endcase
		end
	end
	
endmodule

module flush(MEM_eret_flush, MEM_ex, NPCOp, PCWr,
		PC_Flush,PF_Flush,IF_Flush,ID_Flush,EX_Flush,MEM1_Flush,MEM2_Flush);
	input[1:0] NPCOp;
	input PCWr;
	input MEM_eret_flush;
	input MEM_ex;

	output IF_Flush;
	output ID_Flush;
	output EX_Flush;
	output PC_Flush;
	output MEM1_Flush;
	output MEM2_Flush;
	output PF_Flush;

	assign IF_Flush =  (MEM_eret_flush || MEM_ex) ;
	assign ID_Flush = (MEM_eret_flush || MEM_ex) ;
	assign EX_Flush = (MEM_eret_flush || MEM_ex) ;
	assign MEM1_Flush = (MEM_eret_flush || MEM_ex);
	assign PC_Flush = 1'b0 ;
	assign MEM2_Flush = 1'b0;
	assign PF_Flush = (((NPCOp != 2'b00) && PCWr) || MEM_eret_flush || MEM_ex) ;

endmodule