module cache #(
    parameter ADDRESS_SIZE = 32,
    parameter DATA_SIZE = 32,    // Tamanho da palavra em bits
    parameter BLOCK_SIZE = 4,    // Palavras por bloco
    parameter ASSOCIATIVITY = 4, // Numero de vias
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

    // Extração da TAG e INDEX
    wire [ADDRESS_SIZE-$clog2(N_BLOCKS==1?2:N_BLOCKS)-$clog2(BLOCK_SIZE)-1:0] tag;
    assign tag = address_in[ADDRESS_SIZE-1 : $clog2(N_BLOCKS==1?2:N_BLOCKS)+$clog2(BLOCK_SIZE)];

    localparam T_N_BLOCKS = (N_BLOCKS==1) ? 2 : N_BLOCKS;
    wire [$clog2(T_N_BLOCKS)-1:0] index;
    generate
        if (N_BLOCKS == 1) begin: gen_index_1
            assign index = 1'b0;
        end else begin: gen_index_n
            assign index = address_in[$clog2(T_N_BLOCKS)+$clog2(BLOCK_SIZE)-1 : $clog2(BLOCK_SIZE)];
        end
    endgenerate

    // ==========================================
    // CORREÇÃO: Faltava declarar o is_hit aqui!
    // ==========================================
    wire is_hit; 

    generate
        if (ASSOCIATIVITY == 1) begin: direto_block
            // Bloco de mapeamento direto (mantido original)
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
            wire [ASSOCIATIVITY-1:0] hits;
            wire [ASSOCIATIVITY-1:0] way_wr;
            wire [DATA_SIZE*BLOCK_SIZE-1:0] internal_data_bus;
            
            // SAÍDA DE VÍTIMA CENTRALIZADA
            wire [ASSOCIATIVITY-1:0] victims_out;

            // O Cérebro Centralizado! Instanciado apenas UMA vez para todo o chip!
            algorithm #(
                .ADDRESS_SIZE(ADDRESS_SIZE), 
                .ASSOCIATIVITY(ASSOCIATIVITY),
                .N_BLOCKS(N_BLOCKS),
                .ALGORITHM(ALGORITHM)
            ) central_algorithm (
                .address(address_in), 
                .index(index),        // Informa a linha atual para o algoritmo
                .hits(hits), 
                .enable(req),         
                .wr(wr), 
                .clock(clk), 
                .victims(victims_out) 
            );

            begin: gen_ways
                genvar i;
                for(i=0; i<ASSOCIATIVITY; i=i+1) begin: way_loop
                    // Conexão direta com a decisão do algoritmo central
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
            
            assign is_hit = |hits;

            // A PONTE ENTRE A CPU E A CACHE
            assign data_in = (!wr && is_hit) ? internal_data_bus[DATA_SIZE-1:0] : {DATA_SIZE{1'bz}};
            assign internal_data_bus = (wr) ? {BLOCK_SIZE{data_in}} : {DATA_SIZE*BLOCK_SIZE{1'bz}};
        end
    endgenerate

    // LÓGICA DE CONTROLE CONTÍNUA
    assign ready = req && (is_hit || ack);
    assign ce = req && !is_hit;
    assign we = req && wr && !is_hit;
    
    assign clk_out = clk; 
    assign address_out = address_in;
    assign data_out = (wr && !is_hit) ? {BLOCK_SIZE{data_in}} : {(DATA_SIZE*BLOCK_SIZE){1'bz}};

endmodule