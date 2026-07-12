module tb_algorithm;

	reg clock;
	reg [3:0] address;
	reg [3:0] hits;
	wire [3:0] victims;

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
		$dumpvars(0, tb_algorithm);
		$dumpvars(0, algo);
	end

	initial begin
		integer file;
		integer status; 

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

				@(negedge clock); 
				address = a[3:0];
				hits = d[3:0];

				@(posedge clock);
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