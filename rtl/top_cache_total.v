module top_cache_total (
    input wire clock,
    
    // Conexões da interface da Cache L1 (Voltada para CPU)
    input wire [31:0] l1_addr_in,
    inout wire [31:0] l1_data_in,
    input wire l1_req,
    input wire l1_wr,
    output wire l1_ready,
    
    // Conexões da interface da Cache L2 (Poderia vir da L1 ou Memória)
    input wire [31:0] l2_addr_in,
    inout wire [31:0] l2_data_in,
    input wire l2_req,
    input wire l2_wr,
    output wire l2_ready
);

    // ========================================================================
    // Dummies: Fios tri0 evitam que a memória leia alta impedância ('Z')
    // e estrague a etapa de sintetização (Mapeamento de LEs) do FPGA.
    // ========================================================================
    tri0 [127:0] l1_data_out_dummy;
    tri0 [127:0] l2_data_out_dummy;

    // Instanciação da Cache L1 (Menor capacidade, menos vias, mais rápida)
    cache #(
        .ADDRESS_SIZE(32),
        .DATA_SIZE(32),
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(2), // L1: 2 Vias
        .N_BLOCKS(32),     
        .ALGORITHM(1)      // Usa Perceptron
    ) cache_l1 (
        .address_in(l1_addr_in),
        .data_in(l1_data_in),
        .req(l1_req),
        .wr(l1_wr),
        .ready(l1_ready),
        .clk(clock),
        .address_out(),               // Portas de saída desconectadas neste Wrapper
        .data_out(l1_data_out_dummy),
        .ce(),
        .we(),
        .ack(1'b0),                   
        .clk_out()
    );

    // Instanciação da Cache L2 (Maior capacidade, mais associatividade)
    cache #(
        .ADDRESS_SIZE(32),
        .DATA_SIZE(32),
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(8), // L2: 8 Vias
        .N_BLOCKS(64),     
        .ALGORITHM(1)      // Usa Perceptron
    ) cache_l2 (
        .address_in(l2_addr_in),
        .data_in(l2_data_in),
        .req(l2_req),
        .wr(l2_wr),
        .ready(l2_ready),
        .clk(clock),
        .address_out(),               // Portas de saída desconectadas neste Wrapper
        .data_out(l2_data_out_dummy), 
        .ce(),
        .we(),
        .ack(1'b0),                   
        .clk_out()
    );

endmodule