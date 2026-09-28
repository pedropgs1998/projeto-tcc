UPDATE data_mart.fact_order fo
SET
    order_approved_at = so.order_approved_at,
    order_delivered_carrier_date = so.order_delivered_carrier_date
FROM data_vault.hub_order ho
JOIN data_vault.sat_order so
    ON so.order_hk = ho.order_hk
WHERE fo.order_id = ho.order_id;