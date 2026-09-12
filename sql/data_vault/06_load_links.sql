/*
 * Carga dos Links
 * Data Vault 2.0 — Estado T0
 *
 * Links:
 * - link_order_customer
 * - link_order_item
 *
 * Regras:
 * - Hash Keys determinísticas;
 * - referências resolvidas para os Hubs;
 * - preservação do grão da origem;
 * - reexecução segura com ON CONFLICT DO NOTHING.
 */


/* ============================================================
 * 1. LINK_ORDER_CUSTOMER
 * ============================================================
 *
 * Relacionamento:
 * Pedido ↔ Cliente lógico
 *
 * Origem:
 * raw.orders
 * raw.customers
 *
 * Join da origem:
 *
 * orders.customer_id = customers.customer_id
 *
 * Business Keys participantes:
 *
 * order_id
 * customer_unique_id
 *
 * Grão esperado:
 * uma linha por pedido
 *
 * Esperado:
 * 99.441 registros
 * ============================================================
 */

INSERT INTO data_vault.link_order_customer (
    order_customer_hk,
    order_hk,
    customer_hk,
    record_source
)
SELECT
    data_vault.hash_values(
        ARRAY[
            o.order_id,
            c.customer_unique_id
        ]
    ) AS order_customer_hk,

    ho.order_hk,

    hc.customer_hk,

    'olist.orders+customers' AS record_source

FROM raw.orders o

JOIN raw.customers c
    ON c.customer_id = o.customer_id

JOIN data_vault.hub_order ho
    ON ho.order_id = o.order_id

JOIN data_vault.hub_customer hc
    ON hc.customer_unique_id = c.customer_unique_id

WHERE o.order_id IS NOT NULL
  AND c.customer_unique_id IS NOT NULL

ON CONFLICT (order_customer_hk) DO NOTHING;


/* ============================================================
 * 2. LINK_ORDER_ITEM
 * ============================================================
 *
 * Relacionamento:
 *
 * Pedido ↔ Produto ↔ Vendedor
 *
 * com order_item_id como Dependent Child.
 *
 * Origem:
 * raw.order_items
 *
 * Componentes utilizados para gerar a Hash Key:
 *
 * order_id
 * product_id
 * seller_id
 * order_item_id
 *
 * Grão esperado:
 *
 * (order_id, order_item_id)
 *
 * Esperado:
 * 112.650 registros
 * ============================================================
 */

INSERT INTO data_vault.link_order_item (
    order_item_hk,
    order_hk,
    product_hk,
    seller_hk,
    order_item_id,
    record_source
)
SELECT
    data_vault.hash_values(
        ARRAY[
            oi.order_id,
            oi.product_id,
            oi.seller_id,
            oi.order_item_id::TEXT
        ]
    ) AS order_item_hk,

    ho.order_hk,

    hp.product_hk,

    hs.seller_hk,

    oi.order_item_id,

    'olist.order_items' AS record_source

FROM raw.order_items oi

JOIN data_vault.hub_order ho
    ON ho.order_id = oi.order_id

JOIN data_vault.hub_product hp
    ON hp.product_id = oi.product_id

JOIN data_vault.hub_seller hs
    ON hs.seller_id = oi.seller_id

WHERE oi.order_id IS NOT NULL
  AND oi.product_id IS NOT NULL
  AND oi.seller_id IS NOT NULL
  AND oi.order_item_id IS NOT NULL

ON CONFLICT (order_item_hk) DO NOTHING;


/* ============================================================
 * 3. CONTAGEM DOS LINKS
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
 * 4. UNICIDADE DO LINK_ORDER_CUSTOMER
 * ============================================================
 *
 * Esperado:
 *
 * 99.441 linhas
 * 99.441 pedidos distintos
 *
 * Nenhum pedido deve aparecer associado a mais de um cliente.
 * ============================================================
 */

SELECT
    COUNT(*) AS total_linhas,

    COUNT(
        DISTINCT order_hk
    ) AS pedidos_distintos,

    COUNT(*) - COUNT(
        DISTINCT order_hk
    ) AS relacionamentos_adicionais

