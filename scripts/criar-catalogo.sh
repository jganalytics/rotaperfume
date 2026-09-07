#!/usr/bin/env bash
# Script para criação do Catálogo Unity Catalog no Databricks Free Edition.
#
# POR QUE NÃO ESTÁ NO BUNDLE:
# No Free Edition o Default Storage está ligado, e nessa configuração a API do
# Unity Catalog RECUSA criar catálogo — ela exige um MANAGED LOCATION que a conta
# gratuita não tem:
#   Error: Metastore storage root URL does not exist.
#          Default Storage is enabled in your account. (400 INVALID_STATE)
# O comando SQL (CREATE CATALOG IF NOT EXISTS) funciona normalmente via SQL Warehouse.

set -e

PROFILE="${1:-projeto-dados-ia}"
CATALOG_NAME="lakehouse_rotaperfume"
WAREHOUSE_ID="921cca117c00e223"

echo "=================================================="
echo "Criando catálogo Unity Catalog '${CATALOG_NAME}'..."
echo "Perfil: ${PROFILE}"
echo "=================================================="

python -c "
import subprocess, json, sys, time

profile = '${PROFILE}'
warehouse_id = '${WAREHOUSE_ID}'
sql = 'CREATE CATALOG IF NOT EXISTS ${CATALOG_NAME};'

print(f'Executando SQL via SQL Warehouse ({warehouse_id})...')

cmd = [
    'databricks', 'api', 'post', '/api/2.0/sql/statements',
    '--profile', profile,
    '--json', json.dumps({
        'statement': sql,
        'warehouse_id': warehouse_id,
        'wait_timeout': '30s'
    })
]

res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0:
    data = json.loads(res.stdout)
    status = data.get('status', {}).get('state')
    print(f'Status da execução SQL: {status}')
    if status in ['SUCCEEDED', 'CLOSED']:
        print('Catálogo criado/verificado com sucesso!')
        sys.exit(0)
    else:
        print('Detalhes:', res.stdout)
else:
    print('Erro executando statement:', res.stderr)
    sys.exit(1)
"

echo "Concluído com sucesso!"
