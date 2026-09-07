# Databricks notebook source
# COMMAND ----------
# Notebook de Ingestão da Camada Bronze em Tabelas Delta no Unity Catalog

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit

spark = SparkSession.builder.getOrCreate()

# COMMAND ----------
# Configuração de widgets / parâmetros
dbutils.widgets.text("catalog", "lakehouse_rotaperfume", "Catálogo Unity Catalog")
catalog = dbutils.widgets.get("catalog").strip()

print("==================================================")
print(f"Iniciando Ingestão da Camada BRONZE (Delta)")
print(f"Catálogo: {catalog}")
print("==================================================")

# COMMAND ----------
# Mapeamento das 10 tabelas por sistema de origem
tabelas_por_sistema = {
    "erp": ["produtos", "pedidos", "itens_pedido", "pagamentos", "estoque"],
    "crm": ["clientes", "vendedores", "carteira", "oportunidades", "visitas"]
}

# Leitura da tabela de controle da camada raw para validação de contagem
raw_control_df = spark.table(f"{catalog}.bronze._raw_arquivos")
control_counts = {
    row["arquivo"].replace(".csv", ""): row["linhas"]
    for row in raw_control_df.collect()
}

resumo_ingestao = []
erros = []

def ingerir_tabela_bronze(sistema: str, tabela: str):
    file_path = f"/Volumes/{catalog}/bronze/raw/{sistema}/{tabela}.csv"
    target_table = f"{catalog}.bronze.{tabela}"
    
    print(f"Ingerindo {sistema.upper()} -> {tabela} ({file_path})...")
    
    # Leitura estrita como string sem inferência de esquema
    df_raw = spark.read \
        .option("header", "true") \
        .option("inferSchema", "false") \
        .csv(file_path)
    
    # Adiciona apenas as duas colunas de controle exigidas
    df_bronze = df_raw \
        .withColumn("_ingerido_em", current_timestamp()) \
        .withColumn("_arquivo_origem", lit(file_path))
    
    # Gravação em tabela Delta (overwrite)
    df_bronze.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .saveAsTable(target_table)
    
    # Comentário descritivo na tabela Delta
    comentario = f"Tabela da camada Bronze oriunda do sistema de origem {sistema.upper()}."
    spark.sql(f"COMMENT ON TABLE {target_table} IS '{comentario}';")
    
    # Validação de contagem de linhas contra a tabela de controle _raw_arquivos
    total_linhas = df_bronze.count()
    esperado_linhas = control_counts.get(tabela)
    
    if esperado_linhas is not None and total_linhas != esperado_linhas:
        erros.append(f"Divergência em {tabela}: linhas gravadas ({total_linhas}) != linhas no controle ({esperado_linhas})")
    
    resumo_ingestao.append({
        "sistema": sistema,
        "tabela": tabela,
        "linhas_gravadas": int(total_linhas),
        "status": "OK" if esperado_linhas == total_linhas else "DIVERGENTE"
    })

# COMMAND ----------
# Iteração sobre todas as 10 tabelas
for sistema, lista_tabelas in tabelas_por_sistema.items():
    for tabela in lista_tabelas:
        ingerir_tabela_bronze(sistema, tabela)

# COMMAND ----------
# Validação e exibição do resumo
if erros:
    print("❌ ERROS ENCONTRADOS NA INGESTÃO BRONZE:")
    for err in erros:
        print(f"  - {err}")
    raise Exception(f"Ingestão interrompida. Encontrada(s) {len(erros)} divergência(s) de contagem.")

df_resumo = spark.createDataFrame(resumo_ingestao)
df_resumo.show(truncate=False)

total_geral = sum(r["linhas_gravadas"] for r in resumo_ingestao)
print(f"\n==================================================")
print(f"TOTAL GERAL DE LINHAS INGERIDAS NA BRONZE: {total_geral:,}")
print(f"TOTAL ESPERADO: 313.551")
print(f"==================================================")

if total_geral != 313551:
    raise Exception(f"Total de linhas ingeridas ({total_geral}) diverge do total esperado (313.551).")

print("✅ Ingestão da camada BRONZE concluída com sucesso!")
