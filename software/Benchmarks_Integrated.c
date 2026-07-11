#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

extern uint64_t l1_hits;
extern uint64_t l1_misses;
extern uint64_t l2_hits;
extern uint64_t l2_misses;

void init_cache(void);
void access_cache_L1(uintptr_t addr, int use_perceptron_l1, int use_perceptron_l2);
void print_weights(int show_l1, int show_l2);

#define L2_SIZE_BYTES (32 * 1024) 
#define ARRAY_SIZE    (L2_SIZE_BYTES * 2 / sizeof(int))

#define START_PERF() printf("\n[Iniciando medição...]\n")
#define END_PERF()   printf("[Fim da medição.]\n\n")

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void print_results(int use_l1, int use_l2) {
    double l1_hr = (l1_hits + l1_misses > 0) ? (100.0 * l1_hits / (l1_hits + l1_misses)) : 0.0;
    double l2_hr = (l2_hits + l2_misses > 0) ? (100.0 * l2_hits / (l2_hits + l2_misses)) : 0.0;
    
    uint64_t total_cpu_accesses = l1_hits + l1_misses;
    double global_hr = (total_cpu_accesses > 0) ? (100.0 * (l1_hits + l2_hits) / total_cpu_accesses) : 0.0;

    printf(">> Resultados L1     | Hits: %-8lu | Misses: %-8lu | Hit Rate L1: %.2f%%\n", l1_hits, l1_misses, l1_hr);
    printf(">> Resultados L2     | Hits: %-8lu | Misses: %-8lu | Hit Rate L2: %.2f%%\n", l2_hits, l2_misses, l2_hr);
    printf(">> HIT RATE GLOBAL   | %.2f%% (Referência para a Tabela)\n", global_hr);
    
    if (use_l1 || use_l2) {
        print_weights(use_l1, use_l2);
    }
    printf("--------------------------------------------------------------------------\n");
}

void run_streaming(int *array, volatile int *hot_data, int use_l1, int use_l2) {
    printf("Executando: Streaming + HotSet (Antagonista ao LRU)\n");
    init_cache();
    START_PERF();
    for (int it = 0; it < 10; it++) {
        for (int i = 0; i < ARRAY_SIZE; i++) {
            access_cache_L1((uintptr_t)&array[i], use_l1, use_l2);
            array[i] += i;
            if (i % 64 == 0) {
                access_cache_L1((uintptr_t)hot_data, use_l1, use_l2);
                *hot_data += array[i]; 
            }
        }
    }
    END_PERF();
    print_results(use_l1, use_l2);
}

void run_matrix_conv(int *matrix, int *out, int use_l1, int use_l2) {
    printf("Executando: Matrix Convolution Simulada\n");
    init_cache();
    int dim = 128;
    START_PERF();
    for(int r = 1; r < dim - 1; r++){
        for(int c = 1; c < dim - 1; c++){
            int sum = 0;
            for(int i = -1; i <= 1; i++){
                for(int j = -1; j <= 1; j++){
                    int idx = (r + i) * dim + (c + j);
                    access_cache_L1((uintptr_t)&matrix[idx], use_l1, use_l2);
                    sum += matrix[idx];
                }
            }
            access_cache_L1((uintptr_t)&out[r * dim + c], use_l1, use_l2);
            out[r * dim + c] = sum / 9;
        }
    }
    END_PERF();
    print_results(use_l1, use_l2);
}

void run_linked_list(Node *head, int iters, int use_l1, int use_l2) {
    printf("Executando: Linked List Traversal (Pointer Chasing)\n");
    init_cache();
    START_PERF();
    Node *curr = head;
    for(int i = 0; i < iters * 10; i++) {
        access_cache_L1((uintptr_t)curr, use_l1, use_l2);
        curr->data++;
        curr = curr->next;
    }
    END_PERF();
    print_results(use_l1, use_l2);
}

