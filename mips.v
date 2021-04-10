module mips(clk, rst);
	input clk, rst;
	wire PCWr, DMWr, DMRd, RFWr, RHLWr, IF_IDWr, IF_Flush, Overflow, CMPOut1, MUX3Sel, MUX7Sel,RHLSel_Rd,B_JOp;
	wire[1:0] EXTOp, NPCOp, ALU2Op, MUX1Sel, MUX4Sel,MUX5Sel,RHLSel_Wr, CMPOut2;
	wire[2:0] MUX2_6Sel, DMSel, MUX10Sel;
	wire[3:0] ALU1Op;
	wire[2:0] MUX7Out;
	wire[4:0] MUX1Out;
	wire[31:0] PC, NPC, Instr, Imm32, ALU1Out, GPR_RS, GPR_RT, RHLOut, MUX2Out, MUX3Out, MUX4Out, MUX5Out, MUX6Out, MUX8Out, MUX9Out, MUX10Out, DMOut;
	wire[63:0] IF_ID_Out, ALU2Out;
	wire[202:0] ID_EX_Out;
	wire[272:0] EX_MEM_Out;
	wire[267:0] MEM_WB_Out;

pc U_PC(
		.clk(clk), .rst(rst), .wr(PCWr), .D(NPC), .Q(PC)
	);

npc U_NPC(
		.PC(PC), .Imm(IF_ID_Out[25:0]), .ret_addr(MUX8Out), .NPCOp(NPCOp), .NPC(NPC), .IF_Flush(IF_Flush), .PCWr(PCWr)
	);

IF_ID U_IF_ID(
		.clk(clk), .rst(rst), .IF_IDWr(IF_IDWr), .IF_Flush(IF_Flush), .PC(PC), .Instr(Instr), .out(IF_ID_Out)
	);

ID_EX U_ID_EX(
		.clk(clk), .rst(rst), .RHLSel_Rd(RHLSel_Rd), .PC(IF_ID_Out[63:32]), .ALU1Op(ALU1Op), .ALU2Op(ALU2Op), .MUX1Sel(MUX1Sel), .MUX3Sel(MUX3Sel),
		.ALU1Sel(ALU1Sel), .DMWr(MUX7Out[2]), .DMSel(DMSel), .DMRd(DMRd), .RFWr(MUX7Out[1]), .RHLWr(MUX7Out[0]),.RHLSel_Wr(RHLSel_Wr),
		.MUX2Sel(MUX2_6Sel), .RHLOut(RHLOut), .GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .RS(IF_ID_Out[25:21]),.RT(IF_ID_Out[20:16]),
		.RD(IF_ID_Out[15:11]), .Imm32(Imm32), .shamt(IF_ID_Out[10:6]), .out(ID_EX_Out)
	);

EX_MEM U_EX_MEM(
		.clk(clk), .rst(rst), .RHLSel_Wr(ID_EX_Out[152:151]),.Imm32(ID_EX_Out[36:5]), .PC(ID_EX_Out[201:170]), .DMWr(ID_EX_Out[159]), .DMSel(ID_EX_Out[158:156]), .DMRd(ID_EX_Out[155]), 
		.RFWr(ID_EX_Out[154]), .RHLWr(ID_EX_Out[153]), .MUX2Sel(ID_EX_Out[150:148]), .ALU2Out(ALU2Out),
		.RHLOut(MUX10Out), .GPR_RS(MUX4Out), .ALU1Out(ALU1Out), .GPR_RT(MUX5Out), .RD(MUX1Out), .out(EX_MEM_Out)
	);

MEM_WB U_MEM_WB(
		.clk(clk), .rst(rst), .PC(EX_MEM_Out[240:209]), .RFWr(EX_MEM_Out[203]), .RHLWr(EX_MEM_Out[202]), .RHLSel_Wr(EX_MEM_Out[201:200]), 
		.MUX2Sel(EX_MEM_Out[199:197]), .ALU2Out(EX_MEM_Out[196:133]), .RHLOut(EX_MEM_Out[132:101]), .GPR_RS(EX_MEM_Out[100:69]), 
		.DMOut(DMOut), .ALU1Out(EX_MEM_Out[68:37]), .Imm32(EX_MEM_Out[272:241]), .RD(EX_MEM_Out[4:0]), .out(MEM_WB_Out)
	);

im U_IM(
		.addr(PC[12:2]), .dout(Instr)
	);

dm U_DM(
		.clk(clk), .din(EX_MEM_Out[36:5]), .DMWr(EX_MEM_Out[208]), .DMSel(EX_MEM_Out[207:205]), .addr(EX_MEM_Out[49:37]), .dout(DMOut)
	);

rf U_RF(
		.Addr1(IF_ID_Out[25:21]), .Addr2(IF_ID_Out[20:16]), .Addr3(MEM_WB_Out[4:0]), .WD(MUX2Out), .RFWr(MEM_WB_Out[235]), .clk(clk), 
		.rst(rst), .RD1(GPR_RS), .RD2(GPR_RT)
	);

rhl U_RHL(
		.clk(clk), .Din_64(MEM_WB_Out[228:165]), .Din_32(MEM_WB_Out[132:101]), .RHLWr(MEM_WB_Out[234]), .RHLSel_Rd(RHLSel_Rd),
		.RHLSel_Wr(MEM_WB_Out[233:232]), .RHLOut(RHLOut)
	);

