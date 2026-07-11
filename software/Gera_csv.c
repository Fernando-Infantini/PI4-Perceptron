#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define MAX_WEIGHT 31   
#define MIN_WEIGHT -32
#define N 4

// Variáveis globais de controle de simulação dinâmicas
int BLOCK_SIZE_L1 = 32;
int SETS_L1       = 64;
int WAYS_L1       = 2;

int BLOCK_SIZE_L2 = 64;
int SETS_L2       = 64;
int WAYS_L2       = 8;

uint64_t l1_hits = 0;
uint64_t l1_misses = 0;
uint64_t l2_hits = 0;
uint64_t l2_misses = 0;

int w_l1[N] = {0, 0, 0, 0}; 
int w_l2[N] = {0, 0, 0, 0}; 

typedef struct {
    int valid;
    uint32_t tag;
    int lru;
    int reused;
    int x[N];
} Line;

// Alocação estática superdimensionada para permitir variação dinâmica de tamanho com segurança
Line cache_l1[256][4];   // Suporta até 256 conjuntos e 4 vias
Line cache_l2[512][16];  // Suporta até 512 conjuntos e 16 vias

typedef struct Node {
    int data;
    struct Node *next;
} Node;

// --- FUNÇÕES CORE DA CACHE ---
int predict(int x[N], int w[N]) {
    int y = 0;
    for (int i = 0; i < N; i++) y += w[i] * x[i];
    return y;
}

void train(int x[N], int w[N], int target) {
    int pred = (predict(x, w) >= 0) ? 1 : -1;
    if (pred != target) {
        for (int i = 0; i < N; i++) {
            w[i] += target * x[i];
            if (w[i] > MAX_WEIGHT) w[i] = MAX_WEIGHT;
            if (w[i] < MIN_WEIGHT) w[i] = MIN_WEIGHT;
        }
    }
}

void gen_features(uint32_t tag, int reused, int x[N]) {
    x[0] = 1;                           
    x[1] = (tag & 1) ? 1 : -1;          
    x[2] = ((tag >> 1) & 1) ? 1 : -1;   
    x[3] = reused ? 1 : -1;             
}

void init_cache() {
    for (int s = 0; s < 256; s++) {
        for (int i = 0; i < 4; i++) {
            cache_l1[s][i].valid = 0; cache_l1[s][i].lru = 0; cache_l1[s][i].reused = 0;
        }
    }
    for (int s = 0; s < 512; s++) {
        for (int i = 0; i < 16; i++) {
            cache_l2[s][i].valid = 0; cache_l2[s][i].lru = 0; cache_l2[s][i].reused = 0;
        }
    }
    for (int i = 0; i < N; i++) { w_l1[i] = 0; w_l2[i] = 0; }
    l1_hits = 0; l1_misses = 0;
    l2_hits = 0; l2_misses = 0;
}

void update_lru_l1(int set_idx, int used) {
    for (int i = 0; i < WAYS_L1; i++) {
        if (i == used) cache_l1[set_idx][i].lru = 0;
        else cache_l1[set_idx][i].lru++;
    }
}

void update_lru_l2(int set_idx, int used) {
    for (int i = 0; i < WAYS_L2; i++) {
        if (i == used) cache_l2[set_idx][i].lru = 0;
        else cache_l2[set_idx][i].lru++;
    }
}

int victim_perceptron_l1(int set_idx) {
    int v = 0, worst = predict(cache_l1[set_idx][0].x, w_l1);
    for (int i = 1; i < WAYS_L1; i++) {
        int score = predict(cache_l1[set_idx][i].x, w_l1);
        if (score < worst) { worst = score; v = i; }
    }
    return v;
}

int victim_perceptron_l2(int set_idx) {
    int v = 0, worst = predict(cache_l2[set_idx][0].x, w_l2);
    for (int i = 1; i < WAYS_L2; i++) {
        int score = predict(cache_l2[set_idx][i].x, w_l2);
        if (score < worst) { worst = score; v = i; }
    }
    return v;
}

int victim_lru_l1(int set_idx) {
    int v = 0;
    for (int i = 1; i < WAYS_L1; i++) if (cache_l1[set_idx][i].lru > cache_l1[set_idx][v].lru) v = i;
    return v;
}

int victim_lru_l2(int set_idx) {
    int v = 0;
    for (int i = 1; i < WAYS_L2; i++) if (cache_l2[set_idx][i].lru > cache_l2[set_idx][v].lru) v = i;
    return v;
}

