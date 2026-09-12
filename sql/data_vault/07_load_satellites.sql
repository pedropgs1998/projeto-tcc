/*
 * Carga dos Satellites
 * Data Vault 2.0 — Estado T0
 *
 * Satellites:
 * - sat_order
 * - sat_order_customer
 * - sat_product
 * - sat_seller
 * - sat_order_item
 *
 * Regras:
 * - cálculo determinístico de HashDiff;
 * - inserção de uma nova versão apenas quando o payload
 *   for diferente da versão mais recente;
 * - preservação dos atributos provenientes da camada raw;
 * - record_source identificando a origem.
 */


/* ============================================================
 * 1. SAT_ORDER
 * ============================================================
 *
 * Parent:
 * hub_order
 *
 * Payload T0:
 * - order_status
 * - order_purchase_timestamp
 * - order_delivered_customer_date
 * - order_estimated_delivery_date
 *
 * Esperado na primeira execução:
 * 99.441 registros
 * ============================================================
 */

WITH source_data AS (

    SELECT
        ho.order_hk,

        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        data_vault.hash_values(
            ARRAY[
                o.order_status,

                TO_CHAR(
                    o.order_purchase_timestamp,
                    'YYYY-MM-DD"T"HH24:MI:SS.US'
                ),

                TO_CHAR(
                    o.order_delivered_customer_date,
                    'YYYY-MM-DD"T"HH24:MI:SS.US'
                ),

                TO_CHAR(
                    o.order_estimated_delivery_date,
                    'YYYY-MM-DD"T"HH24:MI:SS.US'
                )
            ]
        ) AS hashdiff

    FROM raw.orders o

    JOIN data_vault.hub_order ho
        ON ho.order_id = o.order_id
)

INSERT INTO data_vault.sat_order (
    order_hk,

    order_status,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    hashdiff,
    record_source
)

SELECT
    src.order_hk,

    src.order_status,
    src.order_purchase_timestamp,
    src.order_delivered_customer_date,
    src.order_estimated_delivery_date,

    src.hashdiff,

    'olist.orders' AS record_source

FROM source_data src

WHERE NOT EXISTS (

    SELECT 1

    FROM LATERAL (

        SELECT
            so.hashdiff

        FROM data_vault.sat_order so

        WHERE so.order_hk = src.order_hk

        ORDER BY
            so.load_timestamp DESC

        LIMIT 1

    ) latest

    WHERE latest.hashdiff = src.hashdiff
);


/* ============================================================
 * 2. SAT_ORDER_CUSTOMER
 * ============================================================
 *
 * Parent:
 * link_order_customer
 *
 * Payload:
 * - customer_id
 * - customer_zip_code_prefix
 * - customer_city
 * - customer_state
 *
 * O Satellite preserva o contexto da ocorrência de cliente
 * utilizada em cada pedido.
 *
 * Esperado na primeira execução:
 * 99.441 registros
 * ============================================================
 */

WITH source_data AS (

    SELECT
        loc.order_customer_hk,

        c.customer_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,

        data_vault.hash_values(
            ARRAY[
                c.customer_id,

                c.customer_zip_code_prefix::TEXT,

                c.customer_city,

                c.customer_state
            ]
        ) AS hashdiff

    FROM raw.orders o

    JOIN raw.customers c
        ON c.customer_id = o.customer_id

    JOIN data_vault.hub_order ho
        ON ho.order_id = o.order_id

    JOIN data_vault.hub_customer hc
        ON hc.customer_unique_id = c.customer_unique_id

    JOIN data_vault.link_order_customer loc
        ON loc.order_hk = ho.order_hk
       AND loc.customer_hk = hc.customer_hk
)

INSERT INTO data_vault.sat_order_customer (
    order_customer_hk,

    customer_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,

    hashdiff,
    record_source
)

SELECT
    src.order_customer_hk,

    src.customer_id,
    src.customer_zip_code_prefix,
    src.customer_city,
    src.customer_state,

    src.hashdiff,

    'olist.orders+customers' AS record_source

FROM source_data src

WHERE NOT EXISTS (

    SELECT 1

    FROM LATERAL (

        SELECT
            soc.hashdiff

        FROM data_vault.sat_order_customer soc

        WHERE soc.order_customer_hk = src.order_customer_hk

        ORDER BY
            soc.load_timestamp DESC

        LIMIT 1

    ) latest

    WHERE latest.hashdiff = src.hashdiff
);


