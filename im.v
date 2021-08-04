module im(addr, dout);
	input[12:2] addr;
	output[31:0] dout;
	reg[31:0] imem[2047:0];//8k
	
	assign dout = imem[{1'b0,addr[11:2]}];

endmodule
