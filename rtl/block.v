module block #(
	parameter ADDRESS_SIZE = 32,
	parameter DATA_SIZE = 32, // Tamanho de uma palavra em bits
	parameter BLOCK_SIZE = 4  // Quantidade de palavras que um bloco armazena
)(
	input wire [ADDRESS_SIZE-$clog2(BLOCK_SIZE)-1:0] tag, // Endereço da tag de entrada
	inout wire [DATA_SIZE*BLOCK_SIZE-1:0] data,           // Barramento bidirecional de dados
	input wire wr,                                        // Sinal de habilitação de escrita
	output wire hit,                                      // Sinaliza se houve acerto (Hit)
	input wire clock                                      // Clock do sistema
);
	// Cálculo do tamanho dos registradores internos
	localparam TAG_ALL = ADDRESS_SIZE-$clog2(BLOCK_SIZE);
	localparam DATA_ALL = DATA_SIZE*BLOCK_SIZE;

	// Registradores de armazenamento interno do bloco
	reg valid;
	reg [TAG_ALL-1:0] current_tag;
	reg [DATA_ALL-1:0] data_memory;

	// Inicialização do bloco (limpeza da tag no reset)
	initial begin
		begin: reset
			 current_tag = {TAG_ALL{1'b0}};
		end
	end

	// Lógica de Hit: Verifica se o bloco é válido e se a tag armazenada bate com a tag buscada
	assign hit = (valid && (current_tag == tag));

	// Escrita síncrona: Atualiza os dados, a tag e marca o bloco como válido
	always @(posedge clock) begin
		if(wr) begin
			valid <= 1'b1;
			current_tag <= tag;
			data_memory <= data;
		end
	end

	// Leitura assíncrona com controle de impedância (High-Z):
	// Se for escrita (wr=1) ou não der hit, a saída fica em alta impedância (Z).
	// Se for leitura (!wr) e der hit, coloca os dados no barramento.
	assign data = ((wr) ? 1 : hit) ? data_memory : {DATA_ALL{1'bz}};

endmodule