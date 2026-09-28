-- ============================================================================
-- TCC UNICAMP
-- T2 / M2
-- Validação de equivalência Kimball x Data Mart
-- ============================================================================


-- ============================================================================
-- Q1
-- ============================================================================

SELECT
    k.valor AS kimball,
    m.valor AS data_mart,
    k.valor - m.valor AS diferenca
FROM (
    SELECT SUM(fi.price) AS valor
    FROM kimball.fact_order_item fi
    WHERE fi.order_status_sk = (
        SELECT order_status_sk
        FROM kimball.dim_order_status
        WHERE order_status = 'delivered'
    )
) k
CROSS JOIN (
    SELECT SUM(fi.price) AS valor
    FROM data_mart.fact_order_item fi
    WHERE fi.order_status_sk = (
        SELECT order_status_sk
        FROM data_mart.dim_order_status
        WHERE order_status = 'delivered'
    )
) m;


-- ============================================================================
-- Q2
-- ============================================================================

WITH kimball_pedidos AS (
    SELECT
        fo.order_id,
        fo.valor_calculado_pedido
    FROM kimball.fact_order fo
    JOIN kimball.dim_order_status s
        ON s.order_status_sk = fo.order_status_sk
    WHERE s.order_status = 'delivered'
),
kimball_pagamentos AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM kimball.fact_payment
    GROUP BY order_id
),
mart_pedidos AS (
    SELECT
        fo.order_id,
        fo.valor_calculado_pedido
    FROM data_mart.fact_order fo
    JOIN data_mart.dim_order_status s
        ON s.order_status_sk = fo.order_status_sk
    WHERE s.order_status = 'delivered'
),
mart_pagamentos AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM data_mart.fact_payment
    GROUP BY order_id
),
kimball_resultado AS (
    SELECT
        AVG(kp.valor_calculado_pedido) AS ticket_calculado,
        AVG(kpg.valor_pago_pedido) AS ticket_pago
    FROM kimball_pedidos kp
    LEFT JOIN kimball_pagamentos kpg
        ON kpg.order_id = kp.order_id
),
mart_resultado AS (
    SELECT
        AVG(mp.valor_calculado_pedido) AS ticket_calculado,
        AVG(mpg.valor_pago_pedido) AS ticket_pago
    FROM mart_pedidos mp
    LEFT JOIN mart_pagamentos mpg
        ON mpg.order_id = mp.order_id
)
SELECT
    k.ticket_calculado AS kimball_ticket_calculado,
    m.ticket_calculado AS mart_ticket_calculado,
    k.ticket_calculado - m.ticket_calculado
        AS diferenca_ticket_calculado,

    k.ticket_pago AS kimball_ticket_pago,
    m.ticket_pago AS mart_ticket_pago,
    k.ticket_pago - m.ticket_pago
        AS diferenca_ticket_pago

FROM kimball_resultado k
CROSS JOIN mart_resultado m;


-- ============================================================================
-- Q3 - cria resultados temporários completos
-- ============================================================================

DROP TABLE IF EXISTS pg_temp.kimball_q3;
DROP TABLE IF EXISTS pg_temp.mart_q3;


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
        fo.indicador_atraso,

        CASE
            WHEN fo.order_approved_at IS NOT NULL
             AND fo.order_purchase_timestamp IS NOT NULL
             AND fo.order_approved_at >= fo.order_purchase_timestamp
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_approved_at
                    - fo.order_purchase_timestamp
                )
            ) / 3600.0
        END AS horas_aprovacao,

        CASE
            WHEN fo.order_delivered_carrier_date IS NOT NULL
             AND fo.order_approved_at IS NOT NULL
             AND fo.order_delivered_carrier_date >= fo.order_approved_at
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_delivered_carrier_date
                    - fo.order_approved_at
                )
            ) / 3600.0
        END AS horas_preparacao,

        CASE
            WHEN fo.order_delivered_customer_date IS NOT NULL
             AND fo.order_delivered_carrier_date IS NOT NULL
             AND fo.order_delivered_customer_date
                 >= fo.order_delivered_carrier_date
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_delivered_customer_date
                    - fo.order_delivered_carrier_date
                )
            ) / 3600.0
        END AS horas_transporte

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
        ) * 100 AS percentual_entregas_atrasadas,

        AVG(p.horas_aprovacao) AS media_horas_aprovacao,
        AVG(p.horas_preparacao) AS media_horas_preparacao,
        AVG(p.horas_transporte) AS media_horas_transporte

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
    p.percentual_entregas_atrasadas,

    p.media_horas_aprovacao,
    p.media_horas_preparacao,
    p.media_horas_transporte

