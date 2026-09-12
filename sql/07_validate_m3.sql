-- =========================================================
-- 07_validate_m3.sql
-- Validação final da Mudança 3
-- =========================================================

-- Pressuposto:
-- o arquivo m3_product_reclassification.csv será carregado
-- posteriormente em uma tabela de controle.

-- ---------------------------------------------------------
-- 1. Conferir categorias originais dos produtos
-- ---------------------------------------------------------

SELECT
    product_id,
    product_category_name
FROM raw.products
WHERE product_id IN (
    '99a4788cb24856965c36a24e339b6058',
    'aca2eb7d00ea1a7b8ebd4e68314663af',
    '422879e10f46682990de24d770e7f83d',
    'd1c427060a0f73f6b889a5c7c61f2ac4',
    '389d119b48cf3043d311335e499d9c6b',
    '53b36df67ebb7c41585e8d54d6772e08',
    '368c6c730842d78016ad823897a372db',
    '53759a2ecddad2bb87a079a1f1519f73',
    '154e7e31ebfa092203795c972e5804a6',
    '2b4609f8948be18874494203496bc318'
)
ORDER BY product_id;


-- ---------------------------------------------------------
-- 2. Confirmar vendas antes e depois da data efetiva
-- ---------------------------------------------------------

SELECT
    oi.product_id,

    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE o.order_purchase_timestamp < TIMESTAMP '2018-01-01'
    ) AS pedidos_antes,

    COUNT(DISTINCT oi.order_id) FILTER (
        WHERE o.order_purchase_timestamp >= TIMESTAMP '2018-01-01'
    ) AS pedidos_depois

FROM raw.order_items oi

INNER JOIN raw.orders o
    ON o.order_id = oi.order_id

WHERE oi.product_id IN (
    '99a4788cb24856965c36a24e339b6058',
    'aca2eb7d00ea1a7b8ebd4e68314663af',
    '422879e10f46682990de24d770e7f83d',
    'd1c427060a0f73f6b889a5c7c61f2ac4',
    '389d119b48cf3043d311335e499d9c6b',
    '53b36df67ebb7c41585e8d54d6772e08',
    '368c6c730842d78016ad823897a372db',
    '53759a2ecddad2bb87a079a1f1519f73',
    '154e7e31ebfa092203795c972e5804a6',
    '2b4609f8948be18874494203496bc318'
)
AND o.order_status = 'delivered'

GROUP BY oi.product_id
ORDER BY oi.product_id;


-- ---------------------------------------------------------
-- 3. Totais que deverão permanecer invariantes
-- ---------------------------------------------------------

SELECT
    COUNT(DISTINCT oi.order_id) AS pedidos,
    COUNT(*) AS itens,
    SUM(oi.price) AS valor_bruto
FROM raw.order_items oi

INNER JOIN raw.orders o
    ON o.order_id = oi.order_id

WHERE oi.product_id IN (
    '99a4788cb24856965c36a24e339b6058',
    'aca2eb7d00ea1a7b8ebd4e68314663af',
    '422879e10f46682990de24d770e7f83d',
    'd1c427060a0f73f6b889a5c7c61f2ac4',
    '389d119b48cf3043d311335e499d9c6b',
    '53b36df67ebb7c41585e8d54d6772e08',
    '368c6c730842d78016ad823897a372db',
    '53759a2ecddad2bb87a079a1f1519f73',
    '154e7e31ebfa092203795c972e5804a6',
    '2b4609f8948be18874494203496bc318'
)
AND o.order_status = 'delivered';