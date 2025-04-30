`include "define.v"

module cache_controller (
    input  wire                     sys_clk,
    input  wire                     sys_rst,
    
    /* From CPU */
    input  wire                     read_en_i,    
    input  wire                     write_en_i,
    input  wire  [`WIDTH-1:0]       address_i,
    input  wire  [`WIDTH-1:0]       write_data_i,        // data from CPU
    
    /* From interconnection */    
    input  wire                     transaction_en_i,
    input  wire  [3:0]              transaction_type_i, 
    input  wire  [`BLOCK_SIZE-1:0]  transaction_data_i,   
    input  wire  [`WIDTH-1:0]       transaction_address_i,
    
    input  wire                     exclusive,
    input  wire  [`CPU_WIDTH-1:0]   ack_num,
    input  wire  [`CPU_WIDTH-1:0]   requesters,          // data requesters, one hot code
    input  wire  [`CPU_WIDTH-1:0]   last_ack,
    input  wire                     put_ack,
    input  wire                     Inv_en_i,
    input  wire  [`WIDTH-1:0]       Inv_address_i,

    /* From cache */
    input  wire                     hit_miss,
    input  wire                     MESI_state,
    input  wire  [`WIDTH-1:0]       read_data_i,
    input  wire  [`BLOCK_SIZE-1:0]  writeBack_data_i,
    input  wire  [`WIDTH-1:0]       writeBack_address_i,
    input  wire                     writeBack_en_i,
    input  wire  [1:0]              put_type,            // PUT_S or PUT_E or PUT_M
    input  wire  [`BLOCK_SIZE-1:0]  Fwd_data_i,
    input  wire                     Fwd_ME,
    
    /* To CPU */
    output reg                      data_en,
    output reg   [`WIDTH-1:0]       read_data_o,
    
    /* To cache */
    output reg                      read_en_o,    
    output reg                      write_en_o,
    output reg   [`WIDTH-1:0]       address_o,
    output reg   [`WIDTH-1:0]       write_data_o,      // data to cache
    output reg   [`BLOCK_SIZE-1:0]  memoryBack_data_o,   // data from memory or other CPU caches
    output reg   [`WIDTH-1:0]       memoryBack_address_o,
    output reg                      memoryBack_en_o,
    output reg   [1:0]              change_state,   
    output reg                      Fwd_en,
    output reg                      Fwd_type,          // Get-S or Get-M
    output reg   [`WIDTH-1:0]       Fwd_address_to_cache,
    output reg                      Inv_en_o,
    output reg   [`WIDTH-1:0]       Inv_address_o,
    

    
    /* To interconnection */
    output wire                     transaction_en_o,
    output wire  [3:0]              transaction_type_o,
    output reg   [`BLOCK_SIZE-1:0]  transaction_data_o,
    output reg   [`WIDTH-1:0]       transaction_address_o,
    output wire  [`CPU_WIDTH-1:0]   unicast_address_o,

    output reg                      Inv_ack_o,
    
    output wire                     Fwd_stall,
    output wire                     Inv_stall    
);


parameter MISS = 1'b0;
parameter HIT  = 1'b1;

parameter MESI_state_IDLE = 1'b0;
parameter MESI_state_MISS = 1'b1;

parameter   FORWARD_STAGE1 = 2'd1;
parameter   FORWARD_STAGE2 = 2'd2;

parameter INVALID   = 2'd0;
parameter SHARED    = 2'd1;
parameter EXCLUSIVE = 2'd2;
parameter MODIFIED  = 2'd3;

parameter IDLE      = 4'd0;
parameter IS_D      = 4'd1;
parameter IM_AD     = 4'd2;
parameter IM_A      = 4'd3;
parameter SM_AD     = 4'd4;
parameter SM_A      = 4'd5;
parameter MI_A      = 4'd6;
parameter SI_A      = 4'd7;
parameter II_A      = 4'd8;


/* case 1: cache miss then forward request */
reg                      transfer_en_case1;
reg   [3:0]              transaction_case1; // GET_S or GET_M
reg   [`WIDTH-1:0]       Fwd_address_case1;

