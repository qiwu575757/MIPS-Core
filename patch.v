module exception(MEM1_Overflow, Temp_Exception, MEM1_DMWr, MEM1_DMSel, MEM1_ALU1Out, MEM1_DMRd, Temp_ExcCode, MEM1_PC,
                    MEM1_ExcCode,MEM1_Exception,MEM1_badvaddr);
    input MEM1_Overflow;
    input Temp_Exception;
    input MEM1_DMWr;
    input[2:0] MEM1_DMSel;
    input[31:0] MEM1_ALU1Out;
    input MEM1_DMRd;
    input[4:0] Temp_ExcCode;
    input[31:0] MEM1_PC;
    output reg[4:0] MEM1_ExcCode;
    output reg MEM1_Exception;
    output reg[31:0] MEM1_badvaddr;

always@(MEM1_Overflow or Temp_Exception or MEM1_DMWr or MEM1_DMSel or MEM1_ALU1Out or MEM1_DMRd or Temp_ExcCode
		or MEM1_PC)
		if (MEM1_Overflow  && !Temp_Exception) begin
		MEM1_ExcCode <= `Ov;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= 32'd0;
		end
		else if (MEM1_DMWr && !Temp_Exception && (MEM1_DMSel == 3'b010 && MEM1_ALU1Out[1:0] != 2'b00 ||
			MEM1_DMSel == 3'b001 && MEM1_ALU1Out[0] != 1'b0) )begin
		MEM1_ExcCode <= `AdES;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= MEM1_ALU1Out;
		end
		else if (MEM1_DMRd && !Temp_Exception && (MEM1_DMSel == 3'b111 && MEM1_ALU1Out[1:0] != 2'b00 ||
			(MEM1_DMSel == 3'b101 || MEM1_DMSel == 3'b110) && MEM1_ALU1Out[0] != 1'b0) ) begin
		MEM1_ExcCode <= `AdEL;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= MEM1_ALU1Out;
		end
		else  begin
		MEM1_ExcCode <= Temp_ExcCode;
		MEM1_Exception <= Temp_Exception;
		MEM1_badvaddr <= MEM1_PC;
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

module mem1_cache_prep(MEM1_dcache_en, MEM1_Exception, MEM1_eret_flush, MEM1_ALU1Out, MEM1_DMWr, MEM1_DMSel,
            MEM1_Paddr, MEM1_cache_sel, MEM1_dcache_valid, DMWen_dcache, MEM1_dCache_wstrb);
    input MEM1_dcache_en;
    input MEM1_Exception;
    input MEM1_eret_flush;
    input[31:0] MEM1_ALU1Out;
    input MEM1_DMWr;
    input[2:0] MEM1_DMSel;

    output[31:0] MEM1_Paddr;
    output MEM1_cache_sel;
    output MEM1_dcache_valid;
    output DMWen_dcache;
    output[3:0] MEM1_dCache_wstrb;

    assign MEM1_Paddr = {3'b000,MEM1_ALU1Out[28:0]};
			//这里的alu1out将来都得改成物理地址
	assign MEM1_cache_sel = (MEM1_Paddr[31:16] == 16'h1faf);
    //assign MEM1_cache_sel = 1'b1;
	// 1 表示uncache�? 0表示uncache

    assign MEM1_dcache_valid = MEM1_dcache_en && !MEM1_Exception && !MEM1_eret_flush && ~MEM1_cache_sel;
    assign DMWen_dcache = MEM1_DMWr && !MEM1_Exception && !MEM1_eret_flush;

// 以下这些东西可以封装成翻译模块，或�?�直接用控制器生成对应信号�??
// 1.设置写使能信�???
    assign MEM1_dCache_wstrb=(~DMWen_dcache)?4'b0:
							(MEM1_DMSel==3'b000)?
								(MEM1_Paddr[1:0]==2'b00 ? 4'b0001 :
								MEM1_Paddr[1:0]==2'b01 ? 4'b0010 :
								MEM1_Paddr[1:0]==2'b10 ? 4'b0100 :
								 				   4'b1000) :
							(MEM1_DMSel==3'b001)?   // sh
								(MEM1_Paddr[1]==1'b0 ? 4'b0011 :
								  				4'b1100 ):
		
												4'b1111 ;//sw

endmodule

module mem2_cache_prep(MEM2_cache_sel, MEM2_DMWr, MEM2_Exception, MEM2_eret_flush, MEM2_dCache_en,
            DMen, DMWen_uncache, MEM2_dcache_valid, uncache_valid);
    input MEM2_cache_sel;
    input MEM2_DMWr;
    input MEM2_Exception;
    input MEM2_eret_flush;
    input MEM2_dCache_en;

    output DMen;
    output DMWen_uncache;
    output MEM2_dcache_valid;
    output uncache_valid;

    assign DMen = MEM2_cache_sel ? uncache_valid : MEM2_dcache_valid;
    assign DMWen_uncache = MEM2_DMWr && !MEM2_Exception && !MEM2_eret_flush;
    assign MEM2_dcache_valid = MEM2_dCache_en && !MEM2_Exception && !MEM2_eret_flush && ~MEM2_cache_sel;
    assign uncache_valid = MEM2_dCache_en && !MEM2_Exception && !MEM2_eret_flush && MEM2_cache_sel;

endmodule

module debug(MUX10Out, WB_PC, WB_RFWr, MEM2_WBWr,WB_RD,
        debug_wb_rf_wdata, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum );
    input[31:0] MUX10Out;
    input[31:0] WB_PC;
    input WB_RFWr;
    input MEM2_WBWr;
    input[4:0] WB_RD;

    output[31:0] debug_wb_rf_wdata;
    output[31:0] debug_wb_pc;
    output[3:0] debug_wb_rf_wen;
    output[4:0] debug_wb_rf_wnum; 

assign 
	debug_wb_rf_wdata = MUX10Out;
assign 
	debug_wb_pc  = WB_PC;
assign 
	debug_wb_rf_wen  = {4{WB_RFWr&MEM2_WBWr&(WB_RD!=5'd0)}};
assign 
	debug_wb_rf_wnum  = WB_RD;

endmodule