SELECT COUNT(*) AS fact_order
FROM data_mart.fact_order;


SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS approved_null,
    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS carrier_null
FROM data_mart.fact_order;


SELECT
    COUNT(*) AS registros_divergentes_vault
FROM data_mart.fact_order fo
JOIN data_vault.hub_order ho
    ON ho.order_id = fo.order_id
JOIN data_vault.sat_order so
    ON so.order_hk = ho.order_hk
WHERE fo.order_approved_at
          IS DISTINCT FROM so.order_approved_at
   OR fo.order_delivered_carrier_date
          IS DISTINCT FROM so.order_delivered_carrier_date;


SELECT
    COUNT(*) AS registros_divergentes_kimball
FROM data_mart.fact_order dm
JOIN kimball.fact_order k
    ON k.order_id = dm.order_id
WHERE dm.order_approved_at
          IS DISTINCT FROM k.order_approved_at
   OR dm.order_delivered_carrier_date
          IS DISTINCT FROM k.order_delivered_carrier_date;


SELECT
    COUNT(*) AS pedidos_vault_sem_fact_order
FROM data_vault.hub_order ho
LEFT JOIN data_mart.fact_order fo
    ON fo.order_id = ho.order_id
WHERE fo.order_id IS NULL;


SELECT
    COUNT(*) FILTER (
        WHERE fo.order_status_sk IS NOT NULL
          AND fo.order_approved_at IS NOT NULL
          AND fo.order_purchase_timestamp IS NOT NULL
          AND fo.order_approved_at >= fo.order_purchase_timestamp
    ) AS validos_tempo_aprovacao,

    COUNT(*) FILTER (
        WHERE fo.order_status_sk IS NOT NULL
          AND fo.order_approved_at IS NOT NULL
          AND fo.order_delivered_carrier_date IS NOT NULL
          AND fo.order_delivered_carrier_date >= fo.order_approved_at
    ) AS validos_tempo_preparacao,

    COUNT(*) FILTER (
        WHERE fo.order_status_sk IS NOT NULL
          AND fo.order_delivered_carrier_date IS NOT NULL
          AND fo.order_delivered_customer_date IS NOT NULL
          AND fo.order_delivered_customer_date >= fo.order_delivered_carrier_date
    ) AS validos_tempo_transporte
FROM data_mart.fact_order fo
JOIN data_mart.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk
WHERE dos.order_status = 'delivered';