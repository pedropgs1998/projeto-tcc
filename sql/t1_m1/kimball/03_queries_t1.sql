-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Kimball
-- Consultas analíticas
-- ============================================================================


-- ============================================================================
-- Q1
-- Valor bruto de itens vendidos em pedidos delivered
-- Não é impactada por M1
-- ============================================================================

SELECT
    SUM(fi.price) AS valor_bruto_itens_vendidos
FROM kimball.fact_order_item fi
WHERE fi.order_status_sk = (
    SELECT order_status_sk
    FROM kimball.dim_order_status
    WHERE order_status = 'delivered'
);


-- ============================================================================
-- Q2
-- Ticket médio calculado + ticket médio pago
--
-- Importante:
--   O ticket calculado considera todos os pedidos delivered.
--   O ticket pago considera apenas pedidos delivered que possuem pagamento.
-- ============================================================================

WITH pedidos_delivered AS (
    SELECT
        fo.order_id,
        fo.valor_calculado_pedido
    FROM kimball.fact_order fo
    JOIN kimball.dim_order_status s
        ON s.order_status_sk = fo.order_status_sk
    WHERE s.order_status = 'delivered'
),
pagamentos_por_pedido AS (
    SELECT
        fp.order_id,
        SUM(fp.payment_value) AS valor_pago_pedido
    FROM kimball.fact_payment fp
    GROUP BY fp.order_id
)
SELECT
    AVG(pd.valor_calculado_pedido) AS ticket_medio_calculado,
    AVG(pp.valor_pago_pedido) AS ticket_medio_pago
FROM pedidos_delivered pd
LEFT JOIN pagamentos_por_pedido pp
    ON pp.order_id = pd.order_id;


-- ============================================================================
-- Q3
-- Desempenho mensal por UF
-- M1 adiciona:
--   valor_pago
--   ticket_medio_pago
-- ============================================================================

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
   AND i.customer_state = p.customer_state

ORDER BY
    p.year,
    p.month,
    p.customer_state;