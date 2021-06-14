module exception(MEM_Overflow, Temp_Exception, MEM_DMWr, MEM_DMSel, MEM_ALU1Out, MEM_DMRd, Temp_ExcCode, MEM_PC,
                    MEM_ExcCode,MEM_Exception,MEM_badvaddr);
    input MEM_Overflow;
    input Temp_Exception;
    input MEM_DMWr;
    input[2:0] MEM_DMSel;
    input[31:0] MEM_ALU1Out;
    input MEM_DMRd;
    input[4:0] Temp_ExcCode;
    input[31:0] MEM_PC;
    output reg[4:0] MEM_ExcCode;
    output reg MEM_Exception;
    output reg[31:0] MEM_badvaddr;

always@(MEM_Overflow or Temp_Exception or MEM_DMWr or MEM_DMSel or MEM_ALU1Out or MEM_DMRd or Temp_ExcCode
		or MEM_PC)
		if (MEM_Overflow  && !Temp_Exception) begin
		MEM_ExcCode <= `Ov;
		MEM_Exception <= 1'b1;
		MEM_badvaddr <= 32'd0;
		end
		else if (MEM_DMWr && !Temp_Exception && (MEM_DMSel == 3'b010 && MEM_ALU1Out[1:0] != 2'b00 ||
			MEM_DMSel == 3'b001 && MEM_ALU1Out[0] != 1'b0) )begin
		MEM_ExcCode <= `AdES;
		MEM_Exception <= 1'b1;
		MEM_badvaddr <= MEM_ALU1Out;
		end
		else if (MEM_DMRd && !Temp_Exception && (MEM_DMSel == 3'b111 && MEM_ALU1Out[1:0] != 2'b00 ||
			(MEM_DMSel == 3'b101 || MEM_DMSel == 3'b110) && MEM_ALU1Out[0] != 1'b0) ) begin
		MEM_ExcCode <= `AdEL;
		MEM_Exception <= 1'b1;
		MEM_badvaddr <= MEM_ALU1Out;
		end
		else  begin
		MEM_ExcCode <= Temp_ExcCode;
		MEM_Exception <= Temp_Exception;
		MEM_badvaddr <= MEM_PC;
		end

endmodule

module instr_fetch(NPC, PCWr, PF_AdEL, PPC);
    input[31:0] NPC;
    input PCWr;
    output PF_AdEL;
    output [31:0] PPC;

    assign PF_AdEL = NPC[1:0] != 2'b00 && PCWr;
    assign PPC={3'b000,NPC[28:0]};

endmodule

module cache_select(MEM_cache_sel, uncache_Out, dcache_Out, MEM_unCache_data_ok, MEM_dCache_data_ok,
                MEM_uncache_rd_req, MEM_dcache_rd_req, MEM_uncache_wr_req, MEM_dcache_wr_req,
                MEM_uncache_rd_type, MEM_dcache_rd_type, MEM_uncache_wr_type, MEM_dcache_wr_type,
                MEM_uncache_rd_addr, MEM_dcache_rd_addr, MEM_uncache_wr_addr, MEM_dcache_wr_addr,
                MEM_uncache_wr_wstrb, MEM_dcache_wr_wstrb,

                cache_Out, MEM_data_ok, MEM_rd_req, MEM_wr_req, MEM_rd_type, MEM_wr_type, MEM_rd_addr,
                MEM_wr_addr, MEM_wr_wstrb
                );
    input MEM_cache_sel;
    input[31:0] uncache_Out;
    input[31:0] dcache_Out;
    input MEM_unCache_data_ok;
    input MEM_dCache_data_ok;
    input MEM_uncache_rd_req;
    input MEM_dcache_rd_req;
    input MEM_uncache_wr_req;
    input MEM_dcache_wr_req;
    input[2:0] MEM_uncache_rd_type;
    input[2:0] MEM_dcache_rd_type;
    input[2:0] MEM_uncache_wr_type;
    input[2:0] MEM_dcache_wr_type;
    input[31:0] MEM_uncache_rd_addr;
    input[31:0] MEM_dcache_rd_addr;
    input[31:0] MEM_uncache_wr_addr;
    input[31:0] MEM_dcache_wr_addr;
    input[3:0] MEM_uncache_wr_wstrb;
    input[3:0] MEM_dcache_wr_wstrb;

    output[31:0] cache_Out;
    output MEM_data_ok;
    output MEM_rd_req;
    output MEM_wr_req;
    output[2:0] MEM_rd_type;
    output[2:0] MEM_wr_type;
    output[31:0] MEM_rd_addr;
    output[31:0] MEM_wr_addr;
    output[3:0] MEM_wr_wstrb;

	assign cache_Out = MEM_cache_sel ? uncache_Out : dcache_Out;
	assign MEM_data_ok = MEM_cache_sel ? MEM_unCache_data_ok : MEM_dCache_data_ok;
	assign MEM_rd_req = MEM_cache_sel ? MEM_uncache_rd_req : MEM_dcache_rd_req;
	assign MEM_wr_req = MEM_cache_sel ? MEM_uncache_wr_req : MEM_dcache_wr_req;
	assign MEM_rd_type = MEM_cache_sel ? MEM_uncache_rd_type : MEM_dcache_rd_type;
	assign MEM_wr_type = MEM_cache_sel ? MEM_uncache_wr_type : MEM_dcache_wr_type;
	assign MEM_rd_addr = MEM_cache_sel ? MEM_uncache_rd_addr : MEM_dcache_rd_addr;
	assign MEM_wr_addr = MEM_cache_sel ? MEM_uncache_wr_addr : MEM_dcache_wr_addr;
	assign MEM_wr_wstrb = MEM_cache_sel ? MEM_uncache_wr_wstrb : MEM_dcache_wr_wstrb;

endmodule

module ex_cache_prep(EXE_dcache_en, EX_Exception, EX_eret_flush, ALU1Out, EX_DMWr, EX_DMSel,
            EX_Paddr, EX_cache_sel, EX_dcache_valid, DMWen_dcache, EX_dCache_wstrb);
    input EXE_dcache_en;
    input EX_Exception;
    input EX_eret_flush;
    input[31:0] ALU1Out;
    input EX_DMWr;
    input[2:0] EX_DMSel;

    output[31:0] EX_Paddr;
    output EX_cache_sel;
    output EX_dcache_valid;
    output DMWen_dcache;
    output[3:0] EX_dCache_wstrb;

    assign EX_Paddr = {3'b000,ALU1Out[28:0]};
			//这里的alu1out将来都得改成物理地址
	assign EX_cache_sel = (EX_Paddr[31:16] == 16'h1faf);
	// 1 表示uncache�? 0表示uncache

    assign EX_dcache_valid = EXE_dcache_en && !EX_Exception && !EX_eret_flush && ~EX_cache_sel;
    assign DMWen_dcache = EX_DMWr && !EX_Exception && !EX_eret_flush;

// 以下这些东西可以封装成翻译模块，或�?�直接用控制器生成对应信号�??
// 1.设置写使能信�???
    assign EX_dCache_wstrb=(~DMWen_dcache)?4'b0:
							(EX_DMSel==3'b000)?
								(EX_Paddr[1:0]==2'b00 ? 4'b0001 :
								EX_Paddr[1:0]==2'b01 ? 4'b0010 :
								EX_Paddr[1:0]==2'b10 ? 4'b0100 :
								 				   4'b1000) :
							(EX_DMSel==3'b001)?   // sh
								(EX_Paddr[1]==1'b0 ? 4'b0011 :
								  				4'b1100 ):
		
												4'b1111 ;//sw

endmodule

module mem_cache_prep(MEM_cache_sel, MEM_DMWr, MEM_Exception, MEM_eret_flush, MEM_dCache_en,
            DMen, DMWen_uncache, MEM_dcache_valid, uncache_valid);
    input MEM_cache_sel;
    input MEM_DMWr;
    input MEM_Exception;
    input MEM_eret_flush;
    input MEM_dCache_en;

    output DMen;
    output DMWen_uncache;
    output MEM_dcache_valid;
    output uncache_valid;

    assign DMen = MEM_cache_sel ? uncache_valid : MEM_dcache_valid;
    assign DMWen_uncache = MEM_DMWr && !MEM_Exception && !MEM_eret_flush;
    assign MEM_dcache_valid = MEM_dCache_en && !MEM_Exception && !MEM_eret_flush && ~MEM_cache_sel;
    assign uncache_valid = MEM_dCache_en && !MEM_Exception && !MEM_eret_flush && MEM_cache_sel;

endmodule

module debug(MUX2Out, WB_PC, WB_RFWr, MEM_WBWr,WB_RD,
        debug_wb_rf_wdata, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum );
    input[31:0] MUX2Out;
    input[31:0] WB_PC;
    input WB_RFWr;
    input MEM_WBWr;
    input[4:0] WB_RD;

    output[31:0] debug_wb_rf_wdata;
    output[31:0] debug_wb_pc;
    output[3:0] debug_wb_rf_wen;
    output[4:0] debug_wb_rf_wnum; 

assign 
	debug_wb_rf_wdata = MUX2Out;
assign 
	debug_wb_pc  = WB_PC;
assign 
	debug_wb_rf_wen  = {4{WB_RFWr&MEM_WBWr}};
assign 
	debug_wb_rf_wnum  = WB_RD[4:0];

endmodule