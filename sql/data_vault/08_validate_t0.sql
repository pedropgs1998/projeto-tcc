/*
 * Validação formal do Raw Vault — Estado T0
 *
 * Objetivos:
 * - validar Hubs;
 * - validar Links;
 * - validar Satellites;
 * - reconciliar o Raw Vault com a camada raw;
 * - confirmar preservação de grãos, chaves e payloads;
 * - garantir que o Raw Vault T0 esteja consistente antes
 *   da construção do Data Mart.
 */


/* ============================================================
 * 1. CONTAGEM DOS HUBS
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
 * 2. UNICIDADE DAS BUSINESS KEYS
 * ============================================================
 */

SELECT
    'hub_order' AS tabela,
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS business_keys_distintas,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicidades
FROM data_vault.hub_order

UNION ALL

SELECT
    'hub_customer',
    COUNT(*),
    COUNT(DISTINCT customer_unique_id),
    COUNT(*) - COUNT(DISTINCT customer_unique_id)
FROM data_vault.hub_customer

UNION ALL

SELECT
    'hub_product',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM data_vault.hub_product

UNION ALL

SELECT
    'hub_seller',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM data_vault.hub_seller;


/* ============================================================
 * 3. VALIDAÇÃO DAS HASH KEYS DOS HUBS
 * ============================================================
 */

SELECT
    'hub_order' AS tabela,
    COUNT(*) AS hashes_inconsistentes
FROM data_vault.hub_order
WHERE order_hk <> data_vault.hash_key(order_id)

UNION ALL

SELECT
    'hub_customer',
    COUNT(*)
FROM data_vault.hub_customer
WHERE customer_hk <> data_vault.hash_key(customer_unique_id)

UNION ALL

SELECT
    'hub_product',
    COUNT(*)
FROM data_vault.hub_product
WHERE product_hk <> data_vault.hash_key(product_id)

UNION ALL

SELECT
    'hub_seller',
    COUNT(*)
FROM data_vault.hub_seller
WHERE seller_hk <> data_vault.hash_key(seller_id);


/* ============================================================
 * 4. CONTAGEM DOS LINKS
 * ============================================================
 */

SELECT
    'link_order_customer' AS tabela,
    COUNT(*) AS quantidade
FROM data_vault.link_order_customer

UNION ALL

SELECT
    'link_order_item',
    COUNT(*)
FROM data_vault.link_order_item;


/* ============================================================
 * 5. VALIDAÇÃO DO GRÃO DOS LINKS
 * ============================================================
 */


/* Link Pedido–Cliente */

SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_hk) AS pedidos_distintos,
    COUNT(*) - COUNT(DISTINCT order_hk)
        AS relacionamentos_adicionais
FROM data_vault.link_order_customer;


/* Um pedido não deve possuir mais de um cliente no T0 */

SELECT
    COUNT(*) AS pedidos_com_multiplos_clientes
FROM (
    SELECT
        order_hk
    FROM data_vault.link_order_customer
    GROUP BY order_hk
    HAVING COUNT(DISTINCT customer_hk) > 1
) x;


/* Link de item */

SELECT
    COUNT(*) AS total_linhas,

    COUNT(
        DISTINCT (
            order_hk,
            order_item_id
        )
    ) AS graos_distintos,

    COUNT(*) - COUNT(
        DISTINCT (
            order_hk,
            order_item_id
        )
    ) AS duplicidades

FROM data_vault.link_order_item;


/* ============================================================
 * 6. VALIDAÇÃO DAS REFERÊNCIAS DOS LINKS
 * ============================================================
 */


/* Pedido–Cliente */

SELECT
    COUNT(*) AS referencias_invalidas

FROM data_vault.link_order_customer loc

LEFT JOIN data_vault.hub_order ho
    ON ho.order_hk = loc.order_hk

LEFT JOIN data_vault.hub_customer hc
    ON hc.customer_hk = loc.customer_hk

WHERE ho.order_hk IS NULL
   OR hc.customer_hk IS NULL;


/* Item */

SELECT
    COUNT(*) AS referencias_invalidas

FROM data_vault.link_order_item loi

LEFT JOIN data_vault.hub_order ho
    ON ho.order_hk = loi.order_hk

LEFT JOIN data_vault.hub_product hp
    ON hp.product_hk = loi.product_hk

LEFT JOIN data_vault.hub_seller hs
    ON hs.seller_hk = loi.seller_hk

WHERE ho.order_hk IS NULL
   OR hp.product_hk IS NULL
   OR hs.seller_hk IS NULL;


