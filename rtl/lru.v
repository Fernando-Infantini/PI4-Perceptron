module lru #(
    parameter ADDRESS_SIZE = 32,
    parameter ASSOCIATIVITY = 4 // Número de vias
)(
    input wire [ADDRESS_SIZE-1:0] address, // Opcional para variações de LRU
    input wire [ASSOCIATIVITY-1:0] hits,   // Vetor indicando qual via deu hit
    input wire enable,
    input wire wr,
    input wire clock,
    output wire [ASSOCIATIVITY-1:0] victims // Indica via escolhida para substituição
);
    // 1. Identificar qual via foi acessada (Hit ou substituição no Miss)
    wire [$clog2(ASSOCIATIVITY)-1:0] victim_index;
    wire [$clog2(ASSOCIATIVITY)-1:0] hit_index;
    wire [$clog2(ASSOCIATIVITY)-1:0] access_index;
    wire is_hit;

    assign is_hit = |hits; // Sinalizador se houve qualquer hit

    // Encoders de prioridade para transformar os vetores de bits em índices binários
    priority_encoder#(.WIDTH(ASSOCIATIVITY)) victim_enc (victims, victim_index);
    priority_encoder#(.WIDTH(ASSOCIATIVITY)) hit_enc (hits, hit_index);

    // Se foi Hit, atualiza a via do Hit. Se foi Miss (e está habilitado), atualiza a via da vítima.
    assign access_index = is_hit ? hit_index : victim_index;

    // 2. Estrutura da Matriz pseudo-LRU
    reg reference [ASSOCIATIVITY*(ASSOCIATIVITY-1)/2-1:0];
    wire [ASSOCIATIVITY-1:0] matrix_reference [ASSOCIATIVITY-1:0];

    // CORREÇÃO: Inicializando a matriz pseudo-LRU com zeros para evitar o estado 'X' (Indefinido) na simulação
    initial begin : reset_matrix
        integer r;
        for(r=0; r < ASSOCIATIVITY*(ASSOCIATIVITY-1)/2; r=r+1) begin
            reference[r] = 1'b0;
        end
    end
    
    // Constrói a matriz lógica de referências cruzadas
    generate
        genvar i, j;
        for(i = 0; i < ASSOCIATIVITY; i=i+1) begin : matrix_row_gen
            for(j = 0; j < ASSOCIATIVITY; j=j+1) begin : matrix_col_gen
                if(i==j) begin
                    assign matrix_reference[i][j] = 1'b0; // Diagonal principal é 0
                end
                else if(i>j) begin
                    assign matrix_reference[i][j] = reference[i*(i-1)/2+j];
                end
                else begin
                    assign matrix_reference[i][j] = ~reference[j*(j-1)/2+i]; // Espelha e inverte
                end
            end
        end
    endgenerate

    // Identifica a vítima de acordo com a via que possui uma linha de zeros na matriz
    generate
        genvar k;
        for(k=0; k < ASSOCIATIVITY; k=k+1) begin : gen_victim_bits
            assign victims[k] = ~|matrix_reference[k]; 
        end
    endgenerate

    // 3. Atualização da Matriz no Posedge
    always @(posedge clock) begin : update
        integer x, y, z;
        // Atualiza os ponteiros se houver um Hit OU se houver um Miss com escrita/acesso habilitado
        if (is_hit || (enable && wr)) begin
            for(x=1; x < ASSOCIATIVITY; x=x+1) begin
                for(y=0; y < x; y=y+1) begin
                    z = x*(x-1)/2+y;
                    if(x[$clog2(ASSOCIATIVITY)-1:0] == access_index) begin
                        reference[z] <= 1'b1; 
                    end
                    else if(y[$clog2(ASSOCIATIVITY)-1:0] == access_index) begin
                        reference[z] <= 1'b0;
                    end
                end
            end
        end
    end
endmodule