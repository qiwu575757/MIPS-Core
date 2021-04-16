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
    debug_wb_rf_wen  ,//榛樿鍐橰F鍧囦负 4 瀛楄妭
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

	wire PCWr, DMWr, DMRd, RFWr, RHLWr, IF_IDWr, PF_AdEL, PC_Flush, IF_Flush, IF_AdEL, Overflow, CMPOut1, MUX3Sel, MUX7Sel,RHLSel_Rd,B_JOp,
		isBD, isBranch, ID_Flush, EX_Flush, Interrupt, eret_flush, CP0WrEn, Exception;
	wire[1:0] EXTOp, NPCOp, ALU2Op, MUX1Sel, MUX4Sel,MUX5Sel,RHLSel_Wr, CMPOut2;
	wire[2:0] MUX2_6Sel, DMSel, MUX10Sel;
	wire[3:0] ALU1Op;
	wire[2:0] MUX7Out;
	wire[4:0] MUX1Out, ExcCode;
	wire[31:0]  Imm32, ALU1Out, GPR_RS, GPR_RT, RHLOut, MUX2Out, MUX3Out, MUX4Out, MUX5Out, 
				MUX6Out, MUX8Out, MUX9Out, MUX10Out, DMOut;
	wire[63:0] ALU2Out;

    wire [31:0] PC;
	wire [31:0] ID_PC;
	wire [31:0] ID_Instr;
	wire IDWr;

	wire [31:0] badvaddr;
	wire CP0Rd;
	reg rst_sign;

	wire [5:0] ext_int_in = 6'd0;
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
	wire [31:0] EX_PC, EX_RHLOut, EX_GPR_RS, EX_GPR_RT, EX_Imm32;
	wire EX_CP0Rd;

	wire  MEM_DMWr, MEM_DMRd, MEM_RFWr, MEM_RHLWr;
	wire  MEM_eret_flush;
	wire MEM_CP0WrEn;
	wire MEM_Exception;
	wire [4:0] MEM_ExcCode;
	wire MEM_isBD;
	wire[1:0] MEM_RHLSel_Wr;
	wire[2:0] MEM_DMSel, MEM_MUX2Sel;
	wire[4:0] MEM_RD;
	wire[31:0] MEM_PC, MEM_RHLOut, MEM_GPR_RS, MEM_ALU1Out, MEM_GPR_RT, MEM_Imm32;
	wire[63:0] MEM_ALU2Out;
	wire MEM_CP0Rd;

	wire WB_RFWr, WB_RHLWr;
	wire[1:0] WB_RHLSel_Wr;
	wire[2:0] WB_MUX2Sel;
	wire[4:0] WB_RD;
	wire[31:0] WB_PC, WB_ALU1Out, WB_DMOut, WB_RHLOut, WB_Imm32, WB_GPR_RS, WB_CP0Out;
	wire[63:0] WB_ALU2Out;

	wire [31:0] CP0Out;
	wire [31:0] EPCOut;

    always@(posedge clk)
        rst_sign <= !rst;
    
    assign PF_AdEL = NPC[1:0] != 2'b00 && PCWr;

pc U_PC(
		.clk(clk), .rst(rst), .wr(PCWr), .NPC(NPC), .PC(PC), .PF_AdEL(PF_AdEL), .IF_AdEL(IF_AdEL), .PC_Flush(PC_Flush)
	);
	
    
npc U_NPC(
		.PC(PC), .Imm(ID_Instr), .ret_addr(MUX8Out), .NPCOp(NPCOp), .NPC(NPC), .IF_Flush(IF_Flush), .PCWr(PCWr), 
		.EPC(EPCOut), .EX_MEM_eret_flush(MEM_ere_flush), .EX_MEM_ex(MEM_Exception), .ID_Flush(ID_Flush),
		.EX_Flush(EX_Flush), .PC_Flush(PC_Flush)
	);

IF_ID U_IF_ID(
		.clk(clk), .rst(rst), .IF_IDWr(IF_IDWr), .IF_Flush(IF_Flush), .PC(PC), .Instr(inst_sram_rdata), .ID_PC(ID_PC), 
		.ID_Instr(ID_Instr)
	);

