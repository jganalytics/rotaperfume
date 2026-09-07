-- ==============================================================================
-- Camada Silver: Clientes (Limpeza, Deduplicação e Contratos)
-- ==============================================================================

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.clientes AS
WITH clientes_normalizados AS (
  SELECT
    trim(cliente_id) AS cliente_id,
    lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0') AS cnpj,
    initcap(regexp_replace(trim(razao_social), '\\s+', ' ')) AS razao_social,
    trim(segmento) AS segmento,
    trim(cidade) AS cidade,
    upper(trim(uf)) AS uf,
    trim(bairro) AS bairro,
    coalesce(
      try_to_date(trim(data_cadastro), 'yyyy-MM-dd'),
      try_to_date(trim(data_cadastro), 'dd/MM/yyyy')
    ) AS data_cadastro,
    CASE WHEN lower(trim(ativo)) = 's' THEN true ELSE false END AS ativo,
    trim(cliente_id) AS raw_cliente_id
  FROM lakehouse_rotaperfume.bronze.clientes
),
clientes_agrupados AS (
  SELECT
    cnpj,
    array_distinct(collect_list(raw_cliente_id)) AS cliente_ids_duplicados,
    count(1) AS _linhas_origem
  FROM clientes_normalizados
  GROUP BY cnpj
),
clientes_deduplicados AS (
  SELECT
    cn.*,
    ca.cliente_ids_duplicados,
    ca._linhas_origem,
    row_number() OVER (
      PARTITION BY cn.cnpj 
      ORDER BY cn.data_cadastro ASC, cn.cliente_id ASC
    ) AS rn
  FROM clientes_normalizados cn
  JOIN clientes_agrupados ca ON cn.cnpj = ca.cnpj
)
SELECT
  cliente_id,
  cnpj,
  razao_social,
  segmento,
  cidade,
  uf,
  bairro,
  data_cadastro,
  ativo,
  cliente_ids_duplicados,
  _linhas_origem,
  current_timestamp() AS _processado_em
FROM clientes_deduplicados
WHERE rn = 1;

-- Comentários descritivos da tabela e colunas
COMMENT ON TABLE lakehouse_rotaperfume.silver.clientes IS 
'Tabela de clientes deduplicada por CNPJ (mantendo o cadastro mais antigo), com CNPJs normalizados para 14 dígitos e datas convertidas.';

ALTER TABLE lakehouse_rotaperfume.silver.clientes ALTER COLUMN cnpj COMMENT 'CNPJ limpo e formatado com exatamente 14 dígitos (com zeros à esquerda).';
ALTER TABLE lakehouse_rotaperfume.silver.clientes ALTER COLUMN cliente_ids_duplicados COMMENT 'Array contendo todos os cliente_ids associados ao mesmo CNPJ antes da deduplicação.';

-- Contratos de Qualidade (Check Constraints)
ALTER TABLE lakehouse_rotaperfume.silver.clientes ADD CONSTRAINT chk_cnpj_len CHECK (length(cnpj) = 14);
ALTER TABLE lakehouse_rotaperfume.silver.clientes ADD CONSTRAINT chk_data_cadastro_not_null CHECK (data_cadastro IS NOT NULL);
