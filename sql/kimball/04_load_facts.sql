/*
 * Carga das tabelas fato do modelo Kimball — T0
 *
 * Ordem:
 * 1. fact_order
 * 2. fact_order_item
 *
 * O estado T0 não utiliza:
 * - pagamentos (M1);
 * - order_approved_at e order_delivered_carrier_date (M2);
 * - histórico de categoria de produto (M3).
 */


/* ============================================================
 * 1. FACT_ORDER
 * ============================================================
 *
 * Grão:
 * uma linha por order_id.
 *
 * Fontes:
 * - raw.orders
 * - raw.order_items
 *
 * raw.order_items é utilizado somente para calcular:
 *
 * valor_calculado_pedido =
 *     SUM(price + freight_value)
 *     por order_id
 *
 * Pedidos sem itens permanecem na fato.
 * Nesses casos, valor_calculado_pedido permanece NULL.
 * ============================================================
 */


WITH order_values AS (

    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS valor_calculado_pedido

    FROM raw.order_items oi

    GROUP BY
        oi.order_id
)

INSERT INTO kimball.fact_order (
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
    o.order_id,

    /* --------------------------------------------------------
     * Dimensão de cliente
     * -------------------------------------------------------- */

    COALESCE(
        c.customer_sk,
        0
    ) AS customer_sk,


    /* --------------------------------------------------------
     * Dimensão de status
     * -------------------------------------------------------- */

    COALESCE(
        os.order_status_sk,
        0
    ) AS order_status_sk,


    /* --------------------------------------------------------
     * Data da compra
     * -------------------------------------------------------- */

    COALESCE(
        TO_CHAR(
            o.order_purchase_timestamp::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS purchase_date_sk,


    /* --------------------------------------------------------
     * Data da entrega ao cliente
     *
     * Quando a origem possuir NULL:
     * delivered_date_sk = 0
     *
     * O timestamp original continua NULL.
     * -------------------------------------------------------- */

    COALESCE(
        TO_CHAR(
            o.order_delivered_customer_date::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS delivered_date_sk,


    /* --------------------------------------------------------
     * Data estimada de entrega
     * -------------------------------------------------------- */

    COALESCE(
        TO_CHAR(
            o.order_estimated_delivery_date::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS estimated_delivery_date_sk,


    /* --------------------------------------------------------
     * Timestamps da origem
     * -------------------------------------------------------- */

    o.order_purchase_timestamp,

    o.order_delivered_customer_date,

    o.order_estimated_delivery_date,


    /* --------------------------------------------------------
     * Valor calculado do pedido
     *
     * Não utilizar COALESCE(..., 0).
     *
     * Pedidos sem itens não devem ser interpretados
     * automaticamente como pedidos de valor zero.
     * -------------------------------------------------------- */

    ov.valor_calculado_pedido,


    /* --------------------------------------------------------
     * Tempo de entrega em dias
     *
     * Mantém a fração do dia.
     *
     * Exemplo:
     * 1,5 = 1 dia e 12 horas.
     *
     * Caso alguma das datas necessárias seja NULL,
     * o resultado também será NULL.
     * -------------------------------------------------------- */

    CASE
        WHEN o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
        THEN
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400.0

        ELSE NULL
    END AS tempo_entrega_dias,


    /* --------------------------------------------------------
     * Indicador de atraso
     *
     * TRUE:
     * entrega após a data estimada.
     *
     * FALSE:
     * entrega dentro ou antes da data estimada.
     *
     * NULL:
     * alguma das datas necessárias está ausente.
     * -------------------------------------------------------- */

    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
        THEN NULL

        ELSE
            o.order_delivered_customer_date
            >
            o.order_estimated_delivery_date
    END AS indicador_atraso

FROM raw.orders o

LEFT JOIN order_values ov
    ON ov.order_id = o.order_id

LEFT JOIN kimball.dim_customer c
    ON c.customer_id = o.customer_id

LEFT JOIN kimball.dim_order_status os
    ON os.order_status = o.order_status

ON CONFLICT (order_id) DO NOTHING;


/* ============================================================
 * 2. FACT_ORDER_ITEM
 * ============================================================
 *
 * Grão:
 * uma linha por (order_id, order_item_id).
 *
 * Fontes:
 * - raw.order_items
 * - raw.orders
 *
 * raw.orders é utilizado para trazer ao grão do item:
 *
 * - cliente;
 * - status do pedido;
 * - data da compra.
 *
 * Essa redundância dimensional é intencional e evita
 * dependência de joins entre fact_order_item e fact_order.
 * ============================================================
 */


INSERT INTO kimball.fact_order_item (
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
    oi.order_id,
    oi.order_item_id,


    /* --------------------------------------------------------
     * Cliente associado ao pedido
     * -------------------------------------------------------- */

    COALESCE(
        c.customer_sk,
        0
    ) AS customer_sk,


    /* --------------------------------------------------------
     * Status do pedido
     * -------------------------------------------------------- */

    COALESCE(
        os.order_status_sk,
        0
    ) AS order_status_sk,


    /* --------------------------------------------------------
     * Data da compra
     * -------------------------------------------------------- */

    COALESCE(
        TO_CHAR(
            o.order_purchase_timestamp::DATE,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS purchase_date_sk,


    /* --------------------------------------------------------
     * Produto
     * -------------------------------------------------------- */

    COALESCE(
        p.product_sk,
        0
    ) AS product_sk,


    /* --------------------------------------------------------
     * Vendedor
     * -------------------------------------------------------- */

    COALESCE(
        s.seller_sk,
        0
    ) AS seller_sk,


    /* --------------------------------------------------------
     * Medidas no grão do item
     * -------------------------------------------------------- */

    oi.price,

    oi.freight_value

FROM raw.order_items oi

JOIN raw.orders o
    ON o.order_id = oi.order_id

LEFT JOIN kimball.dim_customer c
    ON c.customer_id = o.customer_id

LEFT JOIN kimball.dim_order_status os
    ON os.order_status = o.order_status

LEFT JOIN kimball.dim_product p
    ON p.product_id = oi.product_id

LEFT JOIN kimball.dim_seller s
    ON s.seller_id = oi.seller_id

ON CONFLICT (order_id, order_item_id) DO NOTHING;