module bridge(
	din, DMWr, DMSel, addr, dout,
	data_sram_en,
	data_sram_wen,
	data_sram_addr,
	data_sram_wdata,
	data_sram_rdata
	);
	input data_sram_en;
	input [3:0] data_sram_wen;
	input [31:0] data_sram_addr;
	input [31:0] data_sram_wdata;
	input [31:0] data_sram_rdata;
	input  DMWr;
	input[2:0] DMSel;
	input[31:0] addr;
	input[31:0] din;
	output reg[31:0] dout;
	reg[31:0] dmem[2047:0];//8k
	reg[7:0] byte;
	reg[15:0] halfword;
	reg[31:0] word;

	assign data_sram_wdata=
							(DMSel==3'b000)?   // btyte
											{4{din[7:0]}}:
							(DMSel==3'b001)?   // sh
											{2{din[15:0]}}:
											din;
	assign data_sram_en=1'b1;
	assign data_sram_wen=(~DMWr)?4'b0:
							(DMSel==3'b000)?
								(addr[1:0]==2'b00 ? 4'b0001 :
								addr[1:0]==2'b01 ? 4'b0010 :
								addr[1:0]==2'b10 ? 4'b0100 :
								 				   4'b1000) :
							(DMSel==3'b001)?   // sh
								addr[1]==1'b0 ? 4'b0011 :
								  				4'b1100 :
		
												4'b1111 ;//sw


	assign data_sram_addr={addr[31:2],2'b0};
	assign dout=
				DMSel==3'b011 ?  // zero
				(  	addr[1:0]==2'b00 ? {24'b0,data_sram_rdata[7:0]} :
					addr[1:0]==2'b01 ? {24'b0,data_sram_rdata[15:8]} :
					addr[1:0]==2'b10 ? {24'b0,data_sram_rdata[23:16]} :
									   {24'b0,data_sram_rdata[31:24]}) :
				DMSel==3'b100 ?
				(   addr[1:0]==2'b00 ? {24{data_sram_rdata[ 7]},data_sram_rdata[ 7: 0]} :
					addr[1:0]==2'b01 ? {24{data_sram_rdata[15]},data_sram_rdata[15: 8]} :
					addr[1:0]==2'b10 ? {24{data_sram_rdata[23]},data_sram_rdata[23:16]} :
									   {24{data_sram_rdata[31]},data_sram_rdata[31:24]}) :
				DMSel==3'b101 ?
				( 	addr[1]==1'b0 	 ? {16'h0000,data_sram_rdata[15:0]}  :
								 	 ? {16'h0000,data_sram_rdata[31:16]})  :
				DMSel==3'b110 ?
				(	addr[1]==1'b0 	 ? {16{data_sram_rdata[15]},data_sram_rdata[15:0]}  :
							    	   {16{data_sram_rdata[31]},data_sram_rdata[31:16]} ) :
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