void access_cache_L2(uintptr_t addr, int use_perceptron_l2) {
    uint32_t block_addr = addr / BLOCK_SIZE_L2;
    uint32_t index = block_addr % SETS_L2;
    uint32_t tag = block_addr / SETS_L2;
    int hit_way = -1;

    for (int i = 0; i < WAYS_L2; i++) {
        if (cache_l2[index][i].valid && cache_l2[index][i].tag == tag) { hit_way = i; break; }
    }

    if (hit_way != -1) {
        l2_hits++;
        cache_l2[index][hit_way].reused = 1;
        update_lru_l2(index, hit_way);
        gen_features(cache_l2[index][hit_way].tag, 1, cache_l2[index][hit_way].x);
        if (use_perceptron_l2) train(cache_l2[index][hit_way].x, w_l2, +1);
        return;
    }

    l2_misses++;
    int victim = -1;
    for (int i = 0; i < WAYS_L2; i++) {
        if (!cache_l2[index][i].valid) { victim = i; break; }
    }

    if (victim == -1) {
        victim = use_perceptron_l2 ? victim_perceptron_l2(index) : victim_lru_l2(index);
        if (use_perceptron_l2) train(cache_l2[index][victim].x, w_l2, -1);
    }

    cache_l2[index][victim].valid = 1;
    cache_l2[index][victim].tag = tag;
    cache_l2[index][victim].reused = 0;
    gen_features(tag, 0, cache_l2[index][victim].x);
    update_lru_l2(index, victim);
}

void access_cache_L1(uintptr_t addr, int use_perceptron_l1, int use_perceptron_l2) {
    uint32_t block_addr = addr / BLOCK_SIZE_L1;
    uint32_t index = block_addr % SETS_L1;
    uint32_t tag = block_addr / SETS_L1;
    int hit_way = -1;

    for (int i = 0; i < WAYS_L1; i++) {
        if (cache_l1[index][i].valid && cache_l1[index][i].tag == tag) { hit_way = i; break; }
    }

    if (hit_way != -1) {
        l1_hits++;
        cache_l1[index][hit_way].reused = 1;
        update_lru_l1(index, hit_way);
        gen_features(cache_l1[index][hit_way].tag, 1, cache_l1[index][hit_way].x);
        if (use_perceptron_l1) train(cache_l1[index][hit_way].x, w_l1, +1);
        return;
    }

    l1_misses++;
    access_cache_L2(addr, use_perceptron_l2);
    int victim = -1;
    for (int i = 0; i < WAYS_L1; i++) { 
        if (!cache_l1[index][i].valid) { victim = i; break; }
    }

    if (victim == -1) {
        victim = use_perceptron_l1 ? victim_perceptron_l1(index) : victim_lru_l1(index);
        if (use_perceptron_l1) train(cache_l1[index][victim].x, w_l1, -1);
    }

    cache_l1[index][victim].valid = 1;
    cache_l1[index][victim].tag = tag;
    cache_l1[index][victim].reused = 0;
    gen_features(tag, 0, cache_l1[index][victim].x);
    update_lru_l1(index, victim);
}

// --- BENCHMARKS ---
void run_streaming(int *array, volatile int *hot_data, int size, int use_l1, int use_l2) {
    init_cache();
    for (int it = 0; it < 10; it++) {
        for (int i = 0; i < size; i++) {
            access_cache_L1((uintptr_t)&array[i], use_l1, use_l2);
            array[i] += i;
            if (i % 64 == 0) {
                access_cache_L1((uintptr_t)hot_data, use_l1, use_l2);
                *hot_data += array[i]; 
            }
        }
    }
}

void run_matrix_conv(int *matrix, int *out, int use_l1, int use_l2) {
    init_cache();
    int dim = 128;
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
}

void run_linked_list(Node *head, int iters, int use_l1, int use_l2) {
    init_cache();
    Node *curr = head;
    for(int i = 0; i < iters * 10; i++) {
        access_cache_L1((uintptr_t)curr, use_l1, use_l2);
        curr->data++;
        curr = curr->next;
    }
}

void run_pattern_search(uint8_t *blob, int size, int use_l1, int use_l2) {
    init_cache();
    int real_size = size * 4; 
    int found = 0;
    for (int iter = 0; iter < 5; iter++) {
        for(int i = 0; i < real_size - 4; i++) {
            access_cache_L1((uintptr_t)&blob[i], use_l1, use_l2);
            if(blob[i] == 0xDE && blob[i+1] == 0xAD) found++;
        }
    }
}

