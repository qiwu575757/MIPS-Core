`include "MacroDef.v"

module instr_fetch_pre(
    NPC, PCWr, s0_found,s0_v,s0_pfn,
    isStall,TLB_flush,EX_TLB_flush, MEM1_TLB_flush, MEM2_TLB_flush, WB_TLB_flush,

    PF_AdEL,PF_TLB_Exc,PF_ExcCode,
    PF_TLBRill_Exc,PF_Exception,PPC, PF_valid, TLB_flush_signal,
    PF_icache_sel, PF_icache_valid , PF_uncache_valid
    );
    input[31:0] NPC;
    input PCWr;
    input s0_found,s0_v;
    input [19:0] s0_pfn;
    input isStall,TLB_flush, EX_TLB_flush, MEM1_TLB_flush,MEM2_TLB_flush, WB_TLB_flush;

    output PF_AdEL,PF_TLB_Exc,PF_TLBRill_Exc,PF_Exception;
    output [4:0] PF_ExcCode;
    output [31:0] PPC;
    output PF_valid;
    output TLB_flush_signal;
    output PF_icache_sel;
    output PF_icache_valid;
    output PF_uncache_valid;

    wire mapped;
    assign mapped = (~NPC[31] || (NPC[31]&&NPC[30])) ? 1 : 0;
    assign PF_icache_sel = (PPC[31:16] == 16'h1faf);

    assign PF_AdEL = NPC[1:0] != 2'b00 && PCWr;
    assign  PF_TLB_Exc   = mapped&(!s0_found || (s0_found&!s0_v));

    assign PF_Exception = (PF_AdEL || PF_TLB_Exc);
    assign PF_ExcCode = 	 PF_AdEL ? `AdEL : 
                            PF_TLB_Exc ? `TLBL : 5'b0;
    assign 	PF_TLBRill_Exc	= ~PF_AdEL & mapped&(!s0_found);
    
    assign PPC = 
		!mapped ? {3'b000,NPC[28:0]} : 
		(PF_ExcCode == 5'd0) ? {s0_pfn,NPC[11:0]} :
						32'd0;
    assign PF_valid = !isStall&!PF_Exception 
            &!TLB_flush&!EX_TLB_flush&!MEM1_TLB_flush&!MEM2_TLB_flush&!WB_TLB_flush;
    assign PF_icache_valid = PF_valid & ~PF_icache_sel;
    assign PF_uncache_valid = PF_valid & PF_icache_sel;
    assign TLB_flush_signal = TLB_flush | EX_TLB_flush | MEM1_TLB_flush | MEM2_TLB_flush | WB_TLB_flush;

endmodule



module mem1_cache_prep(
    MEM1_dcache_en,MEM1_eret_flush, 
    MEM1_ALU1Out, MEM1_DMWr, MEM1_DMSel,
    MEM1_Overflow, Temp_M1_Exception, 
    MEM1_DMRd, Temp_M1_ExcCode,MEM1_PC,s1_found,s1_v,
    s1_d,s1_pfn,Temp_EX_TLB_Exc,IF_iCache_data_ok,Temp_MEM1_TLBRill_Exc,

    MEM1_Paddr, MEM1_cache_sel, MEM1_dcache_valid, 
    DMWen_dcache, MEM1_dCache_wstrb,MEM1_ExcCode,
    MEM1_Exception,MEM1_badvaddr,MEM1_TLBRill_Exc,MEM1_TLB_Exc,
    MEM1_Paddr
    );
    input MEM1_dcache_en;
    input MEM1_eret_flush;
    input[31:0] MEM1_ALU1Out;
    input MEM1_DMWr;
    input[2:0] MEM1_DMSel;
    input MEM1_Overflow;
    input Temp_M1_Exception;
    input MEM1_DMRd;
    input[4:0] Temp_M1_ExcCode;
    input[31:0] MEM1_PC;
    input s1_found,s1_v;
    input s1_d,Temp_EX_TLB_Exc,IF_iCache_data_ok,Temp_MEM1_TLBRill_Exc;
    input [19:0] s1_pfn;

    output[31:0] MEM1_Paddr;
    output MEM1_cache_sel;
    output MEM1_dcache_valid;
    output DMWen_dcache;
    output[3:0] MEM1_dCache_wstrb;
    output reg[4:0] MEM1_ExcCode;
    output reg MEM1_Exception;
    output reg[31:0] MEM1_badvaddr;
    output  MEM1_TLBRill_Exc,MEM1_TLB_Exc;

    wire data_mapped;
    wire valid;
    wire [4:0] MEM1_TLB_ExCode;
    //wire MEM1_dcache_valid_temp;

    assign data_mapped = (~MEM1_ALU1Out[31] || (MEM1_ALU1Out[31]&&MEM1_ALU1Out[30]));
    assign valid = MEM1_dcache_en &IF_iCache_data_ok;
	assign 	MEM1_TLBRill_Exc	= ((Temp_M1_ExcCode!=`AdEL)&data_mapped&(!s1_found)&valid) | Temp_MEM1_TLBRill_Exc;          
    /*
    Explain:
        valid --> need to use dcache
        DMWen_dcache --> need to write dcache
        !s1_found --> TLB Rill
        s1_found&!s1_v --> TLB Invalid
        s1_found&s1_v&!s1_d --> TLB Mod
    */     
    assign MEM1_TLB_Exc = (data_mapped&(!s1_found || (s1_found&!s1_v) || (s1_found&s1_v&!s1_d))
                                &valid) | Temp_EX_TLB_Exc;//include tlb rill,tlb invaild     
     assign MEM1_TLB_ExCode = 
                MEM1_TLB_Exc ?
                (
                    (DMWen_dcache&(!s1_found||(s1_found&!s1_v))) ? `TLBS :
                    (
                        (DMWen_dcache&(s1_found&s1_v&!s1_d)) ? `TLBMod :
                        (
                            (MEM1_dcache_en&!DMWen_dcache&(!s1_found||(s1_found&!s1_v))) ? `TLBL 
                                                : 5'd0 //MEM1_dcache_en&!DMWen_dcache --> load
                        )
                    )
                )
                                                : 5'b0;            
    assign MEM1_Paddr = 
		        !data_mapped ? {3'b000,MEM1_ALU1Out[28:0]} : 
		        //(MEM1_TLB_ExCode == 5'd0) ? {s1_pfn,MEM1_ALU1Out[11:0]} :
				//		32'd0;
                {s1_pfn,MEM1_ALU1Out[11:0]} ;

	assign MEM1_cache_sel = (MEM1_Paddr[31:16] == 16'h1faf);
    //assign MEM1_cache_sel = 1'b1;
	// 1 表示uncache, 0表示cache

    //assign MEM1_dcache_valid_temp = MEM1_dcache_en && ~MEM1_cache_sel;
    assign DMWen_dcache = MEM1_DMWr && !MEM1_Exception && !MEM1_eret_flush;
    assign MEM1_dcache_valid = MEM1_dcache_en && ~MEM1_cache_sel
                 &IF_iCache_data_ok&!MEM1_Exception&!MEM1_eret_flush;

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

    always@(MEM1_Overflow or Temp_M1_Exception or MEM1_DMWr or MEM1_DMSel or MEM1_ALU1Out or MEM1_DMRd or Temp_M1_ExcCode
		or MEM1_PC or MEM1_TLB_Exc)
		if (MEM1_Overflow  && !Temp_M1_Exception) begin
		MEM1_ExcCode <= `Ov;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= 32'd0;
		end
		else if (MEM1_DMWr && !Temp_M1_Exception && (MEM1_DMSel == 3'b010 && MEM1_ALU1Out[1:0] != 2'b00 ||
			MEM1_DMSel == 3'b001 && MEM1_ALU1Out[0] != 1'b0) )begin
		MEM1_ExcCode <= `AdES;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= MEM1_ALU1Out;
		end
		else if (MEM1_DMRd && !Temp_M1_Exception && (MEM1_DMSel == 3'b111 && MEM1_ALU1Out[1:0] != 2'b00 ||
			(MEM1_DMSel == 3'b101 || MEM1_DMSel == 3'b110) && MEM1_ALU1Out[0] != 1'b0) ) begin
		MEM1_ExcCode <= `AdEL;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= MEM1_ALU1Out;
		end
        else if (MEM1_TLB_Exc)
        begin
        MEM1_ExcCode <= MEM1_TLB_ExCode;
		MEM1_Exception <= 1'b1;
		MEM1_badvaddr <= MEM1_ALU1Out;
        end
		else  begin
		MEM1_ExcCode <= Temp_M1_ExcCode;
		MEM1_Exception <= Temp_M1_Exception;
		MEM1_badvaddr <= MEM1_PC;
		end

endmodule

module cache_select_dm(
    MEM_cache_sel, uncache_Out, dcache_Out, MEM_unCache_data_ok, MEM_dCache_data_ok,
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

module cache_select_im(
    IF_cache_sel, uncache_Out, icache_Out, IF_uncache_data_ok, IF_icache_data_ok,
    IF_uncache_rd_req, IF_icache_rd_req, IF_uncache_wr_req, IF_icache_wr_req,
    IF_uncache_rd_type, IF_icache_rd_type, IF_uncache_wr_type, IF_icache_wr_type,
    IF_uncache_rd_addr, IF_icache_rd_addr, IF_uncache_wr_addr, IF_icache_wr_addr,
    IF_uncache_wr_wstrb, IF_icache_wr_wstrb,

    cache_Out, IF_data_ok, IF_rd_req, IF_wr_req, IF_rd_type, IF_wr_type, IF_rd_addr,
    IF_wr_addr, IF_wr_wstrb
                );
    input IF_cache_sel;
    input[31:0] uncache_Out;
    input[31:0] icache_Out;
    input IF_uncache_data_ok;
    input IF_icache_data_ok;
    input IF_uncache_rd_req;
    input IF_icache_rd_req;
    input IF_uncache_wr_req;
    input IF_icache_wr_req;
    input[2:0] IF_uncache_rd_type;
    input[2:0] IF_icache_rd_type;
    input[2:0] IF_uncache_wr_type;
    input[2:0] IF_icache_wr_type;
    input[31:0] IF_uncache_rd_addr;
    input[31:0] IF_icache_rd_addr;
    input[31:0] IF_uncache_wr_addr;
    input[31:0] IF_icache_wr_addr;
    input[3:0] IF_uncache_wr_wstrb;
    input[3:0] IF_icache_wr_wstrb;

    output[31:0] cache_Out;
    output IF_data_ok;
    output IF_rd_req;
    output IF_wr_req;
    output[2:0] IF_rd_type;
    output[2:0] IF_wr_type;
    output[31:0] IF_rd_addr;
    output[31:0] IF_wr_addr;
    output[3:0] IF_wr_wstrb;

	assign cache_Out = IF_cache_sel ? uncache_Out : icache_Out;
	assign IF_data_ok = IF_cache_sel ? IF_uncache_data_ok : IF_icache_data_ok;
	assign IF_rd_req = IF_cache_sel ? IF_uncache_rd_req : IF_icache_rd_req;
	assign IF_wr_req = IF_cache_sel ? IF_uncache_wr_req : IF_icache_wr_req;
	assign IF_rd_type = IF_cache_sel ? IF_uncache_rd_type : IF_icache_rd_type;
	assign IF_wr_type = IF_cache_sel ? IF_uncache_wr_type : IF_icache_wr_type;
	assign IF_rd_addr = IF_cache_sel ? IF_uncache_rd_addr : IF_icache_rd_addr;
	assign IF_wr_addr = IF_cache_sel ? IF_uncache_wr_addr : IF_icache_wr_addr;
	assign IF_wr_wstrb = IF_cache_sel ? IF_uncache_wr_wstrb : IF_icache_wr_wstrb;

endmodule

module mem2_cache_prep(
    MEM2_cache_sel, MEM2_DMWr, MEM2_Exception, MEM2_eret_flush, MEM2_dCache_en, MEM2_dcache_valid,

    DMen, DMWen_uncache,  uncache_valid
    );
    input MEM2_cache_sel;
    input MEM2_DMWr;
    input MEM2_Exception;
    input MEM2_eret_flush;
    input MEM2_dcache_valid;
    input MEM2_dCache_en;

    output DMen;
    output DMWen_uncache;
    output uncache_valid;

    assign DMen = MEM2_cache_sel ? uncache_valid : MEM2_dcache_valid;
    assign DMWen_uncache = MEM2_DMWr && !MEM2_Exception && !MEM2_eret_flush;
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