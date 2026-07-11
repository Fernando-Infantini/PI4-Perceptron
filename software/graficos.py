import os
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

# =========================================================================
# 1. LEITURA DO ARQUIVO CSV
# =========================================================================
nome_arquivo = "benchmarks_arquitetura_completo.csv"

if not os.path.exists(nome_arquivo):
    raise FileNotFoundError(
        f"Por favor, faça o upload do arquivo '{nome_arquivo}' na barra lateral do Colab antes de rodar!"
    )

df = pd.read_csv(nome_arquivo)

# Configurações estéticas padrão para os slides
sns.set_theme(style="whitegrid")
paleta = ["#4A90E2", "#E24A4A", "#50E3C2", "#F5A623"]  # Azul, Vermelho, Verde, Laranja
plt.rcParams.update({"font.size": 11, "figure.autolayout": True})

print(f"Arquivo {nome_arquivo} carregado com sucesso! Gerando os gráficos limpos...\n")

# =========================================================================
# BLOCADO 1: GRÁFICO GERAL 
# =========================================================================
print("-> Gerando Gráfico 01: Visão Geral...")
plt.figure(figsize=(15, 7))
# errorbar=None remove as linhas pretas verticais indesejadas
ax0 = sns.barplot(
    data=df,
    x="Benchmark",
    y="HitRate_Global(%)",
    hue="Configuracao",
    palette=paleta,
    errorbar=None,
)

# Adiciona os valores em cima de cada barra
for container in ax0.containers:
    ax0.bar_label(container, fmt="%.1f", fontsize=8, padding=4, rotation=0)

plt.title(
    "Comparativo Geral de Hit Rate Global por Benchmark (Média dos Perfis)",
    fontsize=14,
    fontweight="bold",
)
plt.ylabel("Hit Rate Global (%)")
plt.xlabel("Benchmarks")
plt.ylim(40, 115)  # Aumentado para o número não cortar no topo
plt.legend(title="Algoritmos (L1-L2)", loc="lower left")
plt.savefig("01_grafico_geral.png", dpi=300)
plt.close()

# =========================================================================
# BLOCADO 2: EXCLUSIVOS POR TAMANHO / PERFIL DE HARDWARE 
# =========================================================================
print("-> Gerando Gráficos 02: Exclusivos por Perfil de Hardware...")
perfis = df["Hardware_Perfil"].unique()

for perfil in perfis:
    df_perfil = df[df["Hardware_Perfil"] == perfil]

    plt.figure(figsize=(12, 6))
    ax = sns.barplot(
        data=df_perfil,
        x="Benchmark",
        y="HitRate_Global(%)",
        hue="Configuracao",
        palette=paleta,
        errorbar=None,
    )

    for container in ax.containers:
        ax.bar_label(container, fmt="%.1f", fontsize=9, padding=3)

    plt.title(
        f"Hit Rate Global - Perfil Hardware: {perfil}",
        fontsize=13,
        fontweight="bold",
    )
    plt.ylabel("Hit Rate Global (%)")
    plt.xlabel("Benchmark")
    plt.ylim(30, 115)
    plt.legend(title="Configuração", loc="lower right")
    plt.savefig(f"02_hardware_{perfil}.png", dpi=300)
    plt.close()

# =========================================================================
# BLOCADO 3: EXCLUSIVOS POR TESTE / BENCHMARK 
# =========================================================================
print("-> Gerando Gráficos 03: Sensibilidade por Benchmark...")
benchmarks = df["Benchmark"].unique()

for bench in benchmarks:
    df_bench = df[df["Benchmark"] == bench]

    plt.figure(figsize=(12, 6))
    ax = sns.barplot(
        data=df_bench,
        x="Hardware_Perfil",
        y="HitRate_Global(%)",
        hue="Configuracao",
        palette=paleta,
        errorbar=None,
    )

    for container in ax.containers:
        ax.bar_label(container, fmt="%.1f", fontsize=9, padding=3)

    plt.title(
        f"Análise de Sensibilidade de Hardware - Teste: {bench}",
        fontsize=13,
        fontweight="bold",
    )
    plt.ylabel("Hit Rate Global (%)")
    plt.xlabel("Perfis de Hardware")
    plt.ylim(30, 115)
    plt.xticks(rotation=5)
    plt.legend(title="Configuração", loc="lower right")
    plt.savefig(f"03_sensibilidade_{bench}.png", dpi=300)
    plt.close()

# =========================================================================
# BLOCADO 4: GRÁFICO EXTRA - FOCO EXCLUSIVO NA L2 
# =========================================================================
print("-> Gerando Gráfico Extra: Isolamento da Cache L2 (Perfil Base)...")
df_base = df[df["Hardware_Perfil"] == "L1_4KB_L2_32KB_Base"]

plt.figure(figsize=(12, 6))
ax = sns.barplot(
    data=df_base,
    x="Benchmark",
    y="HitRate_L2(%)",
    hue="Configuracao",
    palette=paleta,
    errorbar=None,
)

for container in ax.containers:
    ax.bar_label(container, fmt="%.1f", fontsize=9, padding=3)

plt.title(
    "Comportamento Isolado da Cache L2 (Perfil Base de 32KB)",
    fontsize=13,
    fontweight="bold",
)
plt.ylabel("Hit Rate Local da L2 (%)")
plt.xlabel("Benchmark")
plt.ylim(0, 115)
plt.legend(title="Configuração", loc="upper right")
plt.savefig("04_extra_hit_rate_l2_isolado.png", dpi=300)
plt.close()

print(
    "\n[FINALIZADO!] Gráficos gerados sem linhas pretas e com rótulos numéricos."
)