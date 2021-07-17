module rf(
	Addr1, Addr2, Addr3, WD, RFWr, clk, rst, 
	
	RD1, RD2, bypass_WB_rs, bypass_WB_rt
);
	input[4:0] Addr1, Addr2, Addr3;
	input[31:0] WD;
	input RFWr, clk, rst;
	output[31:0] RD1, RD2;
	output bypass_WB_rs,bypass_WB_rt;
	reg[31:0] register[31:0];

	integer i;

	always@(posedge clk)
		if(!rst)
			for(i = 0; i <= 31; i = i + 1)
				register[i] <= 32'h0000_0000;
		else if(RFWr)
			register[Addr3] <= WD;

	assign RD1 = register[Addr1];
	assign RD2 = register[Addr2];

	assign bypass_WB_rs = (Addr1 == Addr3) && RFWr;
	assign bypass_WB_rt = (Addr2 == Addr3) && RFWr;

endmodule
