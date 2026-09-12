/*
 * Consultas analíticas do Data Mart — Estado T0
 *
 * As consultas possuem a mesma definição funcional
 * utilizada no modelo Kimball.
 *
 * Objetivo:
 * comprovar equivalência dos resultados analíticos entre:
 *
 * Kimball
 *
 * e
 *
 * Data Vault -> Data Mart
 *
 * População principal:
 * pedidos com status = 'delivered'
 */


/* ============================================================
 * Q1 — VALOR BRUTO DOS ITENS VENDIDOS
 * ============================================================
 */

SELECT
    SUM(foi.price) AS valor_bruto_itens_vendidos

FROM data_mart.fact_order_item foi

JOIN data_mart.dim_order_status dos
    ON dos.order_status_sk = foi.order_status_sk

WHERE dos.order_status = 'delivered';


/* ============================================================
 * Q2 — TICKET MÉDIO CALCULADO DOS PEDIDOS ENTREGUES
 * ============================================================
 *
 * Primeiro:
 *
 * valor_calculado_pedido =
 * SUM(price + freight_value)
 *
 * O valor já foi materializado em fact_order.
 *
 * Depois:
 *
 * AVG(valor_calculado_pedido)
 *
 * Apenas pedidos delivered.
 *
 * Pedidos delivered sem itens possuem valor NULL e,
 * consequentemente, não entram no AVG.
 * ============================================================
 */

SELECT
    AVG(fo.valor_calculado_pedido)
        AS ticket_medio_calculado

FROM data_mart.fact_order fo

JOIN data_mart.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk

WHERE dos.order_status = 'delivered';


/* ============================================================
 * Q3 — RELATÓRIO MENSAL DE DESEMPENHO POR UF
 *
 * Grão:
 * year + month + customer_state
 *
 * fact_order e fact_order_item são agregadas separadamente
 * antes da combinação para evitar fan-out.
 * ============================================================
 */

WITH orders_delivered AS (

    SELECT
        EXTRACT(
            YEAR FROM fo.order_purchase_timestamp
        )::INTEGER AS year,

        EXTRACT(
            MONTH FROM fo.order_purchase_timestamp
        )::INTEGER AS month,

        dc.customer_state,

        COUNT(*) AS quantidade_pedidos,

        COUNT(
            DISTINCT dc.customer_unique_id
        ) AS quantidade_clientes,

        SUM(
            fo.valor_calculado_pedido
        ) AS valor_calculado_pedidos,

        AVG(
            fo.valor_calculado_pedido
        ) AS ticket_medio_calculado,

        AVG(
            fo.tempo_entrega_dias
        ) AS tempo_medio_entrega_dias,

        (
            COUNT(*) FILTER (
                WHERE fo.indicador_atraso = TRUE
            )::NUMERIC
            /
            NULLIF(
                COUNT(*) FILTER (
                    WHERE fo.indicador_atraso IS NOT NULL
                ),
                0
            )
        ) * 100 AS percentual_entregas_atrasadas

    FROM data_mart.fact_order fo

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        EXTRACT(
            YEAR FROM fo.order_purchase_timestamp
        )::INTEGER,

        EXTRACT(
            MONTH FROM fo.order_purchase_timestamp
        )::INTEGER,

        dc.customer_state
),

items_delivered AS (

    SELECT
        dd.year::INTEGER AS year,

        dd.month::INTEGER AS month,

        dc.customer_state,

        COUNT(*) AS quantidade_itens,

        COUNT(
            DISTINCT dp.product_id
        ) AS quantidade_produtos,

        COUNT(
            DISTINCT ds.seller_id
        ) AS quantidade_vendedores,

        SUM(
            foi.price
        ) AS valor_bruto_itens,

        SUM(
            foi.freight_value
        ) AS valor_frete

    FROM data_mart.fact_order_item foi

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = foi.customer_sk

    JOIN data_mart.dim_date dd
        ON dd.date_sk = foi.purchase_date_sk

    JOIN data_mart.dim_product dp
        ON dp.product_sk = foi.product_sk

    JOIN data_mart.dim_seller ds
        ON ds.seller_sk = foi.seller_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
        dc.customer_state
)

SELECT
    o.year,

    o.month,

    o.customer_state,

    o.quantidade_pedidos,

    o.quantidade_clientes,

    i.quantidade_itens,

    i.quantidade_produtos,

    i.quantidade_vendedores,

    i.valor_bruto_itens,

    i.valor_frete,

    o.valor_calculado_pedidos,

    o.ticket_medio_calculado,

    o.tempo_medio_entrega_dias,

    o.percentual_entregas_atrasadas

FROM orders_delivered o

JOIN items_delivered i
    ON i.year = o.year
   AND i.month = o.month
   AND i.customer_state = o.customer_state

ORDER BY
    o.year,
    o.month,
    o.customer_state;