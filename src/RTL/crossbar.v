`include "define.v"

module crossbar (
    input  wire                     sys_clk,
    input  wire                     sys_rst,

    /* CPU 0 */
    input  wire                     CPU0_transaction_en_i,
    input  wire  [3:0]              CPU0_transaction_type_i,
    input  wire  [`BLOCK_SIZE-1:0]  CPU0_transaction_data_i,
    input  wire  [`WIDTH-1:0]       CPU0_transaction_address_i,
    input  wire  [`CPU_WIDTH-1:0]   CPU0_unicast_address_i,  
    input  wire                     CPU0_Inv_ack_i,
    input  wire                     CPU0_Fwd_stall,
    input  wire                     CPU0_Inv_stall,    
    
    output reg                      CPU0_transaction_en_o,
    output reg   [3:0]              CPU0_transaction_type_o, 
    output reg   [`BLOCK_SIZE-1:0]  CPU0_transaction_data_o,   
    output reg   [`WIDTH-1:0]       CPU0_transaction_address_o,
    output reg                      CPU0_exclusive,
    output reg   [`CPU_WIDTH-1:0]   CPU0_ack_num,
    output reg   [`CPU_WIDTH-1:0]   CPU0_requesters,                 // data requesters, one hot code
    output reg   [`CPU_WIDTH-1:0]   CPU0_last_ack_o,
    output reg                      CPU0_put_ack,
    output reg                      CPU0_Inv_en_o,
    output reg   [`WIDTH-1:0]       CPU0_Inv_address_o,
    
    /* CPU 1 */
    input  wire                     CPU1_transaction_en_i,
    input  wire  [3:0]              CPU1_transaction_type_i,
    input  wire  [`BLOCK_SIZE-1:0]  CPU1_transaction_data_i,
    input  wire  [`WIDTH-1:0]       CPU1_transaction_address_i,
    input  wire  [`CPU_WIDTH-1:0]   CPU1_unicast_address_i,
    input  wire                     CPU1_Inv_ack_i,
    input wire                      CPU1_Fwd_stall,
    input wire                      CPU1_Inv_stall,        
    
    output reg                      CPU1_transaction_en_o,
    output reg   [3:0]              CPU1_transaction_type_o, 
    output reg   [`BLOCK_SIZE-1:0]  CPU1_transaction_data_o,   
    output reg   [`WIDTH-1:0]       CPU1_transaction_address_o,
    output reg                      CPU1_exclusive,
    output reg   [`CPU_WIDTH-1:0]   CPU1_ack_num,
    output reg   [`CPU_WIDTH-1:0]   CPU1_requesters,               
    output reg   [`CPU_WIDTH-1:0]   CPU1_last_ack_o,
    output reg                      CPU1_put_ack,
    output reg                      CPU1_Inv_en_o,
    output reg   [`WIDTH-1:0]       CPU1_Inv_address_o,
    
    /* Directory */  
    input  wire                     Dir_transaction_en_i,
    input  wire  [3:0]              Dir_transaction_type_i, 
    input  wire  [`BLOCK_SIZE-1:0]  Dir_transaction_data_i,   
    input  wire  [`WIDTH-1:0]       Dir_transaction_address_i,
    input  wire  [`CPU_WIDTH-1:0]   Dir_unicast_address_i,
    input  wire                     Dir_exclusive,
    input  wire  [`CPU_WIDTH-1:0]   Dir_ack_num,
    input  wire  [`CPU_WIDTH-1:0]   Dir_requesters,          
    input  wire                     Dir_put_ack,
    input  wire                     Dir_Inv_en,            
    input  wire  [`CPU_WIDTH:0]     Dir_Inv_unicast_address,           // one-hot code
    input  wire  [`WIDTH-1:0]       Dir_Inv_address,    

    output reg                      Dir_transaction_en_o,
    output reg   [3:0]              Dir_transaction_type_o,
    output reg   [`BLOCK_SIZE-1:0]  Dir_transaction_data_o,
    output reg   [`WIDTH-1:0]       Dir_transaction_address_o,
    output reg   [`CPU_WIDTH-1:0]   Dir_requester_o   
);    


/*******************************************************************
    Parameter
*******************************************************************/
parameter  CPU0 = 1'b0;
parameter  CPU1 = 1'b1;

parameter  CPU0_onehot = 2'b01;
parameter  CPU1_onehot = 2'b10;

parameter IDLE  = 1'b0;
parameter STALL = 1'b1;

reg       Fwd_state;
reg       Inv_state;



/*******************************************************************
    Request Path: Cache controller -> Directory
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        Dir_transaction_en_o      <= 1'b0;
        Dir_transaction_type_o    <= `NONE;
        Dir_transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
        Dir_transaction_address_o <= {`WIDTH{1'b0}};
        Dir_requester_o           <= 0;
    end
    else if (!Dir_transaction_en_o) begin
        if (CPU0_transaction_en_i) begin
            Dir_transaction_en_o      <= 1'b1;
            Dir_transaction_type_o    <= CPU0_transaction_type_i;
            Dir_transaction_data_o    <= CPU0_transaction_data_i;
            Dir_transaction_address_o <= CPU0_transaction_address_i;
            Dir_requester_o           <= CPU0;
        end
        else if (CPU1_transaction_en_i) begin
            Dir_transaction_en_o      <= 1'b1;
            Dir_transaction_type_o    <= CPU1_transaction_type_i;
            Dir_transaction_data_o    <= CPU1_transaction_data_i;
            Dir_transaction_address_o <= CPU1_transaction_address_i;
            Dir_requester_o           <= CPU1;
        end
    end
    else begin
        Dir_transaction_en_o <= 1'b0;
    end
end

/*******************************************************************
    Invalidation
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        Inv_state          <= IDLE;
    
        CPU0_Inv_en_o      <= 1'b0;
        CPU0_Inv_address_o <= {`WIDTH{1'b0}};
        CPU1_Inv_en_o      <= 1'b0;
        CPU1_Inv_address_o <= {`WIDTH{1'b0}};
    end
    else begin
        CPU0_Inv_en_o <= 1'b0;
        CPU1_Inv_en_o <= 1'b0;
        if (Dir_Inv_en) begin
            if (Dir_Inv_unicast_address == CPU0_onehot) begin
                CPU0_Inv_en_o      <= 1'b1;
                CPU0_Inv_address_o <= Dir_Inv_address;
            end
            else begin
                CPU1_Inv_en_o      <= 1'b1;
                CPU1_Inv_address_o <= Dir_Inv_address;
            end
        end
    end
end


/*******************************************************************
    Response path: Directory or Cache controller -> Cache controller
*******************************************************************/

always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        Fwd_state <= IDLE;
        
        // Reset CPU0
        CPU0_transaction_en_o      <= 1'b0;
        CPU0_transaction_type_o    <= `NONE;
        CPU0_transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
        CPU0_transaction_address_o <= {`WIDTH{1'b0}};
        CPU0_exclusive             <= 1'b0;
        CPU0_ack_num               <= 0;
        CPU0_requesters            <= 0;
        CPU0_put_ack               <= 1'b0;

        // Reset CPU1
        CPU1_transaction_en_o      <= 1'b0;
        CPU1_transaction_type_o    <= `NONE;
        CPU1_transaction_data_o    <= {`BLOCK_SIZE{1'b0}};
        CPU1_transaction_address_o <= {`WIDTH{1'b0}};
        CPU1_exclusive             <= 1'b0;
        CPU1_ack_num               <= 0;
        CPU1_requesters            <= 0;
        CPU1_put_ack               <= 1'b0;
    end
    else begin
        // Default outputs
        CPU0_transaction_en_o <= 1'b0;
        CPU1_transaction_en_o <= 1'b0;

        if (Dir_transaction_en_i) begin
            case (Dir_unicast_address_i)
                CPU0: begin
                    CPU0_transaction_en_o      <= 1'b1;
                    CPU0_transaction_type_o    <= Dir_transaction_type_i;
                    CPU0_transaction_data_o    <= Dir_transaction_data_i;
                    CPU0_transaction_address_o <= Dir_transaction_address_i;
                    CPU0_exclusive             <= Dir_exclusive;
                    CPU0_ack_num               <= Dir_ack_num;
                    CPU0_requesters            <= Dir_requesters;
                    CPU0_put_ack               <= Dir_put_ack;
                end
                CPU1: begin
                    CPU1_transaction_en_o      <= 1'b1;
                    CPU1_transaction_type_o    <= Dir_transaction_type_i;
                    CPU1_transaction_data_o    <= Dir_transaction_data_i;
                    CPU1_transaction_address_o <= Dir_transaction_address_i;
                    CPU1_exclusive             <= Dir_exclusive;
                    CPU1_ack_num               <= Dir_ack_num;
                    CPU1_requesters            <= Dir_requesters;
                    CPU1_put_ack               <= Dir_put_ack;
                end
                default: ; 
            endcase
        end
        else if (CPU0_transaction_en_i && (CPU0_transaction_type_i == `FORWARD_DATA_PUT_E || CPU0_transaction_type_i == `FORWARD_DATA_PUT_M)) begin
            CPU1_transaction_en_o      <= 1'b1;
            CPU1_transaction_type_o    <= `FORWARD_DATA;
            CPU1_transaction_data_o    <= CPU0_transaction_data_i;
            CPU1_transaction_address_o <= CPU0_transaction_address_i;
            CPU1_exclusive             <= 1'b0;
            CPU1_ack_num               <= 0;
            CPU1_requesters            <= 0;
            CPU1_put_ack               <= 1'b0;
        end
        else if (CPU1_transaction_en_i && (CPU1_transaction_type_i == `FORWARD_DATA_PUT_E || CPU1_transaction_type_i == `FORWARD_DATA_PUT_M)) begin
            CPU0_transaction_en_o      <= 1'b1;
            CPU0_transaction_type_o    <= `FORWARD_DATA;
            CPU0_transaction_data_o    <= CPU1_transaction_data_i;
            CPU0_transaction_address_o <= CPU1_transaction_address_i;
            CPU0_exclusive             <= 1'b0;
            CPU0_ack_num               <= 0;
            CPU0_requesters            <= 0;
            CPU0_put_ack               <= 1'b0;
        end
    end
end


always @(posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        CPU0_last_ack_o <= 1'b0;
        CPU1_last_ack_o <= 1'b0;
    end
    else begin
        if (CPU0_Inv_ack_i) begin
            CPU1_last_ack_o <= 1'b1;
        end
        else if (CPU1_Inv_ack_i) begin
            CPU0_last_ack_o <= 1'b1;
        end
        else begin
            CPU0_last_ack_o <= 1'b0;
            CPU1_last_ack_o <= 1'b0;
        end
    end
end


endmodule