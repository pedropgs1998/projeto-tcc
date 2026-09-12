-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Mart
-- Validação da fact_payment derivada do Data Vault
-- ============================================================================


-- 1. Volume
SELECT
    COUNT(*) AS fact_payment
FROM data_mart.fact_payment;


-- 2. Grão
SELECT
    COUNT(*) AS total_linhas,
    COUNT(*) - COUNT(
        DISTINCT (order_id, payment_sequential)
    ) AS duplicidades
FROM data_mart.fact_payment;


-- 3. Comparação Vault x Data Mart
SELECT
    (
        SELECT COUNT(*)
        FROM data_vault.sat_order_payment
    ) AS vault_payments,

    (
        SELECT COUNT(*)
        FROM data_mart.fact_payment
    ) AS mart_payments;


-- 4. Valores financeiros
SELECT
    (
        SELECT SUM(payment_value)
        FROM data_vault.sat_order_payment
    ) AS vault_total,

    (
        SELECT SUM(payment_value)
        FROM data_mart.fact_payment
    ) AS mart_total,

    (
        SELECT SUM(payment_value)
        FROM data_vault.sat_order_payment
    )
    -
    (
        SELECT SUM(payment_value)
        FROM data_mart.fact_payment
    ) AS diferenca;


-- 5. Chaves desconhecidas
SELECT
    COUNT(*) FILTER (
        WHERE customer_sk = 0
    ) AS customer_sk_zero,

    COUNT(*) FILTER (
        WHERE order_status_sk = 0
    ) AS order_status_sk_zero,

    COUNT(*) FILTER (
        WHERE purchase_date_sk = 0
    ) AS purchase_date_sk_zero

FROM data_mart.fact_payment;


-- 6. Tipos de pagamento
SELECT
    payment_type,
    COUNT(*) AS quantidade,
    SUM(payment_value) AS valor_pago
FROM data_mart.fact_payment
GROUP BY payment_type
ORDER BY payment_type;


-- 7. Pedidos distintos
SELECT
    COUNT(DISTINCT order_id) AS pedidos_com_pagamento
FROM data_mart.fact_payment;


-- 8. Agregação no grão do pedido
WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM data_mart.fact_payment
    GROUP BY order_id
)
SELECT
    COUNT(*) AS pedidos_com_pagamento,
    SUM(valor_pago_pedido) AS valor_pago_total,
    AVG(valor_pago_pedido) AS ticket_medio_pago
FROM pagamentos_por_pedido;


-- 9. Comparação direta com RAW para controle final
SELECT
    (
        SELECT COUNT(*)
        FROM raw.order_payments
    ) AS raw_linhas,

    (
        SELECT COUNT(*)
        FROM data_mart.fact_payment
    ) AS mart_linhas,

    (
        SELECT SUM(payment_value)
        FROM raw.order_payments
    ) AS raw_total,

    (
        SELECT SUM(payment_value)
        FROM data_mart.fact_payment
    ) AS mart_total;