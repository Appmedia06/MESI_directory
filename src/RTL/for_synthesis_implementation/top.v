`include "define.v"

module top (
    input  wire                     sys_clk,
    input  wire                     sys_rst,
    
    //input  wire  [`WIDTH-1:0]       CPU0_instruction,
    //input  wire  [`WIDTH-1:0]       CPU0_write_data_i,
    input  wire                     CPU0_en_i,
    
    output reg                      CPU0_data_en_o,
    //output wire  [`WIDTH-1:0]       CPU0_read_data_o,


    //input  wire  [`WIDTH-1:0]       CPU1_instruction,
    //input  wire  [`WIDTH-1:0]       CPU1_write_data_i,
    input  wire                     CPU1_en_i,
    
    output reg                      CPU1_data_en_o
    //output wire  [`WIDTH-1:0]       CPU1_read_data_o  
);
wire  [`WIDTH-1:0]      CPU0_read_data_o;
wire  [`WIDTH-1:0]      CPU1_read_data_o;

wire                    CPU0_data_en;
wire                    CPU1_data_en; 

reg  [`WIDTH-1:0]       instructions  [1:0];
reg  [`WIDTH-1:0]       write_data    [1:0];
reg  [1:0]              counter;

initial begin
    instructions[0] = 32'h00502023;
    instructions[1] = 32'h00502023;
    write_data[0]   = 32'h10101010;
    write_data[1]   = 32'h20202020;
end

reg  [`WIDTH-1:0]       CPU0_instruction;
reg  [`WIDTH-1:0]       CPU0_write_data_i;
reg  [`WIDTH-1:0]       CPU1_instruction;
reg  [`WIDTH-1:0]       CPU1_write_data_i;

always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        counter <= 0;
        CPU0_instruction <= 0;
        CPU0_write_data_i <= 0;
        CPU1_instruction <= 0;
        CPU1_write_data_i <= 0;
    end
    else begin
        CPU0_instruction <= 0;
        CPU0_write_data_i <= 0;
        CPU1_instruction <= 0;
        CPU1_write_data_i <= 0;
        if (CPU0_en_i) begin
            CPU0_instruction <= instructions[counter];
            CPU0_write_data_i <= write_data[counter];
            counter <= counter + 1;
        end
        else if (CPU1_en_i) begin
            CPU1_instruction <= instructions[counter];
            CPU1_write_data_i <= write_data[counter];
            counter <= counter + 1;
        end
    end
end

always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        CPU0_data_en_o <= 0;
        CPU1_data_en_o <= 0;
    end
    else begin
        CPU0_data_en_o <= CPU0_data_en;
        CPU1_data_en_o <= CPU1_data_en;
    end
end

/*******************************************************************
    CPU0 Wire
*******************************************************************/
                            
wire                     CPU0_read_en_o;    
wire                     CPU0_write_en_o;
wire   [`WIDTH-1:0]      CPU0_address_o;
wire   [`WIDTH-1:0]      CPU0_write_data_o;

wire                     CPU0_data_en_i;
wire   [`WIDTH-1:0]      CPU0_read_data_i;  

wire                     CPU0_read_en;
wire                     CPU0_write_en;
wire  [`WIDTH-1:0]       CPU0_address;
wire  [`WIDTH-1:0]       CPU0_write_data;        
wire  [`BLOCK_SIZE-1:0]  CPU0_memoryBack_data;   
wire                     CPU0_memoryBack_en;
wire  [`WIDTH-1:0]       CPU0_memoryBack_address;
wire  [1:0]              CPU0_change_state;    
wire                     CPU0_Fwd_en;
wire                     CPU0_Fwd_type;      
wire  [`WIDTH-1:0]       CPU0_Fwd_address;
wire                     CPU0_Inv_en_i;
wire  [`WIDTH-1:0]       CPU0_Inv_address_i;    
                         
wire                     CPU0_hit_miss;
wire                     CPU0_MESI_state;
wire   [`WIDTH-1:0]      CPU0_read_data;
wire   [`BLOCK_SIZE-1:0] CPU0_writeBack_data;
wire   [`WIDTH-1:0]      CPU0_writeBack_address;
wire                     CPU0_writeBack_en;
wire   [1:0]             CPU0_put_type;
wire   [`BLOCK_SIZE-1:0] CPU0_Fwd_data;
wire                     CPU0_Fwd_ME;

wire                     CPU0_transaction_en_o;
wire  [3:0]              CPU0_transaction_type_o;
wire  [`BLOCK_SIZE-1:0]  CPU0_transaction_data_o;
wire  [`WIDTH-1:0]       CPU0_transaction_address_o;
wire  [`CPU_WIDTH-1:0]   CPU0_unicast_address_o;
wire                     CPU0_Inv_ack_o;
wire                     CPU0_Fwd_stall;
wire                     CPU0_Inv_stall;

