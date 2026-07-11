module way #(
    parameter ADDRESS_SIZE = 32,
    parameter DATA_SIZE = 32,
    parameter BLOCK_SIZE = 4,
    parameter N_BLOCKS = 256
)(
    input wire [ADDRESS_SIZE-$clog2(N_BLOCKS==1?2:N_BLOCKS)-$clog2(BLOCK_SIZE)-1:0] tag,
    input wire [$clog2(N_BLOCKS==1?2:N_BLOCKS)-1:0] index,
    inout wire [DATA_SIZE*BLOCK_SIZE-1:0] data,
    input wire wr,
    output wire hit,
    input wire clock
);
    localparam T_N_BLOCKS = (N_BLOCKS==1) ? 2 : N_BLOCKS;
    localparam LINE_TAG = ADDRESS_SIZE-$clog2(T_N_BLOCKS)-$clog2(BLOCK_SIZE);
    localparam META_ALL = 1 + LINE_TAG;
    localparam VALID = META_ALL - 1; 
    localparam DATA_ALL = DATA_SIZE*BLOCK_SIZE;

    // Selecionar tipo de memória
    (* ramstyle = "M9K" *) reg [META_ALL-1:0] meta_memory [T_N_BLOCKS-1:0];
    (* ramstyle = "M9K" *) reg [DATA_ALL-1:0] data_memory [T_N_BLOCKS-1:0];

	initial begin
        begin: reset
            integer i;
            for(i=0; i<T_N_BLOCKS; i=i+1) begin
                 meta_memory[i] = {META_ALL{1'b0}};
                 data_memory[i] = {DATA_ALL{1'b0}};
            end
        end
    end

    reg [META_ALL-1:0] meta_read_reg;
    reg [DATA_ALL-1:0] data_read_reg;

    // Fio para isolar a entrada de dados (evita o loop do inout)
    wire [DATA_ALL-1:0] data_in_wire = data;

    always @(posedge clock) begin
        if(wr) begin
            meta_memory[index] <= {1'b1, tag};
            data_memory[index] <= data_in_wire; // Lê do fio isolado
        end
        meta_read_reg <= meta_memory[index];
        data_read_reg <= data_memory[index];
    end

    wire valid_bit = meta_read_reg[VALID];
    wire [LINE_TAG-1:0] current_tag = meta_read_reg[LINE_TAG-1:0];

    assign hit = valid_bit && (current_tag == tag);

    // =========================================================================
    // A memória só empurra o dado para fora se for uma LEITURA (!wr) e der HIT.
    // Se wr for 1 (escrita), ela fica "muda" (1'bz) para o controlador poder escrever.
    // =========================================================================
    assign data = (!wr && hit) ? data_read_reg : {DATA_ALL{1'bz}};

endmodule