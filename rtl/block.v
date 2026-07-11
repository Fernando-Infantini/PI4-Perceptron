module block #(
	parameter ADDRESS_SIZE = 32,
	parameter DATA_SIZE = 32, //size of a word in bits
	parameter BLOCK_SIZE = 4 //how many words a block stores
)(
	input wire [ADDRESS_SIZE-$clog2(BLOCK_SIZE)-1:0] tag,
	inout wire [DATA_SIZE*BLOCK_SIZE-1:0] data,
	input wire wr,
	output wire hit,
	input wire clock
);
	localparam TAG_ALL = ADDRESS_SIZE-$clog2(BLOCK_SIZE);
	localparam DATA_ALL = DATA_SIZE*BLOCK_SIZE;

	reg valid;
	reg [TAG_ALL-1:0] current_tag;
	reg [DATA_ALL-1:0] data_memory;

	initial begin
		begin: reset
			 current_tag = {TAG_ALL{1'b0}};
		end
	end

	assign hit = (valid && (current_tag == tag));

	always @(posedge clock) begin
		if(wr) begin
			valid <= 1'b1;
			current_tag <= tag;
			data_memory <= data;
		end
	end

	assign data = ((wr) ? 1 : hit) ? data_memory : {DATA_ALL{1'bz}};

endmodule
