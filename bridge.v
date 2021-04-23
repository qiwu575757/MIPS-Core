module bridge_dm(
	din, DMWr, DMSel1,DMSel2, addr1, addr2, dout,
	data_sram_en,
	data_sram_wen,
	data_sram_addr,
	data_sram_wdata,
	data_sram_rdata
	);
	output data_sram_en;
	output [3:0] data_sram_wen;
	output [31:0] data_sram_addr;
	output [31:0] data_sram_wdata;
	input [31:0] data_sram_rdata;
	input  DMWr;
	input[2:0] DMSel1;
	input[2:0] DMSel2;
	input[31:0] addr1;
	input[31:0] addr2;
	input[31:0] din;
	output [31:0] dout;
	// reg[31:0] dmem[2047:0];//8k
	reg[7:0] byte;
	reg[15:0] halfword;
	reg[31:0] word;

	assign data_sram_wdata=
							(DMSel1==3'b000)?   // btyte
											{4{din[7:0]}}:
							(DMSel1==3'b001)?   // sh
											{2{din[15:0]}}:
											din;
	assign data_sram_en=1'b1;
	assign data_sram_wen=(~DMWr)?4'b0:
							(DMSel1==3'b000)?
								(addr1[1:0]==2'b00 ? 4'b0001 :
								addr1[1:0]==2'b01 ? 4'b0010 :
								addr1[1:0]==2'b10 ? 4'b0100 :
								 				   4'b1000) :
							(DMSel1==3'b001)?   // sh
								(addr1[1]==1'b0 ? 4'b0011 :
								  				4'b1100 ):
		
												4'b1111 ;//sw


	assign data_sram_addr={addr1[31:2],2'b0}-32'ha000_0000;
	assign dout=
				DMSel2==3'b011 ?  // zero
				(  	addr2[1:0]==2'b00 ? {24'b0,data_sram_rdata[7:0]} :
					addr2[1:0]==2'b01 ? {24'b0,data_sram_rdata[15:8]} :
					addr2[1:0]==2'b10 ? {24'b0,data_sram_rdata[23:16]} :
									   {24'b0,data_sram_rdata[31:24]}) :
				DMSel2==3'b100 ?
				(   addr2[1:0]==2'b00 ? {{24{data_sram_rdata[ 7]}},data_sram_rdata[ 7: 0]} :
					addr2[1:0]==2'b01 ? {{24{data_sram_rdata[15]}},data_sram_rdata[15: 8]} :
					addr2[1:0]==2'b10 ? {{24{data_sram_rdata[23]}},data_sram_rdata[23:16]} :
									   {{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}) :
				DMSel2==3'b101 ?
				( 	addr2[1]==1'b0 	 ? {16'h0000,data_sram_rdata[15:0]}  :
								 	   {16'h0000,data_sram_rdata[31:16]})  :
				DMSel2==3'b110 ?
				(	addr2[1]==1'b0 	 ? {{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}  :
							    	   {{16{data_sram_rdata[31]}},data_sram_rdata[31:16]} ) :
																data_sram_rdata;
														




	
// 	always@(din, addr)
// 		case(addr[1:0])
// 			2'b00:	byte = dmem[addr[12:2]][7:0];
// 			2'b01:	byte = dmem[addr[12:2]][15:8];
// 			2'b10:	byte = dmem[addr[12:2]][23:16];
// 			default:byte = dmem[addr[12:2]][31:24];
// 		endcase

// 	always@(din, addr)
// 		if(addr[1])
// 			halfword = dmem[addr[12:2]][31:16];
// 		else
// 			halfword = dmem[addr[12:2]][15:0];

// 	always@(din, addr)
// 		word = dmem[addr[12:2]];


// 	always@(byte,halfword,word,DMSel)
// 		case(DMSel)
// 			3'b011:	dout = {24'h000000,byte};	//zero extension,byte to word
// 			3'b100:	if(byte[7])						//sign extension,byte to word
// 						dout = {24'hffffff,byte};
// 					else
// 						dout = {24'h000000,byte};
// 			3'b101:	dout = {16'h0000,halfword};	//zero extension,halfword to word
// 			3'b110:	if(halfword[15])						//sign extension,halfword to word
// 						dout = {16'hffff,halfword};
// 					else
// 						dout = {16'h0000,halfword};
// 			default:dout = word; 					//no extension
// 		endcase
// endmodule

endmodule


// 这个模块用于当前与cpu与乘除器的交互。
// 借助状态机来控制
// * start为1时，乘除法开始计算
// * isBusy为1时，表示正在运行
// * 乘法单周期运算，除法多周期（34个）。
// * C是运算结果，支持都保存，即如果没有新的start，结果会保持为上一次的运算结果
module brodge_RHL(
		aclk,aresetn,A, B, C, ALU2Op,start,isBusy,
	);
input aclk;
input aresetn;
input [31:0 ]A;
input [31:0] B;
input [1:0] ALU2Op;
input start;
output isBusy;
output [63:0] C;
wire [63:0] divider_sign_out;
wire [63:0] divider_unsign_out;
wire [63:0] multi_sign_out;
wire [63:0] multi_unsign_out;
reg [63:0] temp;
reg present_state;
reg next_state;
wire m_axis_dout_tvalid1;
wire m_axis_dout_tvalid2;

wire[63:0] tempA, tempB;

assign tempA = A[31] ? {32'hffffffff,A} : {32'h00000000,A};
assign tempB = B[31] ? {32'hffffffff,B} : {32'h00000000,B};


assign C=temp;
assign isBusy=present_state;

parameter state_free = 1'b0 ;
parameter state_busy = 1'b1 ;

    // 2'b00: C = A * B;
    // 2'b01: C = tempA * tempB;
    // 2'b10: C = {R1,Q1};//unsigned
    // 2'b11: C = {R2,Q2};//signed
assign multi_sign_out=A*B;
assign multi_unsign_out=tempA*tempB;


always @(posedge aclk) begin
	if(ALU2Op==2'b00 &&start)
		temp<=multi_sign_out;
	else if(ALU2Op==2'b01 &&start)
		temp<=multi_unsign_out;
	else if(m_axis_dout_tvalid1) //sign
		temp<=divider_sign_out;
	else if(m_axis_dout_tvalid2 ) //unsign
		temp<=divider_unsign_out;
end

always @(posedge aclk ) begin
	if(aresetn)
	begin
		present_state=state_free;
	end
	else 
	begin
		present_state=next_state;
	end
end

always @(posedge aclk ) begin
	if(start&ALU2Op[1])
	begin
		next_state=state_busy;
	end
	else if (m_axis_dout_tvalid1|m_axis_dout_tvalid2)
	begin
		next_state=state_free;
	end
end



Divider divider (
  .aclk(aclk),                                      // input wire aclk
  .aresetn(aresetn),                                // input wire aresetn
  .s_axis_divisor_tvalid(start&ALU2Op[1]&ALU2Op[0]),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(B),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(start&ALU2Op[1]&ALU2Op[0]),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(A),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid1),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(divider_sign_out)            // output wire [63 : 0] m_axis_dout_tdata
);
Divider_Unsighed divider_unsign (
  .aclk(aclk),                                      // input wire aclk
  .aresetn(aresetn),                                // input wire aresetn
  .s_axis_divisor_tvalid(start&ALU2Op[1]&~ALU2Op[0]),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(B),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(start&ALU2Op[1]&~ALU2Op[0]),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(A),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid2),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(divider_unsign_out)            // output wire [63 : 0] m_axis_dout_tdata
);



endmodule