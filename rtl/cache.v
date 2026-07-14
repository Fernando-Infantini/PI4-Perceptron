module cache #(
    parameter ADDRESS_SIZE = 32,
    parameter DATA_SIZE = 32,    // Tamanho da palavra em bits
    parameter BLOCK_SIZE = 4,    // Palavras por bloco
    parameter ASSOCIATIVITY = 4, // Numero de vias (1 = Mapeamento Direto)
    parameter N_BLOCKS = 256,    // Blocos por via
    parameter ALGORITHM = 1      // 0 para LRU, 1 para Perceptron
)(
    // Pinos voltados para a CPU
    input wire [ADDRESS_SIZE-1:0] address_in,
    inout wire [DATA_SIZE-1:0] data_in,
    input wire req,
    input wire wr,
    output wire ready,
    input wire clk,

    // Pinos voltados para a Memória Principal
    output wire [ADDRESS_SIZE-1:0] address_out,
    inout  wire [DATA_SIZE*BLOCK_SIZE-1:0] data_out,
    output wire ce,
    output wire we,
    input wire ack,
    output wire clk_out
);

    // Extração da TAG baseada no tamanho do endereço e bits de índice/offset
    wire [ADDRESS_SIZE-$clog2(N_BLOCKS==1?2:N_BLOCKS)-$clog2(BLOCK_SIZE)-1:0] tag;
    assign tag = address_in[ADDRESS_SIZE-1 : $clog2(N_BLOCKS==1?2:N_BLOCKS)+$clog2(BLOCK_SIZE)];

    // Extração do INDEX (linha da cache) tratando o edge-case de cache totalmente associativa (N_BLOCKS=1)
    localparam T_N_BLOCKS = (N_BLOCKS==1) ? 2 : N_BLOCKS;
    wire [$clog2(T_N_BLOCKS)-1:0] index;
    generate
        if (N_BLOCKS == 1) begin: gen_index_1
            assign index = 1'b0; // Sem índice se houver apenas 1 bloco por via
        end else begin: gen_index_n
            assign index = address_in[$clog2(T_N_BLOCKS)+$clog2(BLOCK_SIZE)-1 : $clog2(BLOCK_SIZE)];
        end
    endgenerate

    wire is_hit; 

    // Geração condicional baseada na associatividade (Direto vs Associativo)
    generate
        if (ASSOCIATIVITY == 1) begin: direto_block
            // Instanciação para Cache de Mapeamento Direto (Apenas 1 via)
            wire way_hit;
            wire way_wr = req && wr;
            wire [DATA_SIZE*BLOCK_SIZE-1:0] internal_data_bus;

            way #(
                .ADDRESS_SIZE(ADDRESS_SIZE),
                .DATA_SIZE(DATA_SIZE),
                .BLOCK_SIZE(BLOCK_SIZE),
                .N_BLOCKS(N_BLOCKS)
            ) single_way (
                .tag(tag),
                .index(index),
                .data(internal_data_bus),
                .wr(way_wr),
                .hit(way_hit),
                .clock(clk)
            );

            assign is_hit = way_hit;
            assign data_in = (!wr && is_hit) ? internal_data_bus[DATA_SIZE-1:0] : {DATA_SIZE{1'bz}};
            assign internal_data_bus = (wr) ? {BLOCK_SIZE{data_in}} : {DATA_SIZE*BLOCK_SIZE{1'bz}};

        end else begin: associativo_block
            // Instanciação para Cache Associativa em Conjuntos
            wire [ASSOCIATIVITY-1:0] hits;
            wire [ASSOCIATIVITY-1:0] way_wr;
            wire [DATA_SIZE*BLOCK_SIZE-1:0] internal_data_bus;
            
            // Fio que recebe a decisão do algoritmo de substituição de qual via deve ser evictada
            wire [ASSOCIATIVITY-1:0] victims_out;

            // Instancia o controlador central de política de substituição (LRU ou Perceptron)
            algorithm #(
                .ADDRESS_SIZE(ADDRESS_SIZE), 
                .ASSOCIATIVITY(ASSOCIATIVITY),
                .N_BLOCKS(N_BLOCKS),
                .ALGORITHM(ALGORITHM)
            ) central_algorithm (
                .address(address_in), 
                .index(index),        
                .hits(hits), 
                .enable(req),         
                .wr(wr), 
                .clock(clk), 
                .victims(victims_out) 
            );

            // Gera as N vias da cache de forma parametrizada
            begin: gen_ways
                genvar i;
                for(i=0; i<ASSOCIATIVITY; i=i+1) begin: way_loop
                    // Habilita escrita na via 'i' SE: houver requisição E escrita E (foi um hit nesta via OU ela foi a vítima escolhida no miss)
                    assign way_wr[i] = req && wr && ( (|hits) ? hits[i] : victims_out[i] );
                    
                    way #(
                        .ADDRESS_SIZE(ADDRESS_SIZE),
                        .DATA_SIZE(DATA_SIZE),
                        .BLOCK_SIZE(BLOCK_SIZE),
                        .N_BLOCKS(N_BLOCKS)
                    ) ways (
                        .tag(tag),
                        .index(index),
                        .data(internal_data_bus),
                        .wr(way_wr[i]),
                        .hit(hits[i]),
                        .clock(clk)
                    );
                end
            end
            
            // Hit global ocorre se qualquer uma das vias der hit
            assign is_hit = |hits;

            // Roteamento de dados da via correta para a CPU ou da CPU para a via
            assign data_in = (!wr && is_hit) ? internal_data_bus[DATA_SIZE-1:0] : {DATA_SIZE{1'bz}};
            assign internal_data_bus = (wr) ? {BLOCK_SIZE{data_in}} : {DATA_SIZE*BLOCK_SIZE{1'bz}};
        end
    endgenerate

    // Sinais de controle para a CPU e para a Memória Principal
    assign ready = req && (is_hit || ack);          // Cache pronta se hit ou se a memória respondeu
    assign ce = req && !is_hit;                     // Chip Enable para memória em caso de miss
    assign we = req && wr && !is_hit;               // Write Enable para memória
    
    assign clk_out = clk; 
    assign address_out = address_in;
    assign data_out = (wr && !is_hit) ? {BLOCK_SIZE{data_in}} : {(DATA_SIZE*BLOCK_SIZE){1'bz}};

endmodule