void run_pattern_search(uint8_t *blob, int size, int use_l1, int use_l2) {
    printf("Executando: Pattern Search (Unified Stress - Iterativo/Capacidade)\n");
    init_cache();
    
    // Forçamos o tamanho a ser o dobro se passarmos o blob maior
    int real_size = size * 4; 
    
    START_PERF();
    int found = 0;
    
    // Adicionado laço de repetição para gerar LOCALIDADE TEMPORAL
    for (int iter = 0; iter < 5; iter++) {
        for(int i = 0; i < real_size - 4; i++) {
            access_cache_L1((uintptr_t)&blob[i], use_l1, use_l2);
            if(blob[i] == 0xDE && blob[i+1] == 0xAD) {
                found++;
            }
        }
    }
    END_PERF();
    print_results(use_l1, use_l2);
}

void print_config_menu() {
    printf("\n===========================================\n");
    printf("   SIMULADOR DE CACHE RISC-V (L1 + L2)     \n");
    printf("===========================================\n");
    printf("0. L1: LRU        | L2: LRU (Padrão)\n");
    printf("1. L1: Perceptron | L2: Perceptron\n");
    printf("2. L1: Perceptron | L2: LRU (Misto A)\n");
    printf("3. L1: LRU        | L2: Perceptron (Misto B)\n");
    printf("4. Sair\n");
    printf("Escolha a configuração da hierarquia: ");
}

void print_bench_menu() {
    printf("\n==== BENCHMARKS DISPONIVEIS ====\n");
    printf("1. Streaming + HotSet\n");
    printf("2. Matrix Convolution\n");
    printf("3. Linked List Traversal\n");
    printf("4. Pattern Search\n");
    printf("5. Executar Todos em Sequencia\n");
    printf("0. Voltar ao Menu Principal\n");
    printf("Escolha uma opcao: ");
}

int main() {
    int config_choice = -1;
    int bench_choice = -1;
    int use_l1 = 0, use_l2 = 0;
    volatile int hot_val = 0;

    int *big_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    int *out_array = (int *)calloc(ARRAY_SIZE, sizeof(int));
    uint8_t *blob   = (uint8_t *)malloc(L2_SIZE_BYTES*4);
    
    Node *nodes = (Node *)malloc(10000 * sizeof(Node));
    for(int i = 0; i < 9999; i++) nodes[i].next = &nodes[i+1];
    nodes[9999].next = &nodes[0];

    while (1) {
        print_config_menu();
        if (scanf("%d", &config_choice) != 1) break;
        if (config_choice == 4) break;
        
        if (config_choice == 0) { use_l1 = 0; use_l2 = 0; }
        else if (config_choice == 1) { use_l1 = 1; use_l2 = 1; }
        else if (config_choice == 2) { use_l1 = 1; use_l2 = 0; }
        else if (config_choice == 3) { use_l1 = 0; use_l2 = 1; }
        else { printf("Opcao invalida.\n"); continue; }

        while (1) {
            print_bench_menu();
            if (scanf("%d", &bench_choice) != 1) break;
            if (bench_choice == 0) break;

            printf("\n-> Modo: L1=%s | L2=%s\n", use_l1 ? "PERCEPTRON" : "LRU", use_l2 ? "PERCEPTRON" : "LRU");

            switch (bench_choice) {
                case 1: run_streaming(big_array, &hot_val, use_l1, use_l2); break;
                case 2: run_matrix_conv(big_array, out_array, use_l1, use_l2); break;
                case 3: run_linked_list(nodes, 10000, use_l1, use_l2); break;
                case 4: run_pattern_search(blob, L2_SIZE_BYTES, use_l1, use_l2); break;
                case 5:
                    run_streaming(big_array, &hot_val, use_l1, use_l2);
                    run_matrix_conv(big_array, out_array, use_l1, use_l2);
                    run_linked_list(nodes, 10000, use_l1, use_l2);
                    run_pattern_search(blob, L2_SIZE_BYTES, use_l1, use_l2);
                    break;
                default: printf("Opcao invalida!\n");
            }
        }
    }

    free(big_array); free(out_array); free(nodes); free(blob);
    printf("Encerrando simulador...\n");
    return 0;
}