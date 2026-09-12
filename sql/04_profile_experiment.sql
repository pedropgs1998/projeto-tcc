-- =========================================================
-- 04_profile_experiment.sql
-- Profilagem direcionada às decisões experimentais
-- =========================================================


-- ---------------------------------------------------------
-- 1. PEDIDOS SEM ITENS
-- ---------------------------------------------------------

-- Quantos pedidos não aparecem em order_items
SELECT
    COUNT(*) AS pedidos_sem_itens
FROM raw.orders o
LEFT JOIN raw.order_items oi
    ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL;

-- Status desses pedidos
SELECT
    o.order_status,
    COUNT(*) AS quantidade
FROM raw.orders o
LEFT JOIN raw.order_items oi
    ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY quantidade DESC;


-- ---------------------------------------------------------
-- 2. DISTRIBUIÇÃO DE PRODUTOS POR CATEGORIA
-- ---------------------------------------------------------

SELECT
    product_category_name,
    COUNT(*) AS quantidade_produtos
FROM raw.products
GROUP BY product_category_name
ORDER BY quantidade_produtos DESC
LIMIT 30;


-- ---------------------------------------------------------
-- 3. PRODUTOS QUE APARECEM EM MÚLTIPLOS PEDIDOS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS produtos_com_multiplos_pedidos
FROM (
    SELECT
        product_id
    FROM raw.order_items
    GROUP BY product_id
    HAVING COUNT(DISTINCT order_id) > 1
) x;

-- Produtos com maior quantidade de pedidos distintos
SELECT
    product_id,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM raw.order_items
GROUP BY product_id
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY pedidos_distintos DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 4. PRODUTOS VENDIDOS EM DIFERENTES PERÍODOS
-- ---------------------------------------------------------

-- Produtos com primeira e última venda
WITH vendas_produto AS (
    SELECT
        oi.product_id,
        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda,
        COUNT(DISTINCT o.order_id) AS pedidos_distintos
    FROM raw.order_items oi
    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id
    GROUP BY oi.product_id
)
SELECT
    COUNT(*) AS produtos_vendidos_em_datas_diferentes
FROM vendas_produto
WHERE primeira_venda::date <> ultima_venda::date;

-- Exemplos com maior intervalo temporal
WITH vendas_produto AS (
    SELECT
        oi.product_id,
        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda,
        COUNT(DISTINCT o.order_id) AS pedidos_distintos
    FROM raw.order_items oi
    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id
    GROUP BY oi.product_id
)
SELECT
    product_id,
    pedidos_distintos,
    primeira_venda,
    ultima_venda,
    ultima_venda - primeira_venda AS intervalo
FROM vendas_produto
WHERE primeira_venda::date <> ultima_venda::date
ORDER BY intervalo DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 5. SELLERS COM MÚLTIPLOS PRODUTOS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS sellers_com_multiplos_produtos
FROM (
    SELECT
        seller_id
    FROM raw.order_items
    GROUP BY seller_id
    HAVING COUNT(DISTINCT product_id) > 1
) x;

SELECT
    seller_id,
    COUNT(DISTINCT product_id) AS produtos_distintos
FROM raw.order_items
GROUP BY seller_id
ORDER BY produtos_distintos DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 6. PRODUTOS VENDIDOS POR MÚLTIPLOS SELLERS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS produtos_com_multiplos_sellers
FROM (
    SELECT
        product_id
    FROM raw.order_items
    GROUP BY product_id
    HAVING COUNT(DISTINCT seller_id) > 1
) x;

SELECT
    product_id,
    COUNT(DISTINCT seller_id) AS sellers_distintos
FROM raw.order_items
GROUP BY product_id
HAVING COUNT(DISTINCT seller_id) > 1
ORDER BY sellers_distintos DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 7. JANELA TEMPORAL DO DATASET
-- ---------------------------------------------------------

SELECT
    MIN(order_purchase_timestamp) AS primeiro_pedido,
    MAX(order_purchase_timestamp) AS ultimo_pedido
FROM raw.orders;


-- ---------------------------------------------------------
-- 8. REVIEWS: DUPLICIDADE E CARDINALIDADE
-- ---------------------------------------------------------

-- review_id que aparece mais de uma vez
SELECT
    COUNT(*) AS review_ids_duplicados
FROM (
    SELECT
        review_id
    FROM raw.order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) x;

-- Exemplos de review_id duplicado
SELECT
    review_id,
    COUNT(*) AS quantidade,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM raw.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY quantidade DESC
LIMIT 20;

-- Quantos pedidos têm 0, 1 ou mais de 1 review
WITH reviews_por_pedido AS (
    SELECT
        o.order_id,
        COUNT(r.order_id) AS qtd_reviews
    FROM raw.orders o
    LEFT JOIN raw.order_reviews r
        ON r.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    COUNT(*) FILTER (WHERE qtd_reviews = 0) AS pedidos_sem_review,
    COUNT(*) FILTER (WHERE qtd_reviews = 1) AS pedidos_1_review,
    COUNT(*) FILTER (WHERE qtd_reviews > 1) AS pedidos_multiplas_reviews,
    MAX(qtd_reviews) AS max_reviews_em_um_pedido
FROM reviews_por_pedido;


-- ---------------------------------------------------------
-- 9. PRODUTOS CANDIDATOS PARA CENÁRIO HISTÓRICO
-- ---------------------------------------------------------

-- Busca produtos:
-- - com categoria conhecida
-- - vendidos em vários pedidos
-- - vendidos ao longo de um intervalo razoável
WITH candidatos AS (
    SELECT
        oi.product_id,
        p.product_category_name,
        COUNT(DISTINCT oi.order_id) AS qtd_pedidos,
        MIN(o.order_purchase_timestamp) AS primeira_venda,
        MAX(o.order_purchase_timestamp) AS ultima_venda
    FROM raw.order_items oi
    INNER JOIN raw.orders o
        ON o.order_id = oi.order_id
    INNER JOIN raw.products p
        ON p.product_id = oi.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY
        oi.product_id,
        p.product_category_name
)
SELECT
    product_id,
    product_category_name,
    qtd_pedidos,
    primeira_venda,
    ultima_venda,
    ultima_venda - primeira_venda AS intervalo
FROM candidatos
WHERE qtd_pedidos >= 5
  AND ultima_venda - primeira_venda >= INTERVAL '180 days'
ORDER BY qtd_pedidos DESC, intervalo DESC
LIMIT 30;