ID_EX U_ID_EX(
		.clk(clk), .rst(rst), .RHLSel_Rd(RHLSel_Rd), .PC(ID_PC), .ALU1Op(ALU1Op), .ALU2Op(ALU2Op), 
		.MUX1Sel(MUX1Sel), .MUX3Sel(MUX3Sel),.ALU1Sel(ALU1Sel), .DMWr(MUX7Out[2]), .DMSel(DMSel), .DMRd(DMRd), 
		.RFWr(MUX7Out[1]), .RHLWr(MUX7Out[0]),.RHLSel_Wr(RHLSel_Wr), .MUX2Sel(MUX2_6Sel), .RHLOut(RHLOut), 
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .RS(ID_Instr[25:21]),.RT(ID_Instr[20:16]), .RD(ID_Instr[15:11]), 
		.Imm32(Imm32), .shamt(ID_Instr[10:6]), .eret_flush(eret_flush), .ID_Flush(ID_Flush), .CP0WrEn(CP0WrEn), 
		.Exception(Exception), .ExcCode(ExcCode), .isBD(isBD), .isBranch(isBranch), 
		.CP0Addr({ID_Instr[15:11], ID_Instr[2:0]}), .CP0Rd(CP0Rd),
		.EX_eret_flush(EX_eret_flush), .EX_CP0WrEn(EX_CP0WrEn), .EX_Exception(EX_Exception), 
		.EX_ExcCode(EX_ExcCode), .EX_isBD(EX_isBD), .EX_isBranch(EX_isBranch), .EX_RHLSel_Rd(EX_RHLSel_Rd),
	 	.EX_DMWr(EX_DMWr), .EX_DMRd(EX_DMRd), .EX_MUX3Sel(EX_MUX3Sel), .EX_ALU1Sel(EX_ALU1Sel), 
		.EX_RFWr(EX_RFWr), .EX_RHLWr(EX_RHLWr), .EX_ALU2Op(EX_ALU2Op), .EX_MUX1Sel(EX_MUX1Sel), 
		.EX_RHLSel_Wr(EX_RHLSel_Wr), .EX_DMSel(EX_DMSel), .EX_MUX2Sel(EX_MUX2Sel), .EX_ALU1Op(EX_ALU1Op), 
		.EX_RS(EX_RS), .EX_RT(EX_RT), .EX_RD(EX_RD), .EX_shamt(EX_shamt), .EX_PC(EX_PC), .EX_RHLOut(EX_RHLOut), 
		.EX_GPR_RS(EX_GPR_RS), .EX_GPR_RT(EX_GPR_RT), .EX_Imm32(EX_Imm32), .EX_CP0Addr(EX_CP0Addr),
		.EX_CP0Rd(EX_CP0Rd)
	);

EX_MEM U_EX_MEM(
		.clk(clk), .rst(rst), .RHLSel_Wr(EX_RHLSel_Wr),.Imm32(EX_Imm32), .PC(EX_PC), 
		.DMWr(EX_DMWr), .DMSel(EX_DMSel), .DMRd(EX_DMRd), .RFWr(EX_RFWr), 
		.RHLWr(EX_RHLWr), .MUX2Sel(EX_MUX2Sel), .ALU2Out(ALU2Out), .RHLOut(MUX10Out), 
		.GPR_RS(MUX4Out), .ALU1Out(ALU1Out), .GPR_RT(MUX5Out), .RD(MUX1Out), .OverFlow(Overflow), .EX_Flush(EX_Flush), 
		.eret_flush(EX_eret_flush), .CP0WrEn(EX_CP0WrEn), .Exception(EX_Exception), .ExcCode(EX_ExcCode), .isBD(EX_isBD),
		.CP0Addr(EX_CP0Addr), .CP0Rd(EX_CP0Rd), 
		.MEM_DMWr(MEM_DMWr), .MEM_DMRd(MEM_DMRd), .MEM_RFWr(MEM_RFWr), .MEM_RHLWr(MEM_RHLWr), 
		.MEM_eret_flush(MEM_ere_flush), .MEM_CP0WrEn(MEM_CP0WrEn), .MEM_Exception(MEM_Exception), 
		.MEM_ExcCode(MEM_ExcCode), .MEM_isBD(MEM_isBD), .MEM_RHLSel_Wr(MEM_RHLSel_Wr), 
		.MEM_DMSel(MEM_DMSel), .MEM_MUX2Sel(MEM_MUX2Sel), .MEM_RD(MEM_RD), .MEM_PC(MEM_PC), .MEM_RHLOut(MEM_RHLOut), 
		.MEM_GPR_RS(MEM_GPR_RS), .MEM_ALU1Out(MEM_ALU1Out), .MEM_GPR_RT(MEM_GPR_RT), .MEM_Imm32(MEM_Imm32), 
		.MEM_ALU2Out(MEM_ALU2Out), .badvaddr(badvaddr), .MEM_CP0Addr(MEM_CPOAddr), .MEM_CP0Rd(MEM_CP0Rd)
	);

