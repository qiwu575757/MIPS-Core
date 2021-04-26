module mips(
	clk, 
	rst,
	inst_sram_rdata  ,
    data_sram_rdata  ,
    inst_sram_en     ,
	data_sram_en     ,
    data_sram_wen    ,
    data_sram_addr   ,
    data_sram_wdata  ,
    //debug
    debug_wb_pc      ,
    debug_wb_rf_wen  ,
    debug_wb_rf_wnum ,
    debug_wb_rf_wdata,
	NPC
	);
	input clk, rst;
	input [31:0] inst_sram_rdata;
    input [31:0] data_sram_rdata  ;
    output inst_sram_en      ;
	output data_sram_en     ;
    output [3:0] data_sram_wen    ;
    output [31:0] data_sram_addr   ;
    output [31:0] data_sram_wdata  ;

    //debug
    output [31:0] debug_wb_pc     ;
    output [3:0] debug_wb_rf_wen  ;
    output [4:0] debug_wb_rf_wnum ;
    output [31:0] debug_wb_rf_wdata;
	output [31:0] NPC;


	/*signals defination*/

	//---------------F----------------//
	wire PCWr,PF_AdEL;//PF_AdEL,取址地址错误
	wire IF_AdEL;
	wire [31:0] PC, ID_PC;

	//---------------D----------------//
	wire DMWr, DMRd, RFWr, RHLWr;
	wire PC_Flush,IF_Flush, MEM_Flush;
	wire CMPOut1;
	wire MUX3Sel, RHLSel_Rd,B_JOp;//B_JOp,is branch or JR or JALR
	wire isBD,isBranch;
	wire ID_Flush, EX_Flush;
	wire eret_flush,CP0WrEn,Exception;

	wire[1:0] EXTOp, NPCOp, ALU2Op, MUX1Sel, RHLSel_Wr, CMPOut2;
	wire[2:0] MUX2_6Sel,DMSel,MUX7Out;
	wire[31:0] MUX8Out, MUX9Out;
	wire[3:0] ALU1Op;
	wire[4:0] ExcCode;
	wire [31:0] Imm32, GPR_RS, GPR_RT;//GPR_RS --> RS DATA
	wire [31:0] ID_Instr;
	wire CP0Rd, RHL_visit;
	wire start;

	//---------------E----------------//
	wire Overflow;
	wire [4:0] MUX1Out;
	wire [31:0] ALU1Out, RHLOut, MUX3Out, MUX4Out, MUX5Out, DMOut;
	wire DMWen;
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
	wire [5:0] ext_int_in = 6'd0;


	/**************DATA PATH***************/

// ---------------IF---------------------//
assign PF_AdEL = NPC[1:0] != 2'b00 && PCWr;
    
pc U_PC(
		//input
		.clk(clk), .rst(rst), .wr(PCWr), .NPC(NPC),  .PF_AdEL(PF_AdEL),.PC_Flush(PC_Flush) 
		//input signals and output signals are separate
		//output
		,.IF_AdEL(IF_AdEL), .PC(PC)
	);

IF_ID U_IF_ID(
		.clk(clk), .rst(rst), .IF_IDWr(IF_IDWr), .IF_Flush(IF_Flush), 
		.PC(PC), .Instr(inst_sram_rdata), .IF_AdEL(IF_AdEL),

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
		.WRSign({DMWr, RFWr, RHLWr}), .MUX7Sel(MUX7Sel),

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
		.RHL_visit(RHL_visit)
	);

npc U_NPC(
		.PC(PC), .Imm(ID_Instr), .ret_addr(MUX8Out), .NPCOp(NPCOp),.PCWr(PCWr), 
		.EPC(EPCOut), .MEM_eret_flush(MEM_eret_flush), .MEM_ex(MEM_Exception),

		.NPC(NPC), .IF_Flush(IF_Flush), .ID_Flush(ID_Flush),
		.EX_Flush(EX_Flush), .PC_Flush(PC_Flush), .MEM_Flush(MEM_Flush)
	);


