`include "define.v"

module directory (
    input  wire                     sys_clk,
    input  wire                     sys_rst,
    
    /* From Interconnection */
    input  wire                     transaction_en_i,
    input  wire  [3:0]              transaction_type_i,
    input  wire  [`BLOCK_SIZE-1:0]  transaction_data_i,
    input  wire  [`WIDTH-1:0]       transaction_address_i,
    input  wire  [`CPU_WIDTH-1:0]   requester_i,            // who send requestion
    
    /* To Interconnection */ 
    output reg                      transaction_en_o,
    output reg   [3:0]              transaction_type_o, 
    output reg   [`BLOCK_SIZE-1:0]  transaction_data_o,   
    output reg   [`WIDTH-1:0]       transaction_address_o,
    output reg   [`CPU_WIDTH-1:0]   unicast_address,
    
    output reg                      exclusive,
    output reg   [`CPU_WIDTH-1:0]   ack_num,
    output reg   [`CPU_WIDTH-1:0]   requesters,         
    output reg                      put_ack,
    output reg                      Inv_en_o,
    output reg   [`CPU_WIDTH:0]     Inv_unicast_address,    // one-hot code
    output reg   [`WIDTH-1:0]       Inv_address,
    
    /* Memory */
    output reg                      memRead_en,
    output reg                      memWrite_en,
    output reg   [`WIDTH-1:0]       mem_address,
    input  wire  [`BLOCK_SIZE-1:0]  memRead_data,
    output reg   [`BLOCK_SIZE-1:0]  memWrite_data
);    


/*******************************************************************
    Parameter
*******************************************************************/
parameter I = 3'b000;
parameter E = 3'b100;
parameter S = 3'b101;
parameter M = 3'b110;

parameter IDLE = 2'd0;
parameter MEMORY = 2'd1;
parameter S_D = 2'd2;

reg   [1:0]  FSM_state;

reg   [2:0]  MESI_state   [0:`NUM_BLOCK-1];
reg          owner        [0:`NUM_BLOCK-1];
reg   [1:0]  sharer       [0:`NUM_BLOCK-1];
reg          non_owner_put;

wire  [`BLOCK_WIDTH:0] block_idx;
wire  [2:0]            _MESI_state;
wire                   _owner;
wire  [1:0]            _sharer;
wire  [1:0]            remove_sharer;



/*******************************************************************
    Initialization
*******************************************************************/

integer i;


