module mips(
    ext_int_in   ,   //high active

    clk      ,
    rst      ,   //low active

    arid      ,
    araddr    ,
    arlen     ,
    arsize    ,
    arburst   ,
    arlock    ,
    arcache   ,
    arprot    ,
    arvalid   ,
    arready   ,
                
    rid       ,
    rdata     ,
    rresp     ,
    rlast     ,
    rvalid    ,
    rready    ,
               
    awid      ,
    awaddr    ,
    awlen     ,
    awsize    ,
    awburst   ,
    awlock    ,
    awcache   ,
    awprot    ,
    awvalid   ,
    awready   ,
    
    wid       ,
    wdata     ,
    wstrb     ,
    wlast     ,
    wvalid    ,
    wready    ,
    
    bid       ,
    bresp     ,
    bvalid    ,
    bready    ,

    //debug interface
    debug_wb_pc      ,
    debug_wb_rf_wen  ,
    debug_wb_rf_wnum ,
    debug_wb_rf_wdata
);
// 中断信号
    input [5:0] ext_int_in      ;  //interrupt,high active;


// 时钟与复位信�??
    input clk      ;
    input rst      ;   //low active
// 读请求信号�?�道 
    output [ 3:0]   arid      ;
    output [31:0]   araddr    ;
    output [ 3:0]   arlen     ;
    output [ 2:0]   arsize    ;
    output [ 1:0]   arburst   ;
    output [ 1:0]   arlock    ;
    output [ 3:0]   arcache   ;
    output [ 2:0]   arprot    ;
    output          arvalid   ;
    input           arready   ;
//读相应信号�?�道         
    input [ 3:0]    rid       ;  
    input [31:0]    rdata     ;
    input [ 1:0]    rresp     ;
    input           rlast     ;
    input           rvalid    ;
    output          rready    ;
//写请求信号�?�道
    output [ 3:0]   awid      ;
    output [31:0]   awaddr    ;
    output [ 3:0]   awlen     ;
    output [ 2:0]   awsize    ;
    output [ 1:0]   awburst   ;
    output [ 1:0]   awlock    ;
    output [ 3:0]   awcache   ;
    output [ 2:0]   awprot    ;
    output          awvalid   ;
    input           awready   ;
// 写数据信号�?�道
    output [ 3:0]   wid       ;
    output [31:0]   wdata     ;
    output [ 3:0]   wstrb     ;
    output          wlast     ;
    output          wvalid    ;
    input           wready    ;