wire                     CPU0_transaction_en_i;
wire  [3:0]              CPU0_transaction_type_i; 
wire  [`BLOCK_SIZE-1:0]  CPU0_transaction_data_i;   
wire  [`WIDTH-1:0]       CPU0_transaction_address_i;
wire                     CPU0_exclusive;
wire  [`CPU_WIDTH-1:0]   CPU0_ack_num;
wire  [`CPU_WIDTH-1:0]   CPU0_requesters;              
wire  [`CPU_WIDTH-1:0]   CPU0_last_ack_o;
wire                     CPU0_put_ack;
wire                     CPU0_Inv_en_o;
wire  [`WIDTH-1:0]       CPU0_Inv_address_o;    

/*******************************************************************
    CPU1 Wire
*******************************************************************/

wire                     CPU1_read_en_o;    
wire                     CPU1_write_en_o;
wire   [`WIDTH-1:0]      CPU1_address_o;
wire   [`WIDTH-1:0]      CPU1_write_data_o;
                            
wire                     CPU1_data_en_i;
wire   [`WIDTH-1:0]      CPU1_read_data_i;                    
                           

wire                     CPU1_read_en;
wire                     CPU1_write_en;
wire  [`WIDTH-1:0]       CPU1_address;
wire  [`WIDTH-1:0]       CPU1_write_data;        
wire  [`BLOCK_SIZE-1:0]  CPU1_memoryBack_data;   
wire                     CPU1_memoryBack_en;
wire  [`WIDTH-1:0]       CPU1_memoryBack_address;
wire  [1:0]              CPU1_change_state;    
wire                     CPU1_Fwd_en;
wire                     CPU1_Fwd_type;        
wire  [`WIDTH-1:0]       CPU1_Fwd_address;
wire                     CPU1_Inv_en_i;
wire  [`WIDTH-1:0]       CPU1_Inv_address_i;    
                            
wire                     CPU1_hit_miss;
wire                     CPU1_MESI_state;
wire   [`WIDTH-1:0]      CPU1_read_data;
wire   [`BLOCK_SIZE-1:0] CPU1_writeBack_data;
wire   [`WIDTH-1:0]      CPU1_writeBack_address;
wire                     CPU1_writeBack_en;
wire   [1:0]             CPU1_put_type;
wire   [`BLOCK_SIZE-1:0] CPU1_Fwd_data;
wire                     CPU1_Fwd_ME;

wire                     CPU1_transaction_en_o;
wire  [3:0]              CPU1_transaction_type_o;
wire  [`BLOCK_SIZE-1:0]  CPU1_transaction_data_o;
wire  [`WIDTH-1:0]       CPU1_transaction_address_o;
wire  [`CPU_WIDTH-1:0]   CPU1_unicast_address_o;
wire                     CPU1_Inv_ack_o;
wire                     CPU1_Fwd_stall;
wire                     CPU1_Inv_stall;
                            
wire                     CPU1_transaction_en_i;
wire  [3:0]              CPU1_transaction_type_i;
wire  [`BLOCK_SIZE-1:0]  CPU1_transaction_data_i;   
wire  [`WIDTH-1:0]       CPU1_transaction_address_i;
wire                     CPU1_exclusive;
wire  [`CPU_WIDTH-1:0]   CPU1_ack_num;
wire  [`CPU_WIDTH-1:0]   CPU1_requesters;                
wire  [`CPU_WIDTH-1:00]  CPU1_last_ack_o;
wire                     CPU1_put_ack;
wire                     CPU1_Inv_en_o;
wire  [`WIDTH-1:0]       CPU1_Inv_address_o;  

