module icache(       clk, resetn, exception,
        //CPU_Pipeline side
        /*input*/   valid, tag, index, offset, 
        /*output*/  addr_ok, data_ok, rdata,
        //AXI-Bus side 
        /*input*/   rd_rdy, wr_rdy, ret_valid, ret_last, ret_data,
        /*output*/  rd_req, wr_req, rd_type, wr_type, rd_addr, wr_addr, wr_wstrb, wr_data
        );

    //clock and reset
    input clk;
    input resetn;
    input exception;

    // Cache && CPU-Pipeline
    input valid;                    //CPU request signal
    input[17:0] tag;                //CPU address[31:14]
    input[7:0] index;               //CPU address[13:6]
    input[5:0] offset;              //CPU address[5:0]: [5:2] is block offset , [1:0] is byte offset
    output addr_ok;                 //to show address and data is received by Cache 
    output data_ok;                 //to show load or store operation is done
    output reg[31:0] rdata;         //data to be loaded from Cache to CPU

    // Cache && AXI-Bus
    input rd_rdy;                   //AXI-Bus read-ready signal
    input wr_rdy;                   //AXI-Bus write-ready signal
    input ret_valid;                //to show the data returned from AXI-Bus is valid 
    input ret_last;                 //to show the data returned from AXI-Bus is the last one
    input[31:0] ret_data;           //data to be refilled from AXI-Bus to Cache
    output rd_req;                  //Cache read-request signal
    output wr_req;                  //Cache write-request signal
    output[2:0] rd_type;            //read type, assign 3'b100
    output[2:0] wr_type;            //write type, assign 3'b100
    output[31:0] rd_addr;           //read address
    output[31:0] wr_addr;           //write address
    output[3:0] wr_wstrb;           //write code,assign 4'b1111
    output[511:0] wr_data;          //data to be replaced from Cache to AXI-Bus

    //Cache RAM
    /*
    Basic information:
        256 groups : index 0~255
        4 ways : way 0/1/2/3
        16 words in a block : block offset 0~15
        Every block: 1 valid bit + 1 dirty bit + 18 tag bit + 16 * 32 data bit
        Total memory: 64KB
    */

    reg[7:0] VT_addr;
    reg[7:0] Data_addr;
    wire VT_Way0_wen;
    wire VT_Way1_wen;
    wire VT_Way2_wen;
    wire VT_Way3_wen;
    wire[18:0] VT_in;
    wire[18:0] VT_Way0_out;
    wire[18:0] VT_Way1_out;
    wire[18:0] VT_Way2_out;
    wire[18:0] VT_Way3_out;
    wire Way0_Valid = VT_Way0_out[18];
    wire Way1_Valid = VT_Way1_out[18];
    wire Way2_Valid = VT_Way2_out[18];
    wire Way3_Valid = VT_Way3_out[18];
    wire[17:0] Way0_Tag = VT_Way0_out[17:0];
    wire[17:0] Way1_Tag = VT_Way1_out[17:0];
    wire[17:0] Way2_Tag = VT_Way2_out[17:0];
    wire[17:0] Way3_Tag = VT_Way3_out[17:0];
    reg[63:0] Data_Way0_wen;
    reg[63:0] Data_Way1_wen;
    reg[63:0] Data_Way2_wen;
    reg[63:0] Data_Way3_wen;
    reg[511:0] Data_in;
    wire[511:0] Data_Way0_out;
    wire[511:0] Data_Way1_out;
    wire[511:0] Data_Way2_out;
    wire[511:0] Data_Way3_out;
    
    //FINITE STATE MACHINE
    reg[1:0] C_STATE;
    reg[1:0] N_STATE;
    parameter IDLE = 2'b00, LOOKUP = 2'b01, MISS = 2'b10, REFILL = 2'b11;

    //Request Buffer
    reg[7:0] index_RB;
    reg[17:0] tag_RB;
    reg[5:0] offset_RB;

    //Miss Buffer : information for MISS-REPLACE-REFILL use
    reg[1:0] replace_way_MB;        //the way to be replaced and refilled
    reg[17:0] replace_tag_new_MB;   //tag requested from cpu(to be refilled)
    reg[7:0] replace_index_MB;
    reg[511:0] replace_data_MB;
    reg[3:0] ret_number_MB;         //how many data returned from AXI-Bus during REFILL state

    //replace select
    reg[511:0] replace_data;
    reg[1:0] counter;

    //hit
    wire way0_hit;
    wire way1_hit;
    wire way2_hit;
    wire way3_hit;
    wire cache_hit;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Block Ram
    ValidTag_Block VT_Way0(
        clk, 1, VT_Way0_wen, VT_addr, VT_in, VT_Way0_out
    );
    ValidTag_Block VT_Way1(
        clk, 1, VT_Way1_wen, VT_addr, VT_in, VT_Way1_out
    );
    ValidTag_Block VT_Way2(
        clk, 1, VT_Way2_wen, VT_addr, VT_in, VT_Way2_out
    );
    ValidTag_Block VT_Way3(
        clk, 1, VT_Way3_wen, VT_addr, VT_in, VT_Way3_out
    );
    Data_Block Data_Way0(
        clk, 1, Data_Way0_wen, Data_addr, Data_in, Data_Way0_out
    );
    Data_Block Data_Way1(
        clk, 1, Data_Way1_wen, Data_addr, Data_in, Data_Way1_out
    );
    Data_Block Data_Way2(
        clk, 1, Data_Way2_wen, Data_addr, Data_in, Data_Way2_out
    );
    Data_Block Data_Way3(
        clk, 1, Data_Way3_wen, Data_addr, Data_in, Data_Way3_out
    );

    //tag compare && hit judgement
    assign way0_hit = Way0_Valid && (Way0_Tag == tag_RB);
    assign way1_hit = Way1_Valid && (Way1_Tag == tag_RB);
    assign way2_hit = Way2_Valid && (Way2_Tag == tag_RB);
    assign way3_hit = Way3_Valid && (Way3_Tag == tag_RB);
    assign cache_hit = way0_hit || way1_hit || way2_hit || way3_hit;

    //random replacement strategy with a clock counter
    always@(posedge clk)
        if(!resetn)
            counter <= 2'b00;
        else
            counter <= counter + 1;
    always@(*)
        case(counter)
            2'b00:  //choose way0
                    replace_data = Data_Way0_out;
            2'b01:  //choose way1
                    replace_data = Data_Way1_out;
            2'b10:  //choose way2
                    replace_data = Data_Way2_out;
            default://choose way3
                    replace_data = Data_Way3_out;
        endcase

    //Request Buffer
    always@(posedge clk)
        if(!resetn) begin
            index_RB <= 8'd0;
            tag_RB <= 17'd0;
            offset_RB <= 6'd0;
        end
        else if((C_STATE == IDLE && N_STATE == LOOKUP) || (C_STATE == LOOKUP && N_STATE ==LOOKUP)) begin
            index_RB <= index;
            tag_RB <= tag;
            offset_RB <= offset;
        end
    
    //Miss Buffer
    always@(posedge clk)
        if(!resetn) begin
            replace_way_MB <= 1'b0;
            replace_data_MB <= 512'd0; 
            replace_index_MB <= 8'd0;
            replace_tag_new_MB <= 18'd0;
        end
        else if(C_STATE == LOOKUP) begin
            replace_way_MB <= counter;
            replace_data_MB <= replace_data;
            replace_index_MB <= index_RB;
            replace_tag_new_MB <= tag_RB;
        end
    always@(posedge clk)                //help locate the block offset during REFILL state
        if(!resetn)
            ret_number_MB <= 4'b0000;
        else if(rd_rdy)
            ret_number_MB <= 4'b0000;
        else if(ret_valid)
            ret_number_MB <= ret_number_MB + 1;

    //reading from cache to cpu (load)
    always@(*)
        if(way0_hit)        //read way0
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way0_out[ 31:  0];
                4'd1:   rdata = Data_Way0_out[ 63: 32];
                4'd2:   rdata = Data_Way0_out[ 95: 64];
                4'd3:   rdata = Data_Way0_out[127: 96];
                4'd4:   rdata = Data_Way0_out[159:128];
                4'd5:   rdata = Data_Way0_out[191:160];
                4'd6:   rdata = Data_Way0_out[223:192];
                4'd7:   rdata = Data_Way0_out[255:224];
                4'd8:   rdata = Data_Way0_out[287:256];
                4'd9:   rdata = Data_Way0_out[319:288];
                4'd10:  rdata = Data_Way0_out[351:320];
                4'd11:  rdata = Data_Way0_out[383:352];
                4'd12:  rdata = Data_Way0_out[415:384];
                4'd13:  rdata = Data_Way0_out[447:416];
                4'd14:  rdata = Data_Way0_out[479:448];
                default:rdata = Data_Way0_out[511:480];
            endcase
        else if(way1_hit)   //read way1
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way1_out[ 31:  0];
                4'd1:   rdata = Data_Way1_out[ 63: 32];
                4'd2:   rdata = Data_Way1_out[ 95: 64];
                4'd3:   rdata = Data_Way1_out[127: 96];
                4'd4:   rdata = Data_Way1_out[159:128];
                4'd5:   rdata = Data_Way1_out[191:160];
                4'd6:   rdata = Data_Way1_out[223:192];
                4'd7:   rdata = Data_Way1_out[255:224];
                4'd8:   rdata = Data_Way1_out[287:256];
                4'd9:   rdata = Data_Way1_out[319:288];
                4'd10:  rdata = Data_Way1_out[351:320];
                4'd11:  rdata = Data_Way1_out[383:352];
                4'd12:  rdata = Data_Way1_out[415:384];
                4'd13:  rdata = Data_Way1_out[447:416];
                4'd14:  rdata = Data_Way1_out[479:448];
                default:rdata = Data_Way1_out[511:480];
            endcase
        else if(way2_hit)   //read way2
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way2_out[ 31:  0];
                4'd1:   rdata = Data_Way2_out[ 63: 32];
                4'd2:   rdata = Data_Way2_out[ 95: 64];
                4'd3:   rdata = Data_Way2_out[127: 96];
                4'd4:   rdata = Data_Way2_out[159:128];
                4'd5:   rdata = Data_Way2_out[191:160];
                4'd6:   rdata = Data_Way2_out[223:192];
                4'd7:   rdata = Data_Way2_out[255:224];
                4'd8:   rdata = Data_Way2_out[287:256];
                4'd9:   rdata = Data_Way2_out[319:288];
                4'd10:  rdata = Data_Way2_out[351:320];
                4'd11:  rdata = Data_Way2_out[383:352];
                4'd12:  rdata = Data_Way2_out[415:384];
                4'd13:  rdata = Data_Way2_out[447:416];
                4'd14:  rdata = Data_Way2_out[479:448];
                default:rdata = Data_Way2_out[511:480];
            endcase
        else if(way3_hit)   //read way3
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way3_out[ 31:  0];
                4'd1:   rdata = Data_Way3_out[ 63: 32];
                4'd2:   rdata = Data_Way3_out[ 95: 64];
                4'd3:   rdata = Data_Way3_out[127: 96];
                4'd4:   rdata = Data_Way3_out[159:128];
                4'd5:   rdata = Data_Way3_out[191:160];
                4'd6:   rdata = Data_Way3_out[223:192];
                4'd7:   rdata = Data_Way3_out[255:224];
                4'd8:   rdata = Data_Way3_out[287:256];
                4'd9:   rdata = Data_Way3_out[319:288];
                4'd10:  rdata = Data_Way3_out[351:320];
                4'd11:  rdata = Data_Way3_out[383:352];
                4'd12:  rdata = Data_Way3_out[415:384];
                4'd13:  rdata = Data_Way3_out[447:416];
                4'd14:  rdata = Data_Way3_out[479:448];
                default:rdata = Data_Way3_out[511:480];
            endcase
        else                //read ret_data when miss
            rdata = ret_data;
    
    //write from cpu to cache (store)
    always@(ret_data)
            Data_in = {16{ret_data}};
    always@(*)
        if(ret_valid &&(C_STATE == REFILL)) begin
            if(replace_way_MB == 2'd0) begin
                case(ret_number_MB)
                    4'd0:   Data_Way0_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way0_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way0_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way0_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way0_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way0_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way0_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way0_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way0_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way0_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way0_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way0_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way0_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way0_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way0_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way0_wen = {4'b1111,60'd0};
                endcase
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(replace_way_MB == 2'd1) begin
                case(ret_number_MB)
                    4'd0:   Data_Way1_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way1_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way1_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way1_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way1_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way1_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way1_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way1_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way1_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way1_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way1_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way1_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way1_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way1_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way1_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way1_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(replace_way_MB == 2'd2) begin
                case(ret_number_MB)
                    4'd0:   Data_Way2_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way2_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way2_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way2_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way2_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way2_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way2_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way2_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way2_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way2_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way2_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way2_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way2_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way2_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way2_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way2_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else begin
                case(ret_number_MB)
                    4'd0:   Data_Way3_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way3_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way3_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way3_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way3_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way3_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way3_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way3_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way3_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way3_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way3_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way3_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way3_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way3_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way3_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way3_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
            end
        end
        else begin
            Data_Way0_wen = 64'd0;
            Data_Way1_wen = 64'd0;
            Data_Way2_wen = 64'd0;
            Data_Way3_wen = 64'd0;
        end    

    //replace from cache to mem (write memory)
    assign wr_addr = 32'd0 ;
    assign wr_data = 512'd0;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    assign VT_Way0_wen = ret_valid && (replace_way_MB == 0) && (ret_number_MB == 4'h8);
    assign VT_Way1_wen = ret_valid && (replace_way_MB == 1) && (ret_number_MB == 4'h8);
    assign VT_Way2_wen = ret_valid && (replace_way_MB == 2) && (ret_number_MB == 4'h8);
    assign VT_Way3_wen = ret_valid && (replace_way_MB == 3) && (ret_number_MB == 4'h8);
    assign VT_in = {1'b1,replace_tag_new_MB};
    assign rd_type = 3'b100;
    assign rd_addr = {replace_tag_new_MB, replace_index_MB, 6'b000000};

    //block address control
    always@(replace_index_MB, index, C_STATE, valid, index_RB)
        if(!valid)
            VT_addr = index_RB;
        else if(C_STATE == REFILL)
            VT_addr = replace_index_MB;
        else
            VT_addr = index;
    always@(replace_index_MB, index, C_STATE, valid, index_RB)
        if(!valid)
            Data_addr = index_RB;
        else if(C_STATE == REFILL)
            Data_addr = replace_index_MB;
        else
            Data_addr = index;

    //main FSM
    /*
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(posedge clk)
        if(!resetn)
            C_STATE <= IDLE;
        else
            C_STATE <= N_STATE;
    always@(C_STATE, valid, cache_hit, rd_rdy, ret_valid, ret_last, exception)
        case(C_STATE)
            IDLE:   if(valid)
                        N_STATE = LOOKUP;
                    else 
                        N_STATE = IDLE;
            LOOKUP: if(exception)
                        N_STATE = LOOKUP;
                    else if(!cache_hit)
                        N_STATE = MISS;
                    else if(valid)
                        N_STATE = LOOKUP;
                    else
                        N_STATE = IDLE;
            MISS:   if(!rd_rdy)
                        N_STATE = MISS;
                    else
                        N_STATE = REFILL;
            REFILL: if(ret_valid && ret_last)
                        N_STATE = LOOKUP;
                    else
                        N_STATE = REFILL;
            default: N_STATE = IDLE;
        endcase

    //output signals
    assign addr_ok = (C_STATE == IDLE) || ((C_STATE == LOOKUP)) ;
    assign data_ok = (C_STATE == IDLE) || ((C_STATE == LOOKUP) && cache_hit) ;
    assign rd_req = (N_STATE == REFILL) ;
    assign wr_req = 1'b0 ;

endmodule

module dcache(       clk, resetn,
        //CPU_Pipeline side
        /*input*/   valid, op, tag, index, offset, wstrb, wdata, 
        /*output*/  addr_ok, data_ok, rdata,
        //AXI-Bus side 
        /*input*/   rd_rdy, wr_rdy, ret_valid, ret_last, ret_data,
        /*output*/  rd_req, wr_req, rd_type, wr_type, rd_addr, wr_addr, wr_wstrb, wr_data
        );

    //clock and reset
    input clk;
    input resetn;

    // Cache && CPU-Pipeline
    input valid;                    //CPU request signal
    input op;                       //CPU opcode: 0 = load , 1 = store
    input[17:0] tag;                //CPU address[31:14]
    input[7:0] index;               //CPU address[13:6]
    input[5:0] offset;              //CPU address[5:0]: [5:2] is block offset , [1:0] is byte offset
    input[3:0] wstrb;               //write code,including 0001 , 0010 , 0100, 1000, 0011 , 1100 , 1111
    input[31:0] wdata;              //data to be stored from CPU to Cache
    output addr_ok;                 //to show address and data is received by Cache 
    output data_ok;                 //to show load or store operation is done
    output reg[31:0] rdata;         //data to be loaded from Cache to CPU

    // Cache && AXI-Bus
    input rd_rdy;                   //AXI-Bus read-ready signal
    input wr_rdy;                   //AXI-Bus write-ready signal
    input ret_valid;                //to show the data returned from AXI-Bus is valid 
    input ret_last;                 //to show the data returned from AXI-Bus is the last one
    input[31:0] ret_data;           //data to be refilled from AXI-Bus to Cache
    output rd_req;                  //Cache read-request signal
    output wr_req;                  //Cache write-request signal
    output[2:0] rd_type;            //read type, assign 3'b100
    output[2:0] wr_type;            //write type, assign 3'b100
    output[31:0] rd_addr;           //read address
    output[31:0] wr_addr;           //write address
    output[3:0] wr_wstrb;           //write code,assign 4'b1111
    output[511:0] wr_data;          //data to be replaced from Cache to AXI-Bus

    //Cache RAM
    /*
    Basic information:
        256 groups : index 0~255
        4 ways : way 0/1/2/3
        16 words in a block : block offset 0~15
        Every block: 1 valid bit + 1 dirty bit + 18 tag bit + 16 * 32 data bit
        Total memory: 64KB
    */

    reg[7:0] VT_addr;
    reg[7:0] D_addr;
    reg[7:0] Data_addr;
    wire VT_Way0_wen;
    wire VT_Way1_wen;
    wire VT_Way2_wen;
    wire VT_Way3_wen;
    wire[18:0] VT_in;
    wire[18:0] VT_Way0_out;
    wire[18:0] VT_Way1_out;
    wire[18:0] VT_Way2_out;
    wire[18:0] VT_Way3_out;
    wire Way0_Valid = VT_Way0_out[18];
    wire Way1_Valid = VT_Way1_out[18];
    wire Way2_Valid = VT_Way2_out[18];
    wire Way3_Valid = VT_Way3_out[18];
    wire[17:0] Way0_Tag = VT_Way0_out[17:0];
    wire[17:0] Way1_Tag = VT_Way1_out[17:0];
    wire[17:0] Way2_Tag = VT_Way2_out[17:0];
    wire[17:0] Way3_Tag = VT_Way3_out[17:0];
    wire D_Way0_wen;
    wire D_Way1_wen;
    wire D_Way2_wen;
    wire D_Way3_wen;
    wire D_in;
    wire Way0_Dirty;
    wire Way1_Dirty;
    wire Way2_Dirty;
    wire Way3_Dirty;
    reg[63:0] Data_Way0_wen;
    reg[63:0] Data_Way1_wen;
    reg[63:0] Data_Way2_wen;
    reg[63:0] Data_Way3_wen;
    reg[511:0] Data_in;
    wire[511:0] Data_Way0_out;
    wire[511:0] Data_Way1_out;
    wire[511:0] Data_Way2_out;
    wire[511:0] Data_Way3_out;
    
    //FINITE STATE MACHINE
    reg[2:0] C_STATE;
    reg[2:0] N_STATE;
    parameter IDLE = 3'b000, LOOKUP = 3'b001, MISS = 3'b010, REPLACE = 3'b011, REFILL = 3'b100;

    //Request Buffer
    reg op_RB;
    reg[7:0] index_RB;
    reg[17:0] tag_RB;
    reg[5:0] offset_RB;
    reg[3:0] wstrb_RB;
    reg[31:0] wdata_RB;

    //Miss Buffer : information for MISS-REPLACE-REFILL use
    reg[1:0] replace_way_MB;        //the way to be replaced and refilled
    reg replace_Valid_MB;           
    reg replace_Dirty_MB;
    reg[17:0] replace_tag_old_MB;   //unmatched tag in cache(to be replaced)
    reg[17:0] replace_tag_new_MB;   //tag requested from cpu(to be refilled)
    reg[7:0] replace_index_MB;
    reg[511:0] replace_data_MB;
    reg[3:0] ret_number_MB;         //how many data returned from AXI-Bus during REFILL state

    //replace select
    reg[511:0] replace_data;
    reg replace_Valid;
    reg replace_Dirty;
    reg[17:0] replace_tag_old;
    reg[1:0] counter;

    //hit
    wire way0_hit;
    wire way1_hit;
    wire way2_hit;
    wire way3_hit;
    wire cache_hit;
    wire hit_write;
    wire write_conflict;
    wire write_bypass;
    reg[31:0] wdata_bypass;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Block Ram
    ValidTag_Block VT_Way0(
        clk, 1, VT_Way0_wen, VT_addr, VT_in, VT_Way0_out
    );
    ValidTag_Block VT_Way1(
        clk, 1, VT_Way1_wen, VT_addr, VT_in, VT_Way1_out
    );
    ValidTag_Block VT_Way2(
        clk, 1, VT_Way2_wen, VT_addr, VT_in, VT_Way2_out
    );
    ValidTag_Block VT_Way3(
        clk, 1, VT_Way3_wen, VT_addr, VT_in, VT_Way3_out
    );
    Dirty_Block D_Way0(
        clk, 1, D_Way0_wen, D_addr, D_in, Way0_Dirty
    );
    Dirty_Block D_Way1(
        clk, 1, D_Way0_wen, D_addr, D_in, Way1_Dirty
    );
    Dirty_Block D_Way2(
        clk, 1, D_Way0_wen, D_addr, D_in, Way2_Dirty
    );
    Dirty_Block D_Way3(
        clk, 1, D_Way0_wen, D_addr, D_in, Way3_Dirty
    );
    Data_Block Data_Way0(
        clk, 1, Data_Way0_wen, Data_addr, Data_in, Data_Way0_out
    );
    Data_Block Data_Way1(
        clk, 1, Data_Way1_wen, Data_addr, Data_in, Data_Way1_out
    );
    Data_Block Data_Way2(
        clk, 1, Data_Way2_wen, Data_addr, Data_in, Data_Way2_out
    );
    Data_Block Data_Way3(
        clk, 1, Data_Way3_wen, Data_addr, Data_in, Data_Way3_out
    );

    //tag compare && hit judgement
    assign way0_hit = Way0_Valid && (Way0_Tag == tag_RB);
    assign way1_hit = Way1_Valid && (Way1_Tag == tag_RB);
    assign way2_hit = Way2_Valid && (Way2_Tag == tag_RB);
    assign way3_hit = Way3_Valid && (Way3_Tag == tag_RB);
    assign cache_hit = way0_hit || way1_hit || way2_hit || way3_hit;
    assign hit_write = (C_STATE == LOOKUP) && op_RB && cache_hit;
    assign write_conflict = hit_write && !op && valid && ({tag,index,offset[5:2]}!={tag_RB,index_RB,offset_RB});
    assign write_bypass = hit_write && !op && valid && ({tag,index,offset[5:2]}=={tag_RB,index_RB,offset_RB});

    //random replacement strategy with a clock counter
    always@(posedge clk)
        if(!resetn)
            counter <= 2'b00;
        else
            counter <= counter + 1;
    always@(*)
        case(counter)
            2'b00:  begin   //choose way0
                    replace_Valid = Way0_Valid;
                    replace_Dirty = Way0_Dirty;
                    replace_tag_old = Way0_Tag;
                    replace_data = Data_Way0_out;
            end
            2'b01:  begin   //choose way1
                    replace_Valid = Way1_Valid;
                    replace_Dirty = Way1_Dirty;
                    replace_tag_old = Way1_Tag;
                    replace_data = Data_Way1_out;
            end
            2'b10:  begin   //choose way2
                    replace_Valid = Way2_Valid;
                    replace_Dirty = Way2_Dirty;
                    replace_tag_old = Way2_Tag;
                    replace_data = Data_Way2_out;
            end
            default:begin   //choose way3
                    replace_Valid = Way3_Valid;
                    replace_Dirty = Way3_Dirty;
                    replace_tag_old = Way3_Tag;
                    replace_data = Data_Way3_out;
            end
        endcase

    //Request Buffer
    always@(posedge clk)
        if(!resetn) begin
            op_RB <= 1'b0;
            index_RB <= 8'd0;
            tag_RB <= 17'd0;
            offset_RB <= 6'd0;
            wstrb_RB <= 4'd0;
            wdata_RB <= 32'd0;
        end
        else if((C_STATE == IDLE && N_STATE == LOOKUP) || (C_STATE == LOOKUP && N_STATE ==LOOKUP) 
                || write_conflict) begin
            op_RB <= op;
            index_RB <= index;
            tag_RB <= tag;
            offset_RB <= offset;
            wstrb_RB <= wstrb;
            wdata_RB <= wdata;
        end
    
    //Miss Buffer
    always@(posedge clk)
        if(!resetn) begin
            replace_way_MB <= 1'b0;
            replace_data_MB <= 512'd0; 
            replace_Valid_MB <= 1'b0;
            replace_Dirty_MB <= 1'b0;
            replace_index_MB <= 8'd0;
            replace_tag_old_MB <= 18'd0;
            replace_tag_new_MB <= 18'd0;
        end
        else if(C_STATE == LOOKUP) begin
            replace_way_MB <= counter;
            replace_data_MB <= replace_data;
            replace_Valid_MB <= replace_Valid;
            replace_Dirty_MB <= replace_Dirty;
            replace_index_MB <= index_RB;
            replace_tag_old_MB <= replace_tag_old;
            replace_tag_new_MB <= tag_RB;
        end
    always@(posedge clk)                //help locate the block offset during REFILL state
        if(!resetn)
            ret_number_MB <= 4'b0000;
        else if(rd_rdy)
            ret_number_MB <= 4'b0000;
        else if(ret_valid)
            ret_number_MB <= ret_number_MB + 1;

    //reading from cache to cpu (load)
    always@(posedge clk)
        if(!resetn)
            wdata_bypass <= 32'd0;
        else
            wdata_bypass <= wdata_RB;
    always@(*)
        if(write_bypass)
            rdata = wdata_bypass;
        else if(way0_hit)        //read way0
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way0_out[ 31:  0];
                4'd1:   rdata = Data_Way0_out[ 63: 32];
                4'd2:   rdata = Data_Way0_out[ 95: 64];
                4'd3:   rdata = Data_Way0_out[127: 96];
                4'd4:   rdata = Data_Way0_out[159:128];
                4'd5:   rdata = Data_Way0_out[191:160];
                4'd6:   rdata = Data_Way0_out[223:192];
                4'd7:   rdata = Data_Way0_out[255:224];
                4'd8:   rdata = Data_Way0_out[287:256];
                4'd9:   rdata = Data_Way0_out[319:288];
                4'd10:  rdata = Data_Way0_out[351:320];
                4'd11:  rdata = Data_Way0_out[383:352];
                4'd12:  rdata = Data_Way0_out[415:384];
                4'd13:  rdata = Data_Way0_out[447:416];
                4'd14:  rdata = Data_Way0_out[479:448];
                default:rdata = Data_Way0_out[511:480];
            endcase
        else if(way1_hit)   //read way1
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way1_out[ 31:  0];
                4'd1:   rdata = Data_Way1_out[ 63: 32];
                4'd2:   rdata = Data_Way1_out[ 95: 64];
                4'd3:   rdata = Data_Way1_out[127: 96];
                4'd4:   rdata = Data_Way1_out[159:128];
                4'd5:   rdata = Data_Way1_out[191:160];
                4'd6:   rdata = Data_Way1_out[223:192];
                4'd7:   rdata = Data_Way1_out[255:224];
                4'd8:   rdata = Data_Way1_out[287:256];
                4'd9:   rdata = Data_Way1_out[319:288];
                4'd10:  rdata = Data_Way1_out[351:320];
                4'd11:  rdata = Data_Way1_out[383:352];
                4'd12:  rdata = Data_Way1_out[415:384];
                4'd13:  rdata = Data_Way1_out[447:416];
                4'd14:  rdata = Data_Way1_out[479:448];
                default:rdata = Data_Way1_out[511:480];
            endcase
        else if(way2_hit)   //read way2
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way2_out[ 31:  0];
                4'd1:   rdata = Data_Way2_out[ 63: 32];
                4'd2:   rdata = Data_Way2_out[ 95: 64];
                4'd3:   rdata = Data_Way2_out[127: 96];
                4'd4:   rdata = Data_Way2_out[159:128];
                4'd5:   rdata = Data_Way2_out[191:160];
                4'd6:   rdata = Data_Way2_out[223:192];
                4'd7:   rdata = Data_Way2_out[255:224];
                4'd8:   rdata = Data_Way2_out[287:256];
                4'd9:   rdata = Data_Way2_out[319:288];
                4'd10:  rdata = Data_Way2_out[351:320];
                4'd11:  rdata = Data_Way2_out[383:352];
                4'd12:  rdata = Data_Way2_out[415:384];
                4'd13:  rdata = Data_Way2_out[447:416];
                4'd14:  rdata = Data_Way2_out[479:448];
                default:rdata = Data_Way2_out[511:480];
            endcase
        else if(way3_hit)   //read way3
            case(offset_RB[5:2])
                4'd0:   rdata = Data_Way3_out[ 31:  0];
                4'd1:   rdata = Data_Way3_out[ 63: 32];
                4'd2:   rdata = Data_Way3_out[ 95: 64];
                4'd3:   rdata = Data_Way3_out[127: 96];
                4'd4:   rdata = Data_Way3_out[159:128];
                4'd5:   rdata = Data_Way3_out[191:160];
                4'd6:   rdata = Data_Way3_out[223:192];
                4'd7:   rdata = Data_Way3_out[255:224];
                4'd8:   rdata = Data_Way3_out[287:256];
                4'd9:   rdata = Data_Way3_out[319:288];
                4'd10:  rdata = Data_Way3_out[351:320];
                4'd11:  rdata = Data_Way3_out[383:352];
                4'd12:  rdata = Data_Way3_out[415:384];
                4'd13:  rdata = Data_Way3_out[447:416];
                4'd14:  rdata = Data_Way3_out[479:448];
                default:rdata = Data_Way3_out[511:480];
            endcase
        else                //read ret_data when miss
            rdata = ret_data;
    
    //write from cpu to cache (store)
    always@(wdata_RB, wstrb_RB, hit_write, ret_data)
        if(hit_write) begin
            case(wstrb_RB)
                4'b0001:    Data_in = {64{wdata_RB[7:0]}};
                4'b0010:    Data_in = {64{wdata_RB[7:0]}};
                4'b0100:    Data_in = {64{wdata_RB[7:0]}};
                4'b1000:    Data_in = {64{wdata_RB[7:0]}};
                4'b0011:    Data_in = {32{wdata_RB[15:0]}};
                4'b1100:    Data_in = {32{wdata_RB[15:0]}};
                default:    Data_in = {16{wdata_RB}};
            endcase
        end
        else
            Data_in = {16{ret_data}};
    always@(*)
        if(hit_write) begin
            if(way0_hit) begin
                case(offset_RB[5:2])
                    4'd0:   Data_Way0_wen = {60'd0,wstrb_RB};
                    4'd1:   Data_Way0_wen = {56'd0,wstrb_RB,4'd0};
                    4'd2:   Data_Way0_wen = {52'd0,wstrb_RB,8'd0};
                    4'd3:   Data_Way0_wen = {48'd0,wstrb_RB,12'd0};
                    4'd4:   Data_Way0_wen = {44'd0,wstrb_RB,16'd0};
                    4'd5:   Data_Way0_wen = {40'd0,wstrb_RB,20'd0};
                    4'd6:   Data_Way0_wen = {36'd0,wstrb_RB,24'd0};
                    4'd7:   Data_Way0_wen = {32'd0,wstrb_RB,28'd0};
                    4'd8:   Data_Way0_wen = {28'd0,wstrb_RB,32'd0};
                    4'd9:   Data_Way0_wen = {24'd0,wstrb_RB,36'd0};
                    4'd10:  Data_Way0_wen = {20'd0,wstrb_RB,40'd0};
                    4'd11:  Data_Way0_wen = {16'd0,wstrb_RB,44'd0};
                    4'd12:  Data_Way0_wen = {12'd0,wstrb_RB,48'd0};
                    4'd13:  Data_Way0_wen = {8'd0,wstrb_RB,52'd0};
                    4'd14:  Data_Way0_wen = {4'd0,wstrb_RB,56'd0};
                    default:Data_Way0_wen = {wstrb_RB,60'd0};
                endcase
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(way1_hit) begin
                case(offset_RB[5:2])
                    4'd0:   Data_Way1_wen = {60'd0,wstrb_RB};
                    4'd1:   Data_Way1_wen = {56'd0,wstrb_RB,4'd0};
                    4'd2:   Data_Way1_wen = {52'd0,wstrb_RB,8'd0};
                    4'd3:   Data_Way1_wen = {48'd0,wstrb_RB,12'd0};
                    4'd4:   Data_Way1_wen = {44'd0,wstrb_RB,16'd0};
                    4'd5:   Data_Way1_wen = {40'd0,wstrb_RB,20'd0};
                    4'd6:   Data_Way1_wen = {36'd0,wstrb_RB,24'd0};
                    4'd7:   Data_Way1_wen = {32'd0,wstrb_RB,28'd0};
                    4'd8:   Data_Way1_wen = {28'd0,wstrb_RB,32'd0};
                    4'd9:   Data_Way1_wen = {24'd0,wstrb_RB,36'd0};
                    4'd10:  Data_Way1_wen = {20'd0,wstrb_RB,40'd0};
                    4'd11:  Data_Way1_wen = {16'd0,wstrb_RB,44'd0};
                    4'd12:  Data_Way1_wen = {12'd0,wstrb_RB,48'd0};
                    4'd13:  Data_Way1_wen = {8'd0,wstrb_RB,52'd0};
                    4'd14:  Data_Way1_wen = {4'd0,wstrb_RB,56'd0};
                    default:Data_Way1_wen = {wstrb_RB,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(way2_hit) begin
                case(offset_RB[5:2])
                    4'd0:   Data_Way2_wen = {60'd0,wstrb_RB};
                    4'd1:   Data_Way2_wen = {56'd0,wstrb_RB,4'd0};
                    4'd2:   Data_Way2_wen = {52'd0,wstrb_RB,8'd0};
                    4'd3:   Data_Way2_wen = {48'd0,wstrb_RB,12'd0};
                    4'd4:   Data_Way2_wen = {44'd0,wstrb_RB,16'd0};
                    4'd5:   Data_Way2_wen = {40'd0,wstrb_RB,20'd0};
                    4'd6:   Data_Way2_wen = {36'd0,wstrb_RB,24'd0};
                    4'd7:   Data_Way2_wen = {32'd0,wstrb_RB,28'd0};
                    4'd8:   Data_Way2_wen = {28'd0,wstrb_RB,32'd0};
                    4'd9:   Data_Way2_wen = {24'd0,wstrb_RB,36'd0};
                    4'd10:  Data_Way2_wen = {20'd0,wstrb_RB,40'd0};
                    4'd11:  Data_Way2_wen = {16'd0,wstrb_RB,44'd0};
                    4'd12:  Data_Way2_wen = {12'd0,wstrb_RB,48'd0};
                    4'd13:  Data_Way2_wen = {8'd0,wstrb_RB,52'd0};
                    4'd14:  Data_Way2_wen = {4'd0,wstrb_RB,56'd0};
                    default:Data_Way2_wen = {wstrb_RB,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else begin
                case(offset_RB[5:2])
                    4'd0:   Data_Way3_wen = {60'd0,wstrb_RB};
                    4'd1:   Data_Way3_wen = {56'd0,wstrb_RB,4'd0};
                    4'd2:   Data_Way3_wen = {52'd0,wstrb_RB,8'd0};
                    4'd3:   Data_Way3_wen = {48'd0,wstrb_RB,12'd0};
                    4'd4:   Data_Way3_wen = {44'd0,wstrb_RB,16'd0};
                    4'd5:   Data_Way3_wen = {40'd0,wstrb_RB,20'd0};
                    4'd6:   Data_Way3_wen = {36'd0,wstrb_RB,24'd0};
                    4'd7:   Data_Way3_wen = {32'd0,wstrb_RB,28'd0};
                    4'd8:   Data_Way3_wen = {28'd0,wstrb_RB,32'd0};
                    4'd9:   Data_Way3_wen = {24'd0,wstrb_RB,36'd0};
                    4'd10:  Data_Way3_wen = {20'd0,wstrb_RB,40'd0};
                    4'd11:  Data_Way3_wen = {16'd0,wstrb_RB,44'd0};
                    4'd12:  Data_Way3_wen = {12'd0,wstrb_RB,48'd0};
                    4'd13:  Data_Way3_wen = {8'd0,wstrb_RB,52'd0};
                    4'd14:  Data_Way3_wen = {4'd0,wstrb_RB,56'd0};
                    default:Data_Way3_wen = {wstrb_RB,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
            end
        end
        else if(ret_valid &&(C_STATE == REFILL)) begin
            if(replace_way_MB == 2'd0) begin
                case(ret_number_MB)
                    4'd0:   Data_Way0_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way0_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way0_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way0_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way0_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way0_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way0_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way0_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way0_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way0_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way0_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way0_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way0_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way0_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way0_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way0_wen = {4'b1111,60'd0};
                endcase
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(replace_way_MB == 2'd1) begin
                case(ret_number_MB)
                    4'd0:   Data_Way1_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way1_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way1_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way1_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way1_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way1_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way1_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way1_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way1_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way1_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way1_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way1_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way1_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way1_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way1_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way1_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way2_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else if(replace_way_MB == 2'd2) begin
                case(ret_number_MB)
                    4'd0:   Data_Way2_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way2_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way2_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way2_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way2_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way2_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way2_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way2_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way2_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way2_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way2_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way2_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way2_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way2_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way2_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way2_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way3_wen = 64'd0;
            end
            else begin
                case(ret_number_MB)
                    4'd0:   Data_Way3_wen = {60'd0,4'b1111};
                    4'd1:   Data_Way3_wen = {56'd0,4'b1111,4'd0};
                    4'd2:   Data_Way3_wen = {52'd0,4'b1111,8'd0};
                    4'd3:   Data_Way3_wen = {48'd0,4'b1111,12'd0};
                    4'd4:   Data_Way3_wen = {44'd0,4'b1111,16'd0};
                    4'd5:   Data_Way3_wen = {40'd0,4'b1111,20'd0};
                    4'd6:   Data_Way3_wen = {36'd0,4'b1111,24'd0};
                    4'd7:   Data_Way3_wen = {32'd0,4'b1111,28'd0};
                    4'd8:   Data_Way3_wen = {28'd0,4'b1111,32'd0};
                    4'd9:   Data_Way3_wen = {24'd0,4'b1111,36'd0};
                    4'd10:  Data_Way3_wen = {20'd0,4'b1111,40'd0};
                    4'd11:  Data_Way3_wen = {16'd0,4'b1111,44'd0};
                    4'd12:  Data_Way3_wen = {12'd0,4'b1111,48'd0};
                    4'd13:  Data_Way3_wen = {8'd0,4'b1111,52'd0};
                    4'd14:  Data_Way3_wen = {4'd0,4'b1111,56'd0};
                    default:Data_Way3_wen = {4'b1111,60'd0};
                endcase
                Data_Way0_wen = 64'd0;
                Data_Way1_wen = 64'd0;
                Data_Way2_wen = 64'd0;
            end
        end
        else begin
            Data_Way0_wen = 64'd0;
            Data_Way1_wen = 64'd0;
            Data_Way2_wen = 64'd0;
            Data_Way3_wen = 64'd0;
        end    

    //replace from cache to mem (write memory)
    assign wr_addr = {replace_tag_old_MB, replace_index_MB, 6'b000000} ;
    assign wr_data = replace_data_MB;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    assign VT_Way0_wen = ret_valid && (replace_way_MB == 0) && (ret_number_MB == 4'h8);
    assign VT_Way1_wen = ret_valid && (replace_way_MB == 1) && (ret_number_MB == 4'h8);
    assign VT_Way2_wen = ret_valid && (replace_way_MB == 2) && (ret_number_MB == 4'h8);
    assign VT_Way3_wen = ret_valid && (replace_way_MB == 3) && (ret_number_MB == 4'h8);
    assign VT_in = {1'b1,replace_tag_new_MB};
    assign D_Way0_wen = (hit_write && way0_hit) || (ret_valid && (replace_way_MB == 0));
    assign D_Way1_wen = (hit_write && way1_hit) || (ret_valid && (replace_way_MB == 1));
    assign D_Way2_wen = (hit_write && way2_hit) || (ret_valid && (replace_way_MB == 2));
    assign D_Way3_wen = (hit_write && way3_hit) || (ret_valid && (replace_way_MB == 3));
    assign D_in = ret_valid ? 0 : hit_write;
    assign rd_type = 3'b100;
    assign rd_addr = {replace_tag_new_MB, replace_index_MB, 6'b000000};

    //block address control
    always@(replace_index_MB, index, C_STATE, valid, index_RB)
        if(!valid)
            VT_addr = index_RB;
        else if(C_STATE == REFILL)
            VT_addr = replace_index_MB;
        else
            VT_addr = index;
    always@(hit_write, index_RB, replace_index_MB)
        if(hit_write)
            D_addr = index_RB;
        else
            D_addr = replace_index_MB;
    always@(hit_write, index_RB, replace_index_MB, index, C_STATE,valid)
        if(hit_write||!valid)
            Data_addr = index_RB;
        else if(C_STATE == REFILL)
            Data_addr = replace_index_MB;
        else
            Data_addr = index;

    //main FSM
    /*
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(posedge clk)
        if(!resetn)
            C_STATE <= IDLE;
        else
            C_STATE <= N_STATE;
    always@(C_STATE, valid, cache_hit, wr_rdy, rd_rdy, ret_valid, ret_last, 
            replace_Valid_MB, replace_Dirty_MB, write_conflict)
        case(C_STATE)
            IDLE:   if(valid)
                        N_STATE = LOOKUP;
                    else 
                        N_STATE = IDLE;
            LOOKUP: if(!cache_hit)
                        N_STATE = MISS;
                    else if(write_conflict)
                        N_STATE = IDLE;
                    else if(valid)
                        N_STATE = LOOKUP;
                    else
                        N_STATE = IDLE;
            MISS:   if(!replace_Valid_MB || !replace_Dirty_MB) begin    //data is not dirty
                        if(!rd_rdy)
                            N_STATE = MISS;
                        else
                            N_STATE = REFILL;
                    end
                    else if(!wr_rdy)                                    //data is dirty
                        N_STATE = MISS;
                    else
                        N_STATE = REPLACE;
            REPLACE:if(!rd_rdy)
                        N_STATE = REPLACE;
                    else
                        N_STATE = REFILL;
            REFILL: if(ret_valid && ret_last)
                        N_STATE = LOOKUP;
                    else
                        N_STATE = REFILL;
            default: N_STATE = IDLE;
        endcase

    //output signals
    assign addr_ok = (C_STATE == IDLE) || ((C_STATE == LOOKUP) && !write_conflict) ;
    assign data_ok = (C_STATE == IDLE) || ((C_STATE == LOOKUP) && cache_hit) ;
    assign rd_req = (N_STATE == REFILL) ;
    assign wr_req = (N_STATE == REPLACE) ;

endmodule

module uncache(
        clk, resetn,
        //CPU_Pipeline side
        /*input*/   valid, op, addr, wstrb, wdata,
        /*output*/  data_ok, rdata,
        //AXI-Bus side 
        /*input*/   rd_rdy, wr_rdy, ret_valid, ret_last, ret_data, wr_valid,
        /*output*/  rd_req, wr_req, rd_type, wr_type, rd_addr, wr_addr, wr_wstrb, wr_data
);

    input clk;
    input resetn;

    input valid;
    input op;
    input[31:0] addr;
    input[3:0] wstrb;
    input[31:0] wdata;

    output data_ok;
    output[31:0] rdata;

    input rd_rdy;
    input wr_rdy;
    input ret_valid;
    input ret_last;
    input[31:0] ret_data;
    input wr_valid;

    output rd_req;
    output wr_req;
    output[2:0] rd_type;
    output[2:0] wr_type;
    output[31:0] rd_addr;
    output[31:0] wr_addr;
    output[3:0] wr_wstrb;
    output reg[31:0] wr_data;

    reg[1:0] C_STATE;
    reg[1:0] N_STATE;

    parameter DEFAULT = 2'b00;
    parameter LOAD    = 2'b01;
    parameter STORE   = 2'b10;

    wire load;
    wire store;

    assign load = valid & ~op;
    assign store = valid & op;

    always@(posedge clk)
        if(!resetn)
            C_STATE <= DEFAULT;
        else
            C_STATE <= N_STATE;

    always@(C_STATE, load, store, rd_rdy, wr_rdy, ret_valid, ret_last, wr_valid)
        case(C_STATE)
            DEFAULT:    if(load && rd_rdy)
                            N_STATE = LOAD;
                        else if(store && wr_rdy)
                            N_STATE = STORE;
                        else
                            N_STATE = DEFAULT;
            LOAD:       if(ret_valid && ret_last)
                            N_STATE = DEFAULT;
                        else
                            N_STATE = LOAD;
            STORE:      if(wr_valid)
                            N_STATE = DEFAULT;
                        else
                            N_STATE = STORE;
            default:    N_STATE = DEFAULT;
        endcase

    assign data_ok = 
                    (load && (C_STATE == LOAD) && ret_valid && ret_last) ||
                    (store && (C_STATE == STORE) && wr_valid)  ;
    assign rdata = ret_data;

    assign rd_req = (N_STATE == LOAD);
    assign wr_req = (N_STATE == STORE);
    assign rd_type = 3'b010;
    assign wr_type = 3'b010;
    assign rd_addr = addr;
    assign wr_addr = addr;
    assign wr_wstrb = wstrb;
    always@(wstrb, wdata)
        case(wstrb)
            4'b0001:wr_data = {4{wdata[7:0]}};
            4'b0010:wr_data = {4{wdata[7:0]}};
            4'b0100:wr_data = {4{wdata[7:0]}};
            4'b1000:wr_data = {4{wdata[7:0]}};
            4'b0011:wr_data = {2{wdata[15:0]}};
            4'b1100:wr_data = {2{wdata[15:0]}};
            default:wr_data = wdata;
        endcase
endmodule