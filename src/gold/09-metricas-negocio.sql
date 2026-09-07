-- ==============================================================================
-- Camada Gold: Métricas de Negócio Orientadas à Consumo em Linguagem Natural (Genie AI)
-- ==============================================================================

-- 1. Receita Mensal com Sinalização de Mês de Pico
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.receita_mensal (
  ano COMMENT 'Ano de emissão do pedido comercial.',
  mes COMMENT 'Mês numérico de emissão do pedido comercial (1 a 12).',
  receita COMMENT 'Faturamento bruto acumulado no mês em reais (R$), considerando dedução de devoluções.',
  margem COMMENT 'Margem de lucro bruta acumulada no mês em reais (R$).',
  pedidos COMMENT 'Quantidade total de pedidos únicos não cancelados efetuados no mês.',
  mes_pico_setor COMMENT 'Flag booleana indicando se o mês é historicamente um mês de pico de vendas no setor de perfumaria (abril, junho e outubro).'
)
COMMENT 'Qual foi a receita, margem e quantidade de pedidos por mês, e esse mês é um mês de pico do setor de perfumaria?'
AS
SELECT
  f.ano,
  f.mes,
  CAST(SUM(f.receita) AS DECIMAL(18,2)) AS receita,
  CAST(SUM(f.margem) AS DECIMAL(18,2)) AS margem,
  COUNT(DISTINCT f.pedido_id) AS pedidos,
  MAX(COALESCE(c.mes_pico_setor, CASE WHEN f.mes IN (4, 6, 10) THEN true ELSE false END)) AS mes_pico_setor
FROM lakehouse_rotaperfume.gold.fato_vendas f
LEFT JOIN lakehouse_rotaperfume.gold.dim_calendario c ON f.data_pedido = c.data
GROUP BY f.ano, f.mes;


-- 2. Ranking de Marcas
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.ranking_marcas (
  marca COMMENT 'Marca comercial do produto de perfumaria.',
  receita COMMENT 'Faturamento bruto total gerado pela marca em reais (R$), considerando devoluções.',
  margem COMMENT 'Margem de lucro total gerada pela marca em reais (R$).',
  margem_pct COMMENT 'Percentual de margem de lucro sobre a receita gerada pela marca (0 a 100%).',
  participacao_pct COMMENT 'Percentual de participação da marca no faturamento bruto total da distribuidora (0 a 100%).'
)
COMMENT 'Quais são as marcas mais vendidas por receita, margem percentual e participação nas vendas totais?'
AS
WITH stats_marcas AS (
  SELECT
    marca,
    SUM(receita) AS receita,
    SUM(margem) AS margem
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY marca
),
total AS (
  SELECT SUM(receita) AS receita_total FROM stats_marcas
)
SELECT
  m.marca,
  CAST(m.receita AS DECIMAL(18,2)) AS receita,
  CAST(m.margem AS DECIMAL(18,2)) AS margem,
  CAST(ROUND(m.margem * 100.0 / NULLIF(m.receita, 0), 2) AS DECIMAL(18,2)) AS margem_pct,
  CAST(ROUND(m.receita * 100.0 / NULLIF(t.receita_total, 0), 2) AS DECIMAL(18,2)) AS participacao_pct
FROM stats_marcas m
CROSS JOIN total t;


-- 3. Margem por Categoria
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.margem_por_categoria (
  categoria COMMENT 'Categoria mercadológica do produto (ex: Perfumes, Loções, Kits).',
  receita COMMENT 'Faturamento bruto acumulado na categoria em reais (R$).',
  margem COMMENT 'Margem de lucro acumulada na categoria em reais (R$).',
  margem_pct COMMENT 'Percentual de margem de lucro da categoria sobre a receita gerada (0 a 100%).'
)
COMMENT 'Qual a receita, margem de lucro em valor e margem percentual por categoria de produto?'
AS
SELECT
  categoria,
  CAST(SUM(receita) AS DECIMAL(18,2)) AS receita,
  CAST(SUM(margem) AS DECIMAL(18,2)) AS margem,
  CAST(ROUND(SUM(margem) * 100.0 / NULLIF(SUM(receita), 0), 2) AS DECIMAL(18,2)) AS margem_pct
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY categoria;


