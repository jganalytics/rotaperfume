# RotaPerfume — Projeto de Dados & IA (Databricks Asset Bundle)

Projeto de Engenharia de Dados e Inteligência Artificial para a distribuidora B2B **RotaPerfume**, construído com Databricks Asset Bundles (DABs), Delta Lake, PySpark, Python (`uv`) e Genie AI.

## Estrutura do Repositório

* `src/`: Códigos-fonte em PySpark e SQL (Raw, Bronze, Silver, Gold, Métricas de Negócio, Auditoria de Metadados).
* `resources/`: Configurações declarativas de recursos (Databricks Asset Bundle: Jobs, Dashboards Lakeview, Genie Space).
* `docs/`: Documentação de contexto e instruções para o Genie AI.
* `tests/`: Suíte de testes unitários e de qualidade da camada Gold.

## Como Executar Localmente

```bash
# 1. Sincronizar ambiente virtual Python com uv
uv sync --dev

# 2. Validar o bundle
databricks bundle validate --target dev --profile projeto-dados-ia

# 3. Fazer deploy no workspace Databricks
databricks bundle deploy --target dev --profile projeto-dados-ia

# 4. Executar o pipeline de ponta a ponta
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```