/* ============================================================
 * 3. SAT_PRODUCT
 * ============================================================
 *
 * Parent:
 * hub_product
 *
 * Payload T0:
 * - product_category_name
 *
 * Nenhuma regra de histórico efetivo de M3 é aplicada aqui.
 *
 * Esperado na primeira execução:
 * 32.951 registros
 * ============================================================
 */

WITH source_data AS (

    SELECT
        hp.product_hk,

        p.product_category_name,

        data_vault.hash_values(
            ARRAY[
                p.product_category_name
            ]
        ) AS hashdiff

    FROM raw.products p

    JOIN data_vault.hub_product hp
        ON hp.product_id = p.product_id
)

INSERT INTO data_vault.sat_product (
    product_hk,

    product_category_name,

    hashdiff,
    record_source
)

SELECT
    src.product_hk,

    src.product_category_name,

    src.hashdiff,

    'olist.products' AS record_source

FROM source_data src

WHERE NOT EXISTS (

    SELECT 1

    FROM LATERAL (

        SELECT
            sp.hashdiff

        FROM data_vault.sat_product sp

        WHERE sp.product_hk = src.product_hk

        ORDER BY
            sp.load_timestamp DESC

        LIMIT 1

    ) latest

    WHERE latest.hashdiff = src.hashdiff
);


/* ============================================================
 * 4. SAT_SELLER
 * ============================================================
 *
 * Parent:
 * hub_seller
 *
 * Payload:
 * - seller_zip_code_prefix
 * - seller_city
 * - seller_state
 *
 * Esperado na primeira execução:
 * 3.095 registros
 * ============================================================
 */

WITH source_data AS (

    SELECT
        hs.seller_hk,

        s.seller_zip_code_prefix,
        s.seller_city,
        s.seller_state,

        data_vault.hash_values(
            ARRAY[
                s.seller_zip_code_prefix::TEXT,
                s.seller_city,
                s.seller_state
            ]
        ) AS hashdiff

    FROM raw.sellers s

    JOIN data_vault.hub_seller hs
        ON hs.seller_id = s.seller_id
)

INSERT INTO data_vault.sat_seller (
    seller_hk,

    seller_zip_code_prefix,
    seller_city,
    seller_state,

    hashdiff,
    record_source
)

SELECT
    src.seller_hk,

    src.seller_zip_code_prefix,
    src.seller_city,
    src.seller_state,

    src.hashdiff,

    'olist.sellers' AS record_source

FROM source_data src

WHERE NOT EXISTS (

    SELECT 1

    FROM LATERAL (

        SELECT
            ss.hashdiff

        FROM data_vault.sat_seller ss

        WHERE ss.seller_hk = src.seller_hk

        ORDER BY
            ss.load_timestamp DESC

        LIMIT 1

    ) latest

    WHERE latest.hashdiff = src.hashdiff
);


/* ============================================================
 * 5. SAT_ORDER_ITEM
 * ============================================================
 *
 * Parent:
 * link_order_item
 *
 * Payload:
 * - price
 * - freight_value
 *
 * Esperado na primeira execução:
 * 112.650 registros
 * ============================================================
 */

WITH source_data AS (

    SELECT
        loi.order_item_hk,

        oi.price,
        oi.freight_value,

        data_vault.hash_values(
            ARRAY[
                oi.price::TEXT,
                oi.freight_value::TEXT
            ]
        ) AS hashdiff

    FROM raw.order_items oi

    JOIN data_vault.hub_order ho
        ON ho.order_id = oi.order_id

    JOIN data_vault.link_order_item loi
        ON loi.order_hk = ho.order_hk
       AND loi.order_item_id = oi.order_item_id
)

INSERT INTO data_vault.sat_order_item (
    order_item_hk,

    price,
    freight_value,

    hashdiff,
    record_source
)

SELECT
    src.order_item_hk,

    src.price,
    src.freight_value,

    src.hashdiff,

    'olist.order_items' AS record_source

FROM source_data src