/* case 2: Get foward request from Directory */
reg                      transfer_en_case2;
reg   [3:0]              transaction_case2;
reg   [`WIDTH-1:0]       Fwd_address_case2;
reg   [`BLOCK_SIZE-1:0]  Fwd_data_case2;
reg   [`CPU_WIDTH-1:0]   unicast_address_case2;    // one hot code

/* case 3: Replacement request from cache */
reg                      transfer_en_case3;
reg   [3:0]              transaction_case3; // PUT_S or PUT_E or PUT_M
reg   [`BLOCK_SIZE-1:0]  writeBack_data_case3;
reg   [`WIDTH-1:0]       writeBack_address_case3;


/* Miss Status Holding Registers(MSHRs) */
reg   [3:0]        MSHR;

reg   [2:0]        case1_reg;
reg   [`WIDTH-1:0] address_reg;


/* stall */
assign  Fwd_stall = (MSHR == IM_AD) || (MSHR == IM_A) || (MSHR == SM_AD) || (MSHR == SM_A);
assign  Inv_stall = (MSHR == IS_D);



assign  transaction_en_o   = transfer_en_case1 | transfer_en_case2 | transfer_en_case3;
assign  transaction_type_o = transaction_case1 | transaction_case2 | transaction_case3;
assign  unicast_address_o  = unicast_address_case2;

