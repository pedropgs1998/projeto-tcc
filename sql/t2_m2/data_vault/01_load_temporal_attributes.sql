UPDATE data_vault.sat_order so
SET
    order_approved_at = ro.order_approved_at,
    order_delivered_carrier_date = ro.order_delivered_carrier_date,
    hashdiff = data_vault.hash_values(
        ARRAY[
            ro.order_status::TEXT,
            ro.order_purchase_timestamp::TEXT,
            ro.order_approved_at::TEXT,
            ro.order_delivered_carrier_date::TEXT,
            ro.order_delivered_customer_date::TEXT,
            ro.order_estimated_delivery_date::TEXT
        ]
    )
FROM data_vault.hub_order ho
JOIN raw.orders ro
    ON ro.order_id = ho.order_id
WHERE so.order_hk = ho.order_hk;