-- 4. Clientes em Risco (Churn > 90 dias)
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.clientes_em_risco (
  cliente_id COMMENT 'Identificador único do cliente comprador.',
  razao_social COMMENT 'Razão social oficial padronizada do cliente.',
  segmento COMMENT 'Segmento comercial de atuação do cliente (ex: Perfumaria, Varejo).',
  cidade COMMENT 'Cidade de faturamento do cliente.',
  uf COMMENT 'Unidade federativa (Estado) do cliente.',
  dias_desde_ultima_compra COMMENT 'Quantidade de dias sem realizar novas compras (superior a 90 dias).',
  receita_media_mensal COMMENT 'Média mensal de faturamento em reais (R$) gerada pelo cliente no período ativo antes do sumiço.'
)
COMMENT 'Quais clientes estão sem comprar há mais de 90 dias (em risco de churn) e qual era a média mensal de compras antes do sumiço?'
AS
WITH stats_cliente AS (
  SELECT
    cliente_id,
    MIN(data_pedido) AS primeira_compra,
    MAX(data_pedido) AS ultima_compra,
    COUNT(DISTINCT pedido_id) AS total_pedidos,
    SUM(receita) AS receita_total
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY cliente_id
)
SELECT
  c.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.uf,
  c.dias_desde_ultima_compra,
  CAST(ROUND(s.receita_total / NULLIF(GREATEST(1, CEIL(DATEDIFF(s.ultima_compra, s.primeira_compra) / 30.0)), 0), 2) AS DECIMAL(18,2)) AS receita_media_mensal
FROM lakehouse_rotaperfume.gold.dim_cliente c
JOIN stats_cliente s ON c.cliente_id = s.cliente_id
WHERE c.dias_desde_ultima_compra > 90;


-- 5. Efeito Lançamento (Desempenho Primeiros 120 Dias)
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.efeito_lancamento (
  sku COMMENT 'Código SKU único do produto.',
  descricao COMMENT 'Descrição detalhada do produto.',
  marca COMMENT 'Marca comercial do produto.',
  categoria COMMENT 'Categoria mercadológica do produto.',
  data_lancamento COMMENT 'Data oficial de lançamento do SKU no mercado.',
  receita_primeiros_120_dias COMMENT 'Receita total gerada pelo SKU nos primeiros 120 dias a contar da data de lançamento.',
  receita_apos_120_dias COMMENT 'Receita total gerada pelo SKU após o período inicial de 120 dias do lançamento.',
  receita_total COMMENT 'Receita acumulada de vendas de todo o histórico do produto.'
)
COMMENT 'Qual o desempenho de receita dos produtos nos primeiros 120 dias de lançamento comparado ao período posterior?'
AS
SELECT
  p.sku,
  p.descricao,
  p.marca,
  p.categoria,
  p.data_lancamento,
  CAST(COALESCE(SUM(CASE WHEN f.data_pedido BETWEEN p.data_lancamento AND DATE_ADD(p.data_lancamento, 120) THEN f.receita ELSE 0 END), 0) AS DECIMAL(18,2)) AS receita_primeiros_120_dias,
  CAST(COALESCE(SUM(CASE WHEN f.data_pedido > DATE_ADD(p.data_lancamento, 120) THEN f.receita ELSE 0 END), 0) AS DECIMAL(18,2)) AS receita_apos_120_dias,
  CAST(COALESCE(SUM(f.receita), 0) AS DECIMAL(18,2)) AS receita_total
FROM lakehouse_rotaperfume.gold.dim_produto p
LEFT JOIN lakehouse_rotaperfume.gold.fato_vendas f ON p.sku = f.sku
GROUP BY p.sku, p.descricao, p.marca, p.categoria, p.data_lancamento;


-- 6. Ruptura por Marca (Percentual de Snapshots em Ruptura)
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.ruptura_por_marca (
  marca COMMENT 'Marca comercial dos produtos avaliados.',
  total_snapshots COMMENT 'Quantidade total de registros de snapshot de estoque avaliados para a marca.',
  snapshots_em_ruptura COMMENT 'Quantidade de registros de snapshot de estoque em situação de ruptura (sem estoque).',
  pct_ruptura COMMENT 'Percentual de snapshots em ruptura de estoque sobre o total avaliado por marca (0 a 100%).'
)
COMMENT 'Qual a taxa de ruptura de estoque (percentual de produtos indisponíveis) por marca?'
AS
SELECT
  p.marca,
  COUNT(*) AS total_snapshots,
  COUNT(CASE WHEN s.ruptura IS TRUE THEN 1 END) AS snapshots_em_ruptura,
  CAST(ROUND(COUNT(CASE WHEN s.ruptura IS TRUE THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS DECIMAL(18,2)) AS pct_ruptura
FROM lakehouse_rotaperfume.silver.estoque s
JOIN lakehouse_rotaperfume.silver.produtos p ON s.sku = p.sku
GROUP BY p.marca;
