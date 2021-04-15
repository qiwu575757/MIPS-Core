module npc(PC, Imm, EPC, ret_addr, NPCOp, EX_MEM_eret_flush, EX_MEM_ex, NPC, IF_Flush, PCWr,
			ID_Flush, EX_Flush, PC_Flush);

	input[31:0] PC, ret_addr, EPC;
	input[25:0] Imm;
	input[1:0] NPCOp;
	input PCWr;
	input EX_MEM_eret_flush;
	input EX_MEM_ex;
	output reg[31:0] NPC;
	output IF_Flush;
	output ID_Flush;
	output EX_Flush;
	output PC_Flush;

	always@(PC,Imm,ret_addr,NPCOp, EX_MEM_eret_flush, EX_MEM_ex) begin
		if (EX_MEM_eret_flush)
			NPC = EPC + 4;
		else if (EX_MEM_ex)
			NPC = 32'hBFC0_0380;
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

	assign IF_Flush = ((NPCOp != 2'b00) && PCWr) || EX_MEM_eret_flush || EX_MEM_ex;
	assign ID_Flush = EX_MEM_eret_flush || EX_MEM_ex;
	assign EX_Flush = EX_MEM_eret_flush || EX_MEM_ex;
	assign PC_Flush = ((NPCOp != 2'b00) && PCWr) || EX_MEM_eret_flush || EX_MEM_ex;

endmodule
