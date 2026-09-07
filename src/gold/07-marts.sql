-- ==============================================================================
-- Camada Gold: Data Marts para Diretorias (Vendas, Produto e Financeiro)
-- ==============================================================================

-- 1. Mart de Vendas por Vendedor
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor AS
WITH vendas_vendedor AS (
  SELECT
    f.vendedor_id,
    v.nome AS nome_vendedor,
    v.regiao,
    f.ano,
    f.mes,
    CAST(sum(f.receita) AS DECIMAL(18,2)) AS receita,
    CAST(sum(f.margem) AS DECIMAL(18,2)) AS margem,
    first(v.meta_mensal) AS meta_mensal,
    count(distinct f.cliente_id) AS clientes_atendidos,
    count(distinct f.pedido_id) AS total_pedidos
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  LEFT JOIN lakehouse_rotaperfume.silver.vendedores v ON f.vendedor_id = v.vendedor_id
  GROUP BY f.vendedor_id, v.nome, v.regiao, f.ano, f.mes
)
SELECT
  vendedor_id,
  nome_vendedor,
  regiao,
  ano,
  mes,
  receita,
  margem,
  meta_mensal,
  CAST(receita / nullif(meta_mensal, 0) * 100 AS DECIMAL(18,2)) AS atingimento_pct,
  clientes_atendidos,
  CAST(receita / nullif(total_pedidos, 0) AS DECIMAL(18,2)) AS ticket_medio,
  current_timestamp() AS _processado_em
FROM vendas_vendedor;

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor IS 
'Data Mart para a Diretoria Comercial com desempenho de vendas por vendedor e mês, cálculo de % de atingimento de meta e ticket médio.';


-- 2. Mart de Performance de Produto (com Curva ABC)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_produto_performance AS
WITH produto_mes AS (
  SELECT
    f.sku,
    p.descricao,
    f.categoria,
    f.marca,
    f.ano,
    f.mes,
    sum(f.quantidade) AS quantidade,
    CAST(sum(f.receita) AS DECIMAL(18,2)) AS receita,
    CAST(sum(f.margem) AS DECIMAL(18,2)) AS margem
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  LEFT JOIN lakehouse_rotaperfume.silver.produtos p ON f.sku = p.sku
  GROUP BY f.sku, p.descricao, f.categoria, f.marca, f.ano, f.mes
),
produto_acumulado AS (
  SELECT
    *,
    CAST(margem / nullif(receita, 0) * 100 AS DECIMAL(18,2)) AS margem_pct,
    sum(receita) OVER (PARTITION BY ano, mes ORDER BY receita DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS receita_acumulada_mes,
    sum(receita) OVER (PARTITION BY ano, mes) AS receita_total_mes
  FROM produto_mes
)
SELECT
  sku,
  descricao,
  categoria,
  marca,
  ano,
  mes,
  quantidade,
  receita,
  margem,
  margem_pct,
  CASE 
    WHEN (receita_acumulada_mes / nullif(receita_total_mes, 0)) <= 0.80 THEN 'A'
    WHEN (receita_acumulada_mes / nullif(receita_total_mes, 0)) <= 0.95 THEN 'B'
    ELSE 'C'
  END AS curva_abc,
  current_timestamp() AS _processado_em
FROM produto_acumulado;

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_produto_performance IS 
'Data Mart para a Diretoria de Produtos com performance mensal por SKU, margem % e classificação de Curva ABC por receita acumulada.';


-- 3. Mart Financeiro de Recebimento
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento AS
SELECT
  year(data_vencimento) AS ano_vencimento,
  month(data_vencimento) AS mes_vencimento,
  CAST(sum(valor) AS DECIMAL(18,2)) AS valor_a_receber,
  CAST(sum(CASE WHEN lower(status_pagamento) IN ('pago', 'concluido') THEN valor_liquido ELSE 0 END) AS DECIMAL(18,2)) AS valor_recebido,
  CAST(avg(CASE WHEN data_pagamento IS NOT NULL THEN datediff(data_pagamento, data_vencimento) ELSE NULL END) AS DECIMAL(18,2)) AS atraso_medio_dias,
  CAST(sum(valor * (taxa_pct / 100)) AS DECIMAL(18,2)) AS custo_taxa,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.pagamentos
WHERE data_vencimento IS NOT NULL
GROUP BY year(data_vencimento), month(data_vencimento);

COMMENT ON TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento IS 
'Data Mart para a Diretoria Financeira agrupado por mês de vencimento, com totais a receber, recebidos, atraso médio e custo de taxas.';
