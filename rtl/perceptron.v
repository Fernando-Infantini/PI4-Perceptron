module perceptron #(
    parameter ADDRESS_SIZE = 32,
    parameter ASSOCIATIVITY = 4,
    parameter N_BLOCKS = 256
)(
    input wire [ADDRESS_SIZE-1:0] address,
    input wire [$clog2(N_BLOCKS==1?2:N_BLOCKS)-1:0] index, 
    input wire [ASSOCIATIVITY-1:0] hits,
    input wire enable,
    input wire wr,
    input wire clock,
    output reg [ASSOCIATIVITY-1:0] victims 
);

    localparam T_N_BLOCKS = (N_BLOCKS==1) ? 2 : N_BLOCKS;

    // ========================================================================
    // FEATURES E VALIDADE MAPEADAS EM MATRIZES 
    // Matrizes que guardam os metadados de histórico de cada linha e via
    // ========================================================================
    reg [ASSOCIATIVITY-1:0] valid [0:T_N_BLOCKS-1];
    reg [ASSOCIATIVITY-1:0] way_reused [0:T_N_BLOCKS-1]; // Feature: foi reusada?
    reg [ASSOCIATIVITY-1:0] way_tag0 [0:T_N_BLOCKS-1];   // Feature: bit 0 da tag
    reg [ASSOCIATIVITY-1:0] way_tag1 [0:T_N_BLOCKS-1];   // Feature: bit 1 da tag

    // PESOS DO PERCEPTRON POR LINHA (6 bits assinados permitindo range de -32 a +31)
    reg signed [5:0] w_bias [0:T_N_BLOCKS-1];
    reg signed [5:0] w_tag0 [0:T_N_BLOCKS-1];
    reg signed [5:0] w_tag1 [0:T_N_BLOCKS-1];
    reg signed [5:0] w_reused [0:T_N_BLOCKS-1];

    // Extração de features baseada no endereço atual
    wire curr_tag0 = address[0];
    wire curr_tag1 = address[1];

    // Inicialização da tabela de pesos e estados (zera a RAM de histórico)
    initial begin
        begin: reset_ram
            integer i;
            for (i = 0; i < T_N_BLOCKS; i = i + 1) begin
                valid[i] = 0; way_reused[i] = 0; way_tag0[i] = 0; way_tag1[i] = 0;
                w_bias[i] = 0; w_tag0[i] = 0; w_tag1[i] = 0; w_reused[i] = 0;
            end
        end
    end

    // ========================================================================
    // CÁLCULO DO PERCEPTRON (Lógica Combinacional)
    // ========================================================================
    reg signed [7:0] score [0:ASSOCIATIVITY-1];
    
    always @(*) begin
        begin: select_victim
            integer best_way;
            reg signed [7:0] min_score;
            integer k;
            
            victims = 0;
            best_way = 0;
            min_score = 127; // +127: Maior valor inicial positivo (pior caso)

            // Prioridade absoluta para vias vazias (evita descartar dados se houver espaço livre)
            for (k = 0; k < ASSOCIATIVITY; k = k + 1) begin
                if (!valid[index][k]) begin
                    best_way = k;
                    min_score = -128; // -128: Força a escolha imediata desta via (melhor caso)
                end
            end

            // Se todas as vias daquele index estão cheias, calcula o Score do Perceptron
            if (min_score != -128) begin
                for (k = 0; k < ASSOCIATIVITY; k = k + 1) begin
                    // Produto Escalar adaptado para features binárias. Se feature = 1, soma peso. Se 0, subtrai.
                    score[k] = w_bias[index] +
                               (way_tag0[index][k]   ? w_tag0[index]   : -w_tag0[index]) +
                               (way_tag1[index][k]   ? w_tag1[index]   : -w_tag1[index]) +
                               (way_reused[index][k] ? w_reused[index] : -w_reused[index]);

                    // A via com menor pontuação (menor chance de reuso predito) vira a vítima
                    if (score[k] < min_score) begin
                        min_score = score[k];
                        best_way = k;
                    end
                end
            end
            victims[best_way] = 1'b1; // Seta o bit da vítima escolhida
        end
    end

    // ========================================================================
    // TREINAMENTO E ATUALIZAÇÃO SÍNCRONA
    // ========================================================================
    always @(posedge clock) begin
        if (enable) begin
            begin: training_block
                integer j;
                if (|hits) begin
                    // CENÁRIO A: HIT (A previsão anterior foi certa ou estamos ganhando confiança)
                    for (j = 0; j < ASSOCIATIVITY; j = j + 1) begin
                        if (hits[j]) begin
                            way_reused[index][j] <= 1'b1;
                            way_tag0[index][j]   <= curr_tag0;
                            way_tag1[index][j]   <= curr_tag1;

                            // Atualiza os pesos favorecendo os acertos (Limitando com saturação +31 / -32)
                            if (w_bias[index] < 31) w_bias[index] <= w_bias[index] + 1;
                            if (way_tag0[index][j])   begin if (w_tag0[index] < 31) w_tag0[index] <= w_tag0[index] + 1; end else begin if (w_tag0[index] > -32) w_tag0[index] <= w_tag0[index] - 1; end
                            if (way_tag1[index][j])   begin if (w_tag1[index] < 31) w_tag1[index] <= w_tag1[index] + 1; end else begin if (w_tag1[index] > -32) w_tag1[index] <= w_tag1[index] - 1; end
                            if (way_reused[index][j]) begin if (w_reused[index] < 31) w_reused[index] <= w_reused[index] + 1; end else begin if (w_reused[index] > -32) w_reused[index] <= w_reused[index] - 1; end
                        end
                    end
                end else begin
                    // CENÁRIO B: MISS (Houve um erro de previsão ou é uma carga nova)
                    for (j = 0; j < ASSOCIATIVITY; j = j + 1) begin
                        if (victims[j]) begin
                            valid[index][j]      <= 1'b1;
                            way_reused[index][j] <= 1'b0;
                            way_tag0[index][j]   <= curr_tag0;
                            way_tag1[index][j]   <= curr_tag1;

                            // Penaliza os pesos devido ao Miss
                            if (w_bias[index] > -32) w_bias[index] <= w_bias[index] - 1;
                            if (way_tag0[index][j])   begin if (w_tag0[index] > -32) w_tag0[index] <= w_tag0[index] - 1; end else begin if (w_tag0[index] < 31) w_tag0[index] <= w_tag0[index] + 1; end
                            if (way_tag1[index][j])   begin if (w_tag1[index] > -32) w_tag1[index] <= w_tag1[index] - 1; end else begin if (w_tag1[index] < 31) w_tag1[index] <= w_tag1[index] + 1; end
                            if (way_reused[index][j]) begin if (w_reused[index] > -32) w_reused[index] <= w_reused[index] - 1; end else begin if (w_reused[index] < 31) w_reused[index] <= w_reused[index] + 1; end
                        end
                    end
                end
            end
        end
    end

endmodule