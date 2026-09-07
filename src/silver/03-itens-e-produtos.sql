-- ==============================================================================
-- Camada Silver: Produtos e Itens do Pedido (Tipagem, Devoluções e SKU Descontinuado)
-- ==============================================================================

-- 1. Tabela Silver: Produtos
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.produtos AS
SELECT
  trim(sku) AS sku,
  trim(descricao) AS descricao,
  trim(categoria) AS categoria,
  trim(marca) AS marca,
  trim(nota_olfativa) AS nota_olfativa,
  CAST(trim(preco_tabela) AS DECIMAL(18,2)) AS preco_tabela,
  CAST(trim(custo_unitario) AS DECIMAL(18,2)) AS custo_unitario,
  trim(unidade) AS unidade,
  CASE WHEN lower(trim(ativo)) = 's' THEN true ELSE false END AS ativo,
  coalesce(
    try_to_date(trim(data_lancamento), 'yyyy-MM-dd'),
    try_to_date(trim(data_lancamento), 'dd/MM/yyyy')
  ) AS data_lancamento,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.produtos;

COMMENT ON TABLE lakehouse_rotaperfume.silver.produtos IS 
'Tabela de produtos com valores convertidos, datas padronizadas e flag booleana de ativo.';


-- 2. Tabela Silver: Itens de Pedido
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.itens_pedido AS
WITH itens_raw AS (
  SELECT
    trim(item_id) AS item_id,
    trim(pedido_id) AS pedido_id,
    trim(sku) AS sku,
    CAST(trim(quantidade) AS INT) AS quantidade_raw,
    CAST(trim(preco_praticado) AS DECIMAL(18,2)) AS preco_praticado,
    CAST(trim(desconto_pct) AS DECIMAL(18,2)) AS desconto_pct,
    CAST(trim(valor_bruto) AS DECIMAL(18,2)) AS valor_bruto
  FROM lakehouse_rotaperfume.bronze.itens_pedido
)
SELECT
  i.item_id,
  i.pedido_id,
  i.sku,
  i.quantidade_raw AS quantidade,
  abs(i.quantidade_raw) AS quantidade_abs,
  CASE WHEN i.quantidade_raw < 0 THEN true ELSE false END AS devolucao,
  i.preco_praticado,
  i.desconto_pct,
  i.valor_bruto,
  CASE WHEN p.sku IS NOT NULL AND p.ativo IS FALSE THEN true ELSE false END AS sku_descontinuado,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM itens_raw i
LEFT JOIN lakehouse_rotaperfume.silver.produtos p ON i.sku = p.sku;

-- Comentários descritivos da tabela de itens
COMMENT ON TABLE lakehouse_rotaperfume.silver.itens_pedido IS 
'Tabela de itens do pedido com sinalização de devoluções (quantidade negativa) e cruzamento com produtos para marcas de SKU descontinuado.';

ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ALTER COLUMN devolucao COMMENT 'Flag booleana indicando devolução (quantidade original < 0).';
ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ALTER COLUMN sku_descontinuado COMMENT 'Flag booleana indicando se o produto associado ao SKU está inativo/descontinuado no cadastro.';

-- Contrato de Qualidade (Check Constraint)
ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ADD CONSTRAINT chk_qtd_abs CHECK (quantidade_abs > 0);
