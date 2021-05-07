module  bridge_dm(
	addr2,
	Din,
	DMSel2,

	dout
);
	input [31:0] addr2;
	input [31:0] Din;
	input [2:0] DMSel2;
	output [31:0] dout;

assign dout=
				DMSel2==3'b011 ?  // zero
				(  	addr2[1:0]==2'b00 ? {24'b0,Din[7:0]} :
					addr2[1:0]==2'b01 ? {24'b0,Din[15:8]} :
					addr2[1:0]==2'b10 ? {24'b0,Din[23:16]} :
									   {24'b0,Din[31:24]}) :
				DMSel2==3'b100 ?
				(   addr2[1:0]==2'b00 ? {{24{Din[ 7]}},Din[ 7: 0]} :
					addr2[1:0]==2'b01 ? {{24{Din[15]}},Din[15: 8]} :
					addr2[1:0]==2'b10 ? {{24{Din[23]}},Din[23:16]} :
									   {{24{Din[31]}},Din[31:24]}) :
				DMSel2==3'b101 ?
				( 	addr2[1]==1'b0 	 ? {16'h0000,Din[15:0]}  :
								 	   {16'h0000,Din[31:16]})  :
				DMSel2==3'b110 ?
				(	addr2[1]==1'b0 	 ? {{16{Din[15]}},Din[15:0]}  :
							    	   {{16{Din[31]}},Din[31:16]} ) :
																Din;
													
	
endmodule
	


// 这个模块用于当前与cpu与乘除器的交互。
// 借助状态机来控制
// * start为1时，乘除法开始计算
// * isBusy为1时，表示正在运行
// * 乘法单周期运算，除法多周期（34个）。
// * C是运算结果，支持读保存，即如果没有新的start，结果会保持为上一次的运算结果
module bridge_RHL(
		aclk,
		aresetn,
		A,
		B, 
		ALU2Op,
		start, 
		EX_RHLWr, 
		EX_RHLSel_Wr, 
		EX_RHLSel_Rd, 
		MEM_Exception, 
		MEM_eret_flush,

		isBusy, 
		RHLOut
	);
input aclk;
input aresetn;
input [31:0 ]A;
input [31:0] B;
input [1:0] ALU2Op;
input start;
input EX_RHLWr;
input[1:0] EX_RHLSel_Wr;
input EX_RHLSel_Rd;
input MEM_Exception;
input MEM_eret_flush;

output isBusy;
output[31:0] RHLOut;

wire [63:0] divider_sign_out;
wire [63:0] divider_unsign_out;
wire [63:0] multi_sign_out;
wire [63:0] multi_unsign_out;
reg [63:0] RHL;
reg present_state;
reg next_state;
wire m_axis_dout_tvalid_sign;
wire m_axis_dout_tvalid_unsign;
wire[63:0] tempA, tempB;

assign RHLOut = EX_RHLSel_Rd ? RHL[63:32] : RHL[31:0];

assign tempA = A[31] ? {32'hffffffff,A} : {32'h00000000,A};
assign tempB = B[31] ? {32'hffffffff,B} : {32'h00000000,B};


assign isBusy=next_state;

parameter state_free = 1'b0 ;
parameter state_busy = 1'b1 ;


assign multi_unsign_out=A*B;
assign multi_sign_out=tempA*tempB;
				// 6'b011001: ALU2Op <= 2'b00;		/* MULTU */
				// 6'b011000: ALU2Op <= 2'b01;		/* MULT */
				// 6'b011011: ALU2Op <= 2'b10;		/* DIVU */
				// 6'b011010: ALU2Op <= 2'b11;		/* DIV */

always @(posedge aclk) begin
    if(!aresetn)
        RHL <= 64'd0;
	else if(ALU2Op==2'b00 && start && !MEM_Exception && !MEM_eret_flush)
		RHL <= multi_unsign_out;
	else if(ALU2Op==2'b01 && start && !MEM_Exception && !MEM_eret_flush)
		RHL <= multi_sign_out;
	else if(m_axis_dout_tvalid_sign) //sign
		RHL <= {divider_sign_out[31:0],divider_sign_out[63:32]};
	else if(m_axis_dout_tvalid_unsign ) //unsign
		RHL <= {divider_unsign_out[31:0],divider_unsign_out[63:32]};
	else if(EX_RHLWr && EX_RHLSel_Wr == 2'b01)
	    RHL <= {A,RHL[31:0]};
	else if(EX_RHLWr && EX_RHLSel_Wr == 2'b00)
	    RHL <= {RHL[63:32],A};   
end

always @(posedge aclk ) begin
	if(!aresetn)
	begin
		present_state=state_free;
	end
	else 
	begin
		present_state=next_state;
	end
end

always @(present_state, start, ALU2Op, m_axis_dout_tvalid_sign, m_axis_dout_tvalid_unsign) begin
	if(present_state == state_free) begin
	   if(start && ALU2Op[1] && !MEM_Exception && !MEM_eret_flush)
	       next_state=state_busy;
	   else
	       next_state=state_free;
	end
	else begin
	   if (m_axis_dout_tvalid_sign|m_axis_dout_tvalid_unsign)
		   next_state=state_free;
	   else
	       next_state=state_busy;
	end

end


wire divider_sign_valid=start && ALU2Op[1] && ALU2Op[0] && !MEM_Exception && !MEM_eret_flush;
Divider divider (
  .aclk(aclk),                                      // input wire aclk
  .aresetn(aresetn),                                // input wire aresetn
  .s_axis_divisor_tvalid(divider_sign_valid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(B),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(divider_sign_valid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(A),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_sign),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(divider_sign_out)            // output wire [63 : 0] m_axis_dout_tdata
);
wire divider_unsign_valid = start && ALU2Op[1] && !ALU2Op[0] && !MEM_Exception && !MEM_eret_flush;
Divider_Unsighed divider_unsign (
  .aclk(aclk),                                      // input wire aclk
  .aresetn(aresetn),                                // input wire aresetn
  .s_axis_divisor_tvalid(divider_unsign_valid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(B),      // input wire [31 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(divider_unsign_valid),  // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(A),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_unsign),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(divider_unsign_out)            // output wire [63 : 0] m_axis_dout_tdata
);



endmodule

// 因为cache的接口设计是偏向类sram接口的
// 所以用这个模块进行 cpu和cache对axi的交互
// 写着写着又写成转接口了 XD
// 写的很粗糙，有巨大优化空间，目前仅仅为了实现功能
// 将来也许会对cache等做进一步优化

//              -----------
// ***********  |实 现 原 理| ************
//              -----------
//	1.借助状态机实现,按照五个通道的axi设计，顺势设出两个状态机，再多添一个空闲、一个完成
//      FSM_R: 读请求，读响应，空闲， 完成
//		FSM_W：写请求，写数据，写响应，空闲、完成
//  2.根据握手信号实现前请求状态到响应状态的转换
//  3.根据当前状态和其他一些信号的组合逻辑生成一些诸如data_ok,addr_ok的信号
//  4.如果icache和dcache同时缺失，优先响应read dcache
module axi_sram_bridge(

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
	IF_icache_rd_req,
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
	MEM_dcache_rd_req,
	MEM_dcache_rd_type,
	MEM_dcache_rd_addr,
	MEM_dcache_rd_rdy,
	MEM_dcache_ret_valid,
	MEM_dcache_ret_last,
	MEM_dcache_ret_data,
	MEM_dcache_wr_req,
	MEM_dcache_wr_type,
	MEM_dcache_wr_addr,
	MEM_dcache_wr_wstrb,
	MEM_dcache_wr_data,
	MEM_dcache_wr_rdy,

);
// 中断信号
    input [5:0] ext_int_in      ;  //interrupt,high active;


// 时钟与复位信号
    input clk      ;
    input rst      ;   //low active
// 读请求通道 
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
//读相应通道         
    input [ 3:0]    rid       ;  
    input [31:0]    rdata     ;
    input [ 1:0]    rresp     ;
    input           rlast     ;
    input           rvalid    ;
    output          rready    ;
//写请求通道
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
// 写数据通道
    output [ 3:0]   wid       ;
    output [31:0]   wdata     ;
    output [ 3:0]   wstrb     ;
    output          wlast     ;
    output          wvalid    ;
    input           wready    ;
// 写相应通道
    input [3:0]     bid       ;
    input [1:0]     bresp     ;
    input           bvalid    ;
    output          bready    ;

// icache 
	input IF_icache_rd_req;
	input [2:0]IF_icache_rd_type;
	input [31:0] IF_icache_rd_addr;
	output  IF_icache_rd_rdy;
	output  IF_icache_ret_valid;
	output IF_icache_ret_last;
	output [31:0] IF_icache_ret_data;
	input IF_icache_wr_req;
	input [2:0] IF_icache_wr_type;
	input [31:0] IF_icache_wr_addr;
	input [3:0] IF_icache_wr_wstrb;
	input [511:0] IF_icache_wr_data;
	output IF_icache_wr_rdy;
// dcache
	input MEM_dcache_rd_req;
	input [2:0]MEM_dcache_rd_type;
	input [31:0] MEM_dcache_rd_addr;
	output  MEM_dcache_rd_rdy;
	output  MEM_dcache_ret_valid;
	output MEM_dcache_ret_last;
	output [31:0] MEM_dcache_ret_data;
	input MEM_dcache_wr_req;
	input [2:0] MEM_dcache_wr_type;
	input [31:0] MEM_dcache_wr_addr;
	input [3:0] MEM_dcache_wr_wstrb;
	input [511:0] MEM_dcache_wr_data;
	output MEM_dcache_wr_rdy;

//暂时用不到的信号初始化
	assign arid = 4'b0;
   	assign arlen    =   4'b1111;
	assign arsize   =   3'b010;
    assign arburst  =   1;
    assign arlock   =   0;
	assign arcache  =  	0;
    assign arprot   =   0;
    assign awid     =   1;
    assign awlen    =   4'b1111;
	assign awsize   =   3'b010;
    assign awburst  =   1;
    assign awlock   =   0;
    assign awcache  =   0;
    assign awprot   =   0;
    assign wid      =   1;
    // assign wlast    =   1;

//状态定义
/*FSM_R*/
parameter state_rd_free = 2'b00;
parameter state_rd_req = 2'b01;
parameter state_rd_res = 2'b10;
parameter state_rd_finish = 2'b11;

/*FSM_W*/
parameter state_wr_free = 3'b000;
parameter state_wr_req = 3'b001;
parameter state_wr_data = 3'b010;
parameter state_wr_res = 3'b011;
parameter state_wr_finish = 3'b100;

//参数定义

reg [1:0] current_rd_state;
reg [1:0] next_rd_state;

reg [2:0] current_wr_state;
reg [2:0] next_wr_state;
reg [511:0] temp_data;//write buffer
reg [3:0] count_rd16;
reg [3:0] count_wr16;

reg arid_reg;// 寄存事务id

initial begin
	count_rd16 = 0;
	count_wr16 = 0;
end

//Write Passway
always @(posedge clk) begin
	if(!rst)
	begin
		temp_data=0;
	end
	else if(current_wr_state==state_wr_req)
	begin
		temp_data<=MEM_dcache_wr_data;
	end
	else if((current_wr_state==state_wr_data)&&wready)
	begin
		temp_data={32'b0,{temp_data[511:32]}};//需要与 wdata 保持一致
	end
end

always @(posedge clk) begin
	if((current_wr_state==state_wr_data) && wready)
		count_wr16=count_wr16+1;
	else if ((current_wr_state==state_wr_data) && !wready)
		count_wr16=count_wr16;
	else
		count_wr16=0;
end
always @(posedge clk) begin
	if((current_wr_state==state_wr_data) && wready)
		count_rd16=count_rd16+1;
	else if ((current_wr_state==state_wr_data) && !wready)
		count_rd16=count_rd16;
	else
		count_rd16=0;
end

always @(posedge clk) begin
	if(!rst)
	begin
		current_wr_state = state_wr_free;
	end
	else 
	begin
		current_wr_state = next_wr_state;
	end
end

/*FSM_W*/
always @(*) begin
	case(current_wr_state)	
		state_wr_free,state_wr_finish:
		begin
			if (MEM_dcache_wr_req)
			begin
				next_wr_state = state_wr_req;
			end
			else
				next_wr_state = current_wr_state;
		end
		state_wr_req:
		begin
			if(awvalid&awready)
				next_wr_state=state_wr_data;
			else
				next_wr_state = current_wr_state;
		end
		state_wr_data:
		begin
			if(wvalid & wready & (count_wr16==4'hf))
				next_wr_state=state_wr_res;
			else
				next_wr_state = current_wr_state;
		end
		state_wr_res:
		begin
			if(bvalid&bready)
				next_wr_state=state_wr_finish;
			else
				next_wr_state = current_wr_state;
		end
	endcase
end

//Read Passway
// 设置读id
// assign arid = MEM_dcache_rd_req ? 1:
// 			 IF_icache_rd_req  ? 0 : 0;

always @(posedge clk) begin
	if(!rst)
	begin
		arid_reg=0;
	end
	else if(current_rd_state==state_rd_free
	||current_rd_state==state_rd_finish)
	begin
		arid_reg <=MEM_dcache_rd_req ? 1:
			 IF_icache_rd_req  ? 0 : 0;
	end
end

always @(posedge clk) begin
	if(!rst)
	begin
		current_rd_state = state_rd_free;
	end
	else 
	begin
		current_rd_state = next_rd_state;
	end
end

/*FSM_R*/
always @(*) begin
	case(current_rd_state)
		state_rd_free,state_rd_finish:
		begin
			if (MEM_dcache_rd_req|IF_icache_rd_req)
			begin
				next_rd_state = state_rd_req;
			end
			else
				next_rd_state = current_rd_state;
		end
		state_rd_req:
		begin
			if(arvalid&arready)
			begin
				next_rd_state=state_rd_res;
			end
			else
				next_rd_state = current_rd_state;
		end
		state_rd_res:
		begin
			if(rvalid&rready&rlast)
			begin
				next_rd_state=state_rd_finish;
			end
			else
				next_rd_state = current_rd_state;
		end
	endcase
end

assign MEM_dcache_rd_rdy = arready&(current_rd_state!=state_rd_res);
assign MEM_dcache_ret_valid = (current_rd_state==state_rd_res)&rready&rvalid&(arid_reg);
assign MEM_dcache_ret_last = rlast;
assign MEM_dcache_ret_data = rdata;
assign MEM_dcache_wr_rdy = awready;
assign IF_icache_rd_rdy = arready&(current_rd_state!=state_rd_res);
assign IF_icache_ret_valid = (current_rd_state==state_rd_res)&rready&rvalid&(~arid_reg);
assign IF_icache_ret_last = rlast;
assign IF_icache_ret_data = rdata;

// 0 -> instr   1 -> data
assign araddr = arid_reg ? MEM_dcache_rd_addr : IF_icache_rd_addr;

assign arvalid = (current_rd_state==state_rd_req) ? 
						arid_reg ? MEM_dcache_rd_req : IF_icache_rd_req:0;
assign rready = 1;

assign awaddr = arid_reg ? (MEM_dcache_rd_addr+count_wr16*4) : IF_icache_rd_addr;
assign awvalid = (current_wr_state==state_wr_req) ? 
						arid_reg ? MEM_dcache_rd_req : IF_icache_rd_req:0;
					
assign wdata = arid_reg ? temp_data[31:0] : IF_icache_wr_data[31:0];
assign wstrb = MEM_dcache_wr_wstrb; //可能有问题
assign wlast = (current_wr_state==state_wr_data)&(count_wr16==4'hf) ;
assign wvalid = (current_wr_state==state_wr_data) ? 
						MEM_dcache_rd_req : IF_icache_rd_req;
assign bready = 1;

endmodule