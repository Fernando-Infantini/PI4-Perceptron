#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// --- PARÂMETROS DA CACHE L1 (Dados: 4KB, blocos de 32B, 2-way) ---
#define BLOCK_SIZE_L1 32
#define SETS_L1 64      // 4KB / (32B * 2 ways) = 64 conjuntos
#define WAYS_L1 2

#define MAX_WEIGHT 31   // Limite para contador saturado de 6 bits
#define MIN_WEIGHT -32

// --- PARÂMETROS DA CACHE L2 (Unificada: 32KB, blocos de 64B, 8-way) ---
#define BLOCK_SIZE_L2 64
#define SETS_L2 64      // 32KB / (64B * 8 ways) = 64 conjuntos
#define WAYS_L2 8

// --- MÉTRICAS GLOBAIS ---
uint64_t l1_hits = 0;
uint64_t l1_misses = 0;
uint64_t l2_hits = 0;
uint64_t l2_misses = 0;

// --- PERCEPTRON (Pesos separados para L1 e L2) ---
#define N 4
int w_l1[N] = {0, 0, 0, 0}; // Pesos da L1
int w_l2[N] = {0, 0, 0, 0}; // Pesos da L2

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
            // Lógica de Saturação (Limita os extremos para 6 bits)
            if (w[i] > MAX_WEIGHT) w[i] = MAX_WEIGHT;
            if (w[i] < MIN_WEIGHT) w[i] = MIN_WEIGHT;
        }
    }
}

// Features para Hardware
void gen_features(uint32_t tag, int reused, int x[N]) {
    x[0] = 1;                           // Bias
    x[1] = (tag & 1) ? 1 : -1;          // Bit 0 da tag
    x[2] = ((tag >> 1) & 1) ? 1 : -1;   // Bit 1 da tag
    x[3] = reused ? 1 : -1;             // Histórico de Reuso
}

// Função para imprimir os pesos de forma condicional
void print_weights(int show_l1, int show_l2) {
    printf(">> Estado da Inteligencia (Pesos Aprendidos):\n");
    if (show_l1) {
        printf("   [L1] Bias: %-6d | TagBit0: %-6d | TagBit1: %-6d | Reuso: %-6d\n", w_l1[0], w_l1[1], w_l1[2], w_l1[3]);
    }
    if (show_l2) {
        printf("   [L2] Bias: %-6d | TagBit0: %-6d | TagBit1: %-6d | Reuso: %-6d\n", w_l2[0], w_l2[1], w_l2[2], w_l2[3]);
    }
}

// --- ESTRUTURAS DAS CACHES ---
typedef struct {
    int valid;
    uint32_t tag;
    int lru;
    int reused;
    int x[N];
} Line;

typedef struct { Line ways[WAYS_L1]; } SetL1;
typedef struct { Line ways[WAYS_L2]; } SetL2;

SetL1 cache_l1[SETS_L1];
SetL2 cache_l2[SETS_L2];

void init_cache() {
    for (int s = 0; s < SETS_L1; s++) {
        for (int i = 0; i < WAYS_L1; i++) {
            cache_l1[s].ways[i].valid = 0;
            cache_l1[s].ways[i].lru = 0;
            cache_l1[s].ways[i].reused = 0;
        }
    }
    for (int s = 0; s < SETS_L2; s++) {
        for (int i = 0; i < WAYS_L2; i++) {
            cache_l2[s].ways[i].valid = 0;
            cache_l2[s].ways[i].lru = 0;
            cache_l2[s].ways[i].reused = 0;
        }
    }
    for (int i = 0; i < N; i++) { w_l1[i] = 0; w_l2[i] = 0; }
    l1_hits = 0; l1_misses = 0;
    l2_hits = 0; l2_misses = 0;
}

void update_lru_l1(SetL1 *set, int used) {
    for (int i = 0; i < WAYS_L1; i++) {
        if (i == used) set->ways[i].lru = 0;
        else set->ways[i].lru++;
    }
}

void update_lru_l2(SetL2 *set, int used) {
    for (int i = 0; i < WAYS_L2; i++) {
        if (i == used) set->ways[i].lru = 0;
        else set->ways[i].lru++;
    }
}

