module top_perceptron(
    input wire [32-1:0] address,
    input wire [4-1:0] hits,
    input wire enable,
    input wire wr,
    input wire clock,
    output wire [4-1:0] victims
);
	perceptron #(.ADDRESS_SIZE(32), .ASSOCIATIVITY(4)) implementation (address, hits, enable, wr, clock, victims);
endmodule
