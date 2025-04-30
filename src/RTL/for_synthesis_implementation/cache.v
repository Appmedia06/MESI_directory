/*
    Cache
        * size: 128 byte
        * block size: 64 bit = 8 byte
        * 4 way assocativity
*/

`include "define.v"

module cache (
    input  wire                     sys_clk,
    input  wire                     sys_rst,
    
    input  wire                     read_en,
    input  wire                     write_en,
    input  wire  [`WIDTH-1:0]       address,
    input  wire  [`WIDTH-1:0]       write_data,        // data from CPU
    input  wire  [`BLOCK_SIZE-1:0]  memoryBack_data,   // data from memory or other CPU caches
    input  wire                     memoryBack_en,
    input  wire  [`WIDTH-1:0]       memoryBack_address,
    input  wire  [1:0]              change_state,    
    input  wire                     Fwd_en,
    input  wire                     Fwd_type,          // Get-S or Get-M
    input  wire  [`WIDTH-1:0]       Fwd_address,
    input  wire                     Inv_en,
    input  wire  [`WIDTH-1:0]       Inv_address,    
    
    output reg                      hit_miss,
    output wire                     MESI_state,
    output reg   [`WIDTH-1:0]       read_data,
    output reg   [`BLOCK_SIZE-1:0]  writeBack_data,
    output reg   [`WIDTH-1:0]       writeBack_address,
    output reg                      writeBack_en,
    output reg   [1:0]              put_type,
    output reg   [`BLOCK_SIZE-1:0]  Fwd_data,
    output reg                      Fwd_ME             // Modified or Exclusive in forward requestion
);


/*******************************************************************
    Cache block (register)
*******************************************************************/

/* Way 0 */
reg                     valid_0   [0:`NUM_SETS-1];
reg                     dirty_0   [0:`NUM_SETS-1];
reg                     share_0   [0:`NUM_SETS-1];
reg   [1:0]             LRU_0     [0:`NUM_SETS-1];
reg   [`TAG_WIDTH-1:0]  tag_0     [0:`NUM_SETS-1];
reg   [`BLOCK_SIZE-1:0] cache_0   [0:`NUM_SETS-1];

/* Way 1 */
reg                     valid_1   [0:`NUM_SETS-1];
reg                     dirty_1   [0:`NUM_SETS-1];
reg                     share_1   [0:`NUM_SETS-1];
reg   [1:0]             LRU_1     [0:`NUM_SETS-1];
reg   [`TAG_WIDTH-1:0]  tag_1     [0:`NUM_SETS-1];
reg   [`BLOCK_SIZE-1:0] cache_1   [0:`NUM_SETS-1];

/* Way 2 */
reg                     valid_2   [0:`NUM_SETS-1];
reg                     dirty_2   [0:`NUM_SETS-1];
reg                     share_2   [0:`NUM_SETS-1];
reg   [1:0]             LRU_2     [0:`NUM_SETS-1];
reg   [`TAG_WIDTH-1:0]  tag_2     [0:`NUM_SETS-1];
reg   [`BLOCK_SIZE-1:0] cache_2   [0:`NUM_SETS-1];

/* Way 3 */
reg                     valid_3   [0:`NUM_SETS-1];
reg                     dirty_3   [0:`NUM_SETS-1];
reg                     share_3   [0:`NUM_SETS-1];
reg   [1:0]             LRU_3     [0:`NUM_SETS-1];
reg   [`TAG_WIDTH-1:0]  tag_3     [0:`NUM_SETS-1];
reg   [`BLOCK_SIZE-1:0] cache_3   [0:`NUM_SETS-1];


/*******************************************************************
    Initialization
*******************************************************************/

integer i;


/*******************************************************************
    Local parameter
*******************************************************************/

localparam IDLE = 1'b0;
localparam MISS = 1'b1;

parameter INVALID   = 2'd0;
parameter SHARED    = 2'd1;
parameter EXCLUSIVE = 2'd2;
parameter MODIFIED  = 2'd3;

parameter GET_S = 1'b0;
parameter GET_M = 1'b1;

parameter PUT_E     = 2'd0;
parameter PUT_S     = 2'd1;
parameter PUT_M     = 2'd2;

parameter READ  = 1'b0;
parameter WRITE = 1'b1;

/*******************************************************************
    Register
*******************************************************************/

reg                  read_write_reg; // store read or write
reg   [`WIDTH-1:0]   write_data_reg; // store write_data

