module mycpu_top(
    clk              ,
    resetn           ,  //low active
    ext_int          ,  //interrupt,high active

    inst_sram_en     ,
    inst_sram_wen    ,
    inst_sram_addr   ,
    inst_sram_wdata  ,
    inst_sram_rdata  ,

    data_sram_en     ,
    data_sram_wen    ,
    data_sram_addr   ,
    data_sram_wdata  ,
    data_sram_rdata  ,

    //debug
    debug_wb_pc      ,
    debug_wb_rf_wen  ,
    debug_wb_rf_wnum ,
    debug_wb_rf_wdata
);
    input clk              ;
    input resetn           ;  //low active
    input ext_int          ;  //interrupt,high active;

    output  inst_sram_en     ;
    output  reg [3:0] inst_sram_wen    ;
    output  [31:0] inst_sram_addr   ;
    output  reg [31:0] inst_sram_wdata  ;
    input [31:0] inst_sram_rdata  ;

    output  data_sram_en     ;
    output  [3:0] data_sram_wen    ;
    output  [31:0] data_sram_addr   ;
    output  [31:0] data_sram_wdata  ;
    input [31:0] data_sram_rdata  ;

    //debug
    output  [31:0] debug_wb_pc      ;
    output  [3:0] debug_wb_rf_wen  ;
    output  [4:0] debug_wb_rf_wnum ;
    output  [31:0] debug_wb_rf_wdata;

    initial begin
        inst_sram_wen = 4'b0;//默认不会去写 iram
        inst_sram_wdata = 32'b0;
    end

assign inst_sram_en = ~resetn;

    mips MIPS(
        clk, 
        rst,
        inst_sram_rdata,
        data_sram_rdata  ,

	    data_sram_en     ,
        data_sram_wen    ,
        data_sram_addr   ,
        data_sram_wdata  ,
        //debug
        debug_wb_pc      ,
        debug_wb_rf_wen  ,
        debug_wb_rf_wnum ,
        debug_wb_rf_wdata,
        inst_sram_addr   
    );

endmodule 