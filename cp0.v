

`include "MacroDef.v"

`define BadVAddr_index      8'b01000000
`define Count_index         8'b01001000
`define Compare_index       8'b01011000
`define Status_index        8'b01100000
`define Cause_index         8'b01101000
`define EPC_index           8'b01110000

`define status_bev          Status[22]
`define status_im           Status[15:8]
`define status_exl          Status[1]      //例外级
`define status_ie           Status[0]      //全局中断使能位
`define cause_bd            Cause[31]      //是否处于分支延迟槽
`define cause_ti            Cause[30]      //计时器中断提示
`define cause_ip1           Cause[15:10]    //待处理硬件中断，每一位对应一个中断线
`define cause_ip2           Cause[9:8]      //待处理软件中断标识
`define cause_excode        Cause[6:2]     //例外编码


module CP0(
    clk, rst, CP0WrEn, addr, data_in, MEM_Exc, 
    MEM_eret_flush, MEM_bd,ext_int_in, 
    MEM_ExcCode, MEM_badvaddr, MEM_PC,

    data_out, EPC_out, Interrupt
);
    input clk;
    input rst;
    input CP0WrEn;
    input [7:0] addr;
    input [31:0] data_in;
    input MEM_Exc;           //M级中断标识
    input MEM_eret_flush;           //M级eret指令清空信号
    input MEM_bd;            //延迟槽标识
    input [5:0] ext_int_in;       //外部硬件中断标识
    input [4:0] MEM_ExcCode;        //M级例外编码
    input [31:0] MEM_badvaddr;      //出错虚拟地址
    input [31:0] MEM_PC;             

    output [31:0] data_out;
    output [31:0] EPC_out;
    output Interrupt;           //中断

    reg [31:0] BadVAddr;
    reg [31:0] Count;
    reg [31:0] Compare;
    reg [31:0] Status;
    reg [31:0] Cause;
    reg [31:0] EPC;
    wire count_eq_compare;       //Count == Compare
    reg tick;                   
    reg epc_sign;               //epc_sign = 0,例外改写epc；epc_sign = 1,指令改写epc；

    assign count_eq_compare = (Compare == Count);
    assign EPC_out = EPC;
    assign Interrupt = 
        ((Cause[15:8] & `status_im) != 8'h00) && `status_ie == 1'b1 && `status_exl == 1'b0;

    //MFC0读取CP0
    assign data_out = 
                (addr == `BadVAddr_index )    ? BadVAddr :
                (addr == `Count_index)        ? Count:
                (addr == `Compare_index)      ? Compare:
                (addr == `Status_index )      ? Status :
                (addr == `Cause_index )       ? Cause :
                (addr == `EPC_index )         ? EPC + epc_sign * 4:
                                    0;
    //BadVAddr generation
    always @(posedge clk) begin
        if (MEM_Exc && (MEM_ExcCode == `AdEL || MEM_ExcCode == `AdES))
            BadVAddr <= MEM_badvaddr;
    end

    //Count generation
    always @(posedge clk) begin
        if (!rst)
            tick <= 1'b0;
        else 
            tick <= ~tick;
        
        if (CP0WrEn && addr == `Count_index)
            Count <= data_in;
        else if (tick)
            Count <= Count + 1'b1;
    end

    //Compare generation
    always @(posedge clk) begin
        if (CP0WrEn && addr == `Compare_index)
            Compare <= data_in;
    end

    //Status
    always @(posedge clk) begin
        if (!rst)
            `status_bev <= 1'b1;
    end

    //Status
    always @(posedge clk) begin
        if (CP0WrEn && addr == `Status_index)
            `status_im <= data_in[15:8];
    end

    //Status
    always @(posedge clk) begin
        if (!rst)
            `status_exl <= 1'b0;
        else if (MEM_Exc)
            `status_exl <= 1'b1;
        else if (MEM_eret_flush)
            `status_exl <= 1'b0;
        else if (CP0WrEn && addr == `Status_index)
            `status_exl <= data_in[1];
    end

    //Status
    always @(posedge clk) begin
        if (!rst)
            `status_ie <= 1'b0;
        else if (CP0WrEn && addr == `Status_index)
            `status_ie <= data_in[0];
    end

    //Status
    always @(posedge clk) begin
        if (!rst) begin
            Status[31:23] <= 9'b0;
            Status[21:16] <= 6'b0;
            Status[7:2] <= 6'b0;
        end
    end

    //Cause
    always @(posedge clk) begin
        if (!rst)
            `cause_bd <= 1'b0;
        else if (MEM_Exc && !`status_exl)
            `cause_bd <= MEM_bd;
    end

    //Cause
    always @(posedge clk) begin
        if (!rst)
            `cause_ti <= 1'b0;
        else if (CP0WrEn && addr == `Compare_index)
            `cause_ti <= 1'b0;
        else if (count_eq_compare)
            `cause_ti <= 1'b1;
    end

    //Cause
    always @(posedge clk) begin
        if (!rst)
            `cause_ip1 <= 6'b0;
        else begin
            Cause[15] <= ext_int_in[5] | `cause_ti;
            Cause[14:11] <= ext_int_in[4:0];
        end
    end

    //Cause
    always @(posedge clk) begin
        if (!rst)
            `cause_ip2 <= 2'b0;
        else if (CP0WrEn && addr == `Cause_index)
            `cause_ip2 <= data_in[9:8];
    end

    //Cause
    always @(posedge clk) begin
        if (!rst)
            `cause_excode <= 5'b0;
        else if (MEM_Exc)
            `cause_excode <= MEM_ExcCode;
    end

    //Cause
    always @(posedge clk) begin
        if (!rst) begin
            Cause[29:16] <= 14'b0;
            Cause[7] <= 1'b0;
            Cause[1:0] <= 2'b0;
        end
    end

    //EPC
    always @(posedge clk) begin
        if (!rst)
            epc_sign <= 0;
        if (MEM_Exc && !`status_exl) begin
            EPC <= MEM_bd ? MEM_PC - 4 : MEM_PC;
            epc_sign <= 0;
        end   
        else if (CP0WrEn && addr == `EPC_index) begin
            EPC <= data_in - 4;
            epc_sign <= 1;
         end  
    end
    
  

endmodule