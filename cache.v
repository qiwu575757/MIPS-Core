
//  This is a module of a D-Cache.
//  The whole design is based on the Chapter 10 of the book <CPU Design and Practise>
//  The module has been tested with the topmodule and testbench from the book(with a little revision)(with 2 ways and 4 words per way)
//  It's written by Wang Hanmo,finished at 18:45 PM, April 27th 2021
//  The cache operates with single cycle,with 4 ways and 16 words per way
//  Interface remaining to designing: addr_ok, data_ok, rd_type, wr_type, wr_wstrb.

//                      MENU
//      Interface                       Line 32
//      Cache                           Line 63
//      Wires and Regs                  Line 94
//      Hit Compare                     Line 124
//      Random Replacement              Line 132
//      Miss Buffer                     Line 182
//      Data : Cache -> CPU             Line 210
//      Data : CPU   -> Cache           Line 223
//      Data : Cache -> AXI             Line 276
//      Data : AXI   -> Cache           Line 282
//      Finite State Machine            Line 325
//      Output signals                  Line 364

module cache(       clk, resetn,
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
        Every block: 1 valid bit + 1 dirty bit + 17 tag bit + 16 * 32 data bit
        Total memory: 64KB
    */
    reg Way0_Valid[255:0];
    reg Way1_Valid[255:0];
    reg Way2_Valid[255:0];
    reg Way3_Valid[255:0];
    reg Way0_Dirty[255:0];
    reg Way1_Dirty[255:0];
    reg Way2_Dirty[255:0];
    reg Way3_Dirty[255:0];
    reg[17:0] Way0_Tag[255:0];
    reg[17:0] Way1_Tag[255:0];
    reg[17:0] Way2_Tag[255:0];
    reg[17:0] Way3_Tag[255:0];
    reg[31:0] Way0_Data[255:0][15:0];
    reg[31:0] Way1_Data[255:0][15:0];
    reg[31:0] Way2_Data[255:0][15:0];
    reg[31:0] Way3_Data[255:0][15:0];

    //FINITE STATE MACHINE
    reg[1:0] C_STATE;
    reg[1:0] N_STATE;
    parameter LOOKUP = 2'b00, MISS = 2'b01, REPLACE = 2'b10, REFILL = 2'b11;

    //Miss Buffer : infromation for MISS-REPLACE-REFILL use
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

    //loop counter for reset
    integer i;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //tag compare && hit judgement
    assign way0_hit = Way0_Valid[index] && (Way0_Tag[index] == tag);
    assign way1_hit = Way1_Valid[index] && (Way1_Tag[index] == tag);
    assign way2_hit = Way2_Valid[index] && (Way2_Tag[index] == tag);
    assign way3_hit = Way3_Valid[index] && (Way3_Tag[index] == tag);
    assign cache_hit = way0_hit || way1_hit || way2_hit || way3_hit;
    assign hit_write = (C_STATE == LOOKUP) && op && cache_hit && valid;

    //random replacement strategy with a clock counter
    always@(posedge clk)
        if(!resetn)
            counter <= 2'b00;
        else
            counter <= counter + 1;
    always@(*)
        case(counter)
            2'b00:  begin   //choose way0
                    replace_Valid = Way0_Valid[index];
                    replace_Dirty = Way0_Dirty[index];
                    replace_tag_old = Way0_Tag[index];
                    replace_data = {
                        Way0_Data[index][15],Way0_Data[index][14],Way0_Data[index][13],Way0_Data[index][12],
                        Way0_Data[index][11],Way0_Data[index][10],Way0_Data[index][ 9],Way0_Data[index][ 8],
                        Way0_Data[index][ 7],Way0_Data[index][ 6],Way0_Data[index][ 5],Way0_Data[index][ 4],
                        Way0_Data[index][ 3],Way0_Data[index][ 2],Way0_Data[index][ 1],Way0_Data[index][ 0] };
            end
            2'b01:  begin   //choose way1
                    replace_Valid = Way1_Valid[index];
                    replace_Dirty = Way1_Dirty[index];
                    replace_tag_old = Way1_Tag[index];
                    replace_data = {
                        Way1_Data[index][15],Way1_Data[index][14],Way1_Data[index][13],Way1_Data[index][12],
                        Way1_Data[index][11],Way1_Data[index][10],Way1_Data[index][ 9],Way1_Data[index][ 8],
                        Way1_Data[index][ 7],Way1_Data[index][ 6],Way1_Data[index][ 5],Way1_Data[index][ 4],
                        Way1_Data[index][ 3],Way1_Data[index][ 2],Way1_Data[index][ 1],Way1_Data[index][ 0] };
            end
            2'b10:  begin   //choose way2
                    replace_Valid = Way2_Valid[index];
                    replace_Dirty = Way2_Dirty[index];
                    replace_tag_old = Way2_Tag[index];
                    replace_data = {
                        Way2_Data[index][15],Way2_Data[index][14],Way2_Data[index][13],Way2_Data[index][12],
                        Way2_Data[index][11],Way2_Data[index][10],Way2_Data[index][ 9],Way2_Data[index][ 8],
                        Way2_Data[index][ 7],Way2_Data[index][ 6],Way2_Data[index][ 5],Way2_Data[index][ 4],
                        Way2_Data[index][ 3],Way2_Data[index][ 2],Way2_Data[index][ 1],Way2_Data[index][ 0] };
            end
            default:begin   //choose way3
                    replace_Valid = Way3_Valid[index];
                    replace_Dirty = Way3_Dirty[index];
                    replace_tag_old = Way3_Tag[index];
                    replace_data = {
                        Way3_Data[index][15],Way3_Data[index][14],Way3_Data[index][13],Way3_Data[index][12],
                        Way3_Data[index][11],Way3_Data[index][10],Way3_Data[index][ 9],Way3_Data[index][ 8],
                        Way3_Data[index][ 7],Way3_Data[index][ 6],Way3_Data[index][ 5],Way3_Data[index][ 4],
                        Way3_Data[index][ 3],Way3_Data[index][ 2],Way3_Data[index][ 1],Way3_Data[index][ 0] };
            end
        endcase

    //Miss Buffer
    always@(posedge clk)
        if(!resetn) begin
            replace_way_MB <= 1'b0;
            replace_data_MB <= 128'd0; 
            replace_Valid_MB <= 1'b0;
            replace_Dirty_MB <= 1'b0;
            replace_index_MB <= 8'd0;
            replace_tag_old_MB <= 20'd0;
            replace_tag_new_MB <= 20'd0;
        end
        else if(C_STATE == LOOKUP) begin
            replace_way_MB <= counter;
            replace_data_MB <= replace_data;
            replace_Valid_MB <= replace_Valid;
            replace_Dirty_MB <= replace_Dirty;
            replace_index_MB <= index;
            replace_tag_old_MB <= replace_tag_old;
            replace_tag_new_MB <= tag;
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
            rdata = Way0_Data[index][offset[5:2]];
        else if(way1_hit)   //read way1
            rdata = Way1_Data[index][offset[5:2]];
        else if(way2_hit)   //read way2
            rdata = Way2_Data[index][offset[5:2]];
        else if(way3_hit)   //read way3
            rdata = Way3_Data[index][offset[5:2]];
        else                //read ret_data when miss
            rdata = ret_data;
    
    //write from cpu to cache (store)
    always@(posedge clk)
        if(hit_write) begin
            if(way3_hit) begin      //write way3
                case(wstrb)
                    4'b0001:    Way3_Data[index][offset[5:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way3_Data[index][offset[5:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way3_Data[index][offset[5:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way3_Data[index][offset[5:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way3_Data[index][offset[5:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way3_Data[index][offset[5:2]][31:16] <= wdata[15:0];
                    default:    Way3_Data[index][offset[5:2]] <= wdata;
                 endcase
                Way3_Dirty[index] <= 1'b1;
            end
            else if(way2_hit) begin //write way2
                case(wstrb)
                    4'b0001:    Way2_Data[index][offset[3:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way2_Data[index][offset[3:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way2_Data[index][offset[3:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way2_Data[index][offset[3:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way2_Data[index][offset[3:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way2_Data[index][offset[3:2]][31:16] <= wdata[15:0];
                    default:    Way2_Data[index][offset[3:2]] <= wdata;
                 endcase
                Way2_Dirty[index] <= 1'b1;
            end
            else if(way1_hit) begin //write way1
                case(wstrb)
                    4'b0001:    Way1_Data[index][offset[5:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way1_Data[index][offset[5:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way1_Data[index][offset[5:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way1_Data[index][offset[5:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way1_Data[index][offset[5:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way1_Data[index][offset[5:2]][31:16] <= wdata[15:0];
                    default:    Way1_Data[index][offset[5:2]] <= wdata;
                 endcase
                Way1_Dirty[index] <= 1'b1;
            end
            else begin              //write way0
                case(wstrb)
                    4'b0001:    Way0_Data[index][offset[3:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way0_Data[index][offset[3:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way0_Data[index][offset[3:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way0_Data[index][offset[3:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way0_Data[index][offset[3:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way0_Data[index][offset[3:2]][31:16] <= wdata[15:0];
                    default:    Way0_Data[index][offset[3:2]] <= wdata;
                 endcase
                Way0_Dirty[index] <= 1'b1;
            end
        end

    //replace from cache to mem (write memory)
    assign wr_addr = {replace_tag_old_MB, replace_index_MB, 6'b000000} ;
    assign wr_data = replace_data_MB;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    always@(posedge clk)
        if(!resetn)
            for(i=0;i<256;i=i+1) begin
                Way0_Valid[i] <= 1'b0;
                Way1_Valid[i] <= 1'b0;
                Way2_Valid[i] <= 1'b0;
                Way3_Valid[i] <= 1'b0;
                Way0_Dirty[i] <= 1'b0;
                Way1_Dirty[i] <= 1'b0;
                Way2_Dirty[i] <= 1'b0;
                Way3_Dirty[i] <= 1'b0;
            end
        else if(ret_valid)
            case(replace_way_MB)
                2'b00:  begin   //write way0
                    Way0_Valid[replace_index_MB] <= 1'b1;
                    Way0_Dirty[replace_index_MB] <= 1'b0;
                    Way0_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way0_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                2'b01:  begin   //write way1
                    Way1_Valid[replace_index_MB] <= 1'b1;
                    Way1_Dirty[replace_index_MB] <= 1'b0;
                    Way1_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way1_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                2'b10:  begin   //write way2
                    Way2_Valid[replace_index_MB] <= 1'b1;
                    Way2_Dirty[replace_index_MB] <= 1'b0;
                    Way2_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way2_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                default:begin   //write way3
                    Way3_Valid[replace_index_MB] <= 1'b1;
                    Way3_Dirty[replace_index_MB] <= 1'b0;
                    Way3_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way3_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
            endcase
    assign rd_type = 3'b100;
    assign rd_addr = {replace_tag_new_MB, replace_index_MB, 6'b000000};

    //main FSM
    /*
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(posedge clk)
        if(!resetn)
            C_STATE <= LOOKUP;
        else
            C_STATE <= N_STATE;
    always@(C_STATE, valid, cache_hit, wr_rdy, rd_rdy, ret_valid, ret_last, replace_Valid_MB, replace_Dirty_MB)
        case(C_STATE)
            LOOKUP: if(!cache_hit && valid)
                        N_STATE = MISS;
                    else
                        N_STATE = LOOKUP;
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
            default: N_STATE = LOOKUP;
        endcase

    //output signals
    assign addr_ok = ((C_STATE == LOOKUP) && (N_STATE == LOOKUP)) ;
    assign data_ok = ((C_STATE == LOOKUP) && cache_hit) ;
    assign rd_req = (N_STATE == REFILL) ;
    assign wr_req = (N_STATE == REPLACE) ;
            
endmodule

module uncache(
        clk, resetn,
        //CPU_Pipeline side
        /*input*/   valid, op, addr, wstrb, wdata,
        /*output*/  data_ok, rdata,
        //AXI-Bus side 
        /*input*/   rd_rdy, wr_rdy, ret_valid, ret_last, ret_data,
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

    output rd_req;
    output wr_req;
    output[2:0] rd_type;
    output[2:0] wr_type;
    output[31:0] rd_addr;
    output[31:0] wr_addr;
    output[3:0] wr_wstrb;
    output[31:0] wr_data;

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

    always@(C_STATE, load, store, rd_rdy, wr_rdy, ret_valid)
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
            STORE:      N_STATE = DEFAULT;
            default:    N_STATE = DEFAULT;
        endcase

    assign data_ok = 
                    (load && (C_STATE == LOAD) && ret_valid && ret_last) ||
                    (store && C_STATE == STORE) ;
    assign rdata = ret_data;

    assign rd_req = (N_STATE == LOAD);
    assign wr_req = (N_STATE == STORE);
    assign rd_type = 3'b010;
    assign wr_type = 3'b010;
    assign rd_addr = addr;
    assign wr_addr = addr;
    assign wr_wstrb = wstrb;
    assign wr_data = wdata;
endmodule