FROM data_vault.link_order_customer;


/* Verificação explícita:
 * pedidos associados a mais de um cliente.
 *
 * Esperado:
 * 0 registros.
 */

SELECT
    COUNT(*) AS pedidos_com_multiplos_clientes

FROM (
    SELECT
        order_hk

    FROM data_vault.link_order_customer

    GROUP BY order_hk

    HAVING COUNT(DISTINCT customer_hk) > 1
) x;


/* ============================================================
 * 5. UNICIDADE DO LINK_ORDER_ITEM
 * ============================================================
 *
 * Precisamos validar o grão da fonte:
 *
 * (order_id, order_item_id)
 *
 * Como order_id está representado por order_hk:
 *
 * (order_hk, order_item_id)
 *
 * deve ser único.
 * ============================================================
 */

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
 *
 * Como existem Foreign Keys físicas, inconsistências não
 * deveriam ser possíveis.
 *
 * Mesmo assim, as consultas deixam a validação explícita.
 * ============================================================
 */


/* LINK_ORDER_CUSTOMER */

SELECT
    COUNT(*) AS referencias_invalidas

FROM data_vault.link_order_customer loc

LEFT JOIN data_vault.hub_order ho
    ON ho.order_hk = loc.order_hk

LEFT JOIN data_vault.hub_customer hc
    ON hc.customer_hk = loc.customer_hk

WHERE ho.order_hk IS NULL
   OR hc.customer_hk IS NULL;


/* LINK_ORDER_ITEM */

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
 * 7. VALIDAÇÃO DAS HASH KEYS
 * ============================================================
 *
 * Recalcula a Hash Key de cada Link utilizando as respectivas
 * Business Keys.
 *
 * Esperado:
 * 0 inconsistências.
 * ============================================================
 */


/* LINK_ORDER_CUSTOMER */

SELECT
    COUNT(*) AS hashes_inconsistentes

FROM data_vault.link_order_customer loc

JOIN data_vault.hub_order ho
    ON ho.order_hk = loc.order_hk

JOIN data_vault.hub_customer hc
    ON hc.customer_hk = loc.customer_hk

WHERE loc.order_customer_hk
      <>
      data_vault.hash_values(
          ARRAY[
              ho.order_id,
              hc.customer_unique_id
          ]
      );


/* LINK_ORDER_ITEM */

SELECT
    COUNT(*) AS hashes_inconsistentes

FROM data_vault.link_order_item loi

JOIN data_vault.hub_order ho
    ON ho.order_hk = loi.order_hk

JOIN data_vault.hub_product hp
    ON hp.product_hk = loi.product_hk

JOIN data_vault.hub_seller hs
    ON hs.seller_hk = loi.seller_hk

WHERE loi.order_item_hk
      <>
      data_vault.hash_values(
          ARRAY[
              ho.order_id,
              hp.product_id,
              hs.seller_id,
              loi.order_item_id::TEXT
          ]
      );


/* ============================================================
 * 8. RECONCILIAÇÃO COM A CAMADA RAW
 * ============================================================
 */


/* Pedidos da origem que não aparecem no relacionamento
 * Pedido–Cliente.
 *
 * Esperado:
 * 0.
 */

SELECT
    COUNT(*) AS pedidos_raw_sem_link_customer

FROM raw.orders o

JOIN data_vault.hub_order ho
    ON ho.order_id = o.order_id

LEFT JOIN data_vault.link_order_customer loc
    ON loc.order_hk = ho.order_hk

WHERE loc.order_hk IS NULL;


/* Itens da origem que não aparecem no Link.
 *
 * Esperado:
 * 0.
 */

SELECT
    COUNT(*) AS itens_raw_sem_link

FROM raw.order_items oi

JOIN data_vault.hub_order ho
    ON ho.order_id = oi.order_id

LEFT JOIN data_vault.link_order_item loi
    ON loi.order_hk = ho.order_hk
   AND loi.order_item_id = oi.order_item_id

WHERE loi.order_item_hk IS NULL;