-- =========================================================
-- 05_profile_m2.sql
-- Validação dos atributos candidatos da Mudança 2
-- =========================================================


-- ---------------------------------------------------------
-- 1. NULLS NAS DATAS DO CICLO DO PEDIDO
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS pedidos_entregues,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS purchase_null,

    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS approved_null,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS carrier_null,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS delivered_null

FROM raw.orders
WHERE order_status = 'delivered';


-- ---------------------------------------------------------
-- 2. PEDIDOS COM TODAS AS DATAS NECESSÁRIAS
-- ---------------------------------------------------------

SELECT
    COUNT(*) AS pedidos_completos
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;


-- ---------------------------------------------------------
-- 3. INTERVALOS TEMPORAIS INCONSISTENTES
-- ---------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at < order_purchase_timestamp
    ) AS aprovacao_antes_compra,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date < order_approved_at
    ) AS transportadora_antes_aprovacao,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date < order_delivered_carrier_date
    ) AS entrega_antes_transportadora

FROM raw.orders
WHERE order_status = 'delivered';


-- ---------------------------------------------------------
-- 4. ESTATÍSTICAS — TEMPO DE APROVAÇÃO
-- ---------------------------------------------------------

SELECT
    MIN(
        EXTRACT(EPOCH FROM (
            order_approved_at - order_purchase_timestamp
        )) / 3600.0
    ) AS minimo_horas,

    AVG(
        EXTRACT(EPOCH FROM (
            order_approved_at - order_purchase_timestamp
        )) / 3600.0
    ) AS media_horas,

    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (
            order_approved_at - order_purchase_timestamp
        )) / 3600.0
    ) AS mediana_horas,

    MAX(
        EXTRACT(EPOCH FROM (
            order_approved_at - order_purchase_timestamp
        )) / 3600.0
    ) AS maximo_horas

FROM raw.orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_approved_at IS NOT NULL;


-- ---------------------------------------------------------
-- 5. ESTATÍSTICAS — TEMPO DE PREPARAÇÃO
-- ---------------------------------------------------------

SELECT
    MIN(
        EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 3600.0
    ) AS minimo_horas,

    AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 3600.0
    ) AS media_horas,

    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 3600.0
    ) AS mediana_horas,

    MAX(
        EXTRACT(EPOCH FROM (
            order_delivered_carrier_date - order_approved_at
        )) / 3600.0
    ) AS maximo_horas

FROM raw.orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL;


-- ---------------------------------------------------------
-- 6. ESTATÍSTICAS — TEMPO DE TRANSPORTE
-- ---------------------------------------------------------

SELECT
    MIN(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date
            - order_delivered_carrier_date
        )) / 86400.0
    ) AS minimo_dias,

    AVG(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date
            - order_delivered_carrier_date
        )) / 86400.0
    ) AS media_dias,

    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (
            order_delivered_customer_date
            - order_delivered_carrier_date
        )) / 86400.0
    ) AS mediana_dias,

    MAX(
        EXTRACT(EPOCH FROM (
            order_delivered_customer_date
            - order_delivered_carrier_date
        )) / 86400.0
    ) AS maximo_dias

FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;