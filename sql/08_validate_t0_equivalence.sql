/*
 * Validação final de equivalência — Estado T0
 *
 * Compara os resultados analíticos das duas arquiteturas:
 *
 * A) Kimball
 * B) Data Vault -> Data Mart
 *
 * Consultas:
 * - Q1
 * - Q2
 * - Q3
 */


/* ============================================================
 * Q1 — VALOR BRUTO DOS ITENS VENDIDOS
 * ============================================================
 */

WITH kimball_q1 AS (

    SELECT
        SUM(foi.price) AS valor_bruto_itens_vendidos

    FROM kimball.fact_order_item foi

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    WHERE dos.order_status = 'delivered'

),

mart_q1 AS (

    SELECT
        SUM(foi.price) AS valor_bruto_itens_vendidos

    FROM data_mart.fact_order_item foi

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    WHERE dos.order_status = 'delivered'

)

SELECT
    k.valor_bruto_itens_vendidos AS kimball,

    m.valor_bruto_itens_vendidos AS data_mart,

    ABS(
        k.valor_bruto_itens_vendidos
        -
        m.valor_bruto_itens_vendidos
    ) AS diferenca

FROM kimball_q1 k
CROSS JOIN mart_q1 m;


/* ============================================================
 * Q2 — TICKET MÉDIO CALCULADO
 * ============================================================
 */

WITH kimball_q2 AS (

    SELECT
        AVG(
            fo.valor_calculado_pedido
        ) AS ticket_medio_calculado

    FROM kimball.fact_order fo

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    WHERE dos.order_status = 'delivered'

),

mart_q2 AS (

    SELECT
        AVG(
            fo.valor_calculado_pedido
        ) AS ticket_medio_calculado

    FROM data_mart.fact_order fo

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    WHERE dos.order_status = 'delivered'

)

SELECT
    k.ticket_medio_calculado AS kimball,

    m.ticket_medio_calculado AS data_mart,

    ABS(
        k.ticket_medio_calculado
        -
        m.ticket_medio_calculado
    ) AS diferenca

FROM kimball_q2 k
CROSS JOIN mart_q2 m;


/* ============================================================
 * Q3 — KIMBALL
 * ============================================================
 */

DROP TABLE IF EXISTS pg_temp.kimball_q3;

CREATE TEMP TABLE kimball_q3 AS

WITH orders_delivered AS (

    SELECT
        dd.year::INTEGER AS year,

        dd.month::INTEGER AS month,

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
   AND i.customer_state = o.customer_state;


/* ============================================================
 * Q3 — DATA MART
 * ============================================================
 */

DROP TABLE IF EXISTS pg_temp.mart_q3;

CREATE TEMP TABLE mart_q3 AS

WITH orders_delivered AS (

    SELECT
        dd.year::INTEGER AS year,

        dd.month::INTEGER AS month,

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

    JOIN data_mart.dim_date dd
        ON dd.date_sk = fo.purchase_date_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
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
   AND i.customer_state = o.customer_state;


/* ============================================================
 * CONTAGEM DAS LINHAS DA Q3
 * ============================================================
 */

SELECT
    (SELECT COUNT(*)
     FROM kimball_q3) AS kimball_linhas,

    (SELECT COUNT(*)
     FROM mart_q3) AS data_mart_linhas;


/* ============================================================
 * LINHAS PRESENTES NO KIMBALL E AUSENTES/DIFERENTES NO MART
 * ============================================================
 */

SELECT
    COUNT(*) AS kimball_nao_encontrado_no_mart

FROM (

    SELECT *
    FROM kimball_q3

    EXCEPT

    SELECT *
    FROM mart_q3

) x;


/* ============================================================
 * LINHAS PRESENTES NO MART E AUSENTES/DIFERENTES NO KIMBALL
 * ============================================================
 */

SELECT
    COUNT(*) AS mart_nao_encontrado_no_kimball

FROM (

    SELECT *
    FROM mart_q3

    EXCEPT

    SELECT *
    FROM kimball_q3

) x;


/* ============================================================
 * COMPARAÇÃO POR CHAVE ANALÍTICA
 * ============================================================
 */

SELECT
    COUNT(*) AS grupos_com_diferenca

FROM kimball_q3 k

JOIN mart_q3 m
    ON m.year = k.year
   AND m.month = k.month
   AND m.customer_state = k.customer_state

WHERE
       k.quantidade_pedidos
           IS DISTINCT FROM m.quantidade_pedidos

    OR k.quantidade_clientes
           IS DISTINCT FROM m.quantidade_clientes

    OR k.quantidade_itens
           IS DISTINCT FROM m.quantidade_itens

    OR k.quantidade_produtos
           IS DISTINCT FROM m.quantidade_produtos

    OR k.quantidade_vendedores
           IS DISTINCT FROM m.quantidade_vendedores

    OR k.valor_bruto_itens
           IS DISTINCT FROM m.valor_bruto_itens

    OR k.valor_frete
           IS DISTINCT FROM m.valor_frete

    OR k.valor_calculado_pedidos
           IS DISTINCT FROM m.valor_calculado_pedidos

    OR k.ticket_medio_calculado
           IS DISTINCT FROM m.ticket_medio_calculado

    OR k.tempo_medio_entrega_dias
           IS DISTINCT FROM m.tempo_medio_entrega_dias

    OR k.percentual_entregas_atrasadas
           IS DISTINCT FROM m.percentual_entregas_atrasadas;


/* ============================================================
 * RESUMO ESPERADO
 * ============================================================
 *
 * Q1:
 * diferenca = 0
 *
 * Q2:
 * diferenca = 0
 *
 * Q3:
 * kimball_linhas                 = 556
 * data_mart_linhas               = 556
 * kimball_nao_encontrado_no_mart = 0
 * mart_nao_encontrado_no_kimball = 0
 * grupos_com_diferenca            = 0
 *
 * Se todos esses critérios forem atendidos:
 *
 * T0 analiticamente equivalente.
 * ============================================================
 */