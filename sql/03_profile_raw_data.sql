-- =========================================================
-- 03_profile_raw_data.sql
-- Profilagem estrutural do dataset Olist
-- =========================================================


-- ---------------------------------------------------------
-- 1. ORDERS
-- ---------------------------------------------------------

-- Total de linhas x pedidos distintos
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM raw.orders;

-- Pedidos duplicados
SELECT
    order_id,
    COUNT(*) AS quantidade
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY quantidade DESC;

-- Distribuição de status
SELECT
    order_status,
    COUNT(*) AS quantidade
FROM raw.orders
GROUP BY order_status
ORDER BY quantidade DESC;

-- Pedidos sem data de entrega ao cliente
SELECT
    COUNT(*) AS pedidos_sem_data_entrega
FROM raw.orders
WHERE order_delivered_customer_date IS NULL;

-- Pedidos entregues
SELECT
    COUNT(*) AS pedidos_entregues
FROM raw.orders
WHERE order_status = 'delivered';


-- ---------------------------------------------------------
-- 2. CUSTOMERS
-- ---------------------------------------------------------

-- customer_id x customer_unique_id
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT customer_id) AS customer_ids,
    COUNT(DISTINCT customer_unique_id) AS customer_unique_ids
FROM raw.customers;

-- Quantos clientes "reais" possuem mais de um customer_id
SELECT
    COUNT(*) AS unique_customers_com_multiplos_customer_ids
FROM (
    SELECT
        customer_unique_id
    FROM raw.customers
    GROUP BY customer_unique_id
    HAVING COUNT(DISTINCT customer_id) > 1
) x;

-- Maiores quantidades de customer_id por customer_unique_id
SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_id) AS qtd_customer_ids
FROM raw.customers
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
ORDER BY qtd_customer_ids DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 3. ORDER ITEMS
-- ---------------------------------------------------------

-- Quantidade de pedidos representados em order_items
SELECT
    COUNT(*) AS total_itens,
    COUNT(DISTINCT order_id) AS pedidos_com_itens
FROM raw.order_items;

-- Quantos pedidos têm 1 item ou mais de 1 item
WITH itens_por_pedido AS (
    SELECT
        order_id,
        COUNT(*) AS qtd_itens
    FROM raw.order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) FILTER (WHERE qtd_itens = 1) AS pedidos_1_item,
    COUNT(*) FILTER (WHERE qtd_itens > 1) AS pedidos_multiplos_itens,
    MAX(qtd_itens) AS max_itens_em_um_pedido,
    AVG(qtd_itens::NUMERIC) AS media_itens_por_pedido
FROM itens_por_pedido;

-- Pedidos com múltiplos vendedores
WITH vendedores_por_pedido AS (
    SELECT
        order_id,
        COUNT(DISTINCT seller_id) AS qtd_vendedores
    FROM raw.order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) FILTER (WHERE qtd_vendedores = 1) AS pedidos_1_vendedor,
    COUNT(*) FILTER (WHERE qtd_vendedores > 1) AS pedidos_multiplos_vendedores,
    MAX(qtd_vendedores) AS max_vendedores_em_um_pedido
FROM vendedores_por_pedido;

-- order_item_id é único globalmente?
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_item_id) AS order_item_ids_distintos
FROM raw.order_items;

-- order_id + order_item_id é único?
SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT (order_id, order_item_id)) AS chaves_compostas_distintas
FROM raw.order_items;


-- ---------------------------------------------------------
-- 4. PAYMENTS
-- ---------------------------------------------------------

-- Total de registros x pedidos
SELECT
    COUNT(*) AS total_pagamentos,
    COUNT(DISTINCT order_id) AS pedidos_com_pagamento
FROM raw.order_payments;

-- Quantos pagamentos por pedido
WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        COUNT(*) AS qtd_pagamentos
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) FILTER (WHERE qtd_pagamentos = 1) AS pedidos_1_pagamento,
    COUNT(*) FILTER (WHERE qtd_pagamentos > 1) AS pedidos_multiplos_pagamentos,
    MAX(qtd_pagamentos) AS max_pagamentos_em_um_pedido,
    AVG(qtd_pagamentos::NUMERIC) AS media_pagamentos_por_pedido
FROM pagamentos_por_pedido;

-- Pedidos com múltiplos tipos de pagamento
SELECT
    COUNT(*) AS pedidos_com_multiplos_tipos