// 写相应信号�?�道
    input [3:0]     bid       ;
    input [1:0]     bresp     ;
    input           bvalid    ;
    output          bready    ;

    //debug
    output  [31:0] debug_wb_pc      ;
    output  [3:0] debug_wb_rf_wen  ;
    output  [4:0] debug_wb_rf_wnum ;
    output  [31:0] debug_wb_rf_wdata;


	/*signals defination*/

	//---------------F----------------//
	wire PCWr,PF_AdEL;//PF_AdEL,取址地址错误
	wire IF_AdEL;
	wire [31:0] PC, ID_PC;
	wire [31:0] NPC;
	wire IF_iCache_addr_ok;
	wire IF_iCache_data_ok;
	wire [31:0] IF_iCache_rdata;
	wire [31:0] PPC;

	wire IF_icache_rd_req;
	wire [2:0]IF_icache_rd_type;
	wire [31:0] IF_icache_rd_addr;
	wire  IF_icache_rd_rdy;
	wire  IF_icache_ret_valid;
	wire IF_icache_ret_last;
	wire [31:0] IF_icache_ret_data;
	wire IF_icache_wr_req;
	wire [2:0] IF_icache_wr_type;
	wire [31:0] IF_icache_wr_addr;
	wire [3:0] IF_icache_wr_wstrb;
	wire [511:0] IF_icache_wr_data;
	wire IF_icache_wr_rdy;
	//---------------D----------------//
	wire DMWr, DMRd, RFWr, RHLWr;
	wire PC_Flush,IF_Flush, MEM_Flush;
	wire CMPOut1;
	wire ID_AdEL;
	wire MUX8Sel, MUX9Sel;
	wire MUX3Sel, RHLSel_Rd,B_JOp;//B_JOp,is branch or JR or JALR
	wire isBD,isBranch;
	wire ID_Flush, EX_Flush;
	wire eret_flush,CP0WrEn,Exception;
	wire ALU1Sel;
	wire[1:0] EXTOp, NPCOp, ALU2Op, MUX1Sel, RHLSel_Wr, CMPOut2;
	wire[2:0] MUX2_6Sel,DMSel;
	wire[31:0] MUX8Out, MUX9Out;
	wire[3:0] ALU1Op, MUX7Out;
	wire[4:0] ExcCode;
	wire [31:0] Imm32, GPR_RS, GPR_RT;//GPR_RS --> RS DATA
	wire [31:0] ID_Instr;
	wire CP0Rd, RHL_visit;
	wire start;
	wire ID_dcache_en;
	wire ID_EXWr;
	wire EX_MEMWr;
	wire MEM_WBWr;
	//---------------E----------------//
	wire Overflow;
	wire [4:0] MUX1Out;
	wire [31:0] ALU1Out, RHLOut, MUX3Out, MUX4Out, MUX5Out, DMOut;
	wire EX_eret_flush;
	wire EX_CP0WrEn;
	wire EX_Exception;
	wire [4:0] EX_ExcCode;
	wire EX_isBD;
	wire EX_isBranch;
	wire EX_RHLSel_Rd;
	wire EX_DMWr;
	wire EX_DMRd;
	wire EX_MUX3Sel;
	wire EX_ALU1Sel;
	wire EX_RFWr;
	wire EX_RHLWr;
	wire [1:0] EX_ALU2Op;
	wire [1:0] EX_MUX1Sel;
	wire [1:0] EX_RHLSel_Wr;
	wire [2:0] EX_DMSel;
	wire [2:0] EX_MUX2Sel;
	wire [3:0] EX_ALU1Op;
	wire [4:0] EX_RS;
	wire [4:0] EX_RT;
	wire [4:0] EX_RD;
	wire [4:0] EX_shamt;
	wire [31:0] EX_PC, EX_GPR_RS, EX_GPR_RT, EX_Imm32;
	wire EX_CP0Rd;
	wire EX_isBusy;
	wire EX_start;
	wire [7:0] EX_CP0Addr;
	wire EXE_dcache_en;
	wire [31:0] EX_Paddr;
	wire[31:0] EX_badvaddr;


	//---------------M----------------//
	wire Interrupt;
	wire [31:0] MUX6Out;
	wire [31:0] badvaddr;
	wire MEM_DMWr, MEM_DMRd, MEM_RFWr;
	wire MEM_eret_flush;
	wire MEM_CP0WrEn;
	wire MEM_Exception;
	
	wire [4:0] MEM_ExcCode;
	wire MEM_isBD;
	wire[2:0] MEM_DMSel, MEM_MUX2Sel;
	wire[4:0] MEM_RD;
	wire[31:0] MEM_PC, MEM_RHLOut, MEM_ALU1Out, MEM_GPR_RT, MEM_Imm32;
	wire MEM_CP0Rd;
	wire [31:0] CP0Out;
	wire [31:0] EPCOut;
	wire [7:0] MEM_CP0Addr;
	wire [31:0] MEM_Paddr;
	wire MEM_dCache_en;
	wire MEM_dCache_addr_ok;
	wire MEM_dCache_data_ok;
	wire [31:0] MEM_dCache_rdata;
	wire MEM_dcache_rd_req;
	wire [2:0]MEM_dcache_rd_type;
	wire [31:0] MEM_dcache_rd_addr;
	wire  MEM_dcache_rd_rdy;
	wire  MEM_dcache_ret_valid;
	wire MEM_dcache_ret_last;
	wire [31:0] MEM_dcache_ret_data;
	wire MEM_dcache_wr_req;
	wire [2:0] MEM_dcache_wr_type;
	wire [31:0] MEM_dcache_wr_addr;
	wire [3:0] MEM_dcache_wr_wstrb;
	wire [3:0] EX_dCache_wstrb;
	wire [511:0] MEM_dcache_wr_data;
	wire MEM_dcache_wr_rdy;
	wire dcache_stall;

	wire MEM_cache_sel;
	wire EX_cache_sel;

	wire DMen;

	wire DMWen_uncache;
	wire DMWen_dcache;
	wire EX_dcache_valid;
	wire MEM_dcache_valid;
	wire uncache_valid;
	wire[31:0] uncache_Out;
	wire[31:0] dcache_Out;
	wire MEM_unCache_data_ok;
	wire MEM_uncache_rd_req;
	wire MEM_uncache_wr_req;
	wire[2:0] MEM_uncache_rd_type;
	wire[2:0] MEM_uncache_wr_type;
	wire[31:0] MEM_uncache_rd_addr;
	wire[31:0] MEM_uncache_wr_addr;
	wire[3:0] MEM_uncache_wr_wstrb;
	wire[31:0] MEM_uncache_wr_data;
	wire MEM_data_ok;
	wire MEM_rd_req;
	wire MEM_wr_req;
	wire[2:0] MEM_rd_type;
	wire[2:0] MEM_wr_type;
	wire[31:0] MEM_rd_addr;
	wire[31:0] MEM_wr_addr;
	wire[3:0] MEM_wr_wstrb;

	wire [31:0] cache_Out;
	wire MEM_Overflow;
	wire [4:0] Temp_ExcCode;
	wire Temp_Exception;
	wire [31:0] MEM_badvaddr;


	//---------------W----------------//
	wire [31:0] MUX2Out;
	wire WB_RFWr;
	wire[2:0] WB_MUX2Sel;
	wire[4:0] WB_RD;
	wire[31:0] WB_PC, WB_ALU1Out, WB_DMOut, WB_RHLOut, WB_Imm32,WB_CP0Out;

	//---------------Stall----------------//
	wire IF_IDWr,MUX7Sel;
	wire isStall;


	//---------------Bypass----------------//
	wire [1:0] MUX4Sel,MUX5Sel;

	//---------------Outside Signals----------------//


	/**************DATA PATH***************/

