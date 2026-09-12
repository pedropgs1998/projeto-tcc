-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Vault 2.0
-- Carga do Multi-Active Satellite de pagamentos
--
-- A carga é rerunnable:
-- uma nova versão somente é inserida quando o hashdiff da combinação
-- (order_hk, payment_sequential) for diferente da versão mais recente.
-- ============================================================================

WITH candidate AS (
    SELECT
        ho.order_hk,
        p.payment_sequential,

        p.payment_type,
        p.payment_installments,
        p.payment_value,

        data_vault.hash_values(
            ARRAY[
                p.payment_type::TEXT,
                p.payment_installments::TEXT,
                p.payment_value::TEXT
            ]
        ) AS hashdiff,

        'olist_order_payments'::VARCHAR(100) AS record_source

    FROM raw.order_payments p

    INNER JOIN data_vault.hub_order ho
        ON ho.order_id = p.order_id
),

latest AS (
    SELECT DISTINCT ON (
        order_hk,
        payment_sequential
    )
        order_hk,
        payment_sequential,
        hashdiff

    FROM data_vault.sat_order_payment

    ORDER BY
        order_hk,
        payment_sequential,
        load_timestamp DESC
)

INSERT INTO data_vault.sat_order_payment (
    order_hk,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    hashdiff,
    record_source
)
SELECT
    c.order_hk,
    c.payment_sequential,
    c.payment_type,
    c.payment_installments,
    c.payment_value,
    c.hashdiff,
    c.record_source

FROM candidate c

LEFT JOIN latest l
    ON l.order_hk = c.order_hk
   AND l.payment_sequential = c.payment_sequential

WHERE l.order_hk IS NULL
   OR l.hashdiff <> c.hashdiff;