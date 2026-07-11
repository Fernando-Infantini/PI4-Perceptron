# Projeto Integrador IV: Caches Inteligentes em RISC-V (Perceptron)

**Disciplina:** Projeto Integrador IV - 2026/1
**Professor:** Bruno S. Neves
**Alunos:** Fernando Infantini, Ronaldy Gelos

## Objetivo
Implementação e avaliação do algoritmo de substituição de blocos **Perceptron** (Preditor baseado em pesos e produto escalar). O projeto busca superar o algoritmo padrão LRU, analisando o impacto na taxa de acertos, área de silício e frequência máxima em um FPGA Cyclone III.

## Estrutura do Repositório
* `/docs`: Relatório final (PDF), apresentação e gráficos consolidados de análise de sensibilidade e taxa de acertos.
* `/rtl`: Código fonte em Verilog dos módulos de cache (`cache.v`, `perceptron.v`, `lru.v` e `top_cache_total.v`).
* `/sim`: Testbenches (`tb_cache.v`, `tb_algorithm.v` e `tb_way`) e scripts de simulação.
* `/software`: Código-fonte em C dos benchmarks (`Benchmarks_Integrated.c`) e script Python de plotagem (`graficos.py`).
* `/synth`: Arquivos de síntese do Quartus II (`.rpt`, `.summary`) contendo análises de área e timing.

## Instruções de Uso

### 1. Simulação (RTL)
Navegue até a pasta `/sim` e utilize o simulador de sua preferência (ex: Modelsim) para compilar os testbenches contra os arquivos `.v` contidos na pasta `/rtl`. 
* **Atenção aos arquivos de entrada:** Os testbenches requerem arquivos de texto `.in` para injetar os estímulos de leitura/escrita na simulação. 
    * O `tb_cache.v` lê o arquivo `things.in`.
    * O `tb_algorithm.v` lê o arquivo `things_algo.in`.
* **Formato dos arquivos `.in`:** Cada linha deve conter 3 valores inteiros separados por espaço representando: `Endereço Dado Flag_LeituraEscrita` (ex: `15 4 0`).

### 2. Síntese (FPGA)
Abra os relatórios localizados em `/synth` para validar o RTL gerado. A síntese foi realizada no Intel Quartus visando o FPGA Cyclone III (EP3C25F324C6) e avaliando isoladamente o módulo `top_cache_total` devido à indisponibilidade do RISC-V.

### 3. Benchmarks
O script `Gera_csv.c` processa os logs e gera a saída dos benchmarks que pode ser plotada utilizando o `graficos.py` (necessário Python 3 e Pandas).

## Resumo de Resultados (LRU vs Perceptron)

A tabela abaixo detalha o custo físico e o desempenho das quatro configurações possíveis entre os níveis de cache (L1 - L2). Os testes simulam forte estresse de memória executando o *benchmark* de Transposição de Matrizes. O impacto é calculado em relação ao baseline puramente LRU.

| Configuração (L1 - L2) | Taxa de Acerto Global (%) | Impacto no Acerto | Área (LEs) | Impacto na Área | Fmax (MHz) | Impacto em Fmax |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **LRU - LRU** (Baseline) | 46.87% | - | 4.385 un. | - | 90,92 MHz | - |
| **Perceptron - LRU** | 47.27% | + 0.40% | 6.684 un. | + 52.4% | 60,02 MHz | - 34.0% |
| **LRU - Perceptron** | 53.37% | + 6.50% | 8.030 un. | + 83.1% | 30,64 MHz | - 66.3% |
| **Perceptron - Perceptron**| 54.19% | + 7.32% | 10.848 un. | + 147.3% | 28,93 MHz | - 68.1% |