// ---------------IF---------------------//
instr_fetch U_INSTR_FETCH(
		NPC, PCWr, PF_AdEL, PPC
	);
	//搁这儿写个地�??转换,表示物理地址
    // assign PF_AdEL = 0;
pc U_PC(
		//input
		.clk(clk), .rst(rst), .wr(PCWr), .NPC(NPC),  .PF_AdEL(PF_AdEL),.PC_Flush(PC_Flush) 
		//input signals and output signals are separate
		//output
		,.IF_AdEL(IF_AdEL), .PC(PC)
	);



// * cpu && cache
// 		没收到icache_data_ok 要阻�??
// --------------------------------------
// * cache && axi 

 cache U_ICACHE(
	.clk(clk), .resetn(rst), .exception(MEM_eret_flush || MEM_Exception), .id(1'b0),
	// cpu && cache
	/*input*/
  	.valid(~isStall), .op(1'b0), .index(PPC[13:6]), .tag(PPC[31:14]), .offset(PPC[5:0]),
	.wstrb(4'b0), .wdata(32'b0), 
	/*output*/
	.addr_ok(IF_iCache_addr_ok), .data_ok(IF_iCache_data_ok), .rdata(IF_iCache_rdata), 
	//cache && axi
	/*input*/
  	.rd_rdy(IF_icache_rd_rdy),
	.ret_valid(IF_icache_ret_valid),.ret_last(IF_icache_ret_last), 
	.ret_data(IF_icache_ret_data),.wr_rdy(IF_icache_wr_rdy),
	/*output*/
	.rd_req(IF_icache_rd_req),.wr_req(IF_icache_wr_req),.rd_type(IF_icache_rd_type),
	.wr_type(IF_icache_wr_type),.rd_addr(IF_icache_rd_addr),.wr_addr(IF_icache_wr_addr),
	.wr_wstrb(IF_icache_wr_wstrb), .wr_data(IF_icache_wr_data)
	);



IF_ID U_IF_ID(
		.clk(clk), .rst(rst),.IF_IDWr(IF_IDWr), .IF_Flush(IF_Flush), 
		.PC(PC), .Instr(IF_iCache_rdata), .IF_AdEL(IF_AdEL),

		.ID_PC(ID_PC), .ID_Instr(ID_Instr), .ID_AdEL(ID_AdEL)
	);




//-----------------ID-------------------//
rf U_RF(
		.Addr1(ID_Instr[25:21]), .Addr2(ID_Instr[20:16]), .Addr3(WB_RD[4:0]),
		.WD(MUX2Out), .RFWr(WB_RFWr), .clk(clk),

		.rst(rst), .RD1(GPR_RS), .RD2(GPR_RT)
	);

ext U_EXT(
		.Imm16(ID_Instr[15:0]), .EXTOp(EXTOp),

		.Imm32(Imm32)
);

mux7 U_MUX7(
		.WRSign({ID_dcache_en, DMWr, RFWr, RHLWr}), .MUX7Sel(MUX7Sel),

		.MUX7Out(MUX7Out)
	);

mux8 U_MUX8(
		.GPR_RS(GPR_RS), .data_MEM(MUX6Out), .MUX8Sel(MUX8Sel),
		
		.out(MUX8Out)
	);

mux9 U_MUX9(
		.GPR_RT(GPR_RT), .data_MEM(MUX6Out), .MUX9Sel(MUX9Sel),
		
		.out(MUX9Out)
	);

cmp U_CMP(
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out),

		.CMPOut1(CMPOut1), .CMPOut2(CMPOut2)
	);

ctrl U_CTRL(
		.clk(clk), .rst(rst), .OP(ID_Instr[31:26]), .Funct(ID_Instr[5:0]), .rt(ID_Instr[20:16]), .CMPOut1(CMPOut1), 
		.CMPOut2(CMPOut2), .rs(ID_Instr[25:21]), .EXE_isBranch(EX_isBranch), .Interrupt(Interrupt), 
		.ID_AdEL(ID_AdEL), .IF_Flush(IF_Flush),

		.MUX1Sel(MUX1Sel), .MUX2Sel(MUX2_6Sel), .MUX3Sel(MUX3Sel), .RFWr(RFWr), .RHLWr(RHLWr), .DMWr(DMWr), .DMRd(DMRd), 
		.NPCOp(NPCOp), .EXTOp(EXTOp), .ALU1Op(ALU1Op), .ALU1Sel(ALU1Sel), .ALU2Op(ALU2Op), .RHLSel_Rd(RHLSel_Rd), 
		.RHLSel_Wr(RHLSel_Wr), .DMSel(DMSel), .B_JOp(B_JOp), .eret_flush(eret_flush), .CP0WrEn(CP0WrEn), 
		.Exception(Exception), .ExcCode(ExcCode), .isBD(isBD), .isBranch(isBranch), .CP0Rd(CP0Rd), .start(start),
		.RHL_visit(RHL_visit),.dcache_en(ID_dcache_en)
	);

npc U_NPC(
		.PC(PC), .Imm(ID_Instr[25:0]), .ret_addr(MUX8Out), .NPCOp(NPCOp),.PCWr(PCWr), 
		.EPC(EPCOut), .MEM_eret_flush(MEM_eret_flush), .MEM_ex(MEM_Exception),

		.NPC(NPC), .IF_Flush(IF_Flush), .ID_Flush(ID_Flush),
		.EX_Flush(EX_Flush), .PC_Flush(PC_Flush), .MEM_Flush(MEM_Flush)
	);


ID_EX U_ID_EX(
		.clk(clk), .rst(rst), .ID_EXWr(ID_EXWr),.RHLSel_Rd(RHLSel_Rd), .PC(ID_PC), .ALU1Op(ALU1Op), .ALU2Op(ALU2Op), 
		.MUX1Sel(MUX1Sel), .MUX3Sel(MUX3Sel),.ALU1Sel(ALU1Sel), .DMWr(MUX7Out[2]), .DMSel(DMSel), .DMRd(DMRd), 
		.RFWr(MUX7Out[1]), .RHLWr(MUX7Out[0]),.RHLSel_Wr(RHLSel_Wr), .MUX2Sel(MUX2_6Sel),
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .RS(ID_Instr[25:21]),.RT(ID_Instr[20:16]), .RD(ID_Instr[15:11]), 
		.Imm32(Imm32), .shamt(ID_Instr[10:6]), .eret_flush(eret_flush), .ID_Flush(ID_Flush), .CP0WrEn(CP0WrEn), 
		.Exception(Exception), .ExcCode(ExcCode), .isBD(isBD), .isBranch(isBranch), 
		.CP0Addr({ID_Instr[15:11], ID_Instr[2:0]}), .CP0Rd(CP0Rd), .start(start & ~EX_isBusy),.ID_dcache_en(MUX7Out[3]),

		.EX_eret_flush(EX_eret_flush), .EX_CP0WrEn(EX_CP0WrEn), .EX_Exception(EX_Exception), 
		.EX_ExcCode(EX_ExcCode), .EX_isBD(EX_isBD), .EX_isBranch(EX_isBranch), .EX_RHLSel_Rd(EX_RHLSel_Rd),
	 	.EX_DMWr(EX_DMWr), .EX_DMRd(EX_DMRd), .EX_MUX3Sel(EX_MUX3Sel), .EX_ALU1Sel(EX_ALU1Sel), 
		.EX_RFWr(EX_RFWr), .EX_RHLWr(EX_RHLWr), .EX_ALU2Op(EX_ALU2Op), .EX_MUX1Sel(EX_MUX1Sel), 
		.EX_RHLSel_Wr(EX_RHLSel_Wr), .EX_DMSel(EX_DMSel), .EX_MUX2Sel(EX_MUX2Sel), .EX_ALU1Op(EX_ALU1Op), 
		.EX_RS(EX_RS), .EX_RT(EX_RT), .EX_RD(EX_RD), .EX_shamt(EX_shamt), .EX_PC(EX_PC),
		.EX_GPR_RS(EX_GPR_RS), .EX_GPR_RT(EX_GPR_RT), .EX_Imm32(EX_Imm32), .EX_CP0Addr(EX_CP0Addr),
		.EX_CP0Rd(EX_CP0Rd), .EX_start(EX_start),.EXE_dcache_en(EXE_dcache_en)
	);


//-----------------------EX---------------------//
mux1 U_MUX1(
		.RT(EX_RT), .RD(EX_RD), .MUX1Sel(EX_MUX1Sel),
		
		 .Addr3(MUX1Out)
	);

mux3 U_MUX3(
		.RD2(MUX5Out), .Imm32(EX_Imm32), .MUX3Sel(EX_MUX3Sel),
		
		.B(MUX3Out)
	);

mux4 U_MUX4(
		.GPR_RS(EX_GPR_RS), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX4Sel(MUX4Sel),
		
		.out(MUX4Out)
	);

mux5 U_MUX5(
		.GPR_RT(EX_GPR_RT), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX5Sel(MUX5Sel),
		
		.out(MUX5Out)
	);

bridge_RHL U_ALU2(
		.aclk(clk),.aresetn(rst),.A(MUX4Out), .B(MUX5Out), .ALU2Op(EX_ALU2Op) ,.start(EX_start),
		.EX_RHLWr(EX_RHLWr), .EX_RHLSel_Wr(EX_RHLSel_Wr), .EX_RHLSel_Rd(EX_RHLSel_Rd),
		.MEM_Exception(MEM_Exception), .MEM_eret_flush(MEM_eret_flush),

		.isBusy(EX_isBusy),
		.RHLOut(RHLOut)
	);

alu1 U_ALU1(
		.A(MUX4Out), .B(MUX3Out),.ALU1Op(EX_ALU1Op), 
		.ALU1Sel(EX_ALU1Sel), .Shamt(EX_shamt),
		
		.C(ALU1Out),.Overflow(Overflow)
	);


EX_MEM U_EX_MEM(
		.clk(clk), .rst(rst), .EX_MEMWr(EX_MEMWr),.Imm32(EX_Imm32), .EX_PC(EX_PC), 
		.DMWr(EX_DMWr), .DMSel(EX_DMSel), .DMRd(EX_DMRd), .RFWr(EX_RFWr), 
		.MUX2Sel(EX_MUX2Sel),.RHLOut(RHLOut), 
		.ALU1Out(ALU1Out), .GPR_RT(MUX5Out), .RD(MUX1Out), .EX_Flush(EX_Flush), 
		.eret_flush(EX_eret_flush), .CP0WrEn(EX_CP0WrEn), .Exception(EX_Exception), .ExcCode(EX_ExcCode), .isBD(EX_isBD),
		.CP0Addr(EX_CP0Addr), .CP0Rd(EX_CP0Rd), .EXE_dcache_en(EXE_dcache_en), .EX_badvaddr(EX_badvaddr),
		.Overflow(Overflow), .EX_Paddr(EX_Paddr), .EX_dCache_wstrb(EX_dCache_wstrb), .EX_cache_sel(EX_cache_sel),

		.MEM_DMWr(MEM_DMWr), .MEM_DMRd(MEM_DMRd), .MEM_RFWr(MEM_RFWr),
		.MEM_eret_flush(MEM_eret_flush), .MEM_CP0WrEn(MEM_CP0WrEn), .MEM_Exception(Temp_Exception), 
		.MEM_ExcCode(Temp_ExcCode), .MEM_isBD(MEM_isBD),
		.MEM_DMSel(MEM_DMSel), .MEM_MUX2Sel(MEM_MUX2Sel), .MEM_RD(MEM_RD), .MEM_PC(MEM_PC), .MEM_RHLOut(MEM_RHLOut), 
		.MEM_ALU1Out(MEM_ALU1Out), .MEM_GPR_RT(MEM_GPR_RT), .MEM_Imm32(MEM_Imm32), 
		.badvaddr(badvaddr), .MEM_CP0Addr(MEM_CP0Addr), .MEM_CP0Rd(MEM_CP0Rd),.MEM_dCache_en(MEM_dCache_en),
		.MEM_Overflow(MEM_Overflow), .MEM_Paddr(MEM_Paddr), .MEM_unCache_wstrb(MEM_unCache_wstrb),
		.MEM_cache_sel(MEM_cache_sel)
	);


//------------------MEM-------------------------//
CP0 U_CP0(
		.clk(clk), .rst(rst), .CP0WrEn(MEM_CP0WrEn), .addr(MEM_CP0Addr), .data_in(MEM_GPR_RT), 
		.MEM_Exc(MEM_Exception), .MEM_eret_flush(MEM_eret_flush), .MEM_bd(MEM_isBD),
        .ext_int_in(ext_int_in), .MEM_ExcCode(MEM_ExcCode), .MEM_badvaddr(MEM_badvaddr), 
		.MEM_PC(MEM_PC),
		
		.data_out(CP0Out), .EPC_out(EPCOut), .Interrupt(Interrupt)
	);

mux6 U_MUX6(
		.RHLOut(MEM_RHLOut), .ALU1Out(MEM_ALU1Out), .PC(MEM_PC),
		.Imm32(MEM_Imm32), .MUX6Sel(MEM_MUX2Sel[1:0]),
		
		.out(MUX6Out)
	);

exception U_EXCEPTION(
		MEM_Overflow, Temp_Exception, MEM_DMWr, MEM_DMSel, MEM_ALU1Out, MEM_DMRd, Temp_ExcCode, MEM_PC,
        MEM_ExcCode,MEM_Exception,MEM_badvaddr
		);

ex_cache_prep U_EX_CACHE_PREP(
		EXE_dcache_en, EX_Exception, EX_eret_flush, ALU1Out, EX_DMWr, EX_DMSel,
        EX_Paddr, EX_cache_sel, EX_dcache_valid, DMWen_dcache, EX_dCache_wstrb
		);

mem_cache_prep U_MEM_CACHE_PREP(
		MEM_cache_sel, MEM_DMWr, MEM_Exception, MEM_eret_flush, MEM_dCache_en,
        DMen, DMWen_uncache, MEM_dcache_valid, uncache_valid
		);



uncache U_UNCACHE(
        .clk(clk), .resetn(rst),
        .valid(uncache_valid), .op(DMWen_uncache), .addr(MEM_Paddr), .wstrb(MEM_unCache_wstrb), .wdata(MEM_GPR_RT),
        .data_ok(MEM_unCache_data_ok), .rdata(uncache_Out),
        .rd_rdy(MEM_dcache_rd_rdy), .wr_rdy(MEM_dcache_wr_rdy), .ret_valid(MEM_dcache_ret_valid), .ret_last(MEM_dcache_ret_last),
		.ret_data(MEM_dcache_ret_data),
        .rd_req(MEM_uncache_rd_req), .wr_req(MEM_uncache_wr_req), .rd_type(MEM_uncache_rd_type),
		.wr_type(MEM_uncache_wr_type), .rd_addr(MEM_uncache_rd_addr), .wr_addr(MEM_uncache_wr_addr), 
		.wr_wstrb(MEM_uncache_wr_wstrb), .wr_data(MEM_uncache_wr_data)
);

cache U_DCACHE(.clk(clk), .resetn(rst), .exception(MEM_Exception || MEM_eret_flush), .id(1'b1),
	// cpu && cache
  	.valid(EX_dcache_valid&IF_iCache_data_ok), .op(DMWen_dcache), .index(EX_Paddr[13:6]), .tag(EX_Paddr[31:14]), .offset(EX_Paddr[5:0]),
	.wstrb(EX_dCache_wstrb), .wdata(MUX5Out), .addr_ok(MEM_dCache_addr_ok), .data_ok(MEM_dCache_data_ok), .rdata(dcache_Out), 
	//cache && axi
  	.rd_req(MEM_dcache_rd_req), .rd_type(MEM_dcache_rd_type), .rd_addr(MEM_dcache_rd_addr), .rd_rdy(MEM_dcache_rd_rdy),
	  .ret_valid(MEM_dcache_ret_valid), .ret_last(MEM_dcache_ret_last), .ret_data(MEM_dcache_ret_data),
	  .wr_req(MEM_dcache_wr_req), .wr_type(MEM_dcache_wr_type), .wr_addr(MEM_dcache_wr_addr), 
	  .wr_wstrb(MEM_dcache_wr_wstrb), .wr_data(MEM_dcache_wr_data), .wr_rdy(MEM_dcache_wr_rdy)
	);

cache_select U_CACHE_SELECT(
				MEM_cache_sel, uncache_Out, dcache_Out, MEM_unCache_data_ok, MEM_dCache_data_ok,
                MEM_uncache_rd_req, MEM_dcache_rd_req, MEM_uncache_wr_req, MEM_dcache_wr_req,
                MEM_uncache_rd_type, MEM_dcache_rd_type, MEM_uncache_wr_type, MEM_dcache_wr_type,
                MEM_uncache_rd_addr, MEM_dcache_rd_addr, MEM_uncache_wr_addr, MEM_dcache_wr_addr,
                MEM_uncache_wr_wstrb, MEM_dcache_wr_wstrb,

                cache_Out, MEM_data_ok, MEM_rd_req, MEM_wr_req, MEM_rd_type, MEM_wr_type, MEM_rd_addr,
                MEM_wr_addr, MEM_wr_wstrb
                );

//cache只能读出�??个字的数据，使用bridge_dm适配lb等特殊指�??
bridge_dm U_BRIDGE_DM(
		 .addr2(MEM_ALU1Out),
		 .DMSel2(MEM_DMSel),
		 .Din(cache_Out),

		 .dout(DMOut)
	);




MEM_WB U_MEM_WB(
		.clk(clk), .rst(rst), .PC(MEM_PC), .RFWr(MEM_RFWr),.MUX2Sel(MEM_MUX2Sel),
		.RHLOut(MEM_RHLOut), .DMOut(DMOut), .ALU1Out(MEM_ALU1Out), 
		.Imm32(MEM_Imm32), .RD(MEM_RD), .MEM_Flush(MEM_Flush), .CP0Out(CP0Out), .MEM_WBWr(MEM_WBWr),

		.WB_RFWr(WB_RFWr),.WB_MUX2Sel(WB_MUX2Sel), 
		.WB_RD(WB_RD), .WB_PC(WB_PC), .WB_ALU1Out(WB_ALU1Out), .WB_DMOut(WB_DMOut), 
		.WB_RHLOut(WB_RHLOut), .WB_Imm32(WB_Imm32), .WB_CP0Out(WB_CP0Out)
	);

//-------------------W---------------------//
mux2 U_MUX2(
		.ALU1Out(WB_ALU1Out), .RHLOut(WB_RHLOut), .DMOut(WB_DMOut), .PC(WB_PC),
		.Imm32(WB_Imm32),.MUX2Sel(WB_MUX2Sel), .CP0Out(WB_CP0Out),

		.WD(MUX2Out)
	);


bypass U_BYPASS(
		.EX_RS(EX_RS), .EX_RT(EX_RT), .ID_RS(ID_Instr[25:21]), 
		.ID_RT(ID_Instr[20:16]),.MEM_RD(MEM_RD), .WB_RD(WB_RD), 
		.MEM_RFWr(MEM_RFWr), .WB_RFWr(WB_RFWr),.BJOp(B_JOp), .dcache_stall(dcache_stall),
		
		.MUX4Sel(MUX4Sel), .MUX5Sel(MUX5Sel), 
		.MUX8Sel(MUX8Sel), .MUX9Sel(MUX9Sel)
	);

stall U_STALL(
		.clk(clk),.rst(rst) ,
		.EX_RT(MUX1Out), .MEM_RT(MEM_RD), .ID_RS(ID_Instr[25:21]), .ID_RT(ID_Instr[20:16]), 
		.EX_DMRd(EX_DMRd),.ID_PC(ID_PC),.EX_PC(EX_PC), .MEM_DMRd(MEM_DMRd), 
		.BJOp(B_JOp),.EX_RFWr(EX_RFWr), .EX_CP0Rd(EX_CP0Rd), .MEM_CP0Rd(MEM_CP0Rd),
		.rst_sign(!rst), .MEM_ex(MEM_Exception), .MEM_RFWr(MEM_RFWr), 
		.MEM_eret_flush(MEM_eret_flush),.isbusy(EX_isBusy), .RHL_visit(RHL_visit),
		.iCache_data_ok(IF_iCache_data_ok),.dCache_data_ok(MEM_data_ok),.MEM_dCache_en(DMen),
		.EX_cache_sel(EX_cache_sel), .EX_dCache_addr_ok(MEM_dCache_addr_ok),
		.EX_dCache_en(EX_dcache_valid),

		.PCWr(PCWr), .IF_IDWr(IF_IDWr), .MUX7Sel(MUX7Sel),
		.inst_sram_en(IF_iCache_read_en),.isStall(isStall),
		.dcache_stall(dcache_stall), .ID_EXWr(ID_EXWr), .EX_MEMWr(EX_MEMWr), .MEM_WBWr(MEM_WBWr)
	);



 axi_sram_bridge U_AXI_SRAM_BRIDGE(
	 MEM_cache_sel,
    ext_int_in   ,   //high active

    clk      ,
    rst      ,   //low active

    arid      ,
    araddr    ,
    arlen     ,
    arsize    ,
    arburst   ,
    arlock    ,
    arcache   ,
    arprot    ,
    arvalid   ,
    arready   ,
                
    rid       ,
    rdata     ,
    rresp     ,
    rlast     ,
    rvalid    ,
    rready    ,
               
    awid      ,
    awaddr    ,
    awlen     ,
    awsize    ,
    awburst   ,
    awlock    ,
    awcache   ,
    awprot    ,
    awvalid   ,
    awready   ,
    
    wid       ,
    wdata     ,
    wstrb     ,
    wlast     ,
    wvalid    ,
    wready    ,
    
    bid       ,
    bresp     ,
    bvalid    ,
    bready    ,
// icache 
	IF_icache_rd_req,// icache �?? dcache 同时缺失怎么�??
	IF_icache_rd_type,
	IF_icache_rd_addr,
	IF_icache_rd_rdy,
	IF_icache_ret_valid,
	IF_icache_ret_last,
	IF_icache_ret_data,
	IF_icache_wr_req,
	IF_icache_wr_type,
	IF_icache_wr_addr,
	IF_icache_wr_wstrb,
	IF_icache_wr_data,
	IF_icache_wr_rdy,
//	dcache
	MEM_rd_req,
	MEM_rd_type,
	MEM_rd_addr,
	MEM_dcache_rd_rdy,
	MEM_dcache_ret_valid,
	MEM_dcache_ret_last,
	MEM_dcache_ret_data,
	MEM_wr_req,
	MEM_wr_type,
	MEM_wr_addr,
	MEM_wr_wstrb,
	MEM_dcache_wr_data,
	MEM_dcache_wr_rdy,
	MEM_uncache_wr_data
	
);

debug U_DEBUG(MUX2Out, WB_PC, WB_RFWr, MEM_WBWr,WB_RD,
        debug_wb_rf_wdata, debug_wb_pc, debug_wb_rf_wen, debug_wb_rf_wnum );

endmodule
