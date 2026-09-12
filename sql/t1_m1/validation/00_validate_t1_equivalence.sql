-- ============================================================================
-- TCC UNICAMP
-- T1 / M1
-- Validação de equivalência analítica
--
-- Comparação:
--   Kimball x Data Mart derivado do Data Vault 2.0
--
-- Contrato analítico:
--   Q1 - valor bruto dos itens
--   Q2 - ticket médio calculado e ticket médio pago
--   Q3 - desempenho mensal por UF
-- ============================================================================


-- ============================================================================
-- Q1
-- ============================================================================

WITH kimball_q1 AS (
    SELECT
        SUM(fi.price) AS valor
    FROM kimball.fact_order_item fi
    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fi.order_status_sk
    WHERE dos.order_status = 'delivered'
),

mart_q1 AS (
    SELECT
        SUM(fi.price) AS valor
    FROM data_mart.fact_order_item fi
    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fi.order_status_sk
    WHERE dos.order_status = 'delivered'
)

SELECT
    k.valor AS kimball,
    m.valor AS data_mart,
    k.valor - m.valor AS diferenca
FROM kimball_q1 k
CROSS JOIN mart_q1 m;


-- ============================================================================
-- Q2
-- ============================================================================

WITH kimball_delivered AS (
    SELECT
        fo.order_id,
        fo.valor_calculado_pedido
    FROM kimball.fact_order fo
    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk
    WHERE dos.order_status = 'delivered'
),

kimball_payments AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM kimball.fact_payment
    GROUP BY order_id
),

kimball_q2 AS (
    SELECT
        AVG(kd.valor_calculado_pedido) AS ticket_medio_calculado,
        AVG(kp.valor_pago_pedido) AS ticket_medio_pago
    FROM kimball_delivered kd
    LEFT JOIN kimball_payments kp
        ON kp.order_id = kd.order_id
),

mart_delivered AS (
    SELECT
        fo.order_id,
        fo.valor_calculado_pedido
    FROM data_mart.fact_order fo
    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk
    WHERE dos.order_status = 'delivered'
),

mart_payments AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM data_mart.fact_payment
    GROUP BY order_id
),

mart_q2 AS (
    SELECT
        AVG(md.valor_calculado_pedido) AS ticket_medio_calculado,
        AVG(mp.valor_pago_pedido) AS ticket_medio_pago
    FROM mart_delivered md
    LEFT JOIN mart_payments mp
        ON mp.order_id = md.order_id
)

SELECT
    k.ticket_medio_calculado AS kimball_ticket_calculado,
    m.ticket_medio_calculado AS mart_ticket_calculado,

    k.ticket_medio_calculado
        - m.ticket_medio_calculado
        AS diferenca_ticket_calculado,

    k.ticket_medio_pago AS kimball_ticket_pago,
    m.ticket_medio_pago AS mart_ticket_pago,

    k.ticket_medio_pago
        - m.ticket_medio_pago
        AS diferenca_ticket_pago

FROM kimball_q2 k
CROSS JOIN mart_q2 m;


-- ============================================================================
-- Q3 - KIMBALL
-- ============================================================================

DROP TABLE IF EXISTS pg_temp.kimball_q3;

CREATE TEMP TABLE kimball_q3 AS

WITH pedidos AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        dc.customer_state,
        dd.year,
        dd.month,
        fo.valor_calculado_pedido,
        fo.tempo_entrega_dias,
        fo.indicador_atraso

    FROM kimball.fact_order fo

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    JOIN kimball.dim_date dd
        ON dd.date_sk = fo.purchase_date_sk

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    WHERE dos.order_status = 'delivered'
),