FROM (
    SELECT
        order_id
    FROM raw.order_payments
    GROUP BY order_id
    HAVING COUNT(DISTINCT payment_type) > 1
) x;

-- Tipos de pagamento
SELECT
    payment_type,
    COUNT(*) AS quantidade,
    SUM(payment_value) AS valor_total
FROM raw.order_payments
GROUP BY payment_type
ORDER BY quantidade DESC;

-- payment_sequential dentro do pedido
SELECT
    order_id,
    COUNT(*) AS registros,
    MAX(payment_sequential) AS maior_sequencial
FROM raw.order_payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY registros DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 5. RECONCILIAÇÃO: ITENS + FRETE x PAGAMENTOS
-- ---------------------------------------------------------

WITH itens AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS valor_itens_frete
    FROM raw.order_items
    GROUP BY order_id
),
pagamentos AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago
    FROM raw.order_payments
    GROUP BY order_id
),
comparacao AS (
    SELECT
        i.order_id,
        i.valor_itens_frete,
        p.valor_pago,
        p.valor_pago - i.valor_itens_frete AS diferenca
    FROM itens i
    INNER JOIN pagamentos p
        ON p.order_id = i.order_id
)
SELECT
    COUNT(*) AS pedidos_comparados,
    COUNT(*) FILTER (WHERE ABS(diferenca) <= 0.01) AS pedidos_equivalentes,
    COUNT(*) FILTER (WHERE ABS(diferenca) > 0.01) AS pedidos_com_diferenca,
    MAX(ABS(diferenca)) AS maior_diferenca
FROM comparacao;

-- Exemplos de divergência
WITH itens AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS valor_itens_frete
    FROM raw.order_items
    GROUP BY order_id
),
pagamentos AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    i.order_id,
    i.valor_itens_frete,
    p.valor_pago,
    p.valor_pago - i.valor_itens_frete AS diferenca
FROM itens i
INNER JOIN pagamentos p
    ON p.order_id = i.order_id
WHERE ABS(p.valor_pago - i.valor_itens_frete) > 0.01
ORDER BY ABS(p.valor_pago - i.valor_itens_frete) DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 6. REVIEWS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT review_id) AS review_ids_distintos,
    COUNT(DISTINCT order_id) AS pedidos_com_review
FROM raw.order_reviews;

-- Pedidos com mais de uma review
SELECT
    COUNT(*) AS pedidos_com_multiplas_reviews
FROM (
    SELECT
        order_id
    FROM raw.order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;

-- Exemplos
SELECT
    order_id,
    COUNT(*) AS qtd_reviews
FROM raw.order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY qtd_reviews DESC
LIMIT 20;


-- ---------------------------------------------------------
-- 7. PRODUCTS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS total_produtos,
    COUNT(DISTINCT product_id) AS produtos_distintos,
    COUNT(DISTINCT product_category_name) AS categorias
FROM raw.products;

-- NULLs relevantes
SELECT
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS categoria_nula,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS peso_nulo,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS comprimento_nulo,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS altura_nula,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS largura_nula
FROM raw.products;


-- ---------------------------------------------------------
-- 8. SELLERS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS total_vendedores,
    COUNT(DISTINCT seller_id) AS vendedores_distintos
FROM raw.sellers;


-- ---------------------------------------------------------
-- 9. INTEGRIDADE ENTRE AS PRINCIPAIS FONTES
-- ---------------------------------------------------------

-- Pedidos sem customer correspondente
SELECT
    COUNT(*) AS orders_sem_customer
FROM raw.orders o
LEFT JOIN raw.customers c
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- Itens sem order correspondente
SELECT
    COUNT(*) AS itens_sem_order
FROM raw.order_items oi
LEFT JOIN raw.orders o
    ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- Itens sem product correspondente
SELECT
    COUNT(*) AS itens_sem_product
FROM raw.order_items oi
LEFT JOIN raw.products p
    ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;

-- Itens sem seller correspondente
SELECT
    COUNT(*) AS itens_sem_seller
FROM raw.order_items oi
LEFT JOIN raw.sellers s
    ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL;

-- Pagamentos sem order correspondente
SELECT
    COUNT(*) AS pagamentos_sem_order
FROM raw.order_payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL;

-- Reviews sem order correspondente
SELECT
    COUNT(*) AS reviews_sem_order
FROM raw.order_reviews r
LEFT JOIN raw.orders o
    ON o.order_id = r.order_id
WHERE o.order_id IS NULL;