
//  This is a module of a D-Cache.
//  The whole design is based on the Chapter 10 of the book <CPU Design and Practise>
//  The module has been tested with the topmodule and testbench from the book(with a little revision)
//  It's written by Wang Hanmo,finished at 0:13 AM ,April 12th 2021

module cache(clk, rst, valid, op, index, tag, offset, wstrb, wdata, addr_ok, data_ok, rdata, rd_req, rd_type, rd_addr, rd_rdy,ret_valid,
    ret_last, ret_data, wr_req, wr_type, wr_addr, wr_wstrb, wr_data, wr_rdy);

    //clock and reset
    input clk;
    input rst;

    // Cache && CPU-Pipeline
    input valid;
    input op;
    input[7:0] index;
    input[19:0] tag;
    input[3:0] offset;
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
    output[127:0] wr_data;
    input wr_rdy;

    //Cache RAM
    reg Way0_V[255:0];
    reg Way1_V[255:0];
    reg Way0_D[255:0];
    reg Way1_D[255:0];
    reg[19:0] Way0_Tag[255:0];
    reg[19:0] Way1_Tag[255:0];
    reg[31:0] Way0_Data[255:0][3:0];
    reg[31:0] Way1_Data[255:0][3:0];

    //FINITE STATE MACHINE
    reg[2:0] C_STATE_M;
    reg[2:0] N_STATE_M;
    reg C_STATE_WB;
    reg N_STATE_WB;
    parameter IDLE_M = 3'b000, LOOKUP = 3'b001, MISS = 3'b010, REPLACE = 3'b011, REFILL = 3'b100;
    parameter IDLE_WB = 1'b0, WRITE = 1'b1;

    //Request Buffer
    reg op_RB;
    reg[7:0] index_RB;
    reg[19:0] tag_RB;
    reg[3:0] offset_RB;
    reg[3:0] wstrb_RB;
    reg[31:0] wdata_RB;

    //Miss Buffer
    reg replace_way_MB;
    reg[127:0] replace_data_MB;
    reg[3:0] ret_number_MB;

    //Write Buffer
    reg way_WB;
    reg[1:0] bank_WB;
    reg[7:0] index_WB;
    reg[3:0] wstrb_WB;
    reg[31:0] data_WB;

    //replace select
    wire[127:0] replace_data;
    reg counter;

    //hit
    wire way0_hit;
    wire way1_hit;
    wire cache_hit;
    wire hit_write_conflict;
    wire hit_write;

    //loop counter for reset
    integer i;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Tag Compare (hit judgement)
    assign way0_hit = Way0_V[index_RB] && (Way0_Tag[index_RB] == tag_RB);
    assign way1_hit = Way1_V[index_RB] && (Way1_Tag[index_RB] == tag_RB);
    assign cache_hit = way0_hit || way1_hit;

    //Data Select (reading from cache to cpu (load) )
    always@(*)
        if(way0_hit)
            rdata = Way0_Data[index_RB][offset_RB[3:2]];
        else if(way1_hit)
            rdata = Way1_Data[index_RB][offset_RB[3:2]];
        else
            rdata = ret_data;

    //random counter
    always@(posedge clk, posedge rst)
        if(rst)
            counter <= 1'b0;
        else
            counter <= counter + 1;

    //replacement based on random counter
    assign replace_data = counter ? 
        {Way1_Data[index_RB][3], Way1_Data[index_RB][2], Way1_Data[index_RB][1], Way1_Data[index_RB][0]} : 
        {Way0_Data[index_RB][3], Way0_Data[index_RB][2], Way0_Data[index_RB][1], Way0_Data[index_RB][0]} ;
    
    //Request Buffer
    always@(posedge clk, posedge rst)
        if(rst) begin
            op_RB <= 1'b0;
            index_RB <= 8'd0;
            tag_RB <= 20'd0;
            offset_RB <= 4'd0;
            wstrb_RB <= 4'd0;
            wdata_RB <= 32'd0;
        end
        else if((C_STATE_M == IDLE_M && N_STATE_M == LOOKUP) || (C_STATE_M == LOOKUP && N_STATE_M ==LOOKUP)) begin
            op_RB <= op;
            index_RB <= index;
            tag_RB <= tag;
            offset_RB <= offset;
            wstrb_RB <= wstrb_RB;
            wdata_RB <= wdata;
        end

    //Miss Buffer
    always@(posedge clk, posedge rst)
        if(rst) begin
            replace_way_MB <= 1'b0;
            replace_data_MB <= 128'd0;
        end
        else if(C_STATE_M == LOOKUP) begin
            replace_way_MB <= counter;
            replace_data_MB <= replace_data;
        end
    always@(posedge clk, posedge rst)
        if(rst)
            ret_number_MB <= 2'b00;
        else if(rd_rdy)
            ret_number_MB <= 2'b00;
        else if(ret_valid)
            ret_number_MB <= ret_number_MB + 1;

    //Write Buffer
    always@(posedge clk, posedge rst)
        if(rst) begin
            way_WB <= 1'b0;
            bank_WB <= 2'd0;
            index_WB <= 8'd0;
            wstrb_WB <= 4'd0;
            data_WB <= 32'd0;
        end
        else if(hit_write) begin
            way_WB <= way1_hit;
            bank_WB <= offset_RB[3:2];
            index_WB <= index_RB;
            wstrb_WB <= wstrb_RB;
            data_WB <= wdata_RB;
        end

    //hit write signals
    assign hit_write_conflict = ((C_STATE_M == LOOKUP) && op_RB && cache_hit && valid && !op && ({tag, index, offset} == {tag_RB, index_RB,offset_RB}))  || 
                                ((C_STATE_WB == WRITE) && valid && !op && (offset[3:2] == bank_WB));
        //copied from book,still remaining to be checked and improved
    assign hit_write = (C_STATE_M == LOOKUP) && op_RB && cache_hit;

    //write from cpu to cache (store)(write-buffer)
    always@(posedge clk)
        if(C_STATE_WB == WRITE) begin
            if(way_WB) begin
                case(wstrb_WB)
                    4'b0001:    Way1_Data[index_WB][bank_WB][7:0] <= data_WB[7:0];
                    4'b0010:    Way1_Data[index_WB][bank_WB][15:8] <= data_WB[7:0];
                    4'b0100:    Way1_Data[index_WB][bank_WB][23:16] <= data_WB[7:0];
                    4'b1000:    Way1_Data[index_WB][bank_WB][31:24] <= data_WB[7:0];
                    4'b0011:    Way1_Data[index_WB][bank_WB][15:0] <= data_WB[15:0];
                    4'b1100:    Way1_Data[index_WB][bank_WB][31:16] <= data_WB[15:0];
                    default:    Way1_Data[index_WB][bank_WB] <= data_WB;
                 endcase
                Way1_D[index_WB] <= 1'b1;
            end
            else begin
                case(wstrb_WB)
                    4'b0001:    Way0_Data[index_WB][bank_WB][7:0] <= data_WB[7:0];
                    4'b0010:    Way0_Data[index_WB][bank_WB][15:8] <= data_WB[7:0];
                    4'b0100:    Way0_Data[index_WB][bank_WB][23:16] <= data_WB[7:0];
                    4'b1000:    Way0_Data[index_WB][bank_WB][31:24] <= data_WB[7:0];
                    4'b0011:    Way0_Data[index_WB][bank_WB][15:0] <= data_WB[15:0];
                    4'b1100:    Way0_Data[index_WB][bank_WB][31:16] <= data_WB[15:0];
                    default:    Way0_Data[index_WB][bank_WB] <= data_WB;
                 endcase
                Way0_D[index_WB] <= 1'b1;
            end
        end

    //main FSM
    always@(posedge clk, posedge rst)
        if(rst)
            C_STATE_M <= IDLE_M;
        else
            C_STATE_M <= N_STATE_M;
    /*
        IDLE_M: Cache doesn't work
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(C_STATE_M, valid, cache_hit, wr_rdy, rd_rdy, ret_valid, ret_last)
        case(C_STATE_M)
            IDLE_M: if(valid)
                        N_STATE_M = LOOKUP;
                    else
                        N_STATE_M = IDLE_M;
            LOOKUP: if(!cache_hit)
                        N_STATE_M = MISS;
                    else if(cache_hit && valid)
                        N_STATE_M = LOOKUP;
                    else
                        N_STATE_M = IDLE_M;
            MISS:   if(!wr_rdy)
                        N_STATE_M = MISS;
                    else
                        N_STATE_M = REPLACE;
            REPLACE:if(!rd_rdy)
                        N_STATE_M = REPLACE;
                    else
                        N_STATE_M = REFILL;
            REFILL: if(ret_valid && ret_last)
                        N_STATE_M = LOOKUP;
                    else
                        N_STATE_M = REFILL;
            default: N_STATE_M <= IDLE_M;
        endcase

    //writebuffer FSM
    always@(posedge clk, posedge rst)
        if(rst)
            C_STATE_WB <= IDLE_WB;
        else
            C_STATE_WB <= N_STATE_WB;
    /*
        IDLE_WB: Nothing to be written
        WRITE: Writing cache
    */
    always@(C_STATE_WB, hit_write)
        case(C_STATE_WB)
            IDLE_WB: if(hit_write)
                        N_STATE_WB = WRITE;
                    else
                        N_STATE_WB = IDLE_WB;
            WRITE:  if(hit_write)
                        N_STATE_WB = WRITE;
                    else
                        N_STATE_WB = IDLE_WB;
            default:N_STATE_WB = IDLE_WB;
        endcase

    //replace from cache to mem (write memory)
    assign wr_addr = replace_way_MB? 
                    {Way1_Tag[index_RB], index_RB, 4'b0000} :
                    {Way0_Tag[index_RB], index_RB, 4'b0000} ;
    assign wr_data = replace_data_MB;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    always@(posedge clk, posedge rst)
        if(rst)
            for(i=0;i<256;i=i+1) begin
                Way0_V[i] <= 1'b0;
                Way1_V[i] <= 1'b0;
            end
        else if(ret_valid)
            if(replace_way_MB) begin
                Way1_V[index_RB] <= 1'b1;
                Way1_D[index_RB] <= 1'b0;
                Way1_Tag[index_RB] <= tag_RB;
                Way1_Data[index_RB][ret_number_MB] <= ret_data;
            end
            else begin
                Way0_V[index_RB] <= 1'b1;
                Way0_D[index_RB] <= 1'b0;
                Way0_Tag[index_RB] <= tag_RB;
                Way0_Data[index_RB][ret_number_MB] <= ret_data;
            end
    assign rd_type = 3'b100;
    assign rd_addr = {tag_RB, index_RB, 4'b0000};

    //output signals
    assign addr_ok = (C_STATE_M == IDLE_M) || 
                     ((C_STATE_M == LOOKUP) && cache_hit && valid && (op || !hit_write_conflict)) ;
    assign data_ok = ((C_STATE_M == LOOKUP) && cache_hit) /*||
                     ((C_STATE_M == LOOKUP) && op_RB) ||
                     ((C_STATE_M == REFILL) && ret_valid && ret_last)*/ ;
    //data_ok signal remains improving for cpu-pipeline efficiency
    assign rd_req = (N_STATE_M == REFILL) ;
    assign wr_req = (N_STATE_M == REPLACE ) && 
                    (replace_way_MB ? Way1_V[index_RB] : Way0_V[index_RB]) ;
            
endmodule