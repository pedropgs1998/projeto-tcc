SELECT COUNT(*) AS sat_order
FROM data_vault.sat_order;


SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_hk) AS orders_distintos
FROM data_vault.sat_order;


SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS approved_null,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS carrier_null
FROM data_vault.sat_order;


SELECT
    COUNT(*) AS referencias_invalidas
FROM data_vault.sat_order so
LEFT JOIN data_vault.hub_order ho
    ON ho.order_hk = so.order_hk
WHERE ho.order_hk IS NULL;


SELECT
    COUNT(*) AS registros_divergentes
FROM data_vault.sat_order so
JOIN data_vault.hub_order ho
    ON ho.order_hk = so.order_hk
JOIN raw.orders ro
    ON ro.order_id = ho.order_id
WHERE so.order_approved_at
          IS DISTINCT FROM ro.order_approved_at
   OR so.order_delivered_carrier_date
          IS DISTINCT FROM ro.order_delivered_carrier_date;


SELECT
    COUNT(*) AS pedidos_raw_sem_sat_order
FROM raw.orders ro
JOIN data_vault.hub_order ho
    ON ho.order_id = ro.order_id
LEFT JOIN data_vault.sat_order so
    ON so.order_hk = ho.order_hk
WHERE so.order_hk IS NULL;


SELECT
    COUNT(*) AS hashdiffs_inconsistentes
FROM data_vault.sat_order so
JOIN data_vault.hub_order ho
    ON ho.order_hk = so.order_hk
JOIN raw.orders ro
    ON ro.order_id = ho.order_id
WHERE so.hashdiff <> data_vault.hash_values(
    ARRAY[
        ro.order_status::TEXT,
        ro.order_purchase_timestamp::TEXT,
        ro.order_approved_at::TEXT,
        ro.order_delivered_carrier_date::TEXT,
        ro.order_delivered_customer_date::TEXT,
        ro.order_estimated_delivery_date::TEXT
    ]
);


SELECT
    COUNT(*) FILTER (
        WHERE ro.order_status = 'delivered'
          AND so.order_approved_at IS NOT NULL
          AND ro.order_purchase_timestamp IS NOT NULL
          AND so.order_approved_at >= ro.order_purchase_timestamp
    ) AS validos_tempo_aprovacao,

    COUNT(*) FILTER (
        WHERE ro.order_status = 'delivered'
          AND so.order_approved_at IS NOT NULL
          AND so.order_delivered_carrier_date IS NOT NULL
          AND so.order_delivered_carrier_date >= so.order_approved_at
    ) AS validos_tempo_preparacao,

    COUNT(*) FILTER (
        WHERE ro.order_status = 'delivered'
          AND so.order_delivered_carrier_date IS NOT NULL
          AND ro.order_delivered_customer_date IS NOT NULL
          AND ro.order_delivered_customer_date >= so.order_delivered_carrier_date
    ) AS validos_tempo_transporte
FROM data_vault.sat_order so
JOIN data_vault.hub_order ho
    ON ho.order_hk = so.order_hk
JOIN raw.orders ro
    ON ro.order_id = ho.order_id;