/* ============================================================
 * 7. VALIDAÇÃO DAS HASH KEYS DOS LINKS
 * ============================================================
 */


/* Pedido–Cliente */

SELECT
    COUNT(*) AS hashes_inconsistentes

FROM data_vault.link_order_customer loc

JOIN data_vault.hub_order ho
    ON ho.order_hk = loc.order_hk

JOIN data_vault.hub_customer hc
    ON hc.customer_hk = loc.customer_hk

WHERE loc.order_customer_hk <>
      data_vault.hash_values(
          ARRAY[
              ho.order_id,
              hc.customer_unique_id
          ]
      );


/* Item */

SELECT
    COUNT(*) AS hashes_inconsistentes

FROM data_vault.link_order_item loi

JOIN data_vault.hub_order ho
    ON ho.order_hk = loi.order_hk

JOIN data_vault.hub_product hp
    ON hp.product_hk = loi.product_hk

JOIN data_vault.hub_seller hs
    ON hs.seller_hk = loi.seller_hk

WHERE loi.order_item_hk <>
      data_vault.hash_values(
          ARRAY[
              ho.order_id,
              hp.product_id,
              hs.seller_id,
              loi.order_item_id::TEXT
          ]
      );


/* ============================================================
 * 8. CONTAGEM DOS SATELLITES
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
 * 9. QUANTIDADE DE VERSÕES POR PARENT
 * ============================================================
 *
 * No T0 inicial, cada Parent deve possuir exatamente uma versão.
 * ============================================================
 */

SELECT
    'sat_order' AS tabela,
    MIN(qtd) AS min_versoes,
    MAX(qtd) AS max_versoes
FROM (
    SELECT
        order_hk,
        COUNT(*) AS qtd
    FROM data_vault.sat_order
    GROUP BY order_hk
) x

UNION ALL

SELECT
    'sat_order_customer',
    MIN(qtd),
    MAX(qtd)
FROM (
    SELECT
        order_customer_hk,
        COUNT(*) AS qtd
    FROM data_vault.sat_order_customer
    GROUP BY order_customer_hk
) x

UNION ALL

SELECT
    'sat_product',
    MIN(qtd),
    MAX(qtd)
FROM (
    SELECT
        product_hk,
        COUNT(*) AS qtd
    FROM data_vault.sat_product
    GROUP BY product_hk
) x

UNION ALL

SELECT
    'sat_seller',
    MIN(qtd),
    MAX(qtd)
FROM (
    SELECT
        seller_hk,
        COUNT(*) AS qtd
    FROM data_vault.sat_seller
    GROUP BY seller_hk
) x

UNION ALL

SELECT
    'sat_order_item',
    MIN(qtd),
    MAX(qtd)
FROM (
    SELECT
        order_item_hk,
        COUNT(*) AS qtd
    FROM data_vault.sat_order_item
    GROUP BY order_item_hk
) x;


/* ============================================================
 * 10. VALIDAÇÃO DOS HASHDIFFS
 * ============================================================
 */


/* SAT_ORDER */

SELECT
    COUNT(*) AS hashdiffs_inconsistentes

FROM data_vault.sat_order so

WHERE so.hashdiff <>
      data_vault.hash_values(
          ARRAY[
              so.order_status,

              TO_CHAR(
                  so.order_purchase_timestamp,
                  'YYYY-MM-DD"T"HH24:MI:SS.US'
              ),

              TO_CHAR(
                  so.order_delivered_customer_date,
                  'YYYY-MM-DD"T"HH24:MI:SS.US'
              ),

              TO_CHAR(
                  so.order_estimated_delivery_date,
                  'YYYY-MM-DD"T"HH24:MI:SS.US'
              )
          ]
      );


/* SAT_ORDER_CUSTOMER */

SELECT
    COUNT(*) AS hashdiffs_inconsistentes

FROM data_vault.sat_order_customer soc

WHERE soc.hashdiff <>
      data_vault.hash_values(
          ARRAY[
              soc.customer_id,
              soc.customer_zip_code_prefix::TEXT,
              soc.customer_city,
              soc.customer_state
          ]
      );


/* SAT_PRODUCT */

SELECT
    COUNT(*) AS hashdiffs_inconsistentes

FROM data_vault.sat_product sp

WHERE sp.hashdiff <>
      data_vault.hash_values(
          ARRAY[
              sp.product_category_name
          ]
      );


/* SAT_SELLER */

