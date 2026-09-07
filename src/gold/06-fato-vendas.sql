-- ==============================================================================
-- CONTRATO NEGOCIAL DA TABELA FATO VENDAS (gold.fato_vendas):
--
-- Granularidade: Uma linha por ITEM de pedido (não cancelado).
-- Filtro        : Exclui pedidos cancelados (cancelado = true). NÃO exclui devoluções (devolucao = true).
-- Dimensões     : data_pedido, ano, mes, canal, cliente_id, razao_social, segmento, cidade, vendedor_id, sku, categoria, marca, nota_olfativa.
-- Métricas      : quantidade, preco_praticado, receita, custo, margem, devolucao.
-- Regras        : 
--   - receita  = valor_bruto do item (negativo para devoluções).
--   - custo    = quantidade * custo_unitario do produto (negativo para devoluções).
--   - margem   = receita - custo.
--   - Devoluções entram com quantidade e receita NEGATIVAS, mantendo o faturamento líquido total idêntico à Silver.
-- Particionamento: ano, mes.
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fato_vendas
USING DELTA
PARTITIONED BY (ano, mes)
AS
SELECT
  i.item_id,
  i.pedido_id,
  p.data_pedido,
  p.canal,
  p.cliente_id,
  c.razao_social,
  c.segmento,
  c.cidade,
  p.vendedor_id,
  i.sku,
  pr.categoria,
  pr.marca,
  pr.nota_olfativa,
  i.devolucao,
  i.quantidade,
  i.preco_praticado,
  i.valor_bruto AS receita,
  CAST(i.quantidade * pr.custo_unitario AS DECIMAL(18,2)) AS custo,
  CAST(i.valor_bruto - (i.quantidade * pr.custo_unitario) AS DECIMAL(18,2)) AS margem,
  p.ano,
  p.mes,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.itens_pedido i
JOIN lakehouse_rotaperfume.silver.pedidos p ON i.pedido_id = p.pedido_id
LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON p.cliente_id = c.cliente_id
LEFT JOIN lakehouse_rotaperfume.silver.produtos pr ON i.sku = pr.sku
WHERE p.cancelado IS FALSE;

-- Comentários orientados a negócio em TODAS as colunas para o Genie AI
COMMENT ON TABLE lakehouse_rotaperfume.gold.fato_vendas IS 
'Tabela fato de vendas no grão de item de pedido (excluindo pedidos cancelados). Mantém itens de devolução com sinal negativo para conciliação financeira exata.';

ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN item_id COMMENT 'Identificador único da linha de item do pedido comercial.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN pedido_id COMMENT 'Identificador único do pedido de venda ao qual o item pertence.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN data_pedido COMMENT 'Data de realização do pedido no sistema ERP.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN canal COMMENT 'Canal de venda por onde o pedido foi originado (ex: B2B, E-commerce, Representantes).';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN cliente_id COMMENT 'Identificador único do cliente comprador.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN razao_social COMMENT 'Razão social oficial padronizada do cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN segmento COMMENT 'Segmento de atuação comercial do cliente (ex: Perfumaria, Varejo, Distribuidor).';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN cidade COMMENT 'Cidade do endereço de faturamento do cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN vendedor_id COMMENT 'Identificador do vendedor responsável pelo pedido.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN sku COMMENT 'Código SKU do produto vendido.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN categoria COMMENT 'Categoria mercadológica do produto (ex: Perfumes, Loções, Kits).';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN marca COMMENT 'Marca comercial do produto.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN nota_olfativa COMMENT 'Família ou nota olfativa do produto (ex: Floral, Amadeirado, Cítrico).';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN devolucao COMMENT 'Flag booleana indicando devolução de item. Quando true, quantidade e receita são negativas.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN quantidade COMMENT 'Quantidade negociada de unidades do item. Valor negativo em devoluções.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN preco_praticado COMMENT 'Preço unitário líquido negociado por item no pedido.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN receita COMMENT 'Faturamento bruto gerado pelo item (quantidade * preco_praticado). Negativo em devoluções.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN custo COMMENT 'Custo total do produto vendido (quantidade * custo_unitario). Não considera frete ou tributos.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN margem COMMENT 'Receita menos custo do produto. Não considera desconto comercial global nem frete.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN ano COMMENT 'Ano de emissão do pedido para particionamento e análise temporal.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN mes COMMENT 'Mês numérico de emissão do pedido para particionamento e análise temporal.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN _processado_em COMMENT 'Timestamp da última atualização do registro na camada Gold.';
