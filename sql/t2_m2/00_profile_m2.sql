-- sql/t2_m2/00_profile_m2.sql

\echo '============================================================'
\echo 'M2 - Profiling dos atributos temporais'
\echo '============================================================'

-- 1. População geral
SELECT
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS pedidos_delivered
FROM raw.orders;

-- 2. Nulos no conjunto completo
SELECT
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS purchase_null,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS approved_null,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS carrier_null,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS delivered_null
FROM raw.orders;

-- 3. Nulos apenas entre pedidos entregues
SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_purchase_timestamp IS NULL
    ) AS purchase_null_delivered,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_approved_at IS NULL
    ) AS approved_null_delivered,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_carrier_date IS NULL
    ) AS carrier_null_delivered,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS delivered_null_delivered
FROM raw.orders;

-- 4. Pedidos entregues com todos os timestamps necessários
SELECT
    COUNT(*) AS delivered_com_todos_timestamps
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;

-- 5. Anomalias temporais
SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NOT NULL
          AND order_purchase_timestamp IS NOT NULL
          AND order_approved_at < order_purchase_timestamp
    ) AS aprovacao_antes_compra,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NOT NULL
          AND order_approved_at IS NOT NULL
          AND order_delivered_carrier_date < order_approved_at
    ) AS carrier_antes_aprovacao,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date < order_delivered_carrier_date
    ) AS entrega_cliente_antes_carrier,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
          AND order_purchase_timestamp IS NOT NULL
          AND order_delivered_customer_date < order_purchase_timestamp
    ) AS entrega_cliente_antes_compra
FROM raw.orders
WHERE order_status = 'delivered';

-- 6. População válida por métrica
SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_purchase_timestamp IS NOT NULL
          AND order_approved_at IS NOT NULL
          AND order_approved_at >= order_purchase_timestamp
    ) AS validos_tempo_aprovacao,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_approved_at IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_carrier_date >= order_approved_at
    ) AS validos_tempo_preparacao,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date IS NOT NULL
          AND order_delivered_customer_date >= order_delivered_carrier_date
    ) AS validos_tempo_transporte
FROM raw.orders;

-- 7. Estatísticas dos intervalos válidos
SELECT
    MIN(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_purchase_timestamp IS NOT NULL
              AND order_approved_at IS NOT NULL
              AND order_approved_at >= order_purchase_timestamp
        ) AS min_horas_aprovacao,

    AVG(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_purchase_timestamp IS NOT NULL
              AND order_approved_at IS NOT NULL
              AND order_approved_at >= order_purchase_timestamp
        ) AS media_horas_aprovacao,

    MAX(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_purchase_timestamp IS NOT NULL
              AND order_approved_at IS NOT NULL
              AND order_approved_at >= order_purchase_timestamp
        ) AS max_horas_aprovacao,

    MIN(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_approved_at IS NOT NULL
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_carrier_date >= order_approved_at
        ) AS min_horas_preparacao,

    AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_approved_at IS NOT NULL
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_carrier_date >= order_approved_at
        ) AS media_horas_preparacao,

    MAX(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_approved_at IS NOT NULL
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_carrier_date >= order_approved_at
        ) AS max_horas_preparacao,

    MIN(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_customer_date IS NOT NULL
              AND order_delivered_customer_date >= order_delivered_carrier_date
        ) AS min_horas_transporte,

    AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_customer_date IS NOT NULL
              AND order_delivered_customer_date >= order_delivered_carrier_date
        ) AS media_horas_transporte,

    MAX(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date)) / 3600.0)
        FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_carrier_date IS NOT NULL
              AND order_delivered_customer_date IS NOT NULL
              AND order_delivered_customer_date >= order_delivered_carrier_date
        ) AS max_horas_transporte
FROM raw.orders;