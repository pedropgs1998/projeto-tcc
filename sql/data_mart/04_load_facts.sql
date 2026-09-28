/*
 * Carga das tabelas fato do Data Mart — Estado T0
 *
 * Regra principal:
 *
 * As fatos devem ser reconstruídas exclusivamente a partir
 * do schema data_vault.
 *
 * A camada raw não participa diretamente desta carga.
 *
 * Fatos:
 * - fact_order
 * - fact_order_item
 */


/* ============================================================
 * PREPARAÇÃO DO OTIMIZADOR
 * ============================================================
 *
 * A carga das fatos utiliza múltiplos joins entre objetos do
 * Raw Vault e dimensões recém-carregadas do Data Mart.
 *
 * As estatísticas são atualizadas explicitamente antes da carga
 * para evitar que o PostgreSQL escolha planos inadequados logo
 * após uma reconstrução completa do ambiente.
 *
 * Os parâmetros abaixo valem apenas para a sessão que executa
 * este arquivo e não alteram permanentemente a configuração do
 * PostgreSQL.
 * ============================================================
 */

SET work_mem = '128MB';
SET random_page_cost = 1.1;

ANALYZE data_vault.hub_order;
ANALYZE data_vault.hub_customer;
ANALYZE data_vault.hub_product;
ANALYZE data_vault.hub_seller;
ANALYZE data_vault.link_order_customer;
ANALYZE data_vault.link_order_item;
ANALYZE data_vault.sat_order;
ANALYZE data_vault.sat_order_customer;
ANALYZE data_vault.sat_order_item;
ANALYZE data_vault.sat_product;
ANALYZE data_vault.sat_seller;

ANALYZE data_mart.dim_date;
ANALYZE data_mart.dim_customer;
ANALYZE data_mart.dim_order_status;
ANALYZE data_mart.dim_product;
ANALYZE data_mart.dim_seller;


/* ============================================================
 * 1. FACT_ORDER
 * ============================================================
 *
 * Grão:
 * uma linha por order_id
 *
 * Fontes no Raw Vault:
 *
 * hub_order
 * sat_order
 * link_order_customer
 * sat_order_customer
 * hub_customer
 * link_order_item
 * sat_order_item
 *
 * valor_calculado_pedido:
 *
 * SUM(price + freight_value)
 * por pedido
 *
 * Pedidos sem itens permanecem na fato com:
 *
 * valor_calculado_pedido = NULL
 * ============================================================
 */


WITH latest_sat_order AS (

    /*
     * Recupera a versão mais recente de cada pedido.
     *
     * No T0 existe apenas uma versão, mas esta forma evita
     * depender dessa condição e mantém a leitura correta caso
     * Satellites recebam novas versões posteriormente.
     */

    SELECT DISTINCT ON (so.order_hk)
        so.order_hk,
        so.order_status,
        so.order_purchase_timestamp,
        so.order_delivered_customer_date,
        so.order_estimated_delivery_date

    FROM data_vault.sat_order so

    ORDER BY
        so.order_hk,
        so.load_timestamp DESC

),

latest_sat_order_customer AS (

    /*
     * Recupera a versão mais recente do contexto Pedido–Cliente.
     */

    SELECT DISTINCT ON (soc.order_customer_hk)
        soc.order_customer_hk,
        soc.customer_id,
        soc.customer_zip_code_prefix,
        soc.customer_city,
        soc.customer_state

    FROM data_vault.sat_order_customer soc

    ORDER BY
        soc.order_customer_hk,
        soc.load_timestamp DESC

),

latest_sat_order_item AS (

    /*
     * Recupera a versão mais recente de cada item.
     */

    SELECT DISTINCT ON (soi.order_item_hk)
        soi.order_item_hk,
        soi.price,
        soi.freight_value

    FROM data_vault.sat_order_item soi

    ORDER BY
        soi.order_item_hk,
        soi.load_timestamp DESC

),

order_values AS (

    /*
     * Calcula o valor total de cada pedido a partir dos
     * itens preservados no Vault.
     */

    SELECT
        loi.order_hk,

        SUM(
            soi.price
            +
            soi.freight_value
        ) AS valor_calculado_pedido

    FROM data_vault.link_order_item loi

    JOIN latest_sat_order_item soi
        ON soi.order_item_hk = loi.order_item_hk

    GROUP BY
        loi.order_hk
)

INSERT INTO data_mart.fact_order (
    order_id,

    customer_sk,
    order_status_sk,

    purchase_date_sk,
    delivered_date_sk,
    estimated_delivery_date_sk,

    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    valor_calculado_pedido,
    tempo_entrega_dias,
    indicador_atraso
)