int victim_perceptron_l1(SetL1 *set) {
    int v = 0;
    int worst = predict(set->ways[0].x, w_l1);
    for (int i = 1; i < WAYS_L1; i++) {
        int score = predict(set->ways[i].x, w_l1);
        if (score < worst) { worst = score; v = i; }
    }
    return v;
}

int victim_perceptron_l2(SetL2 *set) {
    int v = 0;
    int worst = predict(set->ways[0].x, w_l2);
    for (int i = 1; i < WAYS_L2; i++) {
        int score = predict(set->ways[i].x, w_l2);
        if (score < worst) { worst = score; v = i; }
    }
    return v;
}

int victim_lru_l1(SetL1 *set) {
    int v = 0;
    for (int i = 1; i < WAYS_L1; i++) {
        if (set->ways[i].lru > set->ways[v].lru) v = i;
    }
    return v;
}

int victim_lru_l2(SetL2 *set) {
    int v = 0;
    for (int i = 1; i < WAYS_L2; i++) {
        if (set->ways[i].lru > set->ways[v].lru) v = i;
    }
    return v;
}

void access_cache_L2(uintptr_t addr, int use_perceptron_l2) {
    uint32_t block_addr = addr / BLOCK_SIZE_L2;
    uint32_t index = block_addr % SETS_L2;
    uint32_t tag = block_addr / SETS_L2;
    
    SetL2 *set = &cache_l2[index];
    int hit_way = -1;

    for (int i = 0; i < WAYS_L2; i++) {
        if (set->ways[i].valid && set->ways[i].tag == tag) {
            hit_way = i; break;
        }
    }

    if (hit_way != -1) {
        l2_hits++;
        set->ways[hit_way].reused = 1;
        update_lru_l2(set, hit_way);

        gen_features(set->ways[hit_way].tag, 1, set->ways[hit_way].x);

        if (use_perceptron_l2) train(set->ways[hit_way].x, w_l2, +1);
        return;
    }

    l2_misses++;
    int victim = -1;
    for (int i = 0; i < WAYS_L2; i++) {
        if (!set->ways[i].valid) { victim = i; break; }
    }

    if (victim == -1) {
        victim = use_perceptron_l2 ? victim_perceptron_l2(set) : victim_lru_l2(set);
        if (use_perceptron_l2) {
            int target = -1;
            train(set->ways[victim].x, w_l2, target);
        }
    }

    set->ways[victim].valid = 1;
    set->ways[victim].tag = tag;
    set->ways[victim].reused = 0;
    gen_features(tag, 0, set->ways[victim].x);
    update_lru_l2(set, victim);
}

void access_cache_L1(uintptr_t addr, int use_perceptron_l1, int use_perceptron_l2) {
    uint32_t block_addr = addr / BLOCK_SIZE_L1;
    uint32_t index = block_addr % SETS_L1;
    uint32_t tag = block_addr / SETS_L1;
    
    SetL1 *set = &cache_l1[index];
    int hit_way = -1;

    for (int i = 0; i < WAYS_L1; i++) {
        if (set->ways[i].valid && set->ways[i].tag == tag) {
            hit_way = i; break;
        }
    }

    if (hit_way != -1) {
        l1_hits++;
        set->ways[hit_way].reused = 1;
        update_lru_l1(set, hit_way);
        
        // --- CORREÇÃO AQUI: Atualiza as features antes do treino no Hit! ---
        gen_features(set->ways[hit_way].tag, 1, set->ways[hit_way].x);
        
        if (use_perceptron_l1) train(set->ways[hit_way].x, w_l1, +1);
        return;
    }

    l1_misses++;
    access_cache_L2(addr, use_perceptron_l2);

    int victim = -1;
    for (int i = 0; i < WAYS_L1; i++) { 
        if (!set->ways[i].valid) { victim = i; break; }
    }

    if (victim == -1) {
        victim = use_perceptron_l1 ? victim_perceptron_l1(set) : victim_lru_l1(set);
        if (use_perceptron_l1) {
            int target = -1;
            train(set->ways[victim].x, w_l1, target);
        }
    }

    set->ways[victim].valid = 1;
    set->ways[victim].tag = tag;
    set->ways[victim].reused = 0;
    gen_features(tag, 0, set->ways[victim].x);
    update_lru_l1(set, victim);
}