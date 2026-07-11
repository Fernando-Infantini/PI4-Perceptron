module algorithm #(
    parameter ADDRESS_SIZE = 32,
    parameter ASSOCIATIVITY = 4, 
    parameter N_BLOCKS = 256,    
    parameter ALGORITHM = 1      
)(
    input wire [ADDRESS_SIZE-1:0] address,
    input wire [$clog2(N_BLOCKS==1?2:N_BLOCKS)-1:0] index, 
    input wire [ASSOCIATIVITY-1:0] hits,
    input wire enable,           
    input wire wr,
    input wire clock,
    output wire [ASSOCIATIVITY-1:0] victims
);
    generate
        if (ALGORITHM == 1) begin : gen_perceptron
            perceptron #(
                .ADDRESS_SIZE(ADDRESS_SIZE), 
                .ASSOCIATIVITY(ASSOCIATIVITY),
                .N_BLOCKS(N_BLOCKS)
            ) implementation (
                .address(address), 
                .index(index),      
                .hits(hits), 
                .enable(enable), 
                .wr(wr), 
                .clock(clock), 
                .victims(victims)
            );
        end else begin : gen_lru
            wire [ASSOCIATIVITY-1:0] lru_victims [N_BLOCKS-1:0];
            genvar i;
            for(i=0; i<N_BLOCKS; i=i+1) begin : lru_loop
                wire algo_req = (i == index) ? enable : 1'b0;
                lru #(
                    .ADDRESS_SIZE(ADDRESS_SIZE), 
                    .ASSOCIATIVITY(ASSOCIATIVITY)
                ) lru_impl (
                    .address(address), 
                    .hits(hits), 
                    .enable(algo_req), 
                    .wr(wr), 
                    .clock(clock), 
                    .victims(lru_victims[i])
                );
            end
            assign victims = lru_victims[index];
        end
    endgenerate
endmodule