/*******************************************************************
    Directory Wire
*******************************************************************/

wire                     Dir_transaction_en_i;
wire  [3:0]              Dir_transaction_type_i;
wire  [`BLOCK_SIZE-1:0]  Dir_transaction_data_i;
wire  [`WIDTH-1:0]       Dir_transaction_address_i;
wire  [`CPU_WIDTH-1:0]   Dir_requester_i;            

wire                     Dir_transaction_en_o;
wire  [3:0]              Dir_transaction_type_o;
wire  [`BLOCK_SIZE-1:0]  Dir_transaction_data_o;   
wire  [`WIDTH-1:0]       Dir_transaction_address_o;
wire  [`CPU_WIDTH-1:0]   Dir_unicast_address;

wire                     Dir_exclusive;
wire  [`CPU_WIDTH-1:0]   Dir_ack_num;
wire  [`CPU_WIDTH-1:0]   Dir_requesters;          
wire                     Dir_put_ack;
wire                     Dir_Inv_en_o;
wire  [`CPU_WIDTH:0]     Dir_Inv_unicast_address;
wire  [`WIDTH-1:0]       Dir_Inv_address;

wire                     memRead_en;
wire                     memWrite_en;
wire  [`WIDTH-1:0]       mem_address;
wire  [`BLOCK_SIZE-1:0]  memRead_data;
wire  [`BLOCK_SIZE-1:0]  memWrite_data;


cpu cpu0 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),

    .instruction            (CPU0_instruction),
    .CPU_write_data_i       (CPU0_write_data_i),
    //.CPU_en_i               (CPU0_en_i),
                                
    .CPU_read_en_o          (CPU0_read_en_o),    
    .CPU_write_en_o         (CPU0_write_en_o),
    .CPU_address_o          (CPU0_address_o),
    .CPU_write_data_o       (CPU0_write_data_o),
                                
    .CPU_data_en_i          (CPU0_data_en_i),
    .CPU_read_data_i        (CPU0_read_data_i),
                                
    .CPU_data_en_o          (CPU0_data_en),
    .CPU_read_data_o        (CPU0_read_data_o)
); 

cache_controller cache_controller0 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),

    .read_en_i              (CPU0_read_en_o),    
    .write_en_i             (CPU0_write_en_o),
    .address_i              (CPU0_address_o),
    .write_data_i           (CPU0_write_data_o),     

    .transaction_en_i       (CPU0_transaction_en_i),
    .transaction_type_i     (CPU0_transaction_type_i), 
    .transaction_data_i     (CPU0_transaction_data_i),   
    .transaction_address_i  (CPU0_transaction_address_i),

    .exclusive              (CPU0_exclusive),
    .ack_num                (CPU0_ack_num),
    .requesters             (CPU0_requesters),         
    .last_ack               (CPU0_last_ack_o),
    .put_ack                (CPU0_put_ack),
    .Inv_en_i               (CPU0_Inv_en_i),
    .Inv_address_i          (CPU0_Inv_address_i),

    .hit_miss               (CPU0_hit_miss),
    .MESI_state             (CPU0_MESI_state),
    .read_data_i            (CPU0_read_data),
    .writeBack_data_i       (CPU0_writeBack_data),
    .writeBack_address_i    (CPU0_writeBack_address),
    .writeBack_en_i         (CPU0_writeBack_en),
    .put_type               (CPU0_put_type),       
    .Fwd_data_i             (CPU0_Fwd_data),
    .Fwd_ME                 (CPU0_Fwd_ME),

    .data_en                (CPU0_data_en_i),
    .read_data_o            (CPU0_read_data_i),

    .read_en_o              (CPU0_read_en),    
    .write_en_o             (CPU0_write_en),
    .address_o              (CPU0_address),
    .write_data_o           (CPU0_write_data),      
    .memoryBack_data_o      (CPU0_memoryBack_data),  
    .memoryBack_address_o   (CPU0_memoryBack_address),
    .memoryBack_en_o        (CPU0_memoryBack_en),
    .change_state           (CPU0_change_state),   
    .Fwd_en                 (CPU0_Fwd_en),
    .Fwd_type               (CPU0_Fwd_type),          
    .Fwd_address_to_cache   (CPU0_Fwd_address),
    .Inv_en_o               (CPU0_Inv_en_o),
    .Inv_address_o          (CPU0_Inv_address_o),

    .transaction_en_o       (CPU0_transaction_en_o),
    .transaction_type_o     (CPU0_transaction_type_o),
    .transaction_data_o     (CPU0_transaction_data_o),
    .transaction_address_o  (CPU0_transaction_address_o),
    .unicast_address_o      (CPU0_unicast_address_o),

    .Inv_ack_o              (CPU0_Inv_ack_o),
    
    .Fwd_stall              (CPU0_Fwd_stall),
    .Inv_stall              (CPU0_Inv_stall)
);



cache cache0 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),
        
    .read_en                (CPU0_read_en),
    .write_en               (CPU0_write_en),
    .address                (CPU0_address),
    .write_data             (CPU0_write_data),        
    .memoryBack_data        (CPU0_memoryBack_data),   
    .memoryBack_en          (CPU0_memoryBack_en),
    .memoryBack_address     (CPU0_memoryBack_address),
    .change_state           (CPU0_change_state),    
    .Fwd_en                 (CPU0_Fwd_en),
    .Fwd_type               (CPU0_Fwd_type),          
    .Fwd_address            (CPU0_Fwd_address),
    .Inv_en                 (CPU0_Inv_en_o),
    .Inv_address            (CPU0_Inv_address_o),    
    
    .hit_miss               (CPU0_hit_miss),
    .MESI_state             (CPU0_MESI_state),
    .read_data              (CPU0_read_data),
    .writeBack_data         (CPU0_writeBack_data),
    .writeBack_address      (CPU0_writeBack_address),
    .writeBack_en           (CPU0_writeBack_en),
    .put_type               (CPU0_put_type),
    .Fwd_data               (CPU0_Fwd_data),
    .Fwd_ME                 (CPU0_Fwd_ME)
);


cpu cpu1 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),

    .instruction            (CPU1_instruction),
    .CPU_write_data_i       (CPU1_write_data_i),
    //.CPU_en_i               (CPU1_en_i),
                                
    .CPU_read_en_o          (CPU1_read_en_o),    
    .CPU_write_en_o         (CPU1_write_en_o),
    .CPU_address_o          (CPU1_address_o),
    .CPU_write_data_o       (CPU1_write_data_o),
                                
    .CPU_data_en_i          (CPU1_data_en_i),
    .CPU_read_data_i        (CPU1_read_data_i),
                                
    .CPU_data_en_o          (CPU1_data_en),
    .CPU_read_data_o        (CPU1_read_data_o) 
); 

cache_controller cache_controller1 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),

    .read_en_i              (CPU1_read_en_o),    
    .write_en_i             (CPU1_write_en_o),
    .address_i              (CPU1_address_o),
    .write_data_i           (CPU1_write_data_o),       
                                
    .transaction_en_i       (CPU1_transaction_en_i),
    .transaction_type_i     (CPU1_transaction_type_i), 
    .transaction_data_i     (CPU1_transaction_data_i),   
    .transaction_address_i  (CPU1_transaction_address_i),
                                
    .exclusive              (CPU1_exclusive),
    .ack_num                (CPU1_ack_num),
    .requesters             (CPU1_requesters),          
    .last_ack               (CPU1_last_ack_o),
    .put_ack                (CPU1_put_ack),
    .Inv_en_i               (CPU1_Inv_en_i),
    .Inv_address_i          (CPU1_Inv_address_i),
                                
    .hit_miss               (CPU1_hit_miss),
    .MESI_state             (CPU1_MESI_state),
    .read_data_i            (CPU1_read_data),
    .writeBack_data_i       (CPU1_writeBack_data),
    .writeBack_address_i    (CPU1_writeBack_address),
    .writeBack_en_i         (CPU1_writeBack_en),
    .put_type               (CPU1_put_type),            
    .Fwd_data_i             (CPU1_Fwd_data),
    .Fwd_ME                 (CPU1_Fwd_ME),
                                
    .data_en                (CPU1_data_en_i),
    .read_data_o            (CPU1_read_data_i),
                                
    .read_en_o              (CPU1_read_en),    
    .write_en_o             (CPU1_write_en),
    .address_o              (CPU1_address),
    .write_data_o           (CPU1_write_data),      
    .memoryBack_data_o      (CPU1_memoryBack_data),   
    .memoryBack_address_o   (CPU1_memoryBack_address),
    .memoryBack_en_o        (CPU1_memoryBack_en),
    .change_state           (CPU1_change_state),   
    .Fwd_en                 (CPU1_Fwd_en),
    .Fwd_type               (CPU1_Fwd_type),          
    .Fwd_address_to_cache   (CPU1_Fwd_address),
    .Inv_en_o               (CPU1_Inv_en_o),
    .Inv_address_o          (CPU1_Inv_address_o),
                                
    .transaction_en_o       (CPU1_transaction_en_o),
    .transaction_type_o     (CPU1_transaction_type_o),
    .transaction_data_o     (CPU1_transaction_data_o),
    .transaction_address_o  (CPU1_transaction_address_o),
    .unicast_address_o      (CPU1_unicast_address_o),
    .Inv_ack_o              (CPU1_Inv_ack_o),
    .Fwd_stall              (CPU1_Fwd_stall),
    .Inv_stall              (CPU1_Inv_stall)    
);



cache cache1 (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),
        
    .read_en                (CPU1_read_en),
    .write_en               (CPU1_write_en),
    .address                (CPU1_address),
    .write_data             (CPU1_write_data),        
    .memoryBack_data        (CPU1_memoryBack_data),   
    .memoryBack_en          (CPU1_memoryBack_en),
    .memoryBack_address     (CPU1_memoryBack_address),
    .change_state           (CPU1_change_state),    
    .Fwd_en                 (CPU1_Fwd_en),
    .Fwd_type               (CPU1_Fwd_type),          
    .Fwd_address            (CPU1_Fwd_address),
    .Inv_en                 (CPU1_Inv_en_o),
    .Inv_address            (CPU1_Inv_address_o),    
                                
    .hit_miss               (CPU1_hit_miss),
    .MESI_state             (CPU1_MESI_state),
    .read_data              (CPU1_read_data),
    .writeBack_data         (CPU1_writeBack_data),
    .writeBack_address      (CPU1_writeBack_address),
    .writeBack_en           (CPU1_writeBack_en),
    .put_type               (CPU1_put_type),
    .Fwd_data               (CPU1_Fwd_data),
    .Fwd_ME                 (CPU1_Fwd_ME)
);    


crossbar bus (
    .sys_clk                    (sys_clk),
    .sys_rst                    (sys_rst),

    .CPU0_transaction_en_i      (CPU0_transaction_en_o),
    .CPU0_transaction_type_i    (CPU0_transaction_type_o),
    .CPU0_transaction_data_i    (CPU0_transaction_data_o),
    .CPU0_transaction_address_i (CPU0_transaction_address_o),
    .CPU0_unicast_address_i     (CPU0_unicast_address_o),
    .CPU0_Inv_ack_i             (CPU0_Inv_ack_o),
    .CPU0_Fwd_stall             (CPU0_Fwd_stall),
    .CPU0_Inv_stall             (CPU0_Inv_stall),    

    .CPU0_transaction_en_o      (CPU0_transaction_en_i),
    .CPU0_transaction_type_o    (CPU0_transaction_type_i), 
    .CPU0_transaction_data_o    (CPU0_transaction_data_i),   
    .CPU0_transaction_address_o (CPU0_transaction_address_i),
    .CPU0_exclusive             (CPU0_exclusive),
    .CPU0_ack_num               (CPU0_ack_num),
    .CPU0_requesters            (CPU0_requesters),                 
    .CPU0_last_ack_o            (CPU0_last_ack_o),
    .CPU0_put_ack               (CPU0_put_ack),
    .CPU0_Inv_en_o              (CPU0_Inv_en_i),
    .CPU0_Inv_address_o         (CPU0_Inv_address_i),

    .CPU1_transaction_en_i      (CPU1_transaction_en_o),
    .CPU1_transaction_type_i    (CPU1_transaction_type_o),
    .CPU1_transaction_data_i    (CPU1_transaction_data_o),
    .CPU1_transaction_address_i (CPU1_transaction_address_o),
    .CPU1_unicast_address_i     (CPU1_unicast_address_o),
    .CPU1_Inv_ack_i             (CPU1_Inv_ack_o),
    .CPU1_Fwd_stall             (CPU1_Fwd_stall),
    .CPU1_Inv_stall             (CPU1_Inv_stall),     
                                    
    .CPU1_transaction_en_o      (CPU1_transaction_en_i),
    .CPU1_transaction_type_o    (CPU1_transaction_type_i), 
    .CPU1_transaction_data_o    (CPU1_transaction_data_i),   
    .CPU1_transaction_address_o (CPU1_transaction_address_i),
    .CPU1_exclusive             (CPU1_exclusive),
    .CPU1_ack_num               (CPU1_ack_num),
    .CPU1_requesters            (CPU1_requesters),                
    .CPU1_last_ack_o            (CPU1_last_ack_o),
    .CPU1_put_ack               (CPU1_put_ack),
    .CPU1_Inv_en_o              (CPU1_Inv_en_i),
    .CPU1_Inv_address_o         (CPU1_Inv_address_i),

    .Dir_transaction_en_i       (Dir_transaction_en_o),
    .Dir_transaction_type_i     (Dir_transaction_type_o), 
    .Dir_transaction_data_i     (Dir_transaction_data_o),   
    .Dir_transaction_address_i  (Dir_transaction_address_o),
    .Dir_unicast_address_i      (Dir_unicast_address),
    .Dir_exclusive              (Dir_exclusive),
    .Dir_ack_num                (Dir_ack_num),
    .Dir_requesters             (Dir_requesters),          
    .Dir_put_ack                (Dir_put_ack),
    .Dir_Inv_en                 (Dir_Inv_en_o),            
    .Dir_Inv_unicast_address    (Dir_Inv_unicast_address),
    .Dir_Inv_address            (Dir_Inv_address),

    .Dir_transaction_en_o       (Dir_transaction_en_i),
    .Dir_transaction_type_o     (Dir_transaction_type_i),
    .Dir_transaction_data_o     (Dir_transaction_data_i),
    .Dir_transaction_address_o  (Dir_transaction_address_i),
    .Dir_requester_o            (Dir_requester_i)  
);  


directory directory (
    .sys_clk                (sys_clk),
    .sys_rst                (sys_rst),

    .transaction_en_i       (Dir_transaction_en_i),
    .transaction_type_i     (Dir_transaction_type_i),
    .transaction_data_i     (Dir_transaction_data_i),
    .transaction_address_i  (Dir_transaction_address_i),
    .requester_i            (Dir_requester_i),           

    .transaction_en_o       (Dir_transaction_en_o),
    .transaction_type_o     (Dir_transaction_type_o), 
    .transaction_data_o     (Dir_transaction_data_o),   
    .transaction_address_o  (Dir_transaction_address_o),
    .unicast_address        (Dir_unicast_address),

    .exclusive              (Dir_exclusive),
    .ack_num                (Dir_ack_num),
    .requesters             (Dir_requesters),          
    .put_ack                (Dir_put_ack),
    .Inv_en_o               (Dir_Inv_en_o),
    .Inv_unicast_address    (Dir_Inv_unicast_address),
    .Inv_address            (Dir_Inv_address),

    .memRead_en             (memRead_en),
    .memWrite_en            (memWrite_en),
    .mem_address            (mem_address),
    .memRead_data           (memRead_data),
    .memWrite_data          (memWrite_data)
);


memory memory (
    .sys_clk                (sys_clk),
    
    .memRead_en             (memRead_en),
    .memWrite_en            (memWrite_en),
    .mem_address            (mem_address),
    .memRead_data           (memRead_data),
    .memWrite_data          (memWrite_data)   
);    

endmodule