itens_por_grupo AS (
    SELECT
        dd.year,
        dd.month,
        dc.customer_state,

        COUNT(*) AS quantidade_itens,
        COUNT(DISTINCT fi.product_sk) AS quantidade_produtos,
        COUNT(DISTINCT fi.seller_sk) AS quantidade_vendedores,

        SUM(fi.price) AS valor_bruto_itens,
        SUM(fi.freight_value) AS valor_frete

    FROM kimball.fact_order_item fi

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = fi.customer_sk

    JOIN kimball.dim_date dd
        ON dd.date_sk = fi.purchase_date_sk

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fi.order_status_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
        dc.customer_state
),

pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM kimball.fact_payment
    GROUP BY order_id
),

pedidos_por_grupo AS (
    SELECT
        p.year,
        p.month,
        p.customer_state,

        COUNT(*) AS quantidade_pedidos,
        COUNT(DISTINCT p.customer_unique_id) AS quantidade_clientes,

        SUM(p.valor_calculado_pedido) AS valor_calculado_pedidos,
        AVG(p.valor_calculado_pedido) AS ticket_medio_calculado,

        SUM(pp.valor_pago_pedido) AS valor_pago,
        AVG(pp.valor_pago_pedido) AS ticket_medio_pago,

        AVG(p.tempo_entrega_dias) AS tempo_medio_entrega_dias,

        AVG(
            CASE
                WHEN p.indicador_atraso THEN 1.0
                ELSE 0.0
            END
        ) * 100 AS percentual_entregas_atrasadas

    FROM pedidos p

    LEFT JOIN pagamentos_por_pedido pp
        ON pp.order_id = p.order_id

    GROUP BY
        p.year,
        p.month,
        p.customer_state
)

SELECT
    p.year,
    p.month,
    p.customer_state,

    p.quantidade_pedidos,
    p.quantidade_clientes,

    i.quantidade_itens,
    i.quantidade_produtos,
    i.quantidade_vendedores,

    i.valor_bruto_itens,
    i.valor_frete,

    p.valor_calculado_pedidos,
    p.valor_pago,

    p.ticket_medio_calculado,
    p.ticket_medio_pago,

    p.tempo_medio_entrega_dias,
    p.percentual_entregas_atrasadas

FROM pedidos_por_grupo p

LEFT JOIN itens_por_grupo i
    ON i.year = p.year
   AND i.month = p.month
   AND i.customer_state = p.customer_state;


-- ============================================================================
-- Q3 - DATA MART
-- ============================================================================

DROP TABLE IF EXISTS pg_temp.mart_q3;

CREATE TEMP TABLE mart_q3 AS

WITH pedidos AS (
    SELECT
        fo.order_id,
        dc.customer_unique_id,
        dc.customer_state,
        dd.year,
        dd.month,
        fo.valor_calculado_pedido,
        fo.tempo_entrega_dias,
        fo.indicador_atraso

    FROM data_mart.fact_order fo

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    JOIN data_mart.dim_date dd
        ON dd.date_sk = fo.purchase_date_sk

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    WHERE dos.order_status = 'delivered'
),

itens_por_grupo AS (
    SELECT
        dd.year,
        dd.month,
        dc.customer_state,

        COUNT(*) AS quantidade_itens,
        COUNT(DISTINCT fi.product_sk) AS quantidade_produtos,
        COUNT(DISTINCT fi.seller_sk) AS quantidade_vendedores,

        SUM(fi.price) AS valor_bruto_itens,
        SUM(fi.freight_value) AS valor_frete

    FROM data_mart.fact_order_item fi

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = fi.customer_sk

    JOIN data_mart.dim_date dd
        ON dd.date_sk = fi.purchase_date_sk

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fi.order_status_sk

    WHERE dos.order_status = 'delivered'

    GROUP BY
        dd.year,
        dd.month,
        dc.customer_state
),

pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM data_mart.fact_payment
    GROUP BY order_id
),