/*******************************************************************
    Combination logic
*******************************************************************/
assign block_idx = transaction_address_i[`MEM_BLOCK_WIDTH];
assign _MESI_state = MESI_state[block_idx];
assign _owner = owner[block_idx];
assign _sharer = sharer[block_idx];

assign remove_sharer = ~(1'b1 << requester_i) & _sharer;


/*******************************************************************
    Sequential logic
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        FSM_state             <= IDLE;
        memRead_en            <= 1'b0;
        memWrite_en           <= 1'b0;
        mem_address           <= {`WIDTH{1'b0}};  
        memWrite_data         <= {`BLOCK_SIZE{1'b0}};
        transaction_en_o      <= 1'b0;
        transaction_type_o    <= 3'b0;
        transaction_address_o <= {`WIDTH{1'b0}}; 
        transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
        unicast_address       <= 1'b0;    
        requesters            <= 0;
        put_ack               <= 1'b0;
        exclusive             <= 1'b0;
        ack_num               <= 0;
        Inv_en_o              <= 1'b0;
        Inv_unicast_address   <= 0;
        Inv_address           <= {`WIDTH{1'b0}}; 
        non_owner_put         <= 1'b0; 
        for (i = 0; i < `NUM_BLOCK; i = i + 1) begin
            MESI_state[i]     = 0;
            owner[i]          = 0;
            sharer[i]         = 0;
        end        
    end
    else begin
        memRead_en <= 1'b0;
        memWrite_en <= 1'b0;
        mem_address <= {`WIDTH{1'b0}};  
        memWrite_data <= {`BLOCK_SIZE{1'b0}};
        transaction_en_o <= 1'b0;
        transaction_type_o <= 3'b0;
        transaction_address_o <= {`WIDTH{1'b0}}; 
        transaction_data_o <= {`BLOCK_SIZE{1'b0}};
        requesters <= 0;
        put_ack <= 1'b0;        
        unicast_address <= 1'b0; 
        exclusive <= 1'b0;
        ack_num <= 0;
        Inv_en_o <= 1'b0;
        Inv_unicast_address <= 0;
        Inv_address         <= {`WIDTH{1'b0}};   
        
        if (FSM_state == IDLE && transaction_en_i) begin
            case (transaction_type_i)
                `FWD_GET_S: begin
                    if (_MESI_state == I || _MESI_state == S) begin  // Invalid or Shared
                        FSM_state   <= MEMORY;
                        memRead_en  <= 1'b1;
                        mem_address <= transaction_address_i;
                    end
                    else begin                                       // Exclusive or Modified
                        transaction_en_o      <= 1'b1;
                        transaction_type_o    <= `FWD_GET_S;
                        transaction_address_o <= transaction_address_i;
                        transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
                        unicast_address       <= _owner;            
                        sharer[block_idx]     <= (1'b1 << _owner)| (1'b1 << requester_i) | _sharer;
                        requesters            <= requester_i;
                        FSM_state             <= S_D;
                    end
                end
                 
                `FWD_GET_M: begin
                    if (_MESI_state == I || _MESI_state == S) begin  // Invalid or Shared
                        FSM_state   <= MEMORY;
                        memRead_en  <= 1'b1;
                        mem_address <= transaction_address_i;
                    end
                    else begin                                       // Exclusive or Modified
                        transaction_en_o      <= 1'b1;
                        transaction_type_o    <= `FWD_GET_M;
                        transaction_address_o <= transaction_address_i;
                        transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
                        unicast_address       <= _owner;
                        requesters            <= requester_i;
                        owner[block_idx]      <= requester_i;
                        MESI_state[block_idx] <= M; 
                        non_owner_put         <= 1'b1;
                    end                
                end
                 
                `FWD_PUT_S: begin
                   put_ack         <= 1'b1;
                   unicast_address <= requester_i;
                   if (_MESI_state == S) begin
                       sharer[block_idx]     <= remove_sharer;
                       MESI_state[block_idx] <= (remove_sharer == 0) ? I : S;
                   end
                end
                 
                `FWD_PUT_M, `FORWARD_DATA_PUT_M: begin
                   put_ack               <= 1'b1;
                   unicast_address       <= requester_i;
                   owner[block_idx]      <= (non_owner_put) ? _owner : 1'b0;
                   MESI_state[block_idx] <= (non_owner_put) ? _MESI_state : I;
                   if (non_owner_put) begin 
                       memWrite_en   <= 1'b1;
                       mem_address   <= transaction_address_i;
                       memWrite_data <= transaction_data_i;
                       non_owner_put <= 1'b0; 
                   end

                end
                 
                `FWD_PUT_E, `FORWARD_DATA_PUT_E: begin
                   put_ack               <= 1'b1;
                   unicast_address       <= requester_i;
                   owner[block_idx]      <= (non_owner_put) ? _owner : 1'b0;
                   MESI_state[block_idx] <= (non_owner_put) ? _MESI_state : I;               
                   non_owner_put         <= 1'b0; 
                end
            endcase
        end
        
        else if (FSM_state == MEMORY) begin
            memRead_en    <= 1'b0;
            memWrite_en   <= 1'b0;
            mem_address   <= {`WIDTH{1'b0}};  
            memWrite_data <= {`BLOCK_SIZE{1'b0}};        
            case (transaction_type_i)
                `FWD_GET_S: begin
                    transaction_en_o      <= 1'b1;
                    transaction_type_o    <= `FORWARD_DATA;
                    transaction_address_o <= transaction_address_i;
                    transaction_data_o    <= memRead_data;
                    unicast_address       <= requester_i;
                    if (_MESI_state == I) begin // Invalid
                        exclusive         <= 1'b1;
                        owner[block_idx]  <= requester_i;
                        MESI_state[block_idx] <= E;
                    end
                    else begin // Shared
                        sharer[block_idx] <= (1'b1 << requester_i) | _sharer;
                    end
                end
                
                `FWD_GET_M: begin
                    transaction_en_o      <= 1'b1;
                    transaction_type_o    <= `FORWARD_DATA;
                    transaction_address_o <= transaction_address_i;
                    transaction_data_o    <= memRead_data;
                    unicast_address       <= requester_i;                
                    MESI_state[block_idx] <= M;
                    if (_MESI_state == I) begin // Invalid
                        owner[block_idx] <= requester_i;
                    end
                    else begin // Shared
                        Inv_en_o            <= 1'b1;
                        Inv_unicast_address <= _sharer & ~(1'b1 << requester_i);
                        Inv_address         <= transaction_address_i;
                        owner[block_idx]    <= requester_i;
                        sharer[block_idx]   <= 2'b0;
                        ack_num             <= 1'b1;
                    end
                end
            endcase
            FSM_state <= IDLE;
        end
        else if (FSM_state == S_D) begin
            transaction_en_o <= 1'b0;
            if (transaction_en_i) begin
                case (transaction_type_i)
                    `FORWARD_DATA_PUT_M : begin
                       memWrite_en   <= 1'b1;
                       mem_address   <= transaction_address_i;
                       memWrite_data <= transaction_data_i;
                       MESI_state[block_idx] <= S;
                    end
                    
                    `FWD_PUT_S: begin
                        put_ack <= 1'b1;
                        unicast_address   <= requester_i;
                        sharer[block_idx] <= remove_sharer;
                    end
                endcase
                FSM_state <= IDLE;
            end
        end        
    end

end  

endmodule