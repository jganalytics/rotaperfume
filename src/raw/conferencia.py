# Databricks notebook source
# COMMAND ----------
# Notebook de Conferência de Chegada dos Arquivos Raw no Volume Managed do Unity Catalog

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit
from datetime import datetime
import os

spark = SparkSession.builder.getOrCreate()

# COMMAND ----------
# Configuração de widgets / parâmetros
dbutils.widgets.text("catalog", "lakehouse_rotaperfume", "Catálogo Unity Catalog")
catalog = dbutils.widgets.get("catalog").strip()

print(f"==================================================")
print(f"Iniciando Conferência de Chegada de Arquivos RAW")
print(f"Catálogo: {catalog}")
print(f"==================================================")

# COMMAND ----------
# Mapeamento dos 10 arquivos esperados (5 em ERP, 5 em CRM)
esperados = {
    "erp": ["produtos.csv", "pedidos.csv", "itens_pedido.csv", "pagamentos.csv", "estoque.csv"],
    "crm": ["clientes.csv", "vendedores.csv", "carteira.csv", "oportunidades.csv", "visitas.csv"]
}

volume_root = f"/Volumes/{catalog}/bronze/raw"
conferidos = []
erros = []

for sistema, arquivos in esperados.items():
    folder_path = os.path.join(volume_root, sistema)
    
    try:
        files_info = {f.name: f.size for f in dbutils.fs.ls(folder_path)}
    except Exception as e:
        files_info = {}
        erros.append(f"Diretório ausente ou inacessível: {folder_path} - Erro: {str(e)}")
    
    for arq in arquivos:
        file_path = os.path.join(folder_path, arq)
        if arq not in files_info:
            erros.append(f"Arquivo FALTANDO: sistema={sistema}, arquivo={arq} (caminho: {file_path})")
            continue
        
        num_bytes = files_info[arq]
        if num_bytes == 0:
            erros.append(f"Arquivo VAZIO (0 bytes): sistema={sistema}, arquivo={arq}")
            continue

        try:
            df = spark.read.option("header", "true").csv(file_path)
            num_linhas = df.count()
            if num_linhas == 0:
                erros.append(f"Arquivo SEM LINHAS de dados: sistema={sistema}, arquivo={arq}")
                continue
            
            conferidos.append({
                "sistema": sistema,
                "arquivo": arq,
                "bytes": int(num_bytes),
                "linhas": int(num_linhas),
                "conferido_em": datetime.now()
            })
        except Exception as e:
            erros.append(f"Erro ao ler arquivo CSV: sistema={sistema}, arquivo={arq} - Erro: {str(e)}")

# COMMAND ----------
# Tratamento de exceções e parada caso haja inconsistência
if erros:
    print("❌ FALHA NA CONFERÊNCIA DE ARQUIVOS RAW:")
    for err in erros:
        print(f"  - {err}")
    raise Exception(f"Conferência interrompida. {len(erros)} erro(s) encontrado(s) nos arquivos brutos.")

# COMMAND ----------
# Gravação da tabela de controle bronze._raw_arquivos
conferidos_df = spark.createDataFrame(conferidos)

# Garante a existência do schema bronze
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {catalog}.bronze COMMENT 'Camada Bronze: Armazena os dados brutos ingeridos com preservação do histórico.';")

tabela_controle = f"{catalog}.bronze._raw_arquivos"

conferidos_df.write \
    .mode("overwrite") \
    .option("mergeSchema", "true") \
    .saveAsTable(tabela_controle)

# Adiciona comentário explicativo na tabela de controle
spark.sql(f"COMMENT ON TABLE {tabela_controle} IS 'Tabela de controle contendo o registro de auditoria dos arquivos CSV recebidos no Volume Managed bronze/raw.';")

# COMMAND ----------
# Exibição do relatório final
print("\n✅ CONFERÊNCIA CONCLUÍDA COM SUCESSO!")
print(f"Todos os {len(conferidos)} arquivos esperados foram conferidos e validados.")
print(f"Tabela de controle atualizada: {tabela_controle}\n")

conferidos_df.show(truncate=False)