SELECT
    COUNT(*) AS hashdiffs_inconsistentes

FROM data_vault.sat_seller ss

WHERE ss.hashdiff <>
      data_vault.hash_values(
          ARRAY[
              ss.seller_zip_code_prefix::TEXT,
              ss.seller_city,
              ss.seller_state
          ]
      );


/* SAT_ORDER_ITEM */

SELECT
    COUNT(*) AS hashdiffs_inconsistentes

FROM data_vault.sat_order_item soi

WHERE soi.hashdiff <>
      data_vault.hash_values(
          ARRAY[
              soi.price::TEXT,
              soi.freight_value::TEXT
          ]
      );


/* ============================================================
 * 11. RECONCILIAÇÃO DE ORDERS
 * ============================================================
 */


/* Todos os pedidos da raw devem existir no Hub */

SELECT
    COUNT(*) AS orders_raw_sem_hub

FROM raw.orders o

LEFT JOIN data_vault.hub_order ho
    ON ho.order_id = o.order_id

WHERE ho.order_hk IS NULL;


/* Todos os pedidos devem possuir sat_order */

SELECT
    COUNT(*) AS orders_sem_satellite

FROM data_vault.hub_order ho

LEFT JOIN data_vault.sat_order so
    ON so.order_hk = ho.order_hk

WHERE so.order_hk IS NULL;


/* Compara payload de orders */

SELECT
    COUNT(*) AS orders_com_payload_diferente

FROM raw.orders o

JOIN data_vault.hub_order ho
    ON ho.order_id = o.order_id

JOIN data_vault.sat_order so
    ON so.order_hk = ho.order_hk

WHERE
       so.order_status
           IS DISTINCT FROM o.order_status

    OR so.order_purchase_timestamp
           IS DISTINCT FROM o.order_purchase_timestamp

    OR so.order_delivered_customer_date
           IS DISTINCT FROM o.order_delivered_customer_date

    OR so.order_estimated_delivery_date
           IS DISTINCT FROM o.order_estimated_delivery_date;


/* ============================================================
 * 12. RECONCILIAÇÃO DE CUSTOMER
 * ============================================================
 */


/* Identidades lógicas */

SELECT
    (SELECT COUNT(DISTINCT customer_unique_id)
     FROM raw.customers)
        AS raw_customer_unique_ids,

    (SELECT COUNT(*)
     FROM data_vault.hub_customer)
        AS vault_customer_unique_ids;


/* customer_id preservados */

SELECT
    (SELECT COUNT(DISTINCT customer_id)
     FROM raw.customers)
        AS raw_customer_ids,

    (SELECT COUNT(DISTINCT customer_id)
     FROM data_vault.sat_order_customer)
        AS vault_customer_ids;


/* Payload da ocorrência de cliente */

SELECT
    COUNT(*) AS customers_com_payload_diferente

FROM raw.orders o

JOIN raw.customers c
    ON c.customer_id = o.customer_id

JOIN data_vault.hub_order ho
    ON ho.order_id = o.order_id

JOIN data_vault.link_order_customer loc
    ON loc.order_hk = ho.order_hk

JOIN data_vault.sat_order_customer soc
    ON soc.order_customer_hk = loc.order_customer_hk

WHERE
       soc.customer_id
           IS DISTINCT FROM c.customer_id

    OR soc.customer_zip_code_prefix
           IS DISTINCT FROM c.customer_zip_code_prefix

    OR soc.customer_city
           IS DISTINCT FROM c.customer_city

    OR soc.customer_state
           IS DISTINCT FROM c.customer_state;


/* ============================================================
 * 13. RECONCILIAÇÃO DE PRODUCTS
 * ============================================================
 */

SELECT
    COUNT(*) AS products_raw_sem_hub

FROM raw.products p

LEFT JOIN data_vault.hub_product hp
    ON hp.product_id = p.product_id

WHERE hp.product_hk IS NULL;


SELECT
    COUNT(*) AS products_com_payload_diferente

FROM raw.products p

JOIN data_vault.hub_product hp
    ON hp.product_id = p.product_id

JOIN data_vault.sat_product sp
    ON sp.product_hk = hp.product_hk

WHERE sp.product_category_name
      IS DISTINCT FROM
      p.product_category_name;


/* NULLs de categoria devem ser preservados */

SELECT
    (SELECT COUNT(*)
     FROM raw.products
     WHERE product_category_name IS NULL)
        AS raw_categoria_null,

    (SELECT COUNT(*)
     FROM data_vault.sat_product
     WHERE product_category_name IS NULL)
        AS vault_categoria_null;


