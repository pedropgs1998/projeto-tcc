/*
 * Consultas analíticas do modelo Kimball — Estado T0
 *
 * Q1 — Valor bruto dos itens vendidos
 * Q2 — Ticket médio calculado dos pedidos
 * Q3 — Relatório mensal de desempenho por UF
 *
 * População principal:
 * pedidos com order_status = 'delivered'
 */


/* ============================================================
 * Q1 — VALOR BRUTO DOS ITENS VENDIDOS
 * ============================================================
 *
 * Definição:
 *
 * SUM(price)
 *
 * considerando apenas itens pertencentes a pedidos delivered.
 *
 * Grão de origem:
 * item de pedido.
 * ============================================================
 */

SELECT
    SUM(foi.price) AS valor_bruto_itens_vendidos

FROM kimball.fact_order_item foi

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = foi.order_status_sk

WHERE dos.order_status = 'delivered';


/* ============================================================
 * Q2 — TICKET MÉDIO CALCULADO DOS PEDIDOS
 * ============================================================
 *
 * valor_calculado_pedido já está armazenado em fact_order no
 * grão correto:
 *
 * SUM(price + freight_value)
 * por order_id.
 *
 * O ticket médio é:
 *
 * AVG(valor_calculado_pedido)
 *
 * considerando apenas pedidos delivered.
 * ============================================================
 */

SELECT
    AVG(fo.valor_calculado_pedido)
        AS ticket_medio_calculado

FROM kimball.fact_order fo

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk

WHERE dos.order_status = 'delivered';


/* ============================================================
 * Q3 — RELATÓRIO MENSAL DE DESEMPENHO POR UF
 * ============================================================
 *
 * Grão final:
 *
 * mês da compra + UF do cliente
 *
 * O relatório combina métricas provenientes de dois grãos:
 *
 * 1. pedido
 * 2. item de pedido
 *
 * As duas fatos são agregadas separadamente antes da combinação
 * para evitar duplicação das medidas de pedido.
 * ============================================================
 */


WITH order_metrics AS (

    /* ========================================================
     * Métricas no grão de pedido
     * ========================================================
     */

    SELECT
        dd.year,
        dd.month,

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

        AVG(
            CASE
                WHEN fo.indicador_atraso IS TRUE
                    THEN 1.0

                WHEN fo.indicador_atraso IS FALSE
                    THEN 0.0

                ELSE NULL
            END
        ) * 100.0 AS percentual_entregas_atrasadas

    FROM kimball.fact_order fo

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    JOIN kimball.dim_date dd
        ON dd.date_sk = fo.purchase_date_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
        dc.customer_state

),


item_metrics AS (

    /* ========================================================
     * Métricas no grão de item
     * ========================================================
     */

    SELECT
        dd.year,
        dd.month,

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

    FROM kimball.fact_order_item foi

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = foi.customer_sk

    JOIN kimball.dim_date dd
        ON dd.date_sk = foi.purchase_date_sk

    JOIN kimball.dim_product dp
        ON dp.product_sk = foi.product_sk

    JOIN kimball.dim_seller ds
        ON ds.seller_sk = foi.seller_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
        dc.customer_state

)


/* ============================================================
 * Combinação final
 * ============================================================
 *
 * Ambas as CTEs já estão no mesmo grão:
 *
 * ano + mês + customer_state
 *
 * Portanto, a junção não provoca fan-out.
 * ============================================================
 */

SELECT
    om.year,
    om.month,
    om.customer_state,

    om.quantidade_pedidos,
    om.quantidade_clientes,

    im.quantidade_itens,
    im.quantidade_produtos,
    im.quantidade_vendedores,

    im.valor_bruto_itens,
    im.valor_frete,

    om.valor_calculado_pedidos,
    om.ticket_medio_calculado,

    om.tempo_medio_entrega_dias,
    om.percentual_entregas_atrasadas

FROM order_metrics om

JOIN item_metrics im
    ON im.year = om.year
   AND im.month = om.month
   AND im.customer_state = om.customer_state

ORDER BY
    om.year,
    om.month,
    om.customer_state;