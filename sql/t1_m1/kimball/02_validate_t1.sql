-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Kimball
-- Validação da fact_payment
-- ============================================================================


-- 1. Quantidade total
SELECT
    COUNT(*) AS fact_payment
FROM kimball.fact_payment;


-- 2. Grão
SELECT
    COUNT(*) AS total_linhas,
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)) AS duplicidades
FROM kimball.fact_payment;


-- 3. Comparação com RAW
SELECT
    (SELECT COUNT(*) FROM raw.order_payments) AS raw_payments,
    (SELECT COUNT(*) FROM kimball.fact_payment) AS kimball_payments;


-- 4. Valores
SELECT
    (SELECT SUM(payment_value) FROM raw.order_payments) AS raw_total,
    (SELECT SUM(payment_value) FROM kimball.fact_payment) AS kimball_total,
    (
        SELECT SUM(payment_value) FROM raw.order_payments
    ) - (
        SELECT SUM(payment_value) FROM kimball.fact_payment
    ) AS diferenca;


-- 5. Chaves desconhecidas
SELECT
    COUNT(*) FILTER (WHERE customer_sk = 0) AS customer_sk_zero,
    COUNT(*) FILTER (WHERE order_status_sk = 0) AS order_status_sk_zero,
    COUNT(*) FILTER (WHERE purchase_date_sk = 0) AS purchase_date_sk_zero
FROM kimball.fact_payment;


-- 6. Tipos de pagamento
SELECT
    payment_type,
    COUNT(*) AS quantidade,
    SUM(payment_value) AS valor_pago
FROM kimball.fact_payment
GROUP BY payment_type
ORDER BY payment_type;


-- 7. Integridade com pedidos
SELECT
    COUNT(*) AS pagamentos_sem_order
FROM kimball.fact_payment p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL;


-- 8. Agregação por pedido
WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM kimball.fact_payment
    GROUP BY order_id
)
SELECT
    COUNT(*) AS pedidos_com_pagamento,
    SUM(valor_pago_pedido) AS valor_pago_total,
    AVG(valor_pago_pedido) AS ticket_medio_pago
FROM pagamentos_por_pedido;