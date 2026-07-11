module top_cache_total (
    input wire clock,
    
    // Conexões da L1
    input wire [31:0] l1_addr_in,
    inout wire [31:0] l1_data_in,
    input wire l1_req,
    input wire l1_wr,
    output wire l1_ready,
    
    // Conexões da L2
    input wire [31:0] l2_addr_in,
    inout wire [31:0] l2_data_in,
    input wire l2_req,
    input wire l2_wr,
    output wire l2_ready
);

    // ========================================================================
    // CORREÇÃO 2: Fios tri0 evitam que a memória leia 'Z' e exploda o FPGA.
    // ========================================================================
    tri0 [127:0] l1_data_out_dummy;
    tri0 [127:0] l2_data_out_dummy;

    cache #(
        .ADDRESS_SIZE(32),
        .DATA_SIZE(32),
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(2),
        .N_BLOCKS(32),     // Tamanho Real L1
        .ALGORITHM(1) 
    ) cache_l1 (
        .address_in(l1_addr_in),
        .data_in(l1_data_in),
        .req(l1_req),
        .wr(l1_wr),
        .ready(l1_ready),
        .clk(clock),
        .address_out(),
        .data_out(l1_data_out_dummy), // Lê 0s em vez de Z
        .ce(),
        .we(),
        .ack(1'b0),                   // Finge que a memória principal sempre responde na hora
        .clk_out()
    );

    cache #(
        .ADDRESS_SIZE(32),
        .DATA_SIZE(32),
        .BLOCK_SIZE(4),
        .ASSOCIATIVITY(8),
        .N_BLOCKS(64),     // Tamanho Real L2
        .ALGORITHM(1) 
    ) cache_l2 (
        .address_in(l2_addr_in),
        .data_in(l2_data_in),
        .req(l2_req),
        .wr(l2_wr),
        .ready(l2_ready),
        .clk(clock),
        .address_out(),
        .data_out(l2_data_out_dummy), // Lê 0s em vez de Z
        .ce(),
        .we(),
        .ack(1'b0),                   // Finge que a memória principal sempre responde na hora
        .clk_out()
    );

endmodule