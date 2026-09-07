-- ==============================================================================
-- Camada Silver: CRM e Financeiro (Vendedores, Carteira, Oportunidades, Visitas, Pagamentos e Estoque)
-- ==============================================================================

-- 1. Vendedores
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.vendedores AS
SELECT
  trim(vendedor_id) AS vendedor_id,
  initcap(trim(nome)) AS nome,
  trim(regiao) AS regiao,
  upper(trim(uf)) AS uf,
  coalesce(
    try_to_date(trim(data_admissao), 'yyyy-MM-dd'),
    try_to_date(trim(data_admissao), 'dd/MM/yyyy')
  ) AS data_admissao,
  coalesce(
    try_to_date(trim(data_desligamento), 'yyyy-MM-dd'),
    try_to_date(trim(data_desligamento), 'dd/MM/yyyy')
  ) AS data_desligamento,
  CASE WHEN try_to_date(trim(data_desligamento), 'yyyy-MM-dd') IS NULL 
        AND try_to_date(trim(data_desligamento), 'dd/MM/yyyy') IS NULL 
       THEN true ELSE false END AS ativo,
  CAST(trim(meta_mensal) AS DECIMAL(18,2)) AS meta_mensal,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.vendedores;

COMMENT ON TABLE lakehouse_rotaperfume.silver.vendedores IS 
'Tabela de vendedores com datas de admissão/desligamento padronizadas e flag booleana de ativo.';


-- 2. Carteira (com identificação de vendedor desligado)
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.carteira AS
WITH carteira_raw AS (
  SELECT
    trim(carteira_id) AS carteira_id,
    trim(cliente_id) AS cliente_id,
    trim(vendedor_id) AS vendedor_id,
    coalesce(
      try_to_date(trim(data_inicio), 'yyyy-MM-dd'),
      try_to_date(trim(data_inicio), 'dd/MM/yyyy')
    ) AS data_inicio,
    coalesce(
      try_to_date(trim(data_fim), 'yyyy-MM-dd'),
      try_to_date(trim(data_fim), 'dd/MM/yyyy')
    ) AS data_fim
  FROM lakehouse_rotaperfume.bronze.carteira
)
SELECT
  c.carteira_id,
  c.cliente_id,
  c.vendedor_id,
  c.data_inicio,
  c.data_fim,
  CASE WHEN (c.data_fim IS NULL OR c.data_fim >= current_date()) THEN true ELSE false END AS vigente,
  CASE WHEN v.data_desligamento IS NOT NULL 
        AND (c.data_fim IS NULL OR c.data_fim >= current_date()) 
       THEN true ELSE false END AS orfao_vendedor_desligado,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM carteira_raw c
LEFT JOIN lakehouse_rotaperfume.silver.vendedores v ON c.vendedor_id = v.vendedor_id;

COMMENT ON TABLE lakehouse_rotaperfume.silver.carteira IS 
'Tabela de carteira de clientes expondo vínculos com vendedores desligados (orfao_vendedor_desligado) sem alterar a origem.';

ALTER TABLE lakehouse_rotaperfume.silver.carteira ALTER COLUMN orfao_vendedor_desligado COMMENT 
'Flag booleana indicando carteira vigente associada a vendedor desligado.';


-- 3. Oportunidades
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.oportunidades AS
SELECT
  trim(oportunidade_id) AS oportunidade_id,
  trim(cliente_id) AS cliente_id,
  trim(vendedor_id) AS vendedor_id,
  trim(origem) AS origem,
  coalesce(
    try_to_date(trim(data_abertura), 'yyyy-MM-dd'),
    try_to_date(trim(data_abertura), 'dd/MM/yyyy')
  ) AS data_abertura,
  trim(etapa) AS etapa,
  CAST(trim(probabilidade_pct) AS INT) AS probabilidade_pct,
  CAST(trim(valor_estimado) AS DECIMAL(18,2)) AS valor_estimado,
  coalesce(
    try_to_date(trim(data_fechamento), 'yyyy-MM-dd'),
    try_to_date(trim(data_fechamento), 'dd/MM/yyyy')
  ) AS data_fechamento,
  CAST(trim(ciclo_dias) AS INT) AS ciclo_dias,
  trim(motivo_perda) AS motivo_perda,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.oportunidades;

COMMENT ON TABLE lakehouse_rotaperfume.silver.oportunidades IS 
'Tabela de oportunidades do CRM com etapas mantidas conforme a origem (ex: Fechado ganho, Fechado perdido) e valores tipados.';


-- 4. Visitas
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.visitas AS
SELECT
  trim(visita_id) AS visita_id,
  trim(cliente_id) AS cliente_id,
  trim(vendedor_id) AS vendedor_id,
  coalesce(
    try_to_date(trim(data_visita), 'yyyy-MM-dd'),
    try_to_date(trim(data_visita), 'dd/MM/yyyy')
  ) AS data_visita,
  trim(resultado) AS resultado,
  CAST(trim(duracao_min) AS INT) AS duracao_min,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.visitas;

COMMENT ON TABLE lakehouse_rotaperfume.silver.visitas IS 
'Tabela de visitas do CRM com datas de visita e duração em minutos convertidos.';


-- 5. Pagamentos
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pagamentos AS
SELECT
  trim(pagamento_id) AS pagamento_id,
  trim(pedido_id) AS pedido_id,
  trim(forma_pagamento) AS forma_pagamento,
  CAST(trim(parcelas) AS INT) AS parcelas,
  CAST(trim(valor) AS DECIMAL(18,2)) AS valor,
  CAST(trim(taxa_pct) AS DECIMAL(18,2)) AS taxa_pct,
  CAST(trim(valor_liquido) AS DECIMAL(18,2)) AS valor_liquido,
  coalesce(
    try_to_date(trim(data_vencimento), 'yyyy-MM-dd'),
    try_to_date(trim(data_vencimento), 'dd/MM/yyyy')
  ) AS data_vencimento,
  coalesce(
    try_to_date(trim(data_pagamento), 'yyyy-MM-dd'),
    try_to_date(trim(data_pagamento), 'dd/MM/yyyy')
  ) AS data_pagamento,
  trim(status_pagamento) AS status_pagamento,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.pagamentos;

COMMENT ON TABLE lakehouse_rotaperfume.silver.pagamentos IS 
'Tabela de pagamentos do ERP com valores e taxas decimais, parcelas e datas de vencimento/pagamento tratadas.';


-- 6. Estoque
CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.estoque AS
SELECT
  coalesce(
    try_to_date(trim(data_snapshot), 'yyyy-MM-dd'),
    try_to_date(trim(data_snapshot), 'dd/MM/yyyy')
  ) AS data_snapshot,
  trim(sku) AS sku,
  CAST(trim(saldo) AS INT) AS saldo,
  CASE WHEN CAST(trim(saldo) AS INT) = 0 THEN true ELSE false END AS ruptura,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.bronze.estoque;

COMMENT ON TABLE lakehouse_rotaperfume.silver.estoque IS 
'Tabela de estoque com sinalização de ruptura de produto (saldo igual a zero).';

ALTER TABLE lakehouse_rotaperfume.silver.estoque ALTER COLUMN ruptura COMMENT 'Flag booleana indicando ruptura de produto (saldo = 0).';
