module dm(clk, din, DMWr, DMSel, addr, dout);
	input clk, DMWr;
	input[2:0] DMSel;
	input[12:0] addr;
	input[31:0] din;
	output reg[31:0] dout;
	reg[31:0] dmem[2047:0];//8k
	reg[7:0] byte;
	reg[15:0] halfword;
	reg[31:0] word;

	always@(posedge clk)
		if(DMWr)
			case(DMSel)
				3'b000: case(addr[1:0])//sb
							2'b00:	dmem[addr[12:2]][7:0] <= din[7:0];
							2'b01:	dmem[addr[12:2]][15:8] <= din[7:0];
							2'b10:	dmem[addr[12:2]][23:16] <= din[7:0];
							default:dmem[addr[12:2]][31:24] <= din[7:0];
						endcase
				3'b001: case(addr[1])	//sh
							1'b0:	dmem[addr[12:2]][15:0] <= din[15:0];
							default:dmem[addr[12:2]][31:16] <= din[15:0];
						endcase
				default: dmem[addr[12:2]] <= din;				//sw
			endcase
	
	always@(din, addr)
		case(addr[1:0])
			2'b00:	byte = dmem[addr[12:2]][7:0];
			2'b01:	byte = dmem[addr[12:2]][15:8];
			2'b10:	byte = dmem[addr[12:2]][23:16];
			default:byte = dmem[addr[12:2]][31:24];
		endcase

	always@(din, addr)
		if(addr[1])
			halfword = dmem[addr[12:2]][31:16];
		else
			halfword = dmem[addr[12:2]][15:0];

	always@(din, addr)
		word = dmem[addr[12:2]];


	always@(byte,halfword,word,DMSel)
		case(DMSel)
			3'b011:	dout = {24'h000000,byte};	//zero extension,byte to word
			3'b100:	if(byte[7])						//sign extension,byte to word
						dout = {24'hffffff,byte};
					else
						dout = {24'h000000,byte};
			3'b101:	dout = {16'h0000,halfword};	//zero extension,halfword to word
			3'b110:	if(halfword[15])						//sign extension,halfword to word
						dout = {16'hffff,halfword};
					else
						dout = {16'h0000,halfword};
			default:dout = word; 					//no extension
		endcase
endmodule