ID_EX U_ID_EX(
		.clk(clk), .rst(rst), .RHLSel_Rd(RHLSel_Rd), .PC(ID_PC), .ALU1Op(ALU1Op), .ALU2Op(ALU2Op), 
		.MUX1Sel(MUX1Sel), .MUX3Sel(MUX3Sel),.ALU1Sel(ALU1Sel), .DMWr(MUX7Out[2]), .DMSel(DMSel), .DMRd(DMRd), 
		.RFWr(MUX7Out[1]), .RHLWr(MUX7Out[0]),.RHLSel_Wr(RHLSel_Wr), .MUX2Sel(MUX2_6Sel),
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .RS(ID_Instr[25:21]),.RT(ID_Instr[20:16]), .RD(ID_Instr[15:11]), 
		.Imm32(Imm32), .shamt(ID_Instr[10:6]), .eret_flush(eret_flush), .ID_Flush(ID_Flush), .CP0WrEn(CP0WrEn), 
		.Exception(Exception), .ExcCode(ExcCode), .isBD(isBD), .isBranch(isBranch), 
		.CP0Addr({ID_Instr[15:11], ID_Instr[2:0]}), .CP0Rd(CP0Rd), .start(start),

		.EX_eret_flush(EX_eret_flush), .EX_CP0WrEn(EX_CP0WrEn), .EX_Exception(EX_Exception), 
		.EX_ExcCode(EX_ExcCode), .EX_isBD(EX_isBD), .EX_isBranch(EX_isBranch), .EX_RHLSel_Rd(EX_RHLSel_Rd),
	 	.EX_DMWr(EX_DMWr), .EX_DMRd(EX_DMRd), .EX_MUX3Sel(EX_MUX3Sel), .EX_ALU1Sel(EX_ALU1Sel), 
		.EX_RFWr(EX_RFWr), .EX_RHLWr(EX_RHLWr), .EX_ALU2Op(EX_ALU2Op), .EX_MUX1Sel(EX_MUX1Sel), 
		.EX_RHLSel_Wr(EX_RHLSel_Wr), .EX_DMSel(EX_DMSel), .EX_MUX2Sel(EX_MUX2Sel), .EX_ALU1Op(EX_ALU1Op), 
		.EX_RS(EX_RS), .EX_RT(EX_RT), .EX_RD(EX_RD), .EX_shamt(EX_shamt), .EX_PC(EX_PC),
		.EX_GPR_RS(EX_GPR_RS), .EX_GPR_RT(EX_GPR_RT), .EX_Imm32(EX_Imm32), .EX_CP0Addr(EX_CP0Addr),
		.EX_CP0Rd(EX_CP0Rd), .EX_start(EX_start)
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

assign DMWen = 
			EX_DMWr && !MEM_Exception && !Overflow  && !EX_Exception
			&& !MEM_eret_flush && 
			!((EX_DMSel == 3'b010 && ALU1Out[1:0] != 2'b00) || (EX_DMSel == 3'b001 && ALU1Out[0] != 1'b0));

bridge_dm U_BRIDGE(
		 .din(MUX5Out), .DMWr(DMWen), .DMSel1(EX_DMSel),.DMSel2(MEM_DMSel),
		 .addr1(ALU1Out), .addr2(MEM_ALU1Out),.data_sram_rdata(data_sram_rdata),

		 .data_sram_en(data_sram_en),
		 .data_sram_wen(data_sram_wen),
		 .data_sram_addr(data_sram_addr),
		 .data_sram_wdata(data_sram_wdata),
		 .dout(DMOut)
	);


EX_MEM U_EX_MEM(
		.clk(clk), .rst(rst), .Imm32(EX_Imm32), .EX_PC(EX_PC), 
		.DMWr(EX_DMWr), .DMSel(EX_DMSel), .DMRd(EX_DMRd), .RFWr(EX_RFWr), 
		.MUX2Sel(EX_MUX2Sel),.RHLOut(RHLOut), 
		.ALU1Out(ALU1Out), .GPR_RT(MUX5Out), .RD(MUX1Out), .OverFlow(Overflow), .EX_Flush(EX_Flush), 
		.eret_flush(EX_eret_flush), .CP0WrEn(EX_CP0WrEn), .Exception(EX_Exception), .ExcCode(EX_ExcCode), .isBD(EX_isBD),
		.CP0Addr(EX_CP0Addr), .CP0Rd(EX_CP0Rd), 

		.MEM_DMWr(MEM_DMWr), .MEM_DMRd(MEM_DMRd), .MEM_RFWr(MEM_RFWr),
		.MEM_eret_flush(MEM_eret_flush), .MEM_CP0WrEn(MEM_CP0WrEn), .MEM_Exception(MEM_Exception), 
		.MEM_ExcCode(MEM_ExcCode), .MEM_isBD(MEM_isBD),
		.MEM_DMSel(MEM_DMSel), .MEM_MUX2Sel(MEM_MUX2Sel), .MEM_RD(MEM_RD), .MEM_PC(MEM_PC), .MEM_RHLOut(MEM_RHLOut), 
		.MEM_ALU1Out(MEM_ALU1Out), .MEM_GPR_RT(MEM_GPR_RT), .MEM_Imm32(MEM_Imm32), 
		.badvaddr(badvaddr), .MEM_CP0Addr(MEM_CP0Addr), .MEM_CP0Rd(MEM_CP0Rd)
	);


//------------------MEM-------------------------//
CP0 U_CP0(
		.clk(clk), .rst(rst), .CP0WrEn(MEM_CP0WrEn), .addr(MEM_CP0Addr), .data_in(MEM_GPR_RT), 
		.MEM_Exc(MEM_Exception), .MEM_eret_flush(MEM_eret_flush), .MEM_bd(MEM_isBD),
        .ext_int_in(ext_int_in), .MEM_ExcCode(MEM_ExcCode), .MEM_badvaddr(badvaddr), 
		.MEM_PC(MEM_PC),
		
		.data_out(CP0Out), .EPC_out(EPCOut), .Interrupt(Interrupt)
	);

mux6 U_MUX6(
		.RHLOut(MEM_RHLOut), .ALU1Out(MEM_ALU1Out), .PC(MEM_PC),
		.Imm32(MEM_Imm32), .MUX6Sel(MEM_MUX2Sel[1:0]),
		
		.out(MUX6Out)
	);


MEM_WB U_MEM_WB(
		.clk(clk), .rst(rst), .PC(MEM_PC), .RFWr(MEM_RFWr),.MUX2Sel(MEM_MUX2Sel),
		.RHLOut(MEM_RHLOut), .DMOut(DMOut), .ALU1Out(MEM_ALU1Out), 
		.Imm32(MEM_Imm32), .RD(MEM_RD), .MEM_Flush(MEM_Flush), .CP0Out(CP0Out),

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
		.MEM_RFWr(MEM_RFWr), .WB_RFWr(WB_RFWr),.BJOp(B_JOp),
		
		.MUX4Sel(MUX4Sel), .MUX5Sel(MUX5Sel), 
		.MUX8Sel(MUX8Sel), .MUX9Sel(MUX9Sel)
	);

stall U_STALL(
		.EX_RT(MUX1Out), .MEM_RT(MEM_RD), .ID_RS(ID_Instr[25:21]), .ID_RT(ID_Instr[20:16]), 
		.EX_DMRd(EX_DMRd),.ID_PC(ID_PC),.EX_PC(EX_PC), .MEM_DMRd(MEM_DMRd), 
		.BJOp(B_JOp),.EX_RFWr(EX_RFWr), .EX_CP0Rd(EX_CP0Rd), .MEM_CP0Rd(MEM_CP0Rd),
		.rst_sign(!rst), .MEM_ex(MEM_Exception), .MEM_RFWr(MEM_RFWr), 
		.MEM_eret_flush(MEM_eret_flush),.isbusy(EX_isBusy), .RHL_visit(RHL_visit),

		.PCWr(PCWr), .IF_IDWr(IF_IDWr), .MUX7Sel(MUX7Sel),
		.inst_sram_en(inst_sram_en),.isStall(isStall)
	);

assign 
	debug_wb_rf_wdata = MUX2Out;
assign 
	debug_wb_pc  = WB_PC;
assign 
	debug_wb_rf_wen  = {4{WB_RFWr}};
assign 
	debug_wb_rf_wnum  = WB_RD[4:0];


endmodule
