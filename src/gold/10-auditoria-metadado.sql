-- ==============================================================================
-- Camada Gold: Auditoria Estrita de Metadados (Coverage & Compliance)
-- ==============================================================================
-- Regra Negocial: Metadado ausente na camada Gold é considerado BUG de código, 
-- interrompendo o pipeline com raise_error().

-- 1. Verifica se existe alguma tabela ou view na camada Gold sem COMMENT
SELECT CASE 
  WHEN COUNT(*) > 0 THEN raise_error(CONCAT('BUG DE METADADOS: Encontrada(s) ', COUNT(*), ' tabela(s)/view(s) na camada Gold sem COMMENT! Adicione descrições orientadas a negócio.')) 
END
FROM information_schema.tables
WHERE table_catalog = 'lakehouse_rotaperfume' 
  AND table_schema = 'gold' 
  AND (comment IS NULL OR TRIM(comment) = '');

-- 2. Verifica se existe alguma coluna sem COMMENT em fato_vendas e nas 6 views de negócio
SELECT CASE 
  WHEN COUNT(*) > 0 THEN raise_error(CONCAT('BUG DE METADADOS: Encontrada(s) ', COUNT(*), ' coluna(s) sem COMMENT em fato_vendas ou nas views de negócio da camada Gold!')) 
END
FROM information_schema.columns
WHERE table_catalog = 'lakehouse_rotaperfume' 
  AND table_schema = 'gold' 
  AND table_name IN ('fato_vendas', 'receita_mensal', 'ranking_marcas', 'margem_por_categoria', 'clientes_em_risco', 'efeito_lancamento', 'ruptura_por_marca')
  AND (comment IS NULL OR TRIM(comment) = '');

-- 3. Relatório Executivo de Cobertura de Metadados por Objeto na Gold
SELECT 
  table_name AS objeto_gold,
  COUNT(column_name) AS total_colunas,
  COUNT(comment) AS colunas_comentadas,
  CAST(ROUND(COUNT(comment) * 100.0 / NULLIF(COUNT(column_name), 0), 2) AS DECIMAL(5,2)) AS pct_cobertura_metadados
FROM information_schema.columns
WHERE table_catalog = 'lakehouse_rotaperfume' 
  AND table_schema = 'gold'
GROUP BY table_name
ORDER BY objeto_gold;