FROM pedidos_por_grupo p
LEFT JOIN itens_por_grupo i
    ON i.year = p.year
   AND i.month = p.month
   AND i.customer_state = p.customer_state;


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
        fo.indicador_atraso,

        CASE
            WHEN fo.order_approved_at IS NOT NULL
             AND fo.order_purchase_timestamp IS NOT NULL
             AND fo.order_approved_at >= fo.order_purchase_timestamp
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_approved_at
                    - fo.order_purchase_timestamp
                )
            ) / 3600.0
        END AS horas_aprovacao,

        CASE
            WHEN fo.order_delivered_carrier_date IS NOT NULL
             AND fo.order_approved_at IS NOT NULL
             AND fo.order_delivered_carrier_date >= fo.order_approved_at
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_delivered_carrier_date
                    - fo.order_approved_at
                )
            ) / 3600.0
        END AS horas_preparacao,

        CASE
            WHEN fo.order_delivered_customer_date IS NOT NULL
             AND fo.order_delivered_carrier_date IS NOT NULL
             AND fo.order_delivered_customer_date
                 >= fo.order_delivered_carrier_date
            THEN EXTRACT(
                EPOCH FROM (
                    fo.order_delivered_customer_date
                    - fo.order_delivered_carrier_date
                )
            ) / 3600.0
        END AS horas_transporte

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
        ) * 100 AS percentual_entregas_atrasadas,

        AVG(p.horas_aprovacao) AS media_horas_aprovacao,
        AVG(p.horas_preparacao) AS media_horas_preparacao,
        AVG(p.horas_transporte) AS media_horas_transporte

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
    p.percentual_entregas_atrasadas,

    p.media_horas_aprovacao,
    p.media_horas_preparacao,
    p.media_horas_transporte

FROM pedidos_por_grupo p
LEFT JOIN itens_por_grupo i
    ON i.year = p.year
   AND i.month = p.month
   AND i.customer_state = p.customer_state;


-- ============================================================================
-- Quantidade de grupos
-- ============================================================================

SELECT
    (SELECT COUNT(*) FROM kimball_q3) AS kimball_linhas,
    (SELECT COUNT(*) FROM mart_q3) AS data_mart_linhas;


-- ============================================================================
-- Linhas presentes em Kimball e ausentes no Data Mart
-- ============================================================================

SELECT COUNT(*) AS kimball_nao_encontrado_no_mart
FROM (
    SELECT * FROM kimball_q3
    EXCEPT
    SELECT * FROM mart_q3
) d;


-- ============================================================================
-- Linhas presentes no Data Mart e ausentes em Kimball
-- ============================================================================

SELECT COUNT(*) AS mart_nao_encontrado_no_kimball
FROM (
    SELECT * FROM mart_q3
    EXCEPT
    SELECT * FROM kimball_q3
) d;


-- ============================================================================
-- Comparação específica das três novas métricas
-- ============================================================================

SELECT
    COUNT(*) AS grupos_com_diferenca_metricas_temporais
FROM kimball_q3 k
JOIN mart_q3 m
    ON m.year = k.year
   AND m.month = k.month
   AND m.customer_state = k.customer_state
WHERE k.media_horas_aprovacao
          IS DISTINCT FROM m.media_horas_aprovacao
   OR k.media_horas_preparacao
          IS DISTINCT FROM m.media_horas_preparacao
   OR k.media_horas_transporte
          IS DISTINCT FROM m.media_horas_transporte;


-- ============================================================================
-- Comparação completa de Q3
-- ============================================================================

SELECT
    COUNT(*) AS grupos_com_diferenca
FROM kimball_q3 k
JOIN mart_q3 m
    ON m.year = k.year
   AND m.month = k.month
   AND m.customer_state = k.customer_state
WHERE ROW(k.*) IS DISTINCT FROM ROW(m.*);