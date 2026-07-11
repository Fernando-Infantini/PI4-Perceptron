module tb_cache;
    reg clock;
    reg [3:0] data_w;
    reg [7:0] address_in;
    reg req;
    reg wr;
    wire [3:0] data_in = (wr) ? data_w : 4'bz;
    wire ready;

    wire [7:0] address_out;
    wire [3:0] data_out;
    wire ce, we;
    wire ack = 1'b0; // Mantido em 0 para testar latência de Miss corretamente
    wire clock_out;

    cache #(.ADDRESS_SIZE(8), .DATA_SIZE(4), .BLOCK_SIZE(1), .ASSOCIATIVITY(4), .N_BLOCKS(1)) memoria (
        address_in, data_in, req, wr, ready, clock, address_out, data_out, ce, we, ack, clock_out
    );

    // Gerador de Clock
    initial clock = 0;
    always #5 clock = ~clock;

    initial begin : bloco_leitura
        integer file, status, a, d, rr;
        
        req = 0; wr = 0; address_in = 0; data_w = 0;
        
        file = $fopen("things.in", "r");
        if (file == 0) begin
            $display("Erro ao abrir things.in");
            $finish;
        end

        @(negedge clock); 
        req = 1;

        while(!$feof(file)) begin
            status = $fscanf(file, "%d %d %d\n", a, d, rr);
            if (status != 3) $finish;
            
            address_in = a[7:0];
            data_w = d[3:0];
            wr = rr[0];
            
            @(posedge clock); 
            #1; // Delay propagacional visual
            
            if (wr == 0 && ready == 0) begin
                // Simulador de Memória Externa em caso de Miss
                wr = 1; 
                @(posedge clock);
                #1; 
                wr = 0;
            end
        end

        $fclose(file);
        #20 $finish;
    end
endmodule