always@ (*) begin
    case ({transfer_en_case3, transfer_en_case2, transfer_en_case1}) 
        3'b001: begin
            transaction_data_o    = {`BLOCK_SIZE{1'b0}};
            transaction_address_o = Fwd_address_case1;
        end
        3'b010: begin
            transaction_data_o    = Fwd_data_case2;
            transaction_address_o = Fwd_address_case2;            
        end
        3'b100: begin
            transaction_data_o    = writeBack_data_case3;
            transaction_address_o = writeBack_address_case3;             
        end
        default: begin
            transaction_data_o    = {`BLOCK_SIZE{1'b0}};
            transaction_address_o = {`WIDTH{1'b0}};
        end
    endcase
end


/*******************************************************************
    Handle requests from CPU and forward them to the cache
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        read_en_o    <= 1'b0;
        write_en_o   <= 1'b0;
        address_o    <= {`WIDTH{1'b0}};
        write_data_o <= {`WIDTH{1'b0}};
    end else begin
        read_en_o    <= read_en_i;
        write_en_o   <= write_en_i;
        address_o    <= address_i;
        write_data_o <= write_data_i;
    end
end



/*******************************************************************
    Case 1: Response the cache hit or miss
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        case1_reg <= 1'b0;
        address_reg <= {`WIDTH{1'b0}};
    end 
    else begin
        case1_reg <= {read_en_o, write_en_o, memoryBack_en_o};
        address_reg <= address_o;
    end
end


always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        data_en           <= 1'b0;
        read_data_o       <= {`WIDTH{1'b0}};
        transfer_en_case1 <= 1'b0;
        transaction_case1 <= `NONE;
        Fwd_address_case1 <= {`WIDTH{1'b0}};
    end
    else if (case1_reg & 3'b111) begin
        if (case1_reg[0]) begin  // memory back
            data_en     <= 1'b1;
            read_data_o <= read_data_i;
        end
        else begin
            case (hit_miss)
                HIT: begin
                    if (case1_reg[2]) begin
                        data_en      <= 1'b1;
                        read_data_o  <= read_data_i;
                    end
                    else if (MESI_state == MESI_state_MISS) begin  // write hit but in share state
                        transfer_en_case1 <= 1'b1;
                        transaction_case1 <= `FWD_GET_M;
                        Fwd_address_case1 <= address_reg;
                        // MSHR <= SM_AD;
                    end 
                    else begin  // write hit
                        data_en <= 1'b1;
                    end
                end
                
                MISS: begin
                    if (case1_reg[2]) begin // Read miss
                        transfer_en_case1 <= 1'b1;
                        transaction_case1 <= `FWD_GET_S;
                        Fwd_address_case1 <= address_reg;
                        // MSHR <= IS_D;
                    end
                    else begin             // Write miss in invalid state
                        transfer_en_case1 <= 1'b1;
                        transaction_case1 <= `FWD_GET_M;
                        Fwd_address_case1 <= address_reg;
                        // MSHR <= IM_AD;
                    end
                end
            endcase     
        end
        
    end
    else begin
        data_en           <= 1'b0;
        transfer_en_case1 <= 1'b0;
        transaction_case1 <= `NONE;
    end
end



/*******************************************************************
    Case 2: Response the Forward request and output Forward data 
*******************************************************************/
reg  [1:0]  Fwd_state;
reg         Fwd_stall_flag;

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        Fwd_en                <= 1'b0;
        Fwd_type              <= 1'b0;
        Fwd_address_to_cache  <= {`WIDTH{1'b0}};
        transfer_en_case2     <= 1'b0;
        transaction_case2     <= `NONE;
        Fwd_address_case2     <= {`WIDTH{1'b0}};
        Fwd_data_case2        <= {`BLOCK_SIZE{1'b0}};
        unicast_address_case2 <= 0;
        Fwd_stall_flag        <= 1'b0;
        
        Fwd_state             <= IDLE;
    end
    else begin
        case (Fwd_state)
            IDLE: begin
                transfer_en_case2     <= 1'b0;
                transaction_case2     <= `NONE;
                
                if (transaction_en_i && (transaction_type_i == `FWD_GET_S || transaction_type_i == `FWD_GET_M)) begin
                    if (Fwd_stall) begin
                        Fwd_stall_flag <= 1'b1;
                    end
                    else begin
                        Fwd_type             <= (transaction_type_i == `FWD_GET_M);
                        Fwd_en               <= 1'b1;
                        Fwd_address_to_cache <= transaction_address_i;
                        Fwd_state            <= FORWARD_STAGE1;
                    end
                end
                else if (Fwd_stall_flag && !Fwd_stall) begin
                    Fwd_type             <= (transaction_type_i == `FWD_GET_M);
                    Fwd_en               <= 1'b1;
                    Fwd_address_to_cache <= transaction_address_i;
                    Fwd_state            <= FORWARD_STAGE1;
                    Fwd_stall_flag       <= 1'b0;
                end
            end
            
            FORWARD_STAGE1: begin
                Fwd_en    <= 1'b0;
                Fwd_state <= FORWARD_STAGE2;
            end
            
            FORWARD_STAGE2: begin
                transfer_en_case2     <= 1'b1;
                transaction_case2     <= (Fwd_ME) ? `FORWARD_DATA_PUT_M : `FORWARD_DATA_PUT_E;
                Fwd_address_case2     <= transaction_address_i;
                Fwd_data_case2        <= Fwd_data_i;
                unicast_address_case2 <= requesters;
                Fwd_state             <= IDLE;
            end
            
            default: begin
                Fwd_state             <= IDLE;
            end
        endcase
    end
end


/*******************************************************************
    Case 3: Replacement requestion 
*******************************************************************/
always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        transfer_en_case3 <= 1'b0;
        transaction_case3 <= `NONE;
        writeBack_data_case3 <= {`BLOCK_SIZE{1'b0}};
        writeBack_address_case3 <= {`WIDTH{1'b0}};
    end
    else if (writeBack_en_i) begin
        case ({1'b0, put_type} + 3) 
            `FWD_PUT_S: begin
                transfer_en_case3 <= 1'b1;
                transaction_case3 <= `FWD_PUT_S;
                writeBack_data_case3 <= {`BLOCK_SIZE{1'b0}};
                writeBack_address_case3 <= writeBack_address_i;
            end
            `FWD_PUT_E: begin
                transfer_en_case3 <= 1'b1;
                transaction_case3 <= `FWD_PUT_E;
                writeBack_data_case3 <= {`BLOCK_SIZE{1'b0}};
                writeBack_address_case3 <= writeBack_address_i;
            end
            `FWD_PUT_M: begin
                transfer_en_case3 <= 1'b1;
                transaction_case3 <= `FWD_PUT_M;
                writeBack_data_case3 <= writeBack_data_i;
                writeBack_address_case3 <= writeBack_address_i;
            end
            default: begin
                transfer_en_case3 <= 1'b0;
                transaction_case3 <= `NONE;
                writeBack_data_case3 <= {`BLOCK_SIZE{1'b0}};
                writeBack_address_case3 <= {`WIDTH{1'b0}};
            end
        endcase
    end
end    

/*******************************************************************
    Forward data from memory or other CPU caches to the local cache
*******************************************************************/
always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        MSHR                 <= IDLE;
        change_state         <= 2'b0;
        memoryBack_en_o      <= 1'b0;
        memoryBack_data_o    <= {`BLOCK_SIZE{1'b0}};
        memoryBack_address_o <= {`WIDTH{1'b0}};
        Inv_ack_o            <= 1'b0;
        Inv_en_o             <= 1'b0;
        Inv_address_o        <= {`WIDTH{1'b0}};        
    end
    else begin
        case (MSHR)
            IS_D: begin
                if (transaction_en_i && transaction_type_i == `FORWARD_DATA) begin
                    change_state         <= (exclusive) ? EXCLUSIVE : SHARED;
                    memoryBack_en_o      <= 1'b1;
                    memoryBack_data_o    <= transaction_data_i;
                    memoryBack_address_o <= transaction_address_i;
                    MSHR                 <= IDLE;
                end
            end
            
            IM_AD: begin
                if (transaction_en_i && transaction_type_i == `FORWARD_DATA) begin                    
                    if (ack_num > 0) begin
                        MSHR <= IM_A;
                    end
                    else begin
                        change_state         <= MODIFIED;
                        memoryBack_en_o      <= 1'b1;
                        memoryBack_data_o    <= transaction_data_i;
                        memoryBack_address_o <= transaction_address_i;  
                        MSHR                 <= IDLE;
                    end
                end                
            end
            
            IM_A: begin
                if (last_ack) begin
                    change_state         <= MODIFIED;
                    memoryBack_en_o      <= 1'b1;
                    memoryBack_data_o    <= transaction_data_i;
                    memoryBack_address_o <= transaction_address_i;  
                    MSHR                 <= IDLE;
                end
            end
            
            SM_AD: begin
                if (transaction_en_i) begin   
                    if (transaction_type_i == `FORWARD_DATA)
                        if (ack_num > 0) begin
                            MSHR <= SM_A;
                        end
                        else begin
                            change_state         <= MODIFIED;
                            memoryBack_en_o      <= 1'b1;
                            memoryBack_data_o    <= transaction_data_i;
                            memoryBack_address_o <= transaction_address_i;
                            MSHR                 <= IDLE;
                        end
                    else if (Inv_en_i) begin
                            MSHR          <= IM_AD;
                            Inv_ack_o     <= 1'b1;
                            Inv_en_o      <= 1'b1;
                            Inv_address_o <= Inv_address_i;                        
                    end
                end
                                 
            end
            
            SM_A: begin
                if (last_ack) begin
                    change_state         <= MODIFIED;
                    memoryBack_en_o      <= 1'b1;
                    memoryBack_data_o    <= transaction_data_i;
                    memoryBack_address_o <= transaction_address_i;
                    MSHR                 <= IDLE;
                end
            end
            
            default: begin
                memoryBack_en_o <= 1'b0;
                Inv_en_o        <= 1'b0;
                if (Inv_en_i) begin
                    Inv_ack_o     <= 1'b1;
                    Inv_en_o      <= 1'b1;
                    Inv_address_o <= Inv_address_i;   
                end

                if (case1_reg[2:1] != 2'b0) begin
                    if (hit_miss) begin
                        if (MESI_state == MESI_state_MISS) begin
                            MSHR <= SM_AD;
                        end
                        else begin
                            MSHR <= IDLE; 
                        end
                    end
                    else begin
                        if (case1_reg[2]) begin
                            MSHR <= IS_D;
                        end
                        else begin
                            MSHR <= IM_AD;
                        end
                    end
                end
            end
        endcase
    end
end

endmodule
