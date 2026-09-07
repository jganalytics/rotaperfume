-- ==============================================================================
-- SUÍTE DE 9 TESTES AUTOMATIZADOS DE INTEGRIDADE E CONCILIAÇÃO FINANCEIRA
-- ==============================================================================

WITH t1 AS (
  SELECT
    '1. Conciliação de Receita (Gold = Silver = R$ 102.303.828,05)' AS teste,
    abs(
      (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas) - 102303828.05
    ) <= 0.01 AND
    abs(
      (SELECT round(sum(valor_liquido), 2) FROM lakehouse_rotaperfume.silver.pedidos WHERE NOT cancelado) - 102303828.05
    ) <= 0.01 AS passou,
    concat('Gold: R$ ', (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas), ' | Esperado: R$ 102303828.05') AS detalhe
),
t2 AS (
  SELECT
    '2. CNPJ Único na Silver Clientes' AS teste,
    (SELECT count(*) - count(distinct cnpj) FROM lakehouse_rotaperfume.silver.clientes) = 0 AS passou,
    concat('Duplicados: ', (SELECT count(*) - count(distinct cnpj) FROM lakehouse_rotaperfume.silver.clientes)) AS detalhe
),
t3 AS (
  SELECT
    '3. Sem data_pedido nula na Silver Pedidos' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL) = 0 AS passou,
    concat('Datas nulas: ', (SELECT count(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL)) AS detalhe
),
t4 AS (
  SELECT
    '4. Receita Negativa Exclusiva de Devolução' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas WHERE receita < 0 AND NOT devolucao) = 0 AS passou,
    concat('Inconsistências: ', (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas WHERE receita < 0 AND NOT devolucao)) AS detalhe
),
t5 AS (
  SELECT
    '5. Volume de Linhas da Fato Vendas (140k - 250k)' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas) BETWEEN 140000 AND 250000 AS passou,
    concat('Linhas Fato: ', (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas)) AS detalhe
),
t6 AS (
  SELECT
    '6. Chave Estrangeira pedido_id (Gold -> Silver)' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f LEFT JOIN lakehouse_rotaperfume.silver.pedidos p ON f.pedido_id = p.pedido_id WHERE p.pedido_id IS NULL) = 0 AS passou,
    concat('Pedidos Órfãos: ', (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f LEFT JOIN lakehouse_rotaperfume.silver.pedidos p ON f.pedido_id = p.pedido_id WHERE p.pedido_id IS NULL)) AS detalhe
),
t7 AS (
  SELECT
    '7. Chave Estrangeira cliente_id (Gold -> Silver)' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON f.cliente_id = c.cliente_id WHERE c.cliente_id IS NULL) = 0 AS passou,
    concat('Clientes Órfãos: ', (SELECT count(*) FROM lakehouse_rotaperfume.gold.fato_vendas f LEFT JOIN lakehouse_rotaperfume.silver.clientes c ON f.cliente_id = c.cliente_id WHERE c.cliente_id IS NULL)) AS detalhe
),
t8 AS (
  SELECT
    '8. Conciliação Mart Produto vs Fato Vendas' AS teste,
    abs(
      (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.mart_produto_performance) -
      (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas)
    ) <= 0.01 AS passou,
    concat('Diferença: ', abs((SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.mart_produto_performance) - (SELECT round(sum(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas))) AS detalhe
),
t9 AS (
  SELECT
    '9. CNPJ com exatamente 14 dígitos' AS teste,
    (SELECT count(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) != 14) = 0 AS passou,
    concat('CNPJs Inválidos: ', (SELECT count(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) != 14)) AS detalhe
),
todos_testes AS (
  SELECT * FROM t1
  UNION ALL SELECT * FROM t2
  UNION ALL SELECT * FROM t3
  UNION ALL SELECT * FROM t4
  UNION ALL SELECT * FROM t5
  UNION ALL SELECT * FROM t6
  UNION ALL SELECT * FROM t7
  UNION ALL SELECT * FROM t8
  UNION ALL SELECT * FROM t9
)
SELECT
  teste,
  CASE WHEN passou THEN 'PASSOU ✅' ELSE 'FALHOU ❌' END AS resultado,
  detalhe,
  CASE WHEN NOT passou THEN raise_error(concat('FALHA NO TESTE: ', teste, ' - ', detalhe)) ELSE NULL END AS erro_check
FROM todos_testes;
