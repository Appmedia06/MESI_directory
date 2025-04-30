
`define NUM_CPU             2
`define CPU_WIDTH           1  // log2(NUM_CPU)

`define WIDTH               32
`define BLOCK_SIZE          64
`define NUM_BLOCK           32

`define BLOCK_SHIFT         27 
`define BLOCK_WIDTH         5 // log2(NUM_BLOCK)

`define NUM_WAYS            4
`define NUM_SETS            4

`define INDEX_WIDTH         2
`define TAG_WIDTH           24
`define OFFSET_WIDTH        6
`define OFFSET_BORDER       31

/* Memory address layout */
`define TAG                 31:8	// position of tag in address
`define INDEX               7:6		// position of index in address
`define OFFSET              5:0		// position of offset in address

`define MEM_BLOCK_WIDTH     12:8

/* Transaction */
`define NONE                4'd0
`define FWD_GET_S           4'd1
`define FWD_GET_M           4'd2
                           
`define FWD_PUT_E           4'd3
`define FWD_PUT_S           4'd4
`define FWD_PUT_M           4'd5
                            
`define FORWARD_DATA        4'd6
`define FORWARD_DATA_PUT_E  4'd7
`define FORWARD_DATA_PUT_M  4'd8
                            
`define INV                 4'd9 

/* Instruction */
`define LOAD_OPCODE         7'b000_0011
`define STORE_OPCODE        7'b010_0011
        
`define LB                  3'b000
`define LH                  3'b001
`define LW                  3'b010
`define LBU                 3'b100
`define LHU                 3'b101
        
`define SB                  3'b000
`define SH                  3'b001
`define SW                  3'b010

`define SIMULATION          1'b1
