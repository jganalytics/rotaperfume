#!/usr/bin/env bash
# Script para upload dos arquivos CSV brutos (ERP e CRM) para o Volume Managed no Databricks Unity Catalog.

set -e

PROFILE="${1:?Perfil é obrigatório como primeiro argumento. Ex: bash scripts/subir-raw.sh projeto-dados-ia}"
CATALOG="lakehouse_rotaperfume"
VOLUME_PATH="dbfs:/Volumes/${CATALOG}/bronze/raw"

DADOS_DIR="../dados"
if [ ! -d "${DADOS_DIR}" ]; then
  DADOS_DIR="./dados"
fi

if [ ! -d "${DADOS_DIR}" ]; then
  echo "Diretório 'dados/' não encontrado. Gerando dataset..."
  python material/gerar_dataset.py --saida ./dados --seed 42 || python3 material/gerar_dataset.py --saida ./dados --seed 42
  DADOS_DIR="./dados"
fi

echo "=================================================="
echo "Subindo arquivos brutos para o Volume Managed..."
echo "Destino: ${VOLUME_PATH}"
echo "Perfil: ${PROFILE}"
echo "=================================================="

echo "Enviando ERP (${DADOS_DIR}/erp)..."
databricks fs cp --recursive --overwrite "${DADOS_DIR}/erp" "${VOLUME_PATH}/erp" --profile "${PROFILE}"

echo "Enviando CRM (${DADOS_DIR}/crm)..."
databricks fs cp --recursive --overwrite "${DADOS_DIR}/crm" "${VOLUME_PATH}/crm" --profile "${PROFILE}"

echo "Upload de dados RAW concluído com sucesso!"
