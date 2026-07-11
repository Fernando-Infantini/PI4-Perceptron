module priority_encoder#(
	parameter WIDTH = 4
)(
	input wire [WIDTH-1:0] uncoded_bits,
	output reg [$clog2(WIDTH)-1:0] encoded_bits
);
	wire [WIDTH-1:0] p_uncoded_bits;

	assign p_uncoded_bits[0] = uncoded_bits[0];
	
	generate
		genvar i;
		for(i=1; i<WIDTH; i=i+1) begin: priority_loop
			assign p_uncoded_bits[i] = uncoded_bits[i] & ~|uncoded_bits[i-1:0];
		end
	endgenerate

	always @(*) begin
		encoded_bits = 0;
		begin: encode_gen
			integer j;
			for(j=0; j<WIDTH; j=j+1) begin
				if(p_uncoded_bits[j]) begin
					encoded_bits = j[$clog2(WIDTH)-1:0];
				end
			end
		end
	end

endmodule