void run_matrix_transpose(int *matrix, int *out, int use_l1, int use_l2) {
    init_cache();
    int dim = 128;
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            access_cache_L1((uintptr_t)&matrix[i * dim + j], use_l1, use_l2);
            access_cache_L1((uintptr_t)&out[j * dim + i], use_l1, use_l2);
            out[j * dim + i] = matrix[i * dim + j];
        }
    }
}

// --- SALVAR EXPORTAÇÃO COM NOVAS COLUNAS ---
void save_results_csv(FILE *csv, const char* hardware, const char* bench_name, const char* config) {
    double l1_hr = (l1_hits + l1_misses > 0) ? (100.0 * l1_hits / (l1_hits + l1_misses)) : 0.0;
    double l2_hr = (l2_hits + l2_misses > 0) ? (100.0 * l2_hits / (l2_hits + l2_misses)) : 0.0;
    uint64_t total_cpu_accesses = l1_hits + l1_misses;
    double global_hr = (total_cpu_accesses > 0) ? (100.0 * (l1_hits + l2_hits) / total_cpu_accesses) : 0.0;
    
    fprintf(csv, "%s,%d,%d,%s,%s,%.2f,%.2f,%.2f\n", 
            hardware, SETS_L2, BLOCK_SIZE_L2, bench_name, config, l1_hr, l2_hr, global_hr);
}

int main() {
    FILE *csv = fopen("benchmarks_arquitetura_completo.csv", "w");
    if(!csv) {
        printf("Erro ao criar o arquivo CSV!\n");
        return 1;
    }
    
    // Novo cabeçalho contendo informações de tamanho de hardware
    fprintf(csv, "Hardware_Perfil,Sets_L2,BlockSize_L2,Benchmark,Configuracao,HitRate_L1(%%),HitRate_L2(%%),HitRate_Global(%%)\n");

    int array_size_base = (32 * 1024 * 2 / sizeof(int));
    int *big_array = (int *)calloc(array_size_base * 2, sizeof(int));
    int *out_array = (int *)calloc(array_size_base * 2, sizeof(int));
    uint8_t *blob   = (uint8_t *)malloc(32 * 1024 * 4);
    Node *nodes = (Node *)malloc(10000 * sizeof(Node));
    
    for(int i = 0; i < 9999; i++) nodes[i].next = &nodes[i+1];
    nodes[9999].next = &nodes[0];
    volatile int hot_val = 0;

    int configs[4][2] = {{0,0}, {1,1}, {1,0}, {0,1}};
    const char* config_names[4] = {"LRU-LRU", "Perc-Perc", "Perc-LRU", "LRU-Perc"};

    // =========================================================================
    // LOOP DOS PERFIS DE HARDWARE
    // =========================================================================
    for(int hw_profile = 1; hw_profile <= 3; hw_profile++) {
        const char* hw_name;
        
        if (hw_profile == 1) {
            hw_name = "L1_4KB_L2_32KB_Base";
            SETS_L2 = 64; BLOCK_SIZE_L2 = 64; // Padrão original[cite: 3]
        } else if (hw_profile == 2) {
            hw_name = "L1_4KB_L2_64KB_Capacidade";
            SETS_L2 = 128; BLOCK_SIZE_L2 = 64; // Dobra número de conjuntos (64KB L2)[cite: 3]
        } else {
            hw_name = "L1_4KB_L2_64KB_BlocoLargo";
            SETS_L2 = 64; BLOCK_SIZE_L2 = 128; // Dobra tamanho do bloco (Maior localidade)[cite: 3]
        }

        printf("Simulando Perfil de Hardware: %s...\n", hw_name);

        for(int i = 0; i < 4; i++) {
            int u1 = configs[i][0];
            int u2 = configs[i][1];

            run_streaming(big_array, &hot_val, array_size_base, u1, u2);
            save_results_csv(csv, hw_name, "Streaming", config_names[i]);

            run_matrix_conv(big_array, out_array, u1, u2);
            save_results_csv(csv, hw_name, "Matrix_Conv", config_names[i]);

            run_linked_list(nodes, 10000, u1, u2);
            save_results_csv(csv, hw_name, "Linked_List", config_names[i]);

            run_pattern_search(blob, 32 * 1024, u1, u2);
            save_results_csv(csv, hw_name, "Pattern_Search", config_names[i]);

            run_matrix_transpose(big_array, out_array, u1, u2);
            save_results_csv(csv, hw_name, "Matrix_Transpose", config_names[i]);
        }
    }

    free(big_array); free(out_array); free(nodes); free(blob);
    fclose(csv);
    
    printf("\nProntinho! Arquivo unificado 'benchmarks_arquitetura_completo.csv' gerado.\n");
    return 0;
}