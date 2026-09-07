-- ==============================================================================
-- Camada Silver: Pedidos (Limpeza, Tipagem e Contratos)
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pedidos AS
WITH clientes_normalizados AS (
  SELECT
    trim(cliente_id) AS raw_cliente_id,
    lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0') AS cnpj,
    coalesce(
      try_to_date(trim(data_cadastro), 'yyyy-MM-dd'),
      try_to_date(trim(data_cadastro), 'dd/MM/yyyy')
    ) AS data_cadastro
  FROM lakehouse_rotaperfume.bronze.clientes
),
mapa_clientes AS (
  SELECT
    raw_cliente_id,
    first_value(raw_cliente_id) OVER (
      PARTITION BY cnpj
      ORDER BY data_cadastro ASC, raw_cliente_id ASC
    ) AS canonical_cliente_id
  FROM clientes_normalizados
),
pedidos_normalizados AS (
  SELECT
    trim(p.pedido_id) AS pedido_id,
    coalesce(m.canonical_cliente_id, trim(p.cliente_id)) AS cliente_id,
    trim(p.vendedor_id) AS vendedor_id,
    coalesce(
      try_to_date(trim(p.data_pedido), 'yyyy-MM-dd'),
      try_to_date(trim(p.data_pedido), 'dd/MM/yyyy')
    ) AS data_pedido,
    trim(p.canal) AS canal,
    trim(p.status) AS status,
    CAST(trim(p.valor_total) AS DECIMAL(18,2)) AS valor_total,
    CASE WHEN lower(trim(p.status)) = 'cancelado' THEN true ELSE false END AS cancelado
  FROM lakehouse_rotaperfume.bronze.pedidos p
  LEFT JOIN mapa_clientes m ON trim(p.cliente_id) = m.raw_cliente_id
)
SELECT
  pedido_id,
  cliente_id,
  vendedor_id,
  data_pedido,
  year(data_pedido) AS ano,
  month(data_pedido) AS mes,
  canal,
  status,
  cancelado,
  valor_total,
  CASE WHEN cancelado THEN CAST(0.00 AS DECIMAL(18,2)) ELSE valor_total END AS valor_liquido,
  1 AS _linhas_origem,
  current_timestamp() AS _processado_em
FROM pedidos_normalizados;

-- Comentários descritivos
COMMENT ON TABLE lakehouse_rotaperfume.silver.pedidos IS 
'Tabela de pedidos limpa com tipagem de datas, cálculo de ano/mês, identificação de cancelamentos e cálculo de valor líquido.';

ALTER TABLE lakehouse_rotaperfume.silver.pedidos ALTER COLUMN cancelado COMMENT 'Flag booleana indicando se o pedido foi cancelado com base no status.';
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ALTER COLUMN valor_liquido COMMENT 'Valor líquido do pedido: 0 se cancelado, ou valor_total caso contrário (pode ser negativo em caso de devolução).';

-- Contratos de Qualidade (Check Constraints)
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ADD CONSTRAINT chk_data_pedido_not_null CHECK (data_pedido IS NOT NULL);
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ADD CONSTRAINT chk_cancelado_valor CHECK (NOT cancelado OR valor_liquido = 0);
