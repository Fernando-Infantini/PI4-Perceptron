module tb_algorithm;

	reg clock;
	reg [3:0] address;
	reg [3:0] hits;
	wire [3:0] victims;

	// CORREÇÃO 3: Mudado 1 e 0 para 1'b1 e 1'b0 (evita avisos de tamanho)
	// CORREÇÃO 4: Mudado ALGORITHM de 0 para 1 para testar o seu PERCEPTRON!
	algorithm #(.ADDRESS_SIZE(4), .ASSOCIATIVITY(4), .ALGORITHM(1)) algo (
		.address(address), 
		.hits(hits), 
		.enable(1'b1), 
		.wr(1'b0), 
		.clock(clock), 
		.victims(victims)
	);

	initial begin
		$dumpfile("algo.vcd");
		// CORREÇÃO 1: Mudado 'top' para 'tb_algorithm' para consertar o Erro Fatal
		$dumpvars(0, tb_algorithm);
		$dumpvars(0, algo);
	end

	initial begin
		integer file;
		integer status; // Variável necessária para o fscanf

		file = $fopen("things_algo.in", "r");
		if (file == 0) begin
			$display("Erro ao abrir things_algo.in");
			$finish;
		end

		while(!$feof(file)) begin
				integer a;
				integer d;
				integer rr;
				status = $fscanf(file, "%d %d %d\n", a, d, rr);

				// 1. Aplica os dados na descida do clock (quando o circuito está estável)
				@(negedge clock); 
				address = a[3:0];
				hits = d[3:0];

				// 2. Espera a borda de subida onde o Perceptron calcula e atualiza os pesos
				@(posedge clock);
				#1; // Espera 1ns para o sinal estabilizar antes de printar
				$display("Endereco testado: %d | Vetor de Hits da CPU: %b | Vitima escolhida: %b", a, d, victims);
			end

		$fclose(file);
		$finish;
	end

	initial begin
		clock = 1;
	end

	always begin
		#5 clock = ~clock;
	end
endmodule