MEM_WB U_MEM_WB(
		.clk(clk), .rst(rst), .PC(MEM_PC), .RFWr(MEM_RFWr), .RHLWr(MEM_RHLWr),
		.RHLSel_Wr(MEM_RHLSel_Wr), .MUX2Sel(MEM_MUX2Sel), .ALU2Out(MEM_ALU2Out), 
		.RHLOut(MEM_RHLOut), .GPR_RS(MEM_GPR_RS), .DMOut(DMOut), .ALU1Out(MEM_ALU1Out), 
		.Imm32(MEM_Imm32), .RD(MEM_RD), .CP0Out(CP0Out),
		.WB_RFWr(WB_RFWr), .WB_RHLWr(WB_RHLWr), .WB_RHLSel_Wr(WB_RHLSel_Wr), .WB_MUX2Sel(WB_MUX2Sel), 
		.WB_RD(WB_RD), .WB_PC(WB_PC), .WB_ALU1Out(WB_ALU1Out), .WB_DMOut(WB_DMOut), 
		.WB_RHLOut(WB_RHLOut), .WB_Imm32(WB_Imm32), .WB_GPR_RS(WB_GPR_RS), .WB_CP0Out(WB_CP0Out), 
		.WB_ALU2Out(WB_ALU2Out)
	);

// im U_IM(
// 		.addr(PC[12:2]), .dout(Instr)
// 	);

// dm U_DM(
// 		.clk(clk), .din(MEM_GPR_RT), .DMWr(MEM_DMWr), .DMSel(MEM_DMSel), .addr(MEM_ALU1Out[12:0]), .dout(DMOut)
// 	);

//===========================
bridge U_BRIDGE(
		 .din(MUX5Out), .DMWr(EX_DMWr), .DMSel1(EX_DMSel),.DMSel2(MEM_DMSel), .addr1(ALU1Out), .addr2(MEM_ALU1Out),.dout(DMOut),
		 .data_sram_en(data_sram_en),
		 .data_sram_wen(data_sram_wen),
		 .data_sram_addr(data_sram_addr),
		 .data_sram_wdata(data_sram_wdata),
		 .data_sram_rdata(data_sram_rdata)
	);

rf U_RF(
		.Addr1(ID_Instr[25:21]), .Addr2(ID_Instr[20:16]), .Addr3(WB_RD[4:0]), .WD(MUX2Out), .RFWr(WB_RFWr), .clk(clk), 
		.rst(rst), .RD1(GPR_RS), .RD2(GPR_RT)
	);

rhl U_RHL(
		.clk(clk), .Din_64(WB_ALU2Out), .Din_32(WB_GPR_RS), .RHLWr(WB_RHLWr), .RHLSel_Rd(RHLSel_Rd),
		.RHLSel_Wr(WB_RHLSel_Wr), .RHLOut(RHLOut)
	);

ext U_EXT(
		.Imm16(ID_Instr[15:0]), .Imm32(Imm32), .EXTOp(EXTOp)
);

cmp U_CMP(
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .CMPOut1(CMPOut1), .CMPOut2(CMPOut2)
	);

alu1 U_ALU1(
		.A(MUX4Out), .B(MUX3Out), .C(ALU1Out), .ALU1Op(EX_ALU1Op), .ALU1Sel(EX_ALU1Sel), 
		.Shamt(EX_shamt), .Overflow(Overflow)
	);

alu2 U_ALU2(
		.A(MUX4Out), .B(MUX5Out), .C(ALU2Out), .ALU2Op(EX_ALU2Op)
	);

mux1 U_MUX1(
		.RT(EX_RT), .RD(EX_RD), .MUX1Sel(EX_MUX1Sel), .Addr3(MUX1Out)
	);

mux2 U_MUX2(
		.ALU1Out(WB_ALU1Out), .RHLOut(WB_RHLOut), .DMOut(WB_DMOut), .PC(WB_PC), .Imm32(WB_Imm32),
		.MUX2Sel(WB_MUX2Sel), .WD(MUX2Out), .CP0Out(WB_CP0Out)
	);

mux3 U_MUX3(
		.RD2(MUX5Out), .Imm32(EX_Imm32), .MUX3Sel(EX_MUX3Sel), .B(MUX3Out)
	);

mux4 U_MUX4(
		.GPR_RS(EX_GPR_RS), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX4Sel(MUX4Sel), .out(MUX4Out)
	);

mux5 U_MUX5(
		.GPR_RT(EX_GPR_RT), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX5Sel(MUX5Sel), .out(MUX5Out)
	);


mux6 U_MUX6(
		.RHLOut(MEM_RHLOut), .ALU1Out(MEM_ALU1Out), .PC(MEM_PC), .Imm32(MEM_Imm32), 
		.MUX6Sel(MEM_MUX2Sel[1:0]), .out(MUX6Out)
	);

