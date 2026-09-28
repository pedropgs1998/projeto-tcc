UPDATE kimball.fact_order fo
SET
    order_approved_at = ro.order_approved_at,
    order_delivered_carrier_date = ro.order_delivered_carrier_date
FROM raw.orders ro
WHERE fo.order_id = ro.order_id;