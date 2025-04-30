/*
    Memory
        * size: 2KB
        * block size: 64 bit = 8 byte
        * number of block: 1024
*/

`include "define.v"

module memory (
    input  wire                     sys_clk,  

    input  wire                     memRead_en,
    input  wire                     memWrite_en,
    input  wire  [`WIDTH-1:0]       mem_address,
    output reg   [`BLOCK_SIZE-1:0]  memRead_data,
    input  wire  [`BLOCK_SIZE-1:0]  memWrite_data    
);    

reg   [`BLOCK_SIZE-1:0]  memory   [0:`NUM_BLOCK-1];
wire  [`BLOCK_WIDTH:0]              block_idx;

/*******************************************************************
    Initialize memory (default is 1)
*******************************************************************/

integer i;
initial begin
    for (i = 0; i < `NUM_BLOCK; i = i + 1) begin
        memory[i] = 1;
    end
end

/*******************************************************************
    Block index
*******************************************************************/
assign block_idx = mem_address[`MEM_BLOCK_WIDTH];


/*******************************************************************
    Read
*******************************************************************/

always@ (*) begin
    if (memRead_en) begin
        memRead_data = memory[block_idx];
    end
    else begin
        memRead_data = {`BLOCK_SIZE{1'b0}};
    end
end

/*******************************************************************
    Write
*******************************************************************/

always @(posedge sys_clk) begin
    if (memWrite_en) begin
        memory[block_idx] <= memWrite_data;
    end
end

endmodule