ext U_EXT(
		.Imm16(IF_ID_Out[15:0]), .Imm32(Imm32), .EXTOp(EXTOp)
);

cmp U_CMP(
		.GPR_RS(MUX8Out), .GPR_RT(MUX9Out), .CMPOut1(CMPOut1), .CMPOut2(CMPOut2)
	);

alu1 U_ALU1(
		.A(MUX4Out), .B(MUX3Out), .C(ALU1Out), .ALU1Op(ID_EX_Out[169:166]), .ALU1Sel(ID_EX_Out[160]), .Shamt(ID_EX_Out[4:0]), .Overflow(Overflow)
	);

alu2 U_ALU2(
		.A(MUX4Out), .B(MUX5Out), .C(ALU2Out), .ALU2Op(ID_EX_Out[165:164])
	);

mux1 U_MUX1(
		.RT(ID_EX_Out[46:42]), .RD(ID_EX_Out[41:37]), .MUX1Sel(ID_EX_Out[163:162]), .Addr3(MUX1Out)
	);

mux2 U_MUX2(
		.ALU1Out(MEM_WB_Out[68:37]), .RHLOut(MEM_WB_Out[164:133]), .DMOut(MEM_WB_Out[100:69]), .PC(MEM_WB_Out[267:236]), .Imm32(MEM_WB_Out[36:5]),
		.MUX2Sel(MEM_WB_Out[231:229]), .WD(MUX2Out)
	);

mux3 U_MUX3(
		.RD2(MUX5Out), .Imm32(ID_EX_Out[36:5]), .MUX3Sel(ID_EX_Out[161]), .B(MUX3Out)
	);

mux4 U_MUX4(
		.GPR_RS(ID_EX_Out[115:84]), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX4Sel(MUX4Sel), .out(MUX4Out)
	);

mux5 U_MUX5(
		.GPR_RT(ID_EX_Out[83:52]), .data_EX(MUX6Out), .data_MEM(MUX2Out), .MUX5Sel(MUX5Sel), .out(MUX5Out)
	);


mux6 U_MUX6(
		.RHLOut(EX_MEM_Out[132:101]), .ALU1Out(EX_MEM_Out[68:37]), .PC(EX_MEM_Out[240:209]), .Imm32(EX_MEM_Out[272:241]), 
		.MUX6Sel(EX_MEM_Out[198:197]), .out(MUX6Out)
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
		.RHLOut(ID_EX_Out[147:116]), .EX_MEM_ALU2Out(EX_MEM_Out[196:133]), .EX_MEM_GPR_RS(EX_MEM_Out[100:69]), 
		.MEM_WB_ALU2Out(MEM_WB_Out[228:165]), .MEM_WB_GPR_RS(MEM_WB_Out[132:101]), .MUX10Sel(MUX10Sel), .out(MUX10Out));

ctrl U_CTRL(
		.clk(clk), .rst(rst), .OP(IF_ID_Out[31:26]), .Funct(IF_ID_Out[5:0]), .rt(IF_ID_Out[20:16]), .CMPOut1(CMPOut1), .CMPOut2(CMPOut2),
		.MUX1Sel(MUX1Sel), .MUX2Sel(MUX2_6Sel), .MUX3Sel(MUX3Sel), .RFWr(RFWr), .RHLWr(RHLWr), .DMWr(DMWr), .DMRd(DMRd), .NPCOp(NPCOp),
		.EXTOp(EXTOp), .ALU1Op(ALU1Op), .ALU1Sel(ALU1Sel), .ALU2Op(ALU2Op), .RHLSel_Rd(RHLSel_Rd), .RHLSel_Wr(RHLSel_Wr), .DMSel(DMSel),
		.B_JOp(B_JOp)
	);

bypath U_BYPATH(
		.ID_EX_RS(ID_EX_Out[51:47]), .ID_EX_RT(ID_EX_Out[46:42]), .IF_ID_RS(IF_ID_Out[25:21]), .IF_ID_RT(IF_ID_Out[20:16]),
		.EX_MEM_RD(EX_MEM_Out[4:0]), .MEM_WB_RD(MEM_WB_Out[4:0]), .EX_MEM_RFWr(EX_MEM_Out[203]), .MEM_WB_RFWr(MEM_WB_Out[235]),
		.EX_MEM_RHLWr(EX_MEM_Out[202]), .ID_EX_RHLSelRd(ID_EX_Out[202]), .EX_MEM_RHLSelWr(EX_MEM_Out[201:200]), 
		.MEM_WB_RHLWr(MEM_WB_Out[234]), .MEM_WB_RHLSelWr(MEM_WB_Out[233:232]), .BJOp(B_JOp), .MUX4Sel(MUX4Sel), .MUX5Sel(MUX5Sel), 
		.MUX8Sel(MUX8Sel), .MUX9Sel(MUX9Sel), .MUX10Sel(MUX10Sel)
	);

stall U_STALL(
		.ID_EX_RT(MUX1Out), .EX_MEM_RT(EX_MEM_Out[4:0]), .IF_ID_RS(IF_ID_Out[25:21]), .IF_ID_RT(IF_ID_Out[20:16]), 
		.ID_EX_DMRd(ID_EX_Out[155]), .EX_MEM_DMRd(EX_MEM_Out[204]), .PCWr(PCWr), .IF_IDWr(IF_IDWr), .MUX7Sel(MUX7Sel), .BJOp(B_JOp),
		.ID_EX_RFWr(ID_EX_Out[154])
	);

endmodule