WHERE NOT EXISTS (

    SELECT 1

    FROM LATERAL (

        SELECT
            soi.hashdiff

        FROM data_vault.sat_order_item soi

        WHERE soi.order_item_hk = src.order_item_hk

        ORDER BY
            soi.load_timestamp DESC

        LIMIT 1

    ) latest

    WHERE latest.hashdiff = src.hashdiff
);


/* ============================================================
 * 6. CONTAGEM DOS SATELLITES
 * ============================================================
 */

SELECT
    'sat_order' AS tabela,
    COUNT(*) AS quantidade
FROM data_vault.sat_order

UNION ALL

SELECT
    'sat_order_customer',
    COUNT(*)
FROM data_vault.sat_order_customer

UNION ALL

SELECT
    'sat_product',
    COUNT(*)
FROM data_vault.sat_product

UNION ALL

SELECT
    'sat_seller',
    COUNT(*)
FROM data_vault.sat_seller

UNION ALL

SELECT
    'sat_order_item',
    COUNT(*)
FROM data_vault.sat_order_item;


/* ============================================================
 * 7. VERSÕES POR PARENT
 * ============================================================
 *
 * Na primeira carga T0 todos os Parents devem possuir
 * exatamente uma versão.
 *
 * Esperado:
 * max_versoes = 1
 * ============================================================
 */

SELECT
    'sat_order' AS tabela,
    MIN(quantidade) AS min_versoes,
    MAX(quantidade) AS max_versoes
FROM (
    SELECT
        order_hk,
        COUNT(*) AS quantidade
    FROM data_vault.sat_order
    GROUP BY order_hk
) x

UNION ALL

SELECT
    'sat_order_customer',
    MIN(quantidade),
    MAX(quantidade)
FROM (
    SELECT
        order_customer_hk,
        COUNT(*) AS quantidade
    FROM data_vault.sat_order_customer
    GROUP BY order_customer_hk
) x

UNION ALL

SELECT
    'sat_product',
    MIN(quantidade),
    MAX(quantidade)
FROM (
    SELECT
        product_hk,
        COUNT(*) AS quantidade
    FROM data_vault.sat_product
    GROUP BY product_hk
) x

UNION ALL

SELECT
    'sat_seller',
    MIN(quantidade),
    MAX(quantidade)
FROM (
    SELECT
        seller_hk,
        COUNT(*) AS quantidade
    FROM data_vault.sat_seller
    GROUP BY seller_hk
) x

UNION ALL

SELECT
    'sat_order_item',
    MIN(quantidade),
    MAX(quantidade)
FROM (
    SELECT
        order_item_hk,
        COUNT(*) AS quantidade
    FROM data_vault.sat_order_item
    GROUP BY order_item_hk
) x;


/* ============================================================
 * 8. RECONCILIAÇÃO FINANCEIRA BÁSICA
 * ============================================================
 */

SELECT
    (SELECT SUM(price)
     FROM raw.order_items) AS raw_price,

    (SELECT SUM(price)
     FROM data_vault.sat_order_item) AS vault_price,

    ABS(
        (SELECT SUM(price)
         FROM raw.order_items)
        -
        (SELECT SUM(price)
         FROM data_vault.sat_order_item)
    ) AS diferenca;


SELECT
    (SELECT SUM(freight_value)
     FROM raw.order_items) AS raw_freight,

    (SELECT SUM(freight_value)
     FROM data_vault.sat_order_item) AS vault_freight,

    ABS(
        (SELECT SUM(freight_value)
         FROM raw.order_items)
        -
        (SELECT SUM(freight_value)
         FROM data_vault.sat_order_item)
    ) AS diferenca;


/* ============================================================
 * 9. CUSTOMER_ID PRESERVADO
 * ============================================================
 *
 * O número de customer_id distintos preservados pelo Satellite
 * deve corresponder à origem.
 *
 * Esperado:
 * 99.441
 * ============================================================
 */

SELECT
    COUNT(DISTINCT customer_id)
        AS customer_ids_preservados

FROM data_vault.sat_order_customer;


/* ============================================================
 * 10. CATEGORIAS NULAS PRESERVADAS
 * ============================================================
 *
 * O Raw Vault não deve substituir categorias NULL por valores
 * artificiais.
 *
 * Esperado segundo o profiling T0:
 * 610 produtos.
 * ============================================================
 */

SELECT
    COUNT(*) AS produtos_categoria_null

FROM data_vault.sat_product

WHERE product_category_name IS NULL;