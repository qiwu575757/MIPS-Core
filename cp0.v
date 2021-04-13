`include "MacroDef.v"

`define BadVAddr_index      8'b01000000
`define Count_index         8'b01001000
`define Compare_index       8'b01011000
`define Status_index        8'b01100000
`define Cause_index         8'b01101000
`define EPC_index           8'b01110000

`define status_bev          Status[22]
`define status_im           Status[15:8]
`define status_exl          Status[1]      //发生例外时该位被置为1
`define status_ie           Status[0]      //全局中断使能位
`define cause_bd            Cause[31]      //最近发生例外的指令是否处于分支延迟槽
`define cause_ti            Cause[30]      //计时器中断指示
`define cause_ip1           Cause[15:10]    //待处理硬件（IP7..IP2）中断标识
`define cause_ip2           Cause[9:8]      //待处理软件（IP1..IP0）中断标识
`define cause_excode        Cause[6:2]     //例外编码


module CP0(clk, rst, CP0WrEn, addr, data_in, EX_MEM_Exc, EX_MEM_eret_flush, EX_MEM_bd,
            ext_int_in, EX_MEM_ExcCode, EX_MEM_badvaddr, EX_MEM_PC, data_out, EPC_out, Interrupt);
    input clk;
    input rst;
    input CP0WrEn;
    input [7:0] addr;
    input [31:0] data_in;
    input EX_MEM_Exc;           //访存阶段的例外信号
    input EX_MEM_eret_flush;           //eret指令修改EXL域的使能信号以及返回和刷新流水线信号
    input EX_MEM_bd;            //访存阶段的指令是否是延迟槽指令
    input [5:0] ext_int_in;       //处理器核顶层的6个中断输入信号
    input [4:0] EX_MEM_ExcCode;        //访存阶段的例外编码
    input [31:0] EX_MEM_badvaddr;      //访存阶段的出错虚地址
    input [31:0] EX_MEM_PC;             //访存阶段的PC

    output [31:0] data_out;
    output [31:0] EPC_out;
    output Interrupt;           //中断信号

    reg [31:0] BadVAddr;
    reg [31:0] Count;
    reg [31:0] Compare;
    reg [31:0] Status;
    reg [31:0] Cause;
    reg [31:0] EPC;
    wire count_eq_compare;       //Count寄存器和Compare寄存器相等信号
    reg tick;                   //时钟频率的一半

    assign count_eq_compare = (Compare == Count);
    assign EPC_out = EPC;
    assign Interrupt = 
        ((Cause[15:8] & `status_im) != 8'h00) && `status_ie == 1'b1 && `status_exl == 1'b0;

    //MFC0指令读取CP0
    assign data_out = 
                (addr == `BadVAddr_index )    ? BadVAddr :
                (addr == `Count_index)        ? Count:
                (addr == `Compare_index)      ? Compare:
                (addr == `Status_index )      ? Status :
                (addr == `Cause_index )       ? Cause :
                (addr == `EPC_index )         ? EPC :
                                    0;
    //BadVAddr寄存器
    always @(posedge clk) begin
        if (EX_MEM_Exc && EX_MEM_ExcCode == `AdEL)
            BadVAddr <= EX_MEM_badvaddr;
    end

    //Count寄存器
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

    //Compare寄存器
    always @(posedge clk) begin
        if (CP0WrEn && addr == `Compare_index)
            Compare <= data_in;
    end

    //Status寄存器的bev域
    always @(posedge clk) begin
        if (!rst)
            `status_bev <= 1'b1;
    end

    //Status寄存器的IM7~IM0域
    always @(posedge clkt) begin
        if (CP0WrEn && addr == `Status_index)
            `status_im <= data_in[15:8];
    end

    //Status寄存器的EXL域
    always @(posedge clk) begin
        if (!rst)
            `status_exl <= 1'b0;
        else if (EX_MEM_Exc)
            `status_exl <= 1'b1;
        else if (EX_MEM_eret_flush)
            `status_exl <= 1'b0;
        else if (CP0WrEn && addr == `Status_index)
            `status_exl <= data_in[1];
    end

    //Status寄存器的IE域
    always @(posedge) begin
        if (!rst)
            `status_ie <= 1'b0;
        else if (CP0WrEn && addr == `Status_index)
            `status_ie <= data_in[0];
    end

    //Status寄存器的零域
    always @(posedge clk) begin
        if (!rst) begin
            Status[31:23] <= 9'b0;
            Status[21:16] <= 6'b0;
            Status[7:2] <= 6'b0;
        end
    end

    //Cause寄存器的BD域
    always @(posedge clk) begin
        if (!rst)
            `cause_bd <= 1'b0;
        else if (EX_MEM_Exc && !`status_exl)
            `cause_bd <= EX_MEM_bd;
    end

    //Cause寄存器的TI域
    always @(posedge clk) begin
        if (!rst)
            `cause_ti <= 1'b0;
        else if (CP0WrEn && addr == `Compare_index)
            `cause_ti <= 1'b0;
        else if (count_eq_compare)
            `cause_ti <= 1'b1;
    end

    //Cause寄存器的IP7~IP2域
    always @(posedge clk) begin
        if (!rst)
            `cause_ip1 <= 6'b0;
        else begin
            Cause[15] <= ext_int_in[5] | `cause_ti;
            Cause[14:11] <= ext_int_in[4:0];
        end
    end

    //Cause寄存器的IP1和IP0域
    always @(posedge clk) begin
        if (!rst)
            `cause_ip2 <= 2'b0;
        else if (CP0WrEn && addr == `Cause_index)
            `cause_ip2 <= data_in[9:8];
    end

    //Cause寄存器的Excode域
    always @(posedge clk) begin
        if (!rst)
            `cause_excode <= 5'b0;
        else if (EX_MEM_Exc)
            `cause_excode <= EX_MEM_ExcCode;
    end

    //Cause寄存器的零域
    always @(posedge clk) begin
        if (!rst) begin
            Cause[29:16] <= 14'b0;
            Cause[7] <= 1'b0;
            Cause[1:0] <= 2'b0;
        end
    end

    //EPC寄存器
    always @(posedge clk) begin
        if (EX_MEM_Exc && !`status_exl)
            EPC <= EX_MEM_bd ? EX_MEM_PC - 4: EX_MEM_PC;
        else if (CP0WrEn && addr == `EPC_index)
            EPC <= data_in;
    end

endmodule