mux7 U_MUX7(
		.WRSign({DMWr, RFWr, RHLWr}), .MUX7Sel(MUX7Sel), .MUX7Out(MUX7Out)
	);

mux8 U_MUX8(
		.GPR_RS(GPR_RS), .data_MEM(MUX6Out), .MUX8Sel(MUX8Sel), .out(MUX8Out)
	);

mux9 U_MUX9(
		.GPR_RT(GPR_RT), .data_MEM(MUX6Out), .MUX9Sel(MUX9Sel), .out(MUX9Out)
	);

mux10 U_MUX10(
		.RHLOut(EX_RHLOut), .EX_MEM_ALU2Out(MEM_ALU2Out), .EX_MEM_GPR_RS(MEM_GPR_RS), 
		.MEM_WB_ALU2Out(WB_ALU2Out), .MEM_WB_GPR_RS(WB_GPR_RS), .MUX10Sel(MUX10Sel), .out(MUX10Out));

ctrl U_CTRL(
		.clk(clk), .rst(rst), .OP(ID_Instr[31:26]), .Funct(ID_Instr[5:0]), .rt(ID_Instr[20:16]), .CMPOut1(CMPOut1), 
		.CMPOut2(CMPOut2), .rs(ID_Instr[25:21]), .ID_EXE_isBranch(EX_isBranch), .Interrupt(Interrupt), 
		.IF_AdEL(IF_AdEL), .IF_Flush(IF_Flush),
		.MUX1Sel(MUX1Sel), .MUX2Sel(MUX2_6Sel), .MUX3Sel(MUX3Sel), .RFWr(RFWr), .RHLWr(RHLWr), .DMWr(DMWr), .DMRd(DMRd), 
		.NPCOp(NPCOp), .EXTOp(EXTOp), .ALU1Op(ALU1Op), .ALU1Sel(ALU1Sel), .ALU2Op(ALU2Op), .RHLSel_Rd(RHLSel_Rd), 
		.RHLSel_Wr(RHLSel_Wr), .DMSel(DMSel), .B_JOp(B_JOp), .eret_flush(eret_flush), .CP0WrEn(CP0WrEn), 
		.Exception(Exception), .ExcCode(ExcCode), .isBD(isBD), .isBranch(isBranch), .CP0Rd(CP0Rd)
	);

bypath U_BYPATH(
		.ID_EX_RS(EX_RS), .ID_EX_RT(EX_RT), .IF_ID_RS(ID_Instr[25:21]), .IF_ID_RT(ID_Instr[20:16]),
		.EX_MEM_RD(MEM_RD), .MEM_WB_RD(WB_RD), .EX_MEM_RFWr(MEM_RFWr), .MEM_WB_RFWr(WB_RFWr),
		.EX_MEM_RHLWr(MEM_RHLWr), .ID_EX_RHLSelRd(EX_RHLSel_Rd), .EX_MEM_RHLSelWr(MEM_RHLSel_Wr), 
		.MEM_WB_RHLWr(WB_RHLWr), .MEM_WB_RHLSelWr(WB_RHLSel_Wr), .BJOp(B_JOp), .MUX4Sel(MUX4Sel), .MUX5Sel(MUX5Sel), 
		.MUX8Sel(MUX8Sel), .MUX9Sel(MUX9Sel), .MUX10Sel(MUX10Sel)
	);

stall U_STALL(
		.ID_EX_RT(MUX1Out), .EX_MEM_RT(MEM_RD), .IF_ID_RS(ID_Instr[25:21]), .IF_ID_RT(ID_Instr[20:16]), 
		.ID_EX_DMRd(EX_DMRd), .EX_MEM_DMRd(MEM_DMRd), .PCWr(PCWr), .IF_IDWr(IF_IDWr), .MUX7Sel(MUX7Sel),
		.BJOp(B_JOp),.ID_EX_RFWr(EX_RFWr), .ID_EX_CP0Rd(EX_CP0Rd), .EX_MEM_CP0Rd(MEM_CP0Rd),
		.rst_sign(rst_sign), .inst_sram_en(inst_sram_en)
	);

CP0 U_CP0(
		.clk(clk), .rst(rst), .CP0WrEn(MEM_CP0WrEn), .addr(MEM_CPOAddr), .data_in(MEM_GPR_RT), 
		.EX_MEM_Exc(MEM_Exception), .EX_MEM_eret_flush(MEM_ere_flush), .EX_MEM_bd(MEM_isBD),
        .ext_int_in(ext_int_in), .EX_MEM_ExcCode(MEM_ExcCode), .EX_MEM_badvaddr(EX_MEM_badvaddr), 
		.EX_MEM_PC(MEM_PC), .data_out(CP0Out), .EPC_out(EPCOut), .Interrupt(Interrupt)
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
