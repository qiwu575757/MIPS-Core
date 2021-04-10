module npc(PC, Imm, ret_addr, NPCOp, NPC, IF_Flush, PCWr);
	input[31:0] PC, ret_addr;
	input[25:0] Imm;
	input[1:0] NPCOp;
	input PCWr;
	output reg[31:0] NPC;
	output IF_Flush;

	always@(PC,Imm,ret_addr,NPCOp)
		case(NPCOp)
			2'b00:	NPC = PC + 4;									//sequential execution
			2'b01:	if(Imm[15])									//branch
						NPC = PC + {14'h3fff,Imm[15:0],2'b00};
					else
						NPC = PC + {14'h0000,Imm[15:0],2'b00};
			2'b10:	NPC = {PC[31:28],Imm[25:0],2'b00};				//jump
			default:NPC = ret_addr;									//jump return
		endcase

	assign IF_Flush = (NPCOp != 2'b00) && PCWr;

endmodule