/* ============================================================
 * 14. RECONCILIAÇÃO DE SELLERS
 * ============================================================
 */

SELECT
    COUNT(*) AS sellers_raw_sem_hub

FROM raw.sellers s

LEFT JOIN data_vault.hub_seller hs
    ON hs.seller_id = s.seller_id

WHERE hs.seller_hk IS NULL;


SELECT
    COUNT(*) AS sellers_com_payload_diferente

FROM raw.sellers s

JOIN data_vault.hub_seller hs
    ON hs.seller_id = s.seller_id

JOIN data_vault.sat_seller ss
    ON ss.seller_hk = hs.seller_hk

WHERE
       ss.seller_zip_code_prefix
           IS DISTINCT FROM s.seller_zip_code_prefix

    OR ss.seller_city
           IS DISTINCT FROM s.seller_city

    OR ss.seller_state
           IS DISTINCT FROM s.seller_state;


/* ============================================================
 * 15. RECONCILIAÇÃO DE ORDER_ITEMS
 * ============================================================
 */


/* Quantidade */

SELECT
    (SELECT COUNT(*)
     FROM raw.order_items)
        AS raw_order_items,

    (SELECT COUNT(*)
     FROM data_vault.link_order_item)
        AS vault_order_items;


/* Itens da raw sem Link */

SELECT
    COUNT(*) AS itens_raw_sem_link

FROM raw.order_items oi

JOIN data_vault.hub_order ho
    ON ho.order_id = oi.order_id

LEFT JOIN data_vault.link_order_item loi
    ON loi.order_hk = ho.order_hk
   AND loi.order_item_id = oi.order_item_id

WHERE loi.order_item_hk IS NULL;


/* Produto e seller associados ao item */

SELECT
    COUNT(*) AS itens_com_relacionamento_diferente

FROM raw.order_items oi

JOIN data_vault.hub_order ho
    ON ho.order_id = oi.order_id

JOIN data_vault.link_order_item loi
    ON loi.order_hk = ho.order_hk
   AND loi.order_item_id = oi.order_item_id

JOIN data_vault.hub_product hp
    ON hp.product_hk = loi.product_hk

JOIN data_vault.hub_seller hs
    ON hs.seller_hk = loi.seller_hk

WHERE
       hp.product_id IS DISTINCT FROM oi.product_id
    OR hs.seller_id IS DISTINCT FROM oi.seller_id;


/* Payload financeiro */

SELECT
    COUNT(*) AS itens_com_payload_diferente

FROM raw.order_items oi

JOIN data_vault.hub_order ho
    ON ho.order_id = oi.order_id

JOIN data_vault.link_order_item loi
    ON loi.order_hk = ho.order_hk
   AND loi.order_item_id = oi.order_item_id

JOIN data_vault.sat_order_item soi
    ON soi.order_item_hk = loi.order_item_hk

WHERE
       soi.price
           IS DISTINCT FROM oi.price

    OR soi.freight_value
           IS DISTINCT FROM oi.freight_value;


/* ============================================================
 * 16. RECONCILIAÇÃO FINANCEIRA
 * ============================================================
 */


/* Price */

SELECT
    (SELECT SUM(price)
     FROM raw.order_items)
        AS raw_price,

    (SELECT SUM(price)
     FROM data_vault.sat_order_item)
        AS vault_price,

    ABS(
        (SELECT SUM(price)
         FROM raw.order_items)
        -
        (SELECT SUM(price)
         FROM data_vault.sat_order_item)
    ) AS diferenca;


/* Freight */

SELECT
    (SELECT SUM(freight_value)
     FROM raw.order_items)
        AS raw_freight,

    (SELECT SUM(freight_value)
     FROM data_vault.sat_order_item)
        AS vault_freight,

    ABS(
        (SELECT SUM(freight_value)
         FROM raw.order_items)
        -
        (SELECT SUM(freight_value)
         FROM data_vault.sat_order_item)
    ) AS diferenca;


/* Total price + freight */

SELECT
    (SELECT SUM(price + freight_value)
     FROM raw.order_items)
        AS raw_total,

    (SELECT SUM(price + freight_value)
     FROM data_vault.sat_order_item)
        AS vault_total,

    ABS(
        (SELECT SUM(price + freight_value)
         FROM raw.order_items)
        -
        (SELECT SUM(price + freight_value)
         FROM data_vault.sat_order_item)
    ) AS diferenca;