SELECT
    ho.order_id,


    /* --------------------------------------------------------
     * Cliente
     * --------------------------------------------------------
     */

    COALESCE(
        dc.customer_sk,
        0
    ) AS customer_sk,


    /* --------------------------------------------------------
     * Status
     * --------------------------------------------------------
     */

    COALESCE(
        dos.order_status_sk,
        0
    ) AS order_status_sk,


    /* --------------------------------------------------------
     * Data da compra
     * --------------------------------------------------------
     */

    COALESCE(
        TO_CHAR(
            so.order_purchase_timestamp::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS purchase_date_sk,


    /* --------------------------------------------------------
     * Data da entrega
     * --------------------------------------------------------
     */

    COALESCE(
        TO_CHAR(
            so.order_delivered_customer_date::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS delivered_date_sk,


    /* --------------------------------------------------------
     * Data estimada
     * --------------------------------------------------------
     */

    COALESCE(
        TO_CHAR(
            so.order_estimated_delivery_date::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS estimated_delivery_date_sk,


    /* --------------------------------------------------------
     * Timestamps
     * --------------------------------------------------------
     */

    so.order_purchase_timestamp,

    so.order_delivered_customer_date,

    so.order_estimated_delivery_date,


    /* --------------------------------------------------------
     * Valor calculado
     *
     * Não utilizar COALESCE para zero.
     *
     * Pedido sem item permanece NULL.
     * --------------------------------------------------------
     */

    ov.valor_calculado_pedido,


    /* --------------------------------------------------------
     * Tempo de entrega em dias
     * --------------------------------------------------------
     */

    CASE
        WHEN so.order_purchase_timestamp IS NOT NULL
         AND so.order_delivered_customer_date IS NOT NULL
        THEN
            EXTRACT(
                EPOCH FROM (
                    so.order_delivered_customer_date
                    -
                    so.order_purchase_timestamp
                )
            ) / 86400.0

        ELSE NULL
    END AS tempo_entrega_dias,


    /* --------------------------------------------------------
     * Indicador de atraso
     * --------------------------------------------------------
     */

    CASE
        WHEN so.order_delivered_customer_date IS NULL
          OR so.order_estimated_delivery_date IS NULL
        THEN NULL

        ELSE
            so.order_delivered_customer_date
            >
            so.order_estimated_delivery_date

    END AS indicador_atraso


FROM data_vault.hub_order ho

JOIN latest_sat_order so
    ON so.order_hk = ho.order_hk


/* ------------------------------------------------------------
 * Pedido → Cliente lógico
 * ------------------------------------------------------------
 */

LEFT JOIN data_vault.link_order_customer loc
    ON loc.order_hk = ho.order_hk


LEFT JOIN latest_sat_order_customer soc
    ON soc.order_customer_hk = loc.order_customer_hk


LEFT JOIN data_mart.dim_customer dc
    ON dc.customer_id = soc.customer_id


/* ------------------------------------------------------------
 * Status
 * ------------------------------------------------------------
 */

LEFT JOIN data_mart.dim_order_status dos
    ON dos.order_status = so.order_status


/* ------------------------------------------------------------
 * Valor calculado do pedido
 * ------------------------------------------------------------
 */

LEFT JOIN order_values ov
    ON ov.order_hk = ho.order_hk


ON CONFLICT (order_id) DO NOTHING;


/* ============================================================
 * 2. FACT_ORDER_ITEM
 * ============================================================
 *
 * Grão:
 *
 * (order_id, order_item_id)
 *
 * Fontes:
 *
 * link_order_item
 * sat_order_item
 * hub_order
 * hub_product
 * hub_seller
 *
 * Para contexto do pedido:
 *
 * sat_order
 * link_order_customer
 * sat_order_customer
 *
 * O objetivo é reconstruir a mesma estrutura existente na
 * fact_order_item do modelo Kimball.
 * ============================================================
 */


WITH latest_sat_order AS (

    SELECT DISTINCT ON (so.order_hk)
        so.order_hk,
        so.order_status,
        so.order_purchase_timestamp

    FROM data_vault.sat_order so

    ORDER BY
        so.order_hk,
        so.load_timestamp DESC

),

latest_sat_order_customer AS (

    SELECT DISTINCT ON (soc.order_customer_hk)
        soc.order_customer_hk,
        soc.customer_id

    FROM data_vault.sat_order_customer soc

    ORDER BY
        soc.order_customer_hk,
        soc.load_timestamp DESC

),

latest_sat_order_item AS (

    SELECT DISTINCT ON (soi.order_item_hk)
        soi.order_item_hk,
        soi.price,
        soi.freight_value

    FROM data_vault.sat_order_item soi

    ORDER BY
        soi.order_item_hk,
        soi.load_timestamp DESC

)

INSERT INTO data_mart.fact_order_item (
    order_id,
    order_item_id,

    customer_sk,
    order_status_sk,
    purchase_date_sk,

    product_sk,
    seller_sk,

    price,
    freight_value
)

SELECT
    ho.order_id,

    loi.order_item_id,


    /* --------------------------------------------------------
     * Cliente
     * --------------------------------------------------------
     */

    COALESCE(
        dc.customer_sk,
        0
    ) AS customer_sk,


    /* --------------------------------------------------------
     * Status
     * --------------------------------------------------------
     */

    COALESCE(
        dos.order_status_sk,
        0
    ) AS order_status_sk,


    /* --------------------------------------------------------
     * Data da compra
     * --------------------------------------------------------
     */

    COALESCE(
        TO_CHAR(
            so.order_purchase_timestamp::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS purchase_date_sk,


    /* --------------------------------------------------------
     * Produto
     * --------------------------------------------------------
     */

    COALESCE(
        dp.product_sk,
        0
    ) AS product_sk,


    /* --------------------------------------------------------
     * Seller
     * --------------------------------------------------------
     */

    COALESCE(
        ds.seller_sk,
        0
    ) AS seller_sk,


    /* --------------------------------------------------------
     * Medidas
     * --------------------------------------------------------
     */

    soi.price,

    soi.freight_value


FROM data_vault.link_order_item loi


/* ------------------------------------------------------------
 * Business Keys participantes do Link
 * ------------------------------------------------------------
 */

JOIN data_vault.hub_order ho
    ON ho.order_hk = loi.order_hk

JOIN data_vault.hub_product hp
    ON hp.product_hk = loi.product_hk

JOIN data_vault.hub_seller hs
    ON hs.seller_hk = loi.seller_hk


/* ------------------------------------------------------------
 * Payload do item
 * ------------------------------------------------------------
 */

JOIN latest_sat_order_item soi
    ON soi.order_item_hk = loi.order_item_hk


/* ------------------------------------------------------------
 * Contexto do pedido
 * ------------------------------------------------------------
 */

JOIN latest_sat_order so
    ON so.order_hk = loi.order_hk


/* ------------------------------------------------------------
 * Contexto Pedido–Cliente
 * ------------------------------------------------------------
 */

LEFT JOIN data_vault.link_order_customer loc
    ON loc.order_hk = loi.order_hk

LEFT JOIN latest_sat_order_customer soc
    ON soc.order_customer_hk = loc.order_customer_hk


/* ------------------------------------------------------------
 * Resolução das dimensões do Data Mart
 * ------------------------------------------------------------
 */

LEFT JOIN data_mart.dim_customer dc
    ON dc.customer_id = soc.customer_id

LEFT JOIN data_mart.dim_order_status dos
    ON dos.order_status = so.order_status

LEFT JOIN data_mart.dim_product dp
    ON dp.product_id = hp.product_id

LEFT JOIN data_mart.dim_seller ds
    ON ds.seller_id = hs.seller_id


ON CONFLICT (
    order_id,
    order_item_id
) DO NOTHING;


/* ============================================================
 * 3. CONTAGEM DAS FATOS
 * ============================================================
 */

SELECT
    'fact_order' AS tabela,
    COUNT(*) AS quantidade

FROM data_mart.fact_order

UNION ALL

SELECT
    'fact_order_item',
    COUNT(*)

FROM data_mart.fact_order_item;


/* ============================================================
 * 4. SURROGATE KEYS NÃO RESOLVIDAS
 * ============================================================
 */


/* FACT_ORDER */

SELECT
    COUNT(*) FILTER (
        WHERE customer_sk = 0
    ) AS customer_desconhecido,

    COUNT(*) FILTER (
        WHERE order_status_sk = 0
    ) AS status_desconhecido,

    COUNT(*) FILTER (
        WHERE purchase_date_sk = 0
    ) AS purchase_date_desconhecida,

    COUNT(*) FILTER (
        WHERE delivered_date_sk = 0
    ) AS delivered_date_desconhecida,

    COUNT(*) FILTER (
        WHERE estimated_delivery_date_sk = 0
    ) AS estimated_date_desconhecida

FROM data_mart.fact_order;


/* FACT_ORDER_ITEM */

SELECT
    COUNT(*) FILTER (
        WHERE customer_sk = 0
    ) AS customer_desconhecido,

    COUNT(*) FILTER (
        WHERE order_status_sk = 0
    ) AS status_desconhecido,

    COUNT(*) FILTER (
        WHERE purchase_date_sk = 0
    ) AS purchase_date_desconhecida,

    COUNT(*) FILTER (
        WHERE product_sk = 0
    ) AS product_desconhecido,

    COUNT(*) FILTER (
        WHERE seller_sk = 0
    ) AS seller_desconhecido

FROM data_mart.fact_order_item;


/* ============================================================
 * 5. PEDIDOS SEM ITENS
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_sem_itens

FROM data_mart.fact_order

WHERE valor_calculado_pedido IS NULL;


/* ============================================================
 * 6. CONTROLE FINANCEIRO
 * ============================================================
 */

SELECT
    SUM(price) AS total_price,
    SUM(freight_value) AS total_freight,
    SUM(price + freight_value) AS total

FROM data_mart.fact_order_item;