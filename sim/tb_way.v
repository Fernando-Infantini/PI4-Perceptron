module tb_way;

	reg clock;
	reg [3:0] address;
	reg wr; 
	reg [3:0] data_w;
	wire [3:0] data = (wr) ? data_w : 4'bz;
	wire hit;

	way #(.ADDRESS_SIZE(4), .DATA_SIZE(4), .BLOCK_SIZE(1), .N_BLOCKS(4)) memoria (address[3:2], address[1:0], data, wr, hit, clock);

	initial begin
		$dumpfile("way.vcd");
		$dumpvars(0, tb_way);
		$dumpvars(0, memoria);
	end

	initial begin : bloco_leitura 
		integer file;
		integer accesses;
		integer a;  
		integer d;  
		integer rr; 

		file = $fopen("things.in", "r");

		#1 while(!$feof(file)) begin
			$fscanf(file, "%d %d %d\n", a, d, rr);
			address = a[3:0];
			data_w = d[3:0];
			wr = rr[0];
			$display("%d %d %d\n", a, d, rr);
			#10;
		end

		$fclose(file);
		$finish;
	end

	initial begin
		clock = 0;
	end

	always begin
		#5 clock = ~clock;
	end
endmodule