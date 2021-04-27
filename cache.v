
//  This is a module of a D-Cache.
//  The whole design is based on the Chapter 10 of the book <CPU Design and Practise>
//  The module has been tested with the topmodule and testbench from the book(with a little revision)
//  It's written by Wang Hanmo,finished at 23:45 PM, April 26th 2021
//  The cache operates with single cycle,but still 2 ways and 4 words per way

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
    reg[1:0] C_STATE_M;
    reg[1:0] N_STATE_M;
    reg C_STATE_WB;
    reg N_STATE_WB;
    parameter LOOKUP = 2'b00, MISS = 2'b01, REPLACE = 2'b10, REFILL = 2'b11;
    parameter IDLE = 1'b0, WRITE = 1'b1;

    //Miss Buffer
    reg replace_way_MB;
    reg replace_V_MB;
    reg replace_D_MB;
    reg[19:0] replace_tag_old_MB;
    reg[19:0] replace_tag_new_MB;
    reg[7:0] replace_index_MB;
    reg[127:0] replace_data_MB;
    reg[3:0] ret_number_MB;

    //Write Buffer
    reg way_WB;
    reg[1:0] bank_WB;
    reg[7:0] index_WB;
    reg[3:0] wstrb_WB;
    reg[31:0] data_WB;
    reg[31:0] data_bypass;

    //replace select
    wire[127:0] replace_data;
    wire replace_V;
    wire replace_D;
    wire[19:0] replace_tag_old;
    reg counter;

    //hit
    wire way0_hit;
    wire way1_hit;
    wire cache_hit;
    wire hit_write;

    //loop counter for reset
    integer i;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Tag Compare (hit judgement)
    assign way0_hit = Way0_V[index] && (Way0_Tag[index] == tag);
    assign way1_hit = Way1_V[index] && (Way1_Tag[index] == tag);
    assign cache_hit = way0_hit || way1_hit;

    //Data Select (reading from cache to cpu (load) )
    always@(*)
        if(way0_hit)
            rdata = Way0_Data[index][offset[3:2]];
        else if(way1_hit)
            rdata = Way1_Data[index][offset[3:2]];
        else
            rdata = ret_data;

    //random counter
    always@(posedge clk)
        if(!resetn)
            counter <= 1'b0;
        else
            counter <= counter + 1;

    //replacement based on random counter
    assign replace_data = counter ? 
        {(((way_WB == 1) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 3)) ? data_bypass : Way1_Data[index][3]),
         (((way_WB == 1) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 2)) ? data_bypass : Way1_Data[index][2]),
         (((way_WB == 1) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 1)) ? data_bypass : Way1_Data[index][1]),
         (((way_WB == 1) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 0)) ? data_bypass : Way1_Data[index][0]) } : 
        {(((way_WB == 0) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 3)) ? data_bypass : Way0_Data[index][3]),
         (((way_WB == 0) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 2)) ? data_bypass : Way0_Data[index][2]),
         (((way_WB == 0) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 1)) ? data_bypass : Way0_Data[index][1]),
         (((way_WB == 0) && (C_STATE_WB == WRITE) && (index_WB == index) && (bank_WB == 0)) ? data_bypass : Way0_Data[index][0]) } ;
    assign replace_V = counter ? Way1_V[index] : Way0_V[index] ;
    assign replace_D = counter ? Way1_D[index] : Way0_D[index] ;
    assign replace_tag_old = counter ? Way1_Tag[index] : Way0_Tag[index] ;

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
        else if(C_STATE_M == LOOKUP) begin
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
            ret_number_MB <= 2'b00;
        else if(rd_rdy)
            ret_number_MB <= 2'b00;
        else if(ret_valid)
            ret_number_MB <= ret_number_MB + 1;

    //Write Buffer
    always@(posedge clk)
        if(!resetn) begin
            way_WB <= 1'b0;
            bank_WB <= 2'd0;
            index_WB <= 8'd0;
            wstrb_WB <= 4'd0;
            data_WB <= 32'd0;
        end
        else if(hit_write) begin
            way_WB <= way1_hit;
            bank_WB <= offset[3:2];
            index_WB <= index;
            wstrb_WB <= wstrb;
            data_WB <= wdata;
        end

    //hit write signal
    assign hit_write = (C_STATE_M == LOOKUP) && op && cache_hit && valid;

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

    //write bypass
    always@(*)
        if(way_WB) begin
                case(wstrb_WB)
                    4'b0001:    data_bypass = {Way1_Data[index_WB][bank_WB][31:8],data_WB[7:0]};
                    4'b0010:    data_bypass = {Way1_Data[index_WB][bank_WB][31:16],data_WB[7:0],Way1_Data[index_WB][bank_WB][7:0]};
                    4'b0100:    data_bypass = {Way1_Data[index_WB][bank_WB][31:24],data_WB[7:0],Way1_Data[index_WB][bank_WB][15:0]};
                    4'b1000:    data_bypass = {data_WB[7:0],Way1_Data[index_WB][bank_WB][23:0]};
                    4'b0011:    data_bypass = {Way1_Data[index_WB][bank_WB][31:16],data_WB[15:0]};
                    4'b1100:    data_bypass = {data_WB[15:0],Way1_Data[index_WB][bank_WB][15:0]};
                    default:    data_bypass = data_WB;
                 endcase
            end
            else begin
                case(wstrb_WB)
                    4'b0001:    data_bypass = {Way0_Data[index_WB][bank_WB][31:8],data_WB[7:0]};
                    4'b0010:    data_bypass = {Way0_Data[index_WB][bank_WB][31:16],data_WB[7:0],Way0_Data[index_WB][bank_WB][7:0]};
                    4'b0100:    data_bypass = {Way0_Data[index_WB][bank_WB][31:24],data_WB[7:0],Way0_Data[index_WB][bank_WB][15:0]};
                    4'b1000:    data_bypass = {data_WB[7:0],Way0_Data[index_WB][bank_WB][23:0]};
                    4'b0011:    data_bypass = {Way0_Data[index_WB][bank_WB][31:16],data_WB[15:0]};
                    4'b1100:    data_bypass = {data_WB[15:0],Way0_Data[index_WB][bank_WB][15:0]};
                    default:    data_bypass = data_WB;
                 endcase
            end

    //main FSM
    always@(posedge clk)
        if(!resetn)
            C_STATE_M <= LOOKUP;
        else
            C_STATE_M <= N_STATE_M;
    /*
        LOOKUP: Cache checks hit (if hit,begin read/write)
        MISS: Cache doesn't hit and wait for replace
        REPLACE: Cache replaces data (writing memory)
        REFILL: Cache refills data (reading memory)
    */
    always@(C_STATE_M, valid, cache_hit, wr_rdy, rd_rdy, ret_valid, ret_last, replace_D_MB)
        case(C_STATE_M)
            LOOKUP: if(!cache_hit && valid)
                        N_STATE_M = MISS;
                    else
                        N_STATE_M = LOOKUP;
            MISS:   if(!replace_V_MB || !replace_D_MB)
                        N_STATE_M = REFILL;
                    else if(!wr_rdy)
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
            default: N_STATE_M = LOOKUP;
        endcase

    //writebuffer FSM
    always@(posedge clk)
        if(!resetn)
            C_STATE_WB <= IDLE;
        else
            C_STATE_WB <= N_STATE_WB;
    /*
        IDLE: Nothing to be written
        WRITE: Writing cache
    */
    always@(C_STATE_WB, hit_write)
        case(C_STATE_WB)
            IDLE: if(hit_write)
                        N_STATE_WB = WRITE;
                    else
                        N_STATE_WB = IDLE;
            WRITE:  if(hit_write)
                        N_STATE_WB = WRITE;
                    else
                        N_STATE_WB = IDLE;
            default:N_STATE_WB = IDLE;
        endcase

    //replace from cache to mem (write memory)
    assign wr_addr = {replace_tag_old_MB, replace_index_MB, 4'b0000} ;
    assign wr_data = replace_data_MB;
    assign wr_type = 3'b100;
    assign wr_wstrb = 4'b1111;

    //refill from mem to cache (read memory)
    always@(posedge clk)
        if(!resetn)
            for(i=0;i<256;i=i+1) begin
                Way0_V[i] <= 1'b0;
                Way1_V[i] <= 1'b0;
                Way0_D[i] <= 1'b0;
                Way1_D[i] <= 1'b0;
            end
        else if(ret_valid)
            if(replace_way_MB) begin
                Way1_V[replace_index_MB] <= 1'b1;
                Way1_D[replace_index_MB] <= 1'b0;
                Way1_Tag[replace_index_MB] <= replace_tag_new_MB;
                Way1_Data[replace_index_MB][ret_number_MB] <= ret_data;
            end
            else begin
                Way0_V[replace_index_MB] <= 1'b1;
                Way0_D[replace_index_MB] <= 1'b0;
                Way0_Tag[replace_index_MB] <= replace_tag_new_MB;
                Way0_Data[replace_index_MB][ret_number_MB] <= ret_data;
            end
    assign rd_type = 3'b100;
    assign rd_addr = {replace_tag_new_MB, replace_index_MB, 4'b0000};

    //output signals
    assign addr_ok = ((C_STATE_M == LOOKUP) && cache_hit && valid) ;
    assign data_ok = ((C_STATE_M == LOOKUP) && cache_hit) ;
    assign rd_req = (N_STATE_M == REFILL) ;
    assign wr_req = (N_STATE_M == REPLACE) ;
            
endmodule