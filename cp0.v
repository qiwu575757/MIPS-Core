`include "MacroDef.v"

`define BadVAddr_index      8'b01000000
`define Count_index         8'b01001000
`define Compare_index       8'b01011000
`define Status_index        8'b01100000
`define Cause_index         8'b01101000
`define EPC_index           8'b01110000

`define status_bev          Status[22]
`define status_im           Status[15:8]
`define status_exl          Status[1]      //鍙戠敓渚嬪鏃惰浣嶈缃负1
`define status_ie           Status[0]      //鍏ㄥ眬涓柇浣胯兘浣?
`define cause_bd            Cause[31]      //鏈?杩戝彂鐢熶緥澶栫殑鎸囦护鏄惁澶勪簬鍒嗘敮寤惰繜妲?
`define cause_ti            Cause[30]      //璁℃椂鍣ㄤ腑鏂寚绀?
`define cause_ip1           Cause[15:10]    //寰呭鐞嗙‖浠讹紙IP7..IP2锛変腑鏂爣璇?
`define cause_ip2           Cause[9:8]      //寰呭鐞嗚蒋浠讹紙IP1..IP0锛変腑鏂爣璇?
`define cause_excode        Cause[6:2]     //渚嬪缂栫爜


module CP0(clk, rst, CP0WrEn, addr, data_in, EX_MEM_Exc, EX_MEM_eret_flush, EX_MEM_bd,
            ext_int_in, EX_MEM_ExcCode, EX_MEM_badvaddr, EX_MEM_PC, data_out, EPC_out, Interrupt);
    input clk;
    input rst;
    input CP0WrEn;
    input [7:0] addr;
    input [31:0] data_in;
    input EX_MEM_Exc;           //璁垮瓨闃舵鐨勪緥澶栦俊鍙?
    input EX_MEM_eret_flush;           //eret鎸囦护淇敼EXL鍩熺殑浣胯兘淇″彿浠ュ強杩斿洖鍜屽埛鏂版祦姘寸嚎淇″彿
    input EX_MEM_bd;            //璁垮瓨闃舵鐨勬寚浠ゆ槸鍚︽槸寤惰繜妲芥寚浠?
    input [5:0] ext_int_in;       //澶勭悊鍣ㄦ牳椤跺眰鐨?6涓腑鏂緭鍏ヤ俊鍙?
    input [4:0] EX_MEM_ExcCode;        //璁垮瓨闃舵鐨勪緥澶栫紪鐮?
    input [31:0] EX_MEM_badvaddr;      //璁垮瓨闃舵鐨勫嚭閿欒櫄鍦板潃
    input [31:0] EX_MEM_PC;             //璁垮瓨闃舵鐨凱C

    output [31:0] data_out;
    output [31:0] EPC_out;
    output Interrupt;           //涓柇淇″彿

    reg [31:0] BadVAddr;
    reg [31:0] Count;
    reg [31:0] Compare;
    reg [31:0] Status;
    reg [31:0] Cause;
    reg [31:0] EPC;
    wire count_eq_compare;       //Count瀵勫瓨鍣ㄥ拰Compare瀵勫瓨鍣ㄧ浉绛変俊鍙?
    reg tick;                   //鏃堕挓棰戠巼鐨勪竴鍗?
    reg epc_sign;               //epc_sign = 0,例外改写epc；epc_sign = 1,指令改写epc；

    assign count_eq_compare = (Compare == Count);
    assign EPC_out = EPC;
    assign Interrupt = 
        ((Cause[15:8] & `status_im) != 8'h00) && `status_ie == 1'b1 && `status_exl == 1'b0;

    //MFC0鎸囦护璇诲彇CP0
    assign data_out = 
                (addr == `BadVAddr_index )    ? BadVAddr :
                (addr == `Count_index)        ? Count:
                (addr == `Compare_index)      ? Compare:
                (addr == `Status_index )      ? Status :
                (addr == `Cause_index )       ? Cause :
                (addr == `EPC_index )         ? EPC + epc_sign * 4:
                                    0;
    //BadVAddr瀵勫瓨鍣?
    always @(posedge clk) begin
        if (EX_MEM_Exc && (EX_MEM_ExcCode == `AdEL || EX_MEM_ExcCode == `AdES))
            BadVAddr <= EX_MEM_badvaddr;
    end

    //Count瀵勫瓨鍣?
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

    //Compare瀵勫瓨鍣?
    always @(posedge clk) begin
        if (CP0WrEn && addr == `Compare_index)
            Compare <= data_in;
    end

    //Status瀵勫瓨鍣ㄧ殑bev鍩?
    always @(posedge clk) begin
        if (!rst)
            `status_bev <= 1'b1;
    end

    //Status瀵勫瓨鍣ㄧ殑IM7~IM0鍩?
    always @(posedge clk) begin
        if (CP0WrEn && addr == `Status_index)
            `status_im <= data_in[15:8];
    end

    //Status瀵勫瓨鍣ㄧ殑EXL鍩?
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

    //Status瀵勫瓨鍣ㄧ殑IE鍩?
    always @(posedge clk) begin
        if (!rst)
            `status_ie <= 1'b0;
        else if (CP0WrEn && addr == `Status_index)
            `status_ie <= data_in[0];
    end

    //Status瀵勫瓨鍣ㄧ殑闆跺煙
    always @(posedge clk) begin
        if (!rst) begin
            Status[31:23] <= 9'b0;
            Status[21:16] <= 6'b0;
            Status[7:2] <= 6'b0;
        end
    end

    //Cause瀵勫瓨鍣ㄧ殑BD鍩?
    always @(posedge clk) begin
        if (!rst)
            `cause_bd <= 1'b0;
        else if (EX_MEM_Exc && !`status_exl)
            `cause_bd <= EX_MEM_bd;
    end

    //Cause瀵勫瓨鍣ㄧ殑TI鍩?
    always @(posedge clk) begin
        if (!rst)
            `cause_ti <= 1'b0;
        else if (CP0WrEn && addr == `Compare_index)
            `cause_ti <= 1'b0;
        else if (count_eq_compare)
            `cause_ti <= 1'b1;
    end

    //Cause瀵勫瓨鍣ㄧ殑IP7~IP2鍩?
    always @(posedge clk) begin
        if (!rst)
            `cause_ip1 <= 6'b0;
        else begin
            Cause[15] <= ext_int_in[5] | `cause_ti;
            Cause[14:11] <= ext_int_in[4:0];
        end
    end

    //Cause瀵勫瓨鍣ㄧ殑IP1鍜孖P0鍩?
    always @(posedge clk) begin
        if (!rst)
            `cause_ip2 <= 2'b0;
        else if (CP0WrEn && addr == `Cause_index)
            `cause_ip2 <= data_in[9:8];
    end

    //Cause瀵勫瓨鍣ㄧ殑Excode鍩?
    always @(posedge clk) begin
        if (!rst)
            `cause_excode <= 5'b0;
        else if (EX_MEM_Exc)
            `cause_excode <= EX_MEM_ExcCode;
    end

    //Cause瀵勫瓨鍣ㄧ殑闆跺煙
    always @(posedge clk) begin
        if (!rst) begin
            Cause[29:16] <= 14'b0;
            Cause[7] <= 1'b0;
            Cause[1:0] <= 2'b0;
        end
    end

    //EPC瀵勫瓨鍣?
    always @(posedge clk) begin
        if (!rst)
            epc_sign <= 0;
        if (EX_MEM_Exc && !`status_exl) begin
            EPC <= EX_MEM_bd ? EX_MEM_PC - 4 : EX_MEM_PC  ;
            epc_sign <= 0;
        end   
        else if (CP0WrEn && addr == `EPC_index) begin
            EPC <= data_in - 4;
            epc_sign <= 1;
         end  
    end
    
  

endmodule