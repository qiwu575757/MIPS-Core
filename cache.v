
//  This is a module of a D-Cache.
//  The whole design is based on the Chapter 10 of the book <CPU Design and Practise>
//  The module has been tested with the topmodule and testbench from the book(with a little revision)(with 2 ways and 4 words per way)
//  It's written by Wang Hanmo,finished at 18:45 PM, April 27th 2021
//  The cache operates with single cycle,with 4 ways and 16 words per way
//  Interface remaining to designing: addr_ok, data_ok, rd_type, wr_type, wr_wstrb.

module cache(clk, resetn, valid, op, index, tag, offset, wstrb, wdata, addr_ok, data_ok, rdata, 
rd_req, rd_type, rd_addr, rd_rdy,ret_valid,
    ret_last, ret_data, wr_req, wr_type, wr_addr, wr_wstrb, wr_data, wr_rdy);

    //clock and reset
    input clk;
    input resetn;

    // Cache && CPU-Pipeline
    input valid;
    input op;
    input[7:0] index;
    input[17:0] tag;
    input[5:0] offset;
    input[3:0] wstrb;
    input[31:0] wdata;
    output addr_ok;
    output data_ok;
    output reg[31:0] rdata;

    // Cache && AXI-Bus
    output rd_req;
    output rd_type;
    output[31:0] rd_addr;
    input rd_rdy;
    input ret_valid;
    input ret_last;
    input[31:0] ret_data;
    output wr_req;
    output[2:0] wr_type;
    output[31:0] wr_addr;
    output[3:0] wr_wstrb;
    output[511:0] wr_data;
    input wr_rdy;

    //Cache RAM
    reg Way0_V[255:0];
    reg Way1_V[255:0];
    reg Way2_V[255:0];
    reg Way3_V[255:0];
    reg Way0_D[255:0];
    reg Way1_D[255:0];
    reg Way2_D[255:0];
    reg Way3_D[255:0];
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

    //Miss Buffer
    reg[1:0] replace_way_MB;
    reg replace_V_MB;
    reg replace_D_MB;
    reg[17:0] replace_tag_old_MB;
    reg[17:0] replace_tag_new_MB;
    reg[7:0] replace_index_MB;
    reg[511:0] replace_data_MB;
    reg[3:0] ret_number_MB;

    //replace select
    reg[511:0] replace_data;
    reg replace_V;
    reg replace_D;
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

    //Tag Compare (hit judgement)
    assign way0_hit = Way0_V[index] && (Way0_Tag[index] == tag);
    assign way1_hit = Way1_V[index] && (Way1_Tag[index] == tag);
    assign way2_hit = Way2_V[index] && (Way2_Tag[index] == tag);
    assign way3_hit = Way3_V[index] && (Way3_Tag[index] == tag);
    assign cache_hit = way0_hit || way1_hit || way2_hit || way3_hit;

    //Data Select (reading from cache to cpu (load) )
    always@(*)
        if(way0_hit)
            rdata = Way0_Data[index][offset[5:2]];
        else if(way1_hit)
            rdata = Way1_Data[index][offset[5:2]];
        else if(way2_hit)
            rdata = Way2_Data[index][offset[5:2]];
        else if(way3_hit)
            rdata = Way3_Data[index][offset[5:2]];
        else
            rdata = ret_data;

    //random counter
    always@(posedge clk)
        if(!resetn)
            counter <= 2'b00;
        else
            counter <= counter + 1;

    //replacement based on random counter
    always@(*)
        case(counter)
            2'b00:  begin
                    replace_V = Way0_V[index];
                    replace_D = Way0_D[index];
                    replace_tag_old = Way0_Tag[index];
                    replace_data = {
                        Way0_Data[index][15],Way0_Data[index][14],Way0_Data[index][13],Way0_Data[index][12],
                        Way0_Data[index][11],Way0_Data[index][10],Way0_Data[index][ 9],Way0_Data[index][ 8],
                        Way0_Data[index][ 7],Way0_Data[index][ 6],Way0_Data[index][ 5],Way0_Data[index][ 4],
                        Way0_Data[index][ 3],Way0_Data[index][ 2],Way0_Data[index][ 1],Way0_Data[index][ 0] };
            end
            2'b01:  begin
                    replace_V = Way1_V[index];
                    replace_D = Way1_D[index];
                    replace_tag_old = Way1_Tag[index];
                    replace_data = {
                        Way1_Data[index][15],Way1_Data[index][14],Way1_Data[index][13],Way1_Data[index][12],
                        Way1_Data[index][11],Way1_Data[index][10],Way1_Data[index][ 9],Way1_Data[index][ 8],
                        Way1_Data[index][ 7],Way1_Data[index][ 6],Way1_Data[index][ 5],Way1_Data[index][ 4],
                        Way1_Data[index][ 3],Way1_Data[index][ 2],Way1_Data[index][ 1],Way1_Data[index][ 0] };
            end
            2'b10:  begin
                    replace_V = Way2_V[index];
                    replace_D = Way2_D[index];
                    replace_tag_old = Way2_Tag[index];
                    replace_data = {
                        Way2_Data[index][15],Way2_Data[index][14],Way2_Data[index][13],Way2_Data[index][12],
                        Way2_Data[index][11],Way2_Data[index][10],Way2_Data[index][ 9],Way2_Data[index][ 8],
                        Way2_Data[index][ 7],Way2_Data[index][ 6],Way2_Data[index][ 5],Way2_Data[index][ 4],
                        Way2_Data[index][ 3],Way2_Data[index][ 2],Way2_Data[index][ 1],Way2_Data[index][ 0] };
            end
            default:begin
                    replace_V = Way3_V[index];
                    replace_D = Way3_D[index];
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
            replace_V_MB <= 1'b0;
            replace_D_MB <= 1'b0;
            replace_index_MB <= 8'd0;
            replace_tag_old_MB <= 20'd0;
            replace_tag_new_MB <= 20'd0;
        end
        else if(C_STATE == LOOKUP) begin
            replace_way_MB <= counter;
            replace_data_MB <= replace_data;
            replace_V_MB <= replace_V;
            replace_D_MB <= replace_D;
            replace_index_MB <= index;
            replace_tag_old_MB <= replace_tag_old;
            replace_tag_new_MB <= tag;
        end
    always@(posedge clk)
        if(!resetn)
            ret_number_MB <= 4'b0000;
        else if(rd_rdy)
            ret_number_MB <= 4'b0000;
        else if(ret_valid)
            ret_number_MB <= ret_number_MB + 1;

    //hit write signal
    assign hit_write = (C_STATE == LOOKUP) && op && cache_hit && valid;

    //write from cpu to cache (store)
    always@(posedge clk)
        if(hit_write) begin
            if(way3_hit) begin
                case(wstrb)
                    4'b0001:    Way3_Data[index][offset[5:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way3_Data[index][offset[5:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way3_Data[index][offset[5:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way3_Data[index][offset[5:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way3_Data[index][offset[5:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way3_Data[index][offset[5:2]][31:16] <= wdata[15:0];
                    default:    Way3_Data[index][offset[5:2]] <= wdata;
                 endcase
                Way3_D[index] <= 1'b1;
            end
            else if(way2_hit) begin
                case(wstrb)
                    4'b0001:    Way2_Data[index][offset[3:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way2_Data[index][offset[3:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way2_Data[index][offset[3:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way2_Data[index][offset[3:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way2_Data[index][offset[3:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way2_Data[index][offset[3:2]][31:16] <= wdata[15:0];
                    default:    Way2_Data[index][offset[3:2]] <= wdata;
                 endcase
                Way2_D[index] <= 1'b1;
            end
            else if(way1_hit) begin
                case(wstrb)
                    4'b0001:    Way1_Data[index][offset[5:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way1_Data[index][offset[5:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way1_Data[index][offset[5:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way1_Data[index][offset[5:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way1_Data[index][offset[5:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way1_Data[index][offset[5:2]][31:16] <= wdata[15:0];
                    default:    Way1_Data[index][offset[5:2]] <= wdata;
                 endcase
                Way1_D[index] <= 1'b1;
            end
            else begin
                case(wstrb)
                    4'b0001:    Way0_Data[index][offset[3:2]][7:0] <= wdata[7:0];
                    4'b0010:    Way0_Data[index][offset[3:2]][15:8] <= wdata[7:0];
                    4'b0100:    Way0_Data[index][offset[3:2]][23:16] <= wdata[7:0];
                    4'b1000:    Way0_Data[index][offset[3:2]][31:24] <= wdata[7:0];
                    4'b0011:    Way0_Data[index][offset[3:2]][15:0] <= wdata[15:0];
                    4'b1100:    Way0_Data[index][offset[3:2]][31:16] <= wdata[15:0];
                    default:    Way0_Data[index][offset[3:2]] <= wdata;
                 endcase
                Way0_D[index] <= 1'b1;
            end
        end

    //main FSM
    always@(posedge clk)
        if(!resetn)
            C_STATE <= LOOKUP;
        else
            C_STATE <= N_STATE;
    /*
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(C_STATE, valid, cache_hit, wr_rdy, rd_rdy, ret_valid, ret_last, replace_D_MB)
        case(C_STATE)
            LOOKUP: if(!cache_hit && valid)
                        N_STATE = MISS;
                    else
                        N_STATE = LOOKUP;
            MISS:   if(!replace_V_MB || !replace_D_MB)
                        N_STATE = REFILL;
                    else if(!wr_rdy)
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

    //replace from cache to mem (write memory)
    assign wr_addr = {replace_tag_old_MB, replace_index_MB, 6'b000000} ;
    assign wr_data = replace_data_MB;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    always@(posedge clk)
        if(!resetn)
            for(i=0;i<256;i=i+1) begin
                Way0_V[i] <= 1'b0;
                Way1_V[i] <= 1'b0;
                Way2_V[i] <= 1'b0;
                Way3_V[i] <= 1'b0;
                Way0_D[i] <= 1'b0;
                Way1_D[i] <= 1'b0;
                Way2_D[i] <= 1'b0;
                Way3_D[i] <= 1'b0;
            end
        else if(ret_valid)
            case(replace_way_MB)
                2'b00:  begin
                    Way0_V[replace_index_MB] <= 1'b1;
                    Way0_D[replace_index_MB] <= 1'b0;
                    Way0_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way0_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                2'b01:  begin
                    Way1_V[replace_index_MB] <= 1'b1;
                    Way1_D[replace_index_MB] <= 1'b0;
                    Way1_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way1_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                2'b10:  begin
                    Way2_V[replace_index_MB] <= 1'b1;
                    Way2_D[replace_index_MB] <= 1'b0;
                    Way2_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way2_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
                default:begin
                    Way3_V[replace_index_MB] <= 1'b1;
                    Way3_D[replace_index_MB] <= 1'b0;
                    Way3_Tag[replace_index_MB] <= replace_tag_new_MB;
                    Way3_Data[replace_index_MB][ret_number_MB] <= ret_data;
                end
            endcase
    assign rd_type = 3'b100;
    assign rd_addr = {replace_tag_new_MB, replace_index_MB, 6'b000000};

    //output signals
    assign addr_ok = ((C_STATE == LOOKUP) && (N_STATE == LOOKUP)) ;
    assign data_ok = ((C_STATE == LOOKUP) && cache_hit) ;
    assign rd_req = (N_STATE == REFILL) ;
    assign wr_req = (N_STATE == REPLACE) ;
            
endmodule