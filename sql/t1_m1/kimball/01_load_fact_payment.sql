-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Kimball
-- Carga da fact_payment
-- ============================================================================

TRUNCATE TABLE kimball.fact_payment;

INSERT INTO kimball.fact_payment (
    order_id,
    payment_sequential,
    customer_sk,
    order_status_sk,
    purchase_date_sk,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    p.order_id,
    p.payment_sequential,

    COALESCE(c.customer_sk, 0) AS customer_sk,
    COALESCE(s.order_status_sk, 0) AS order_status_sk,
    COALESCE(d.date_sk, 0) AS purchase_date_sk,

    p.payment_type,
    p.payment_installments,
    p.payment_value

FROM raw.order_payments p

INNER JOIN raw.orders o
    ON o.order_id = p.order_id

LEFT JOIN kimball.dim_customer c
    ON c.customer_id = o.customer_id

LEFT JOIN kimball.dim_order_status s
    ON s.order_status = o.order_status

LEFT JOIN kimball.dim_date d
    ON d.full_date = o.order_purchase_timestamp::date;