pedidos_por_grupo AS (
    SELECT
        p.year,
        p.month,
        p.customer_state,

        COUNT(*) AS quantidade_pedidos,
        COUNT(DISTINCT p.customer_unique_id) AS quantidade_clientes,

        SUM(p.valor_calculado_pedido) AS valor_calculado_pedidos,
        AVG(p.valor_calculado_pedido) AS ticket_medio_calculado,

        SUM(pp.valor_pago_pedido) AS valor_pago,
        AVG(pp.valor_pago_pedido) AS ticket_medio_pago,

        AVG(p.tempo_entrega_dias) AS tempo_medio_entrega_dias,

        AVG(
            CASE
                WHEN p.indicador_atraso THEN 1.0
                ELSE 0.0
            END
        ) * 100 AS percentual_entregas_atrasadas

    FROM pedidos p

    LEFT JOIN pagamentos_por_pedido pp
        ON pp.order_id = p.order_id

    GROUP BY
        p.year,
        p.month,
        p.customer_state
)

SELECT
    p.year,
    p.month,
    p.customer_state,

    p.quantidade_pedidos,
    p.quantidade_clientes,

    i.quantidade_itens,
    i.quantidade_produtos,
    i.quantidade_vendedores,

    i.valor_bruto_itens,
    i.valor_frete,

    p.valor_calculado_pedidos,
    p.valor_pago,

    p.ticket_medio_calculado,
    p.ticket_medio_pago,

    p.tempo_medio_entrega_dias,
    p.percentual_entregas_atrasadas

FROM pedidos_por_grupo p

LEFT JOIN itens_por_grupo i
    ON i.year = p.year
   AND i.month = p.month
   AND i.customer_state = p.customer_state;


-- ============================================================================
-- CONTAGEM DE GRUPOS
-- ============================================================================

SELECT
    (SELECT COUNT(*) FROM kimball_q3) AS kimball_linhas,
    (SELECT COUNT(*) FROM mart_q3) AS data_mart_linhas;


-- ============================================================================
-- GRUPOS AUSENTES
-- ============================================================================

SELECT
    COUNT(*) AS kimball_nao_encontrado_no_mart
FROM kimball_q3 k
LEFT JOIN mart_q3 m
    ON m.year = k.year
   AND m.month = k.month
   AND m.customer_state = k.customer_state
WHERE m.year IS NULL;


SELECT
    COUNT(*) AS mart_nao_encontrado_no_kimball
FROM mart_q3 m
LEFT JOIN kimball_q3 k
    ON k.year = m.year
   AND k.month = m.month
   AND k.customer_state = m.customer_state
WHERE k.year IS NULL;


-- ============================================================================
-- DIFERENÇAS DE CONTEÚDO
-- ============================================================================

SELECT
    COUNT(*) AS grupos_com_diferenca
FROM kimball_q3 k

JOIN mart_q3 m
    ON m.year = k.year
   AND m.month = k.month
   AND m.customer_state = k.customer_state

WHERE
       k.quantidade_pedidos IS DISTINCT FROM m.quantidade_pedidos
    OR k.quantidade_clientes IS DISTINCT FROM m.quantidade_clientes
    OR k.quantidade_itens IS DISTINCT FROM m.quantidade_itens
    OR k.quantidade_produtos IS DISTINCT FROM m.quantidade_produtos
    OR k.quantidade_vendedores IS DISTINCT FROM m.quantidade_vendedores
    OR k.valor_bruto_itens IS DISTINCT FROM m.valor_bruto_itens
    OR k.valor_frete IS DISTINCT FROM m.valor_frete
    OR k.valor_calculado_pedidos IS DISTINCT FROM m.valor_calculado_pedidos
    OR k.valor_pago IS DISTINCT FROM m.valor_pago
    OR k.ticket_medio_calculado IS DISTINCT FROM m.ticket_medio_calculado
    OR k.ticket_medio_pago IS DISTINCT FROM m.ticket_medio_pago
    OR k.tempo_medio_entrega_dias IS DISTINCT FROM m.tempo_medio_entrega_dias
    OR k.percentual_entregas_atrasadas IS DISTINCT FROM m.percentual_entregas_atrasadas;