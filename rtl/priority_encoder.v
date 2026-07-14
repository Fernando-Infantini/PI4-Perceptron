module priority_encoder#(
	parameter WIDTH = 4 // Número de bits de entrada
)(
	input wire [WIDTH-1:0] uncoded_bits,            // Vetor de entrada não codificado
	output reg [$clog2(WIDTH)-1:0] encoded_bits     // Índice do bit mais prioritário (menor índice ganha)
);
	wire [WIDTH-1:0] p_uncoded_bits;

	// O bit 0 sempre tem prioridade máxima se estiver em nível lógico alto
	assign p_uncoded_bits[0] = uncoded_bits[0];
	
	// Mascara os bits subsequentes: um bit superior só repassa 1 se ele for 1 e NENHUM bit abaixo dele for 1
	generate
		genvar i;
		for(i=1; i<WIDTH; i=i+1) begin: priority_loop
			assign p_uncoded_bits[i] = uncoded_bits[i] & ~|uncoded_bits[i-1:0];
		end
	endgenerate

	// Bloco combinacional que codifica a posição ativa no vetor mascarado em um valor binário
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