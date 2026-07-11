module lru #(
	parameter ADDRESS_SIZE = 32,
	parameter ASSOCIATIVITY = 4 // Número de vias
)(
	input wire [ADDRESS_SIZE-1:0] address,
	input wire [ASSOCIATIVITY-1:0] hits,
	input wire enable,
	input wire wr,
	input wire clock,
	output wire [ASSOCIATIVITY-1:0] victims
);
	wire [$clog2(ASSOCIATIVITY)-1:0] victim_index;
	reg [$clog2(ASSOCIATIVITY)-1:0] victim_index_reg;
	
	priority_encoder#(.WIDTH(ASSOCIATIVITY)) encoder (victims, victim_index);

	reg reference [ASSOCIATIVITY*(ASSOCIATIVITY-1)/2-1:0];
	wire [ASSOCIATIVITY-1:0] matrix_reference [ASSOCIATIVITY-1:0];

	generate
		genvar i;
		genvar j;
		// Os laços for internos do generate ganharam os nomes "matrix_row_gen" e "matrix_col_gen"
		for(i = 0; i < ASSOCIATIVITY; i=i+1) begin : matrix_row_gen
			for(j = 0; j < ASSOCIATIVITY; j=j+1) begin : matrix_col_gen
				if(i==j) begin
					assign matrix_reference[i][j] = 1'b1;
				end
				else if(i>j) begin
					assign matrix_reference[i][j] = reference[i*(i-1)/2+j];
				end
				else begin
					assign matrix_reference[i][j] = ~reference[j*(j-1)/2+i];
				end
			end
		end
	endgenerate

	generate
		genvar k;
		// Laço for nomeado como "gen_victim_bits"
		for(k=0; k < ASSOCIATIVITY; k=k+1) begin : gen_victim_bits
			assign victims[k] = &matrix_reference[k];
		end
	endgenerate

	always @(posedge clock) begin
		victim_index_reg <= victim_index;
	end

	always @(posedge clock) begin
		begin: update
			integer x;
			integer y;
			integer z;
			if(enable) begin
				for(x=1; x < ASSOCIATIVITY; x=x+1) begin
					for(y=0; y < x; y=y+1) begin
						z = x*(x-1)/2+y;
						if(x[$clog2(ASSOCIATIVITY)-1:0] == victim_index) begin
							reference[z] <= 1'b0;
						end
						else if(y[$clog2(ASSOCIATIVITY)-1:0] == victim_index) begin
							// CORRIGIDO AQUI: O erro 10260 acontecia porque estava 0'b1
							reference[z] <= 1'b1; 
						end
					end
				end
			end
		end
	end
endmodule