reg                  state;


/*******************************************************************
    Store data register
*******************************************************************/

always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        read_write_reg <= 1'b0;
        write_data_reg <= 32'd0;
    end
    else if (read_en || write_en) begin
        read_write_reg <= write_en;
        write_data_reg <= write_data;
    end
end

/*******************************************************************
    Cache response from CPU
*******************************************************************/
parameter READ_EN  = 4'b0001;
parameter WRITE_EN = 4'b0010;
parameter FWD_EN   = 4'b0100;
parameter INV_EN   = 4'b1000;

wire   [3:0]  enable;
wire   [1:0]  LRU_block;
assign enable = {Inv_en, Fwd_en, write_en, read_en};


assign LRU_block = (LRU_0[memoryBack_address[`INDEX]] == 2'd3) ? 2'b0: (LRU_1[memoryBack_address[`INDEX]] == 2'd3) ? 2'd1 : (LRU_2[memoryBack_address[`INDEX]] == 2'd3) ? 2'd2 : 2'd3;

assign MESI_state = state;

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        state             <= IDLE;
        hit_miss          <= 1'b0;
        read_data         <= {`WIDTH{1'b0}};
        Fwd_data          <= {`BLOCK_SIZE{1'b0}};
        Fwd_ME            <= 1'b0;
        writeBack_en      <= 1'b0;
        writeBack_address <= {`WIDTH{1'b0}};
        writeBack_data    <= {`BLOCK_SIZE{1'b0}};
        put_type          <= 2'b0;

        for (i = 0; i < `NUM_SETS; i = i + 1) begin
            valid_0[i] = 0;
            valid_1[i] = 0;
            valid_2[i] = 0;
            valid_3[i] = 0;
            dirty_0[i] = 0;
            dirty_1[i] = 0;
            dirty_2[i] = 0;
            dirty_3[i] = 0;
            share_0[i] = 0;
            share_1[i] = 0;
            share_2[i] = 0;
            share_3[i] = 0;
            LRU_0[i]   = 0;
            LRU_1[i]   = 0;
            LRU_2[i]   = 0;
            LRU_3[i]   = 0;
            cache_0[i] = 0;
            cache_1[i] = 0;
            cache_2[i] = 0;
            cache_3[i] = 0;
        end        
    end
    else begin
        case (state)
            IDLE: begin
                hit_miss <= (
                                (valid_0[address[`INDEX]] && (tag_0[address[`INDEX]] == address[`TAG])) ||
                                (valid_1[address[`INDEX]] && (tag_1[address[`INDEX]] == address[`TAG])) ||
                                (valid_2[address[`INDEX]] && (tag_2[address[`INDEX]] == address[`TAG])) ||
                                (valid_3[address[`INDEX]] && (tag_3[address[`INDEX]] == address[`TAG]))
                            );
                
                case (enable)
                    
                    INV_EN: begin
                        if (tag_0[Inv_address[`INDEX]] == Inv_address[`TAG]) begin
                            valid_0[Inv_address[`INDEX]] = 1'b0;
                            share_0[Inv_address[`INDEX]] = 1'b0;
                            dirty_0[Inv_address[`INDEX]] = 1'b0;            
                        end
                        else if (tag_1[Inv_address[`INDEX]] == Inv_address[`TAG]) begin
                            valid_1[Inv_address[`INDEX]] = 1'b0;
                            share_1[Inv_address[`INDEX]] = 1'b0;
                            dirty_1[Inv_address[`INDEX]] = 1'b0;            
                        end
                        else if (tag_2[Inv_address[`INDEX]] == Inv_address[`TAG]) begin
                            valid_2[Inv_address[`INDEX]] = 1'b0;
                            share_2[Inv_address[`INDEX]] = 1'b0;
                            dirty_2[Inv_address[`INDEX]] = 1'b0;            
                        end        
                        else if (tag_3[Inv_address[`INDEX]] == Inv_address[`TAG]) begin
                            valid_3[Inv_address[`INDEX]] = 1'b0;
                            share_3[Inv_address[`INDEX]] = 1'b0;
                            dirty_3[Inv_address[`INDEX]] = 1'b0;            
                        end     
                    end
                    
                    FWD_EN: begin
                        /* Way 0 */
                        if (tag_0[Fwd_address[`INDEX]] == Fwd_address[`TAG]) begin
                            case (Fwd_type) 
                                GET_S: begin // transfer to S state
                                    Fwd_data                     <= cache_0[Fwd_address[`INDEX]];
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_0[Fwd_address[`INDEX]] <= 1'b1;
                                    valid_0[Fwd_address[`INDEX]] <= 1'b1;
                                    dirty_0[Fwd_address[`INDEX]] <= 1'b0;
                                end
                                
                                GET_M: begin // transfer to I state
                                    Fwd_data                     <= cache_0[Fwd_address[`INDEX]];   
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;                                
                                    share_0[Fwd_address[`INDEX]] <= 1'b0;
                                    valid_0[Fwd_address[`INDEX]] <= 1'b0;
                                    dirty_0[Fwd_address[`INDEX]] <= 1'b0;
                                end
                            endcase
                        end
                        /* Way 1 */
                        else if (tag_1[Fwd_address[`INDEX]] == Fwd_address[`TAG]) begin
                            case (Fwd_type) 
                                GET_S: begin // transfer to S state
                                    Fwd_data                     <= cache_1[Fwd_address[`INDEX]];      
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;                                
                                    share_1[Fwd_address[`INDEX]] <= 1'b1;
                                    valid_1[Fwd_address[`INDEX]] <= 1'b1;
                                    dirty_1[Fwd_address[`INDEX]] <= 1'b0;
                                end
                                
                                GET_M: begin // transfer to I state
                                    Fwd_data                     <= cache_1[Fwd_address[`INDEX]];  
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_1[Fwd_address[`INDEX]] <= 1'b0;
                                    valid_1[Fwd_address[`INDEX]] <= 1'b0;
                                    dirty_1[Fwd_address[`INDEX]] <= 1'b0;
                                end
                            endcase
                        end
                        /* Way 2 */
                        else if (tag_2[Fwd_address[`INDEX]] == Fwd_address[`TAG]) begin
                            case (Fwd_type) 
                                GET_S: begin // transfer to S state
                                    Fwd_data                     <= cache_2[Fwd_address[`INDEX]];  
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_2[Fwd_address[`INDEX]] <= 1'b1;
                                    valid_2[Fwd_address[`INDEX]] <= 1'b1;
                                    dirty_2[Fwd_address[`INDEX]] <= 1'b0;
                                end
                                
                                GET_M: begin // transfer to I state
                                    Fwd_data                     <= cache_2[Fwd_address[`INDEX]];   
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_2[Fwd_address[`INDEX]] <= 1'b0;
                                    valid_2[Fwd_address[`INDEX]] <= 1'b0;
                                    dirty_2[Fwd_address[`INDEX]] <= 1'b0;
                                end
                            endcase
                        end
                        /* Way 3 */
                        else if (tag_3[Fwd_address[`INDEX]] == Fwd_address[`TAG]) begin
                            case (Fwd_type) 
                                GET_S: begin // transfer to S state
                                    Fwd_data                     <= cache_3[Fwd_address[`INDEX]];  
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_3[Fwd_address[`INDEX]] <= 1'b1;
                                    valid_3[Fwd_address[`INDEX]] <= 1'b1;
                                    dirty_3[Fwd_address[`INDEX]] <= 1'b0;
                                end
                                
                                GET_M: begin // transfer to I state
                                    Fwd_data                     <= cache_3[Fwd_address[`INDEX]]; 
                                    Fwd_ME                       <= (dirty_0[Fwd_address[`INDEX]]) ? 1'b1 : 1'b0;
                                    share_3[Fwd_address[`INDEX]] <= 1'b0;
                                    valid_3[Fwd_address[`INDEX]] <= 1'b0;
                                    dirty_3[Fwd_address[`INDEX]] <= 1'b0;
                                end
                            endcase
                        end
                    end
                    
                    WRITE_EN, READ_EN: begin
                        /* CPU read or write requestion */
                        /* Way 0 */
                        if (valid_0[address[`INDEX]] && (tag_0[address[`INDEX]] == address[`TAG])) begin
                            /* Read hit */
                            if (read_en) begin
                                read_data <= (address[`OFFSET] <= `OFFSET_BORDER) ? cache_0[address[`INDEX]][`WIDTH-1:0] : cache_0[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH];
                            end
                            /* Write hit */
                            else if (write_en) begin
                                if (share_0[address[`INDEX]]) begin
                                    state <= MISS;
                                end
                                else begin
                                    read_data <= {`WIDTH{1'b0}};
                                    /* Transfer to M state */
                                    dirty_0[address[`INDEX]] <= 1'b1;
                                    share_0[address[`INDEX]] <= 1'b0;
                                    if (address[`OFFSET] <= `OFFSET_BORDER) begin
                                        cache_0[address[`INDEX]][`WIDTH-1:0] <= write_data;
                                    end
                                    else begin
                                        cache_0[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH] <= write_data;
                                    end                        
                                end
                            end
                            /* LRU policy */
                            if (LRU_1[address[`INDEX]] <= LRU_0[address[`INDEX]]) begin
                                LRU_1[address[`INDEX]] <= LRU_1[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_2[address[`INDEX]] <= LRU_0[address[`INDEX]]) begin
                                LRU_2[address[`INDEX]] <= LRU_2[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_3[address[`INDEX]] <= LRU_0[address[`INDEX]]) begin
                                LRU_3[address[`INDEX]] <= LRU_3[address[`INDEX]] + 1'b1;
                            end
                            LRU_0[address[`INDEX]] <= 2'b0;
                        end
                        /* Way 1 */
                        else if (valid_1[address[`INDEX]] && (tag_1[address[`INDEX]] == address[`TAG])) begin
                            /* Read hit */
                            if (read_en) begin
                                read_data <= (address[`OFFSET] <= `OFFSET_BORDER) ? cache_1[address[`INDEX]][`WIDTH-1:0] : cache_1[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH];
                            end
                            /* Write hit */
                            else if (write_en) begin
                                if (share_1[address[`INDEX]]) begin
                                    state <= MISS;
                                end
                                else begin
                                    read_data <= {`WIDTH{1'b0}};
                                    /* Transfer to M state */
                                    dirty_1[address[`INDEX]] <= 1'b1;
                                    share_1[address[`INDEX]] <= 1'b0;
                                    if (address[`OFFSET] <= `OFFSET_BORDER) begin
                                        cache_1[address[`INDEX]][`WIDTH-1:0] <= write_data;
                                    end
                                    else begin
                                        cache_1[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH] <= write_data;
                                    end    
                                end

                            end
                            /* LRU policy */
                            if (LRU_2[address[`INDEX]] <= LRU_1[address[`INDEX]]) begin
                                LRU_2[address[`INDEX]] <= LRU_2[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_3[address[`INDEX]] <= LRU_1[address[`INDEX]]) begin
                                LRU_3[address[`INDEX]] <= LRU_3[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_0[address[`INDEX]] <= LRU_1[address[`INDEX]]) begin
                                LRU_0[address[`INDEX]] <= LRU_0[address[`INDEX]] + 1'b1;
                            end
                            LRU_1[address[`INDEX]] <= 1'b0;
                        end
                        /* Way 2 */
                        else if (valid_2[address[`INDEX]] && (tag_2[address[`INDEX]] == address[`TAG])) begin
                            /* Read hit */
                            if (read_en) begin
                                read_data <= (address[`OFFSET] <= `OFFSET_BORDER) ? cache_2[address[`INDEX]][`WIDTH-1:0] : cache_2[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH];
                            end
                            /* Write hit */
                            else if (write_en) begin
                                if (share_2[address[`INDEX]]) begin
                                    state <= MISS;
                                end
                                else begin
                                    read_data <= {`WIDTH{1'b0}};
                                    /* Transfer to M state */
                                    dirty_2[address[`INDEX]] <= 1'b1;
                                    share_2[address[`INDEX]] <= 1'b0;
                                    if (address[`OFFSET] <= `OFFSET_BORDER) begin
                                        cache_2[address[`INDEX]][`WIDTH-1:0] <= write_data;
                                    end
                                    else begin
                                        cache_2[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH] <= write_data;
                                    end
                                end
                            end
                            /* LRU policy */
                            if (LRU_3[address[`INDEX]] <= LRU_2[address[`INDEX]]) begin
                                LRU_3[address[`INDEX]] <= LRU_3[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_0[address[`INDEX]] <= LRU_2[address[`INDEX]]) begin
                                LRU_0[address[`INDEX]] <= LRU_0[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_1[address[`INDEX]] <= LRU_2[address[`INDEX]]) begin
                                LRU_1[address[`INDEX]] <= LRU_1[address[`INDEX]] + 1'b1;
                            end
                            LRU_2[address[`INDEX]] <= 1'b0;
                        end
                        /* Way 3 */
                        else if (valid_3[address[`INDEX]] && (tag_3[address[`INDEX]] == address[`TAG])) begin
                            /* Read hit */
                            if (read_en) begin
                                read_data <= (address[`OFFSET] <= `OFFSET_BORDER) ? cache_3[address[`INDEX]][`WIDTH-1:0] : cache_3[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH];
                            end
                            /* Write hit */
                            else if (write_en) begin
                                if (share_3[address[`INDEX]]) begin
                                    state <= MISS;
                                end
                                else begin
                                    read_data <= {`WIDTH{1'b0}};
                                    /* Transfer to M state */
                                    dirty_3[address[`INDEX]] <= 1'b1;
                                    share_3[address[`INDEX]] <= 1'b0;
                                    if (address[`OFFSET] <= `OFFSET_BORDER) begin
                                        cache_3[address[`INDEX]][`WIDTH-1:0] <= write_data;
                                    end
                                    else begin
                                        cache_3[address[`INDEX]][`BLOCK_SIZE-1:`WIDTH] <= write_data;
                                    end
                                end
                            end
                            /* LRU policy */
                            if (LRU_0[address[`INDEX]] <= LRU_3[address[`INDEX]]) begin
                                LRU_0[address[`INDEX]] <= LRU_0[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_1[address[`INDEX]] <= LRU_3[address[`INDEX]]) begin
                                LRU_1[address[`INDEX]] <= LRU_1[address[`INDEX]] + 1'b1;
                            end
                            if (LRU_2[address[`INDEX]] <= LRU_3[address[`INDEX]]) begin
                                LRU_2[address[`INDEX]] <= LRU_2[address[`INDEX]] + 1'b1;
                            end
                            LRU_3[address[`INDEX]] <= 1'b0;
                        end
                        else begin
                            state <= MISS;
                        end
                end
                
                default: begin
                    state <= IDLE;
                end
                endcase
            end

            MISS: begin
                /*  Waiting until memory write back */
                if (memoryBack_en) begin
                    /* if any way is Invalid, no evict block will be swapped */
                    state <= IDLE;
                    /* Way 0 */
                    if (~valid_0[memoryBack_address[`INDEX]] || (tag_0[memoryBack_address[`INDEX]] == memoryBack_address[`TAG])) begin
                        
                        if (read_write_reg == READ) begin // Read miss
                            cache_0[memoryBack_address[`INDEX]] <= memoryBack_data;
                            tag_0[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_0[memoryBack_address[`INDEX]] <= 1'b1;
                            share_0[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                            dirty_0[memoryBack_address[`INDEX]] <= 1'b0;
                            read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                        end
                        else begin                        // Write miss transfer to M state
                            cache_0[memoryBack_address[`INDEX]] <= write_data_reg;
                            tag_0[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_0[memoryBack_address[`INDEX]] <= 1'b1;
                            share_0[memoryBack_address[`INDEX]] <= 1'b0;
                            dirty_0[memoryBack_address[`INDEX]] <= 1'b1;
                        end
                        
                        /* LRU policy */
                        if (LRU_1[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                            LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_2[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                            LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_3[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                            LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        LRU_0[memoryBack_address[`INDEX]] <= 2'b0;                        
                    end

                    /* Way 1 */
                    else if (~valid_1[memoryBack_address[`INDEX]] || (tag_1[memoryBack_address[`INDEX]] == memoryBack_address[`TAG])) begin 
                        if (read_write_reg == READ) begin // Read miss
                            cache_1[memoryBack_address[`INDEX]] <= memoryBack_data;
                            tag_1[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_1[memoryBack_address[`INDEX]] <= 1'b1;
                            share_1[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                            dirty_1[memoryBack_address[`INDEX]] <= 1'b0;
                            read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                        end
                        else begin                        // Write miss transfer to M state
                            cache_1[memoryBack_address[`INDEX]] <= write_data_reg;
                            tag_1[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_1[memoryBack_address[`INDEX]] <= 1'b1;
                            share_1[memoryBack_address[`INDEX]] <= 1'b0;
                            dirty_1[memoryBack_address[`INDEX]] <= 1'b1;
                        end
                        /* LRU policy */
                        if (LRU_2[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                            LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_3[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                            LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_0[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                            LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        LRU_1[memoryBack_address[`INDEX]] <= 1'b0;                        
                    end
                    
                    /* Way 2 */
                    else if (~valid_2[memoryBack_address[`INDEX]] || (tag_2[memoryBack_address[`INDEX]] == memoryBack_address[`TAG])) begin 
                        if (read_write_reg == READ) begin // Read miss
                            cache_2[memoryBack_address[`INDEX]] <= memoryBack_data;
                            tag_2[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_2[memoryBack_address[`INDEX]] <= 1'b1;
                            share_2[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                            dirty_2[memoryBack_address[`INDEX]] <= 1'b0;
                            read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                        end
                        else begin                        // Write miss transfer to M state
                            cache_2[memoryBack_address[`INDEX]] <= write_data_reg;
                            tag_2[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_2[memoryBack_address[`INDEX]] <= 1'b1;
                            share_2[memoryBack_address[`INDEX]] <= 1'b0;
                            dirty_2[memoryBack_address[`INDEX]] <= 1'b1;
                        end
                        /* LRU policy */
                        if (LRU_3[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                            LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_0[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                            LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_1[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                            LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        LRU_2[memoryBack_address[`INDEX]] <= 1'b0;                        
                    end

                    /* Way 3 */
                    else if (~valid_3[memoryBack_address[`INDEX]] || (tag_3[memoryBack_address[`INDEX]] == memoryBack_address[`TAG])) begin 
                        if (read_write_reg == READ) begin // Read miss
                            cache_3[memoryBack_address[`INDEX]] <= memoryBack_data;
                            tag_3[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_3[memoryBack_address[`INDEX]] <= 1'b1;
                            share_3[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                            dirty_3[memoryBack_address[`INDEX]] <= 1'b0;
                            read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                        end
                        else begin                        // Write miss transfer to M state
                            cache_3[memoryBack_address[`INDEX]] <= write_data_reg;
                            tag_3[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                            valid_3[memoryBack_address[`INDEX]] <= 1'b1;
                            share_3[memoryBack_address[`INDEX]] <= 1'b0;
                            dirty_3[memoryBack_address[`INDEX]] <= 1'b1;
                        end
                        /* LRU policy */
                        if (LRU_0[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                            LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_1[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                            LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        if (LRU_2[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                            LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                        end
                        LRU_3[memoryBack_address[`INDEX]] <= 1'b0;                        
                    end                    
                    
                    /* Choose an evict block using LRU policy */
                    else begin
                        
                        case (LRU_block)
                            2'd0: begin
                                /* Replacement */
                                writeBack_en      <= 1'b1;
                                writeBack_data    <= cache_0[memoryBack_address[`INDEX]];                        
                                writeBack_address <= {tag_0[memoryBack_address[`INDEX]], memoryBack_address[`INDEX]};
                                put_type          <= {dirty_0[memoryBack_address[`INDEX]], share_0[memoryBack_address[`INDEX]]};

                                if (read_write_reg == READ) begin // Read miss
                                        cache_0[memoryBack_address[`INDEX]] <= memoryBack_data;
                                        tag_0[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                        valid_0[memoryBack_address[`INDEX]] <= 1'b1;
                                        share_0[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                                        dirty_0[memoryBack_address[`INDEX]] <= 1'b0;     
                                        read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                                end
                                else begin                        // Write miss transfer to M state
                                    cache_0[memoryBack_address[`INDEX]] <= write_data_reg;
                                    tag_0[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_0[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_0[memoryBack_address[`INDEX]] <= 1'b0;
                                    dirty_0[memoryBack_address[`INDEX]] <= 1'b1;
                                    read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                                end
                                
                                /* LRU policy */
                                if (LRU_1[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                                    LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_2[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                                    LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_3[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]]) begin
                                    LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                LRU_0[memoryBack_address[`INDEX]] <= 2'b0; 
                            end
                            
                            2'd1: begin
                                /* Replacement */
                                writeBack_en      <= 1'b1;
                                writeBack_data    <= cache_1[memoryBack_address[`INDEX]];                        
                                writeBack_address <= {tag_1[memoryBack_address[`INDEX]], memoryBack_address[`INDEX]};
                                put_type          <= {dirty_1[memoryBack_address[`INDEX]], share_1[memoryBack_address[`INDEX]]};
                                
                                if (read_write_reg == READ) begin // Read miss
                                    cache_1[memoryBack_address[`INDEX]] <= memoryBack_data;
                                    tag_1[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_1[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_1[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                                    dirty_1[memoryBack_address[`INDEX]] <= 1'b0;
                                    read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                                end
                                else begin                        // Write miss transfer to M state
                                    cache_1[memoryBack_address[`INDEX]] <= write_data_reg;
                                    tag_1[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_1[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_1[memoryBack_address[`INDEX]] <= 1'b0;
                                    dirty_1[memoryBack_address[`INDEX]] <= 1'b1;
                                end
                                /* LRU policy */
                                if (LRU_2[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                                    LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_3[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                                    LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_0[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]]) begin
                                    LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                LRU_1[memoryBack_address[`INDEX]] <= 1'b0;  
                            end
                            
                            2'd2: begin
                                /* Replacement */
                                writeBack_en      <= 1'b1;
                                writeBack_data    <= cache_2[memoryBack_address[`INDEX]];                        
                                writeBack_address <= {tag_2[memoryBack_address[`INDEX]], memoryBack_address[`INDEX]};
                                put_type          <= {dirty_2[memoryBack_address[`INDEX]], share_2[memoryBack_address[`INDEX]]};
                                
                                if (read_write_reg == READ) begin // Read miss
                                    cache_2[memoryBack_address[`INDEX]] <= memoryBack_data;
                                    tag_2[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_2[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_2[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                                    dirty_2[memoryBack_address[`INDEX]] <= 1'b0;
                                    read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                                end
                                else begin                        // Write miss transfer to M state
                                    cache_2[memoryBack_address[`INDEX]] <= write_data_reg;
                                    tag_2[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_2[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_2[memoryBack_address[`INDEX]] <= 1'b0;
                                    dirty_2[memoryBack_address[`INDEX]] <= 1'b1;
                                end
                                /* LRU policy */
                                if (LRU_3[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                                    LRU_3[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_0[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                                    LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_1[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]]) begin
                                    LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                LRU_2[memoryBack_address[`INDEX]] <= 1'b0;  
                            end
                            
                            3'd3: begin
                                /* Replacement */
                                writeBack_en      <= 1'b1;
                                writeBack_data    <= cache_3[memoryBack_address[`INDEX]];                        
                                writeBack_address <= {tag_3[memoryBack_address[`INDEX]], memoryBack_address[`INDEX]};
                                put_type          <= {dirty_3[memoryBack_address[`INDEX]], share_3[memoryBack_address[`INDEX]]};
                                
                                if (read_write_reg == READ) begin // Read miss
                                    cache_3[memoryBack_address[`INDEX]] <= memoryBack_data;
                                    tag_3[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_3[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_3[memoryBack_address[`INDEX]] <= (change_state == SHARED) ? 1'b1 : 1'b0; // Share or Exclusive
                                    dirty_3[memoryBack_address[`INDEX]] <= 1'b0;
                                    read_data <= (memoryBack_address[`OFFSET] <= `OFFSET_BORDER) ? memoryBack_data[`WIDTH-1:0] : memoryBack_data[`BLOCK_SIZE-1:`WIDTH];
                                end
                                else begin                        // Write miss transfer to M state
                                    cache_3[memoryBack_address[`INDEX]] <= write_data_reg;
                                    tag_3[memoryBack_address[`INDEX]]   <= memoryBack_address[`TAG];
                                    valid_3[memoryBack_address[`INDEX]] <= 1'b1;
                                    share_3[memoryBack_address[`INDEX]] <= 1'b0;
                                    dirty_3[memoryBack_address[`INDEX]] <= 1'b1;
                                end
                                /* LRU policy */
                                if (LRU_0[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                                    LRU_0[memoryBack_address[`INDEX]] <= LRU_0[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_1[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                                    LRU_1[memoryBack_address[`INDEX]] <= LRU_1[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                if (LRU_2[memoryBack_address[`INDEX]] <= LRU_3[memoryBack_address[`INDEX]]) begin
                                    LRU_2[memoryBack_address[`INDEX]] <= LRU_2[memoryBack_address[`INDEX]] + 1'b1;
                                end
                                LRU_3[memoryBack_address[`INDEX]] <= 1'b0;
                            end
                        endcase
                    end
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end


endmodule
