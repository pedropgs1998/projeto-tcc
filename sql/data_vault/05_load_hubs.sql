/*
 * Carga dos Hubs
 * Data Vault 2.0 — Estado T0
 *
 * Hubs:
 * - hub_order
 * - hub_customer
 * - hub_product
 * - hub_seller
 *
 * Regras:
 * - geração determinística de Hash Keys;
 * - preservação das Business Keys;
 * - uma linha por Business Key;
 * - record_source identificando a origem;
 * - reexecução segura com ON CONFLICT DO NOTHING.
 */


/* ============================================================
 * 1. HUB_ORDER
 * ============================================================
 *
 * Business Key:
 * order_id
 *
 * Origem:
 * raw.orders
 *
 * Esperado:
 * 99.441 registros
 * ============================================================
 */

INSERT INTO data_vault.hub_order (
    order_hk,
    order_id,
    record_source
)
SELECT
    data_vault.hash_key(
        o.order_id
    ) AS order_hk,

    o.order_id,

    'olist.orders' AS record_source

FROM raw.orders o

WHERE o.order_id IS NOT NULL

ON CONFLICT (order_hk) DO NOTHING;


/* ============================================================
 * 2. HUB_CUSTOMER
 * ============================================================
 *
 * Business Key:
 * customer_unique_id
 *
 * Origem:
 * raw.customers
 *
 * Importante:
 * customer_id NÃO é a Business Key do Hub.
 *
 * Um mesmo customer_unique_id pode possuir vários customer_id.
 *
 * Esperado:
 * 96.096 registros
 * ============================================================
 */

INSERT INTO data_vault.hub_customer (
    customer_hk,
    customer_unique_id,
    record_source
)
SELECT DISTINCT
    data_vault.hash_key(
        c.customer_unique_id
    ) AS customer_hk,

    c.customer_unique_id,

    'olist.customers' AS record_source

FROM raw.customers c

WHERE c.customer_unique_id IS NOT NULL

ON CONFLICT (customer_hk) DO NOTHING;


/* ============================================================
 * 3. HUB_PRODUCT
 * ============================================================
 *
 * Business Key:
 * product_id
 *
 * Origem:
 * raw.products
 *
 * Esperado:
 * 32.951 registros
 * ============================================================
 */

INSERT INTO data_vault.hub_product (
    product_hk,
    product_id,
    record_source
)
SELECT
    data_vault.hash_key(
        p.product_id
    ) AS product_hk,

    p.product_id,

    'olist.products' AS record_source

FROM raw.products p

WHERE p.product_id IS NOT NULL

ON CONFLICT (product_hk) DO NOTHING;


/* ============================================================
 * 4. HUB_SELLER
 * ============================================================
 *
 * Business Key:
 * seller_id
 *
 * Origem:
 * raw.sellers
 *
 * Esperado:
 * 3.095 registros
 * ============================================================
 */

INSERT INTO data_vault.hub_seller (
    seller_hk,
    seller_id,
    record_source
)
SELECT
    data_vault.hash_key(
        s.seller_id
    ) AS seller_hk,

    s.seller_id,

    'olist.sellers' AS record_source

FROM raw.sellers s

WHERE s.seller_id IS NOT NULL

ON CONFLICT (seller_hk) DO NOTHING;


/* ============================================================
 * 5. VALIDAÇÃO BÁSICA
 * ============================================================
 */

SELECT
    'hub_order' AS tabela,
    COUNT(*) AS quantidade
FROM data_vault.hub_order

UNION ALL

SELECT
    'hub_customer',
    COUNT(*)
FROM data_vault.hub_customer

UNION ALL

SELECT
    'hub_product',
    COUNT(*)
FROM data_vault.hub_product

UNION ALL

SELECT
    'hub_seller',
    COUNT(*)
FROM data_vault.hub_seller;


/* ============================================================
 * 6. VALIDAÇÃO DE UNICIDADE DAS BUSINESS KEYS
 * ============================================================
 */

SELECT
    'hub_order' AS tabela,
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS business_keys_distintas
FROM data_vault.hub_order

UNION ALL

SELECT
    'hub_customer',
    COUNT(*),
    COUNT(DISTINCT customer_unique_id)
FROM data_vault.hub_customer

UNION ALL

SELECT
    'hub_product',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM data_vault.hub_product

UNION ALL

SELECT
    'hub_seller',
    COUNT(*),
    COUNT(DISTINCT seller_id)
FROM data_vault.hub_seller;


/* ============================================================
 * 7. VALIDAÇÃO DAS HASH KEYS
 * ============================================================
 *
 * Recalcula as Hash Keys a partir das Business Keys.
 *
 * Esperado:
 * 0 inconsistências em todos os Hubs.
 * ============================================================
 */

SELECT
    'hub_order' AS tabela,
    COUNT(*) AS hashes_inconsistentes
FROM data_vault.hub_order
WHERE order_hk
      <>
      data_vault.hash_key(order_id)

UNION ALL

SELECT
    'hub_customer',
    COUNT(*)
FROM data_vault.hub_customer
WHERE customer_hk
      <>
      data_vault.hash_key(customer_unique_id)

UNION ALL

SELECT
    'hub_product',
    COUNT(*)
FROM data_vault.hub_product
WHERE product_hk
      <>
      data_vault.hash_key(product_id)

UNION ALL

SELECT
    'hub_seller',
    COUNT(*)
FROM data_vault.hub_seller
WHERE seller_hk
      <>
      data_vault.hash_key(seller_id);