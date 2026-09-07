-- ==============================================================================
-- Camada Gold: Dimensões Conformadas (dim_cliente, dim_produto, dim_vendedor, dim_calendario)
-- ==============================================================================

-- 1. Dimensão Cliente
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_cliente AS
WITH stats_pedidos AS (
  SELECT
    cliente_id,
    min(data_pedido) AS data_primeiro_pedido,
    max(data_pedido) AS data_ultimo_pedido,
    count(distinct pedido_id) AS total_pedidos,
    CAST(sum(valor_liquido) AS DECIMAL(18,2)) AS receita_acumulada
  FROM lakehouse_rotaperfume.silver.pedidos
  WHERE cancelado IS FALSE
  GROUP BY cliente_id
)
SELECT
  c.cliente_id,
  c.cnpj,
  c.razao_social,
  c.segmento,
  c.cidade,
  c.uf,
  c.data_cadastro,
  s.data_primeiro_pedido,
  s.data_ultimo_pedido,
  coalesce(s.total_pedidos, 0) AS total_pedidos,
  coalesce(s.receita_acumulada, CAST(0.00 AS DECIMAL(18,2))) AS receita_acumulada,
  datediff(current_date(), s.data_ultimo_pedido) AS dias_desde_ultima_compra,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.clientes c
LEFT JOIN stats_pedidos s ON c.cliente_id = s.cliente_id;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_cliente IS 
'Dimensão de Clientes contendo dados cadastrais, agregação histórica de pedidos/receita acumulada e recência de compra.';

ALTER TABLE lakehouse_rotaperfume.gold.dim_cliente ALTER COLUMN dias_desde_ultima_compra COMMENT 
'Número de dias decorridos entre a data atual e a data do último pedido não cancelado do cliente.';


-- 2. Dimensão Produto
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_produto AS
SELECT
  sku,
  descricao,
  categoria,
  marca,
  nota_olfativa,
  custo_unitario,
  preco_tabela,
  unidade,
  data_lancamento,
  NOT ativo AS descontinuado,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.produtos;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_produto IS 
'Dimensão de Produtos por SKU com preços de tabela, custo unitário e indicador de item descontinuado.';


-- 3. Dimensão Vendedor
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_vendedor AS
SELECT
  vendedor_id,
  nome,
  regiao,
  uf,
  meta_mensal,
  ativo,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.vendedores;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_vendedor IS 
'Dimensão de Vendedores com dados cadastrais, região de atuação e metas mensais estipuladas.';


-- 4. Dimensão Calendário
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_calendario AS
WITH datas AS (
  SELECT explode(sequence(to_date('2024-01-01'), to_date('2025-12-31'), interval 1 day)) AS data
)
SELECT
  data,
  year(data) AS ano,
  month(data) AS mes,
  date_format(data, 'MMMM') AS nome_mes,
  quarter(data) AS trimestre,
  date_format(data, 'EEEE') AS dia_da_semana,
  CASE WHEN month(data) IN (4, 6, 10) THEN true ELSE false END AS mes_pico_setor,
  current_timestamp() AS _processado_em
FROM datas;

COMMENT ON TABLE lakehouse_rotaperfume.gold.dim_calendario IS 
'Dimensão Calendário cobrindo o período de 24 meses (2024-2025) com sinalização de meses de pico de vendas do setor de perfumaria.';

ALTER TABLE lakehouse_rotaperfume.gold.dim_calendario ALTER COLUMN mes_pico_setor COMMENT 
'Flag booleana indicando meses de alta demanda/sazonalidade no setor (abril, junho e outubro).';
