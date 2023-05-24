`timescale 1ns/100ps

module instruction_cache(
    // Port declaration
	pc_address,
    clock,
    reset,
    inst_readdata,
    inst_busywait,
    inst_read,
    instruction,
    inst_address,
    busywait
);

    input [31:0] pc_address;                    
    input clock;
    input reset;
    input [127:0] inst_readdata;        
    input inst_busywait;               
    output reg inst_read;              
    output [31:0] instruction;          
    output reg [27:0] inst_address;     
    output reg busywait;               

    reg [127:0] inst_data [7:0];       
    reg inst_valid [7:0];              
    reg [2:0] inst_tag [7:0];          
    reg [9:0] address;                 

    // Defining Memory Block Arrays (Reg Arrays) 
    // of the Instruction Cache
    wire valid [0:7];         
    wire [24:0] tag [0:7];     
    reg [127:0] data [0:7];   

    always @ (pc_address) begin
		address = {pc_address[9:0]};	
		busywait = 1'b1;
    end

    always @ (*) begin
        #1 data = inst_data[address[6:4]];            
    end
	
    assign #1 valid = inst_valid[address[6:4]];    
    assign #1 tag = inst_tag[address[6:4]];

    wire comparatorsignal;
    wire hitsignal;         

    assign #0.9 comparatorsignal = (tag == address[9:7]) ? 1 : 0;

    assign hitsignal = comparatorsignal && valid;

    always @ (posedge clock)
    if (hitsignal) begin
        busywait = 1'b0;	// set busywait to 0
    end

    assign #1 instruction = ((address[3:2] == 2'b01) && hitsignal) ? data[63:32] :
							((address[3:2] == 2'b10) && hitsignal) ? data[95:64] :
							((address[3:2] == 2'b11) && hitsignal) ? data[127:96] : data[31:0];
    
    /* Cache Controller FSM Start */
    parameter IDLE = 2'b00, MEM_READ = 2'b01, CACHE_UPDATE = 2'b10;
    reg [1:0] state, next_state;

    // combinational next state logic
    always @(*) begin
        case (state)
            IDLE:
                if (!hitsignal)  
                    next_state = MEM_READ;  
                else
                    next_state = IDLE;             
            
            MEM_READ:
                if (inst_busywait)
                    next_state = MEM_READ;          
                else    
                    next_state = CACHE_UPDATE;      

            CACHE_UPDATE:
                next_state = IDLE;                  
        endcase
    end

    // combinational output logic
    always @(state) begin
        case(state)
            IDLE: begin
					inst_read = 0;
					inst_address = 28'dx;
					busywait = 0;
				end
         
            MEM_READ: begin
					inst_read = 1;                    
					inst_address = {address[31:4]};  
				end
            
            CACHE_UPDATE: begin
					inst_read = 0;
					inst_address = 28'dx;

					#1
					inst_data[address[6:4]] = inst_readdata;   
					inst_tag[address[6:4]] = address[9:7];     
					inst_valid[address[6:4]] = 1'b1;       
				end
        endcase
    end

    // sequential logic for state transitioning 
    always @(posedge clock, reset) begin
        if(reset)
            state = IDLE;
        else
            state = next_state;
    end
    /* Cache Controller FSM End */

    // Reset instruction cache
    integer i;
	always @ (reset) begin
        for(i = 0; i < 8; i++) begin
            inst_valid[i] = 1'd0;
            inst_tag[i] = 3'dx;
            inst_data[i] = 32'dx;
        end
    end
    
endmodule