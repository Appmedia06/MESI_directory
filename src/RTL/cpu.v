`include "define.v"

module cpu (
    input  wire                     sys_clk,
    input  wire                     sys_rst,
    
    input  wire  [`WIDTH-1:0]       instruction,
    input  wire  [`WIDTH-1:0]       CPU_write_data_i,
    
    output reg                      CPU_read_en_o,    
    output reg                      CPU_write_en_o,
    output reg   [`WIDTH-1:0]       CPU_address_o,
    output reg   [`WIDTH-1:0]       CPU_write_data_o,
    
    input  wire                     CPU_data_en_i,
    input  wire  [`WIDTH-1:0]       CPU_read_data_i,

    output reg                      CPU_data_en_o,
    output reg   [`WIDTH-1:0]       CPU_read_data_o
); 

reg  [`WIDTH-1:0]  base_register;
reg  [`WIDTH-1:0]  dest_register;
reg                write_read_reg;
reg  [2:0]         funct3_reg;

wire [6:0]         opcode;
wire [2:0]         funct3;
wire [11:0]        load_offset;
wire [`WIDTH-1:0]  load_address;
wire [11:0]        store_offset;
wire [`WIDTH-1:0]  store_address;


/*******************************************************************
    Combination logic
*******************************************************************/
assign opcode        = instruction[6:0];
assign funct3        = instruction[14:12];

assign load_offset   = instruction[31:20];
assign load_address  = $signed(base_register) + $signed(load_offset);

assign store_offset  = {instruction[31:25], instruction[11:7]};
assign store_address = $signed(base_register) + $signed(store_offset);


/*******************************************************************
    store data register
*******************************************************************/
always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        base_register <= {`WIDTH{1'b0}};
        funct3_reg    <= 3'b0;
    end
    else if (opcode == `LOAD_OPCODE || opcode == `STORE_OPCODE) begin
        base_register <= {`WIDTH{1'b0}};
        funct3_reg    <= funct3;
    end
end


/*******************************************************************
    Send requestion
*******************************************************************/
always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        CPU_read_en_o    <= 1'b0;
        CPU_write_en_o   <= 1'b0;
        CPU_address_o    <= {`WIDTH{1'b0}};
        CPU_write_data_o <= {`WIDTH{1'b0}};
        write_read_reg   <= 1'b0;
    end
    else begin
        case (opcode)
            `LOAD_OPCODE: begin
                CPU_read_en_o    <= 1'b1;
                CPU_write_en_o   <= 1'b0;
                CPU_address_o    <= load_address;
                CPU_write_data_o <= {`WIDTH{1'b0}}; 
                write_read_reg   <= 1'b0;
            end
            `STORE_OPCODE: begin
                CPU_read_en_o    <= 1'b0;
                CPU_write_en_o   <= 1'b1;
                CPU_address_o    <= store_address;
                write_read_reg   <= 1'b1;
                case (funct3)
                    `SB: begin
                        CPU_write_data_o <= CPU_write_data_i[7:0];
                    end
                    `SH: begin
                        CPU_write_data_o <= CPU_write_data_i[15:0];
                    end
                    `SW: begin
                        CPU_write_data_o <= CPU_write_data_i;
                    end
                    default: begin
                        CPU_write_data_o <= CPU_write_data_i;
                    end
                endcase
            end
            default: begin
                CPU_read_en_o    <= 1'b0;
                CPU_write_en_o   <= 1'b0;
                CPU_address_o    <= {`WIDTH{1'b0}};
                CPU_write_data_o <= {`WIDTH{1'b0}};                
            end
        endcase
    end
end


/*******************************************************************
    Receive cache data
*******************************************************************/
always@ (posedge sys_clk or posedge sys_rst) begin
    if (sys_rst) begin
        CPU_data_en_o   <= 1'b0;
        CPU_read_data_o <= {`WIDTH{1'b0}};
        dest_register   <= {`WIDTH{1'b0}};
    end
    else if (CPU_data_en_i) begin
        CPU_data_en_o   <= 1'b1;
        if (!write_read_reg) begin // read
            case (funct3_reg)
                `LB: begin
                    CPU_read_data_o <= {{24{CPU_read_data_i[7]}}, CPU_read_data_i[7:0]};
                    dest_register   <= {{24{CPU_read_data_i[7]}}, CPU_read_data_i[7:0]}; 
                end
                `LH: begin
                    CPU_read_data_o <= {{16{CPU_read_data_i[15]}}, CPU_read_data_i[15:0]};
                    dest_register   <= {{16{CPU_read_data_i[15]}}, CPU_read_data_i[15:0]};
                end
                `LW: begin
                    CPU_read_data_o <= CPU_read_data_i;
                    dest_register   <= CPU_read_data_i; 
                end  
                `LBU: begin
                    CPU_read_data_o <= {24'b0, CPU_read_data_i[7:0]};
                    dest_register   <= {24'b0, CPU_read_data_i[7:0]};
                end
                `LHU: begin
                    CPU_read_data_o <= {16'b0, CPU_read_data_i[15:0]};
                    dest_register   <= {16'b0, CPU_read_data_i[15:0]};
                end    
                default: begin
                    CPU_read_data_o <= CPU_read_data_i;
                    dest_register   <= CPU_read_data_i; 
                end
            endcase
        end
    end
    else begin
        CPU_data_en_o   <= 1'b0;
    end
end

endmodule