/* ============================================================
 * 17. RECONCILIAÇÃO DE STATUS
 * ============================================================
 */

SELECT
    r.order_status,

    r.quantidade_raw,

    v.quantidade_vault,

    r.quantidade_raw
        - v.quantidade_vault AS diferenca

FROM (

    SELECT
        order_status,
        COUNT(*) AS quantidade_raw

    FROM raw.orders

    GROUP BY
        order_status

) r

JOIN (

    SELECT
        order_status,
        COUNT(*) AS quantidade_vault

    FROM data_vault.sat_order

    GROUP BY
        order_status

) v
    ON v.order_status = r.order_status

ORDER BY
    r.order_status;


/* ============================================================
 * 18. RECONCILIAÇÃO DOS TIMESTAMPS DE PEDIDO
 * ============================================================
 */

SELECT
    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS purchase_null,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS delivered_null,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS estimated_null

FROM data_vault.sat_order;


/* ============================================================
 * 19. COBERTURA DO RELACIONAMENTO PEDIDO–CLIENTE
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_sem_customer_link

FROM data_vault.hub_order ho

LEFT JOIN data_vault.link_order_customer loc
    ON loc.order_hk = ho.order_hk

WHERE loc.order_customer_hk IS NULL;


/* Todo Link deve possuir Satellite de contexto */

SELECT
    COUNT(*) AS customer_links_sem_satellite

FROM data_vault.link_order_customer loc

LEFT JOIN data_vault.sat_order_customer soc
    ON soc.order_customer_hk = loc.order_customer_hk

WHERE soc.order_customer_hk IS NULL;


/* ============================================================
 * 20. COBERTURA DO LINK DE ITEM
 * ============================================================
 */

SELECT
    COUNT(*) AS item_links_sem_satellite

FROM data_vault.link_order_item loi

LEFT JOIN data_vault.sat_order_item soi
    ON soi.order_item_hk = loi.order_item_hk

WHERE soi.order_item_hk IS NULL;


/* ============================================================
 * 21. PEDIDOS SEM ITENS
 * ============================================================
 *
 * Devem continuar preservados em hub_order/sat_order,
 * mesmo sem relacionamento em link_order_item.
 *
 * Esperado:
 * 775.
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_sem_itens_vault

FROM data_vault.hub_order ho

WHERE NOT EXISTS (

    SELECT 1

    FROM data_vault.link_order_item loi

    WHERE loi.order_hk = ho.order_hk
);


/* Comparação direta com raw */

SELECT
    COUNT(*) AS pedidos_sem_itens_raw

FROM raw.orders o

WHERE NOT EXISTS (

    SELECT 1

    FROM raw.order_items oi

    WHERE oi.order_id = o.order_id
);


/* ============================================================
 * 22. RESUMO DE CONTROLE DO RAW VAULT T0
 * ============================================================
 *
 * Valores principais esperados:
 *
 * hub_order              = 99.441
 * hub_customer           = 96.096
 * hub_product            = 32.951
 * hub_seller             = 3.095
 *
 * link_order_customer    = 99.441
 * link_order_item        = 112.650
 *
 * sat_order              = 99.441
 * sat_order_customer     = 99.441
 * sat_product            = 32.951
 * sat_seller             = 3.095
 * sat_order_item         = 112.650
 *
 * pedidos sem itens      = 775
 *
 * todas as inconsistências:
 * 0
 * ============================================================
 */

SELECT
    (SELECT COUNT(*)
     FROM data_vault.hub_order)
        AS hub_order,

    (SELECT COUNT(*)
     FROM data_vault.hub_customer)
        AS hub_customer,

    (SELECT COUNT(*)
     FROM data_vault.hub_product)
        AS hub_product,

    (SELECT COUNT(*)
     FROM data_vault.hub_seller)
        AS hub_seller,

    (SELECT COUNT(*)
     FROM data_vault.link_order_customer)
        AS link_order_customer,

    (SELECT COUNT(*)
     FROM data_vault.link_order_item)
        AS link_order_item,

    (SELECT COUNT(*)
     FROM data_vault.sat_order)
        AS sat_order,

    (SELECT COUNT(*)
     FROM data_vault.sat_order_customer)
        AS sat_order_customer,

    (SELECT COUNT(*)
     FROM data_vault.sat_product)
        AS sat_product,

    (SELECT COUNT(*)
     FROM data_vault.sat_seller)
        AS sat_seller,

    (SELECT COUNT(*)
     FROM data_vault.sat_order_item)
        AS sat_order_item;