module top_perceptron(
    input wire [8-1:0] address,
    input wire [0:0] index,    
    input wire [2-1:0] hits,
    input wire enable,
    input wire wr,
    input wire clock,
    output wire [2-1:0] victims
);

    perceptron #(
        .ADDRESS_SIZE(8),
        .ASSOCIATIVITY(2),
        .N_BLOCKS(2) 
    ) implementation (
        .address(address),
        .index(index),
        .hits(hits),
        .enable(enable),
        .wr(wr),
        .clock(clock),
        .victims(victims)
    );

endmodule