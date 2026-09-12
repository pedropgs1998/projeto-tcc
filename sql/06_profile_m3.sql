-- =========================================================
-- 06_profile_m3.sql
-- Validação dos candidatos para a Mudança 3
-- Preservação histórica de product_category_name
-- =========================================================


-- ---------------------------------------------------------
-- PARÂMETRO DA MUDANÇA
-- ---------------------------------------------------------
-- Data efetiva candidata:
-- 2018-01-01
--
-- A ideia é verificar produtos que tenham vendas suficientes
-- antes e depois dessa data.


-- ---------------------------------------------------------
-- 1. BASE DE PRODUTOS ELEGÍVEIS
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,
        p.product_category_name,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois,

        COUNT(DISTINCT oi.order_id) AS pedidos_total,

        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_category_name
)

SELECT
    COUNT(*) AS produtos_com_vendas_antes_e_depois
FROM produto_vendas
WHERE pedidos_antes > 0
  AND pedidos_depois > 0;


-- ---------------------------------------------------------
-- 2. SENSIBILIDADE DO CRITÉRIO
-- ---------------------------------------------------------
-- Quantos produtos seriam elegíveis utilizando diferentes
-- quantidades mínimas de pedidos antes e depois da mudança.
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY p.product_id
)

SELECT
    COUNT(*) FILTER (
        WHERE pedidos_antes >= 1
          AND pedidos_depois >= 1
    ) AS minimo_1_1,

    COUNT(*) FILTER (
        WHERE pedidos_antes >= 3
          AND pedidos_depois >= 3
    ) AS minimo_3_3,

    COUNT(*) FILTER (
        WHERE pedidos_antes >= 5
          AND pedidos_depois >= 5
    ) AS minimo_5_5,

    COUNT(*) FILTER (
        WHERE pedidos_antes >= 10
          AND pedidos_depois >= 10
    ) AS minimo_10_10,

    COUNT(*) FILTER (
        WHERE pedidos_antes >= 20
          AND pedidos_depois >= 20
    ) AS minimo_20_20

FROM produto_vendas;


-- ---------------------------------------------------------
-- 3. CANDIDATOS COM CRITÉRIO 5 ANTES + 5 DEPOIS
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,
        p.product_category_name,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois,

        COUNT(DISTINCT oi.order_id) AS pedidos_total,

        COUNT(*) AS itens_total,

        SUM(oi.price) AS valor_bruto_total,

        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_category_name
)

SELECT
    product_id,
    product_category_name,
    pedidos_antes,
    pedidos_depois,
    pedidos_total,
    itens_total,
    valor_bruto_total,
    primeira_venda,
    ultima_venda

FROM produto_vendas

WHERE pedidos_antes >= 5
  AND pedidos_depois >= 5

ORDER BY
    pedidos_total DESC,
    product_id

LIMIT 30;


-- ---------------------------------------------------------
-- 4. TOP 10 CANDIDATOS PELA REGRA PROPOSTA
-- ---------------------------------------------------------
-- Regra candidata:
--
-- - categoria não nula
-- - pedidos entregues
-- - >= 5 pedidos antes de 2018-01-01
-- - >= 5 pedidos depois de 2018-01-01
-- - selecionar os 10 produtos com mais pedidos
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,
        p.product_category_name,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois,

        COUNT(DISTINCT oi.order_id) AS pedidos_total,

        COUNT(*) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS itens_antes,

        COUNT(*) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS itens_depois,

        SUM(oi.price) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS valor_bruto_antes,

        SUM(oi.price) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS valor_bruto_depois,

        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_category_name
),

selecionados AS (
    SELECT *
    FROM produto_vendas
    WHERE pedidos_antes >= 5
      AND pedidos_depois >= 5
    ORDER BY
        pedidos_total DESC,
        product_id
    LIMIT 10
)

SELECT
    product_id,
    product_category_name AS categoria_original,

    pedidos_antes,
    pedidos_depois,

    itens_antes,
    itens_depois,

    valor_bruto_antes,
    valor_bruto_depois,

    primeira_venda,
    ultima_venda,

    DATE '2018-01-01' AS data_efetiva_m3

FROM selecionados

ORDER BY
    pedidos_antes + pedidos_depois DESC,
    product_id;


-- ---------------------------------------------------------
-- 5. VALIDAÇÃO DA MASSA EXPERIMENTAL DOS 10 SELECIONADOS
-- ---------------------------------------------------------
-- Mostra quanto esses produtos representam antes/depois.
-- Serve apenas para verificar se existe massa suficiente para
-- tornar o comportamento histórico observável.
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois,

        COUNT(DISTINCT oi.order_id) AS pedidos_total

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY p.product_id
),

selecionados AS (
    SELECT
        product_id
    FROM produto_vendas
    WHERE pedidos_antes >= 5
      AND pedidos_depois >= 5
    ORDER BY
        pedidos_total DESC,
        product_id
    LIMIT 10
)

SELECT
    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
    ) AS pedidos_antes,

    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
    ) AS pedidos_depois,

    COUNT(*) FILTER (
        WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
    ) AS itens_antes,

    COUNT(*) FILTER (
        WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
    ) AS itens_depois,

    SUM(oi.price) FILTER (
        WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
    ) AS valor_bruto_antes,

    SUM(oi.price) FILTER (
        WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
    ) AS valor_bruto_depois

FROM raw.order_items oi

INNER JOIN raw.orders o
    ON o.order_id = oi.order_id

INNER JOIN selecionados s
    ON s.product_id = oi.product_id

WHERE o.order_status = 'delivered';


-- ---------------------------------------------------------
-- 6. DISTRIBUIÇÃO DAS CATEGORIAS DOS 10 PRODUTOS
-- ---------------------------------------------------------
-- Ajuda posteriormente a escolher categorias novas legíveis
-- para o cenário sintético.
-- ---------------------------------------------------------

WITH produto_vendas AS (
    SELECT
        p.product_id,
        p.product_category_name,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
        ) AS pedidos_antes,

        COUNT(DISTINCT oi.order_id) FILTER (
            WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
        ) AS pedidos_depois,

        COUNT(DISTINCT oi.order_id) AS pedidos_total

    FROM raw.products p

    INNER JOIN raw.order_items oi
        ON oi.product_id = p.product_id

    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id

    WHERE p.product_category_name IS NOT NULL
      AND o.order_status = 'delivered'

    GROUP BY
        p.product_id,
        p.product_category_name
),

selecionados AS (
    SELECT *
    FROM produto_vendas
    WHERE pedidos_antes >= 5
      AND pedidos_depois >= 5
    ORDER BY
        pedidos_total DESC,
        product_id
    LIMIT 10
)

SELECT
    product_category_name,
    COUNT(*) AS produtos_selecionados

FROM selecionados

GROUP BY product_category_name

ORDER BY
    produtos_selecionados DESC,
    product_category_name;