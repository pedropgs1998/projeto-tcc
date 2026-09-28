SELECT COUNT(*) AS fact_order
FROM kimball.fact_order;


SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS approved_null,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS carrier_null
FROM kimball.fact_order;


SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS raw_approved_null,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS raw_carrier_null
FROM raw.orders;


SELECT
    COUNT(*) AS registros_divergentes
FROM kimball.fact_order fo
JOIN raw.orders ro
    ON ro.order_id = fo.order_id
WHERE fo.order_approved_at IS DISTINCT FROM ro.order_approved_at
   OR fo.order_delivered_carrier_date
      IS DISTINCT FROM ro.order_delivered_carrier_date;


SELECT
    COUNT(*) AS pedidos_raw_sem_fact_order
FROM raw.orders ro
LEFT JOIN kimball.fact_order fo
    ON fo.order_id = ro.order_id
WHERE fo.order_id IS NULL;