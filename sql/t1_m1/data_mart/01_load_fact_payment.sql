-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Mart
-- Carga da fact_payment a partir do Data Vault 2.0
-- ============================================================================

TRUNCATE TABLE data_mart.fact_payment;


-- ============================================================================
-- Seleciona a versão mais recente de cada pagamento no Satellite.
--
-- Embora no estado T1 exista apenas uma versão por pagamento, o Data Mart
-- utiliza explicitamente a versão mais recente para preservar a lógica de
-- consumo caso novas versões sejam adicionadas posteriormente.
-- ============================================================================

WITH latest_payment AS (
    SELECT DISTINCT ON (
        sop.order_hk,
        sop.payment_sequential
    )
        sop.order_hk,
        sop.payment_sequential,
        sop.payment_type,
        sop.payment_installments,
        sop.payment_value

    FROM data_vault.sat_order_payment sop

    ORDER BY
        sop.order_hk,
        sop.payment_sequential,
        sop.load_timestamp DESC
),

latest_order AS (
    SELECT DISTINCT ON (so.order_hk)
        so.order_hk,
        so.order_status,
        so.order_purchase_timestamp

    FROM data_vault.sat_order so

    ORDER BY
        so.order_hk,
        so.load_timestamp DESC
),

latest_order_customer AS (
    SELECT DISTINCT ON (soc.order_customer_hk)
        soc.order_customer_hk,
        soc.customer_id

    FROM data_vault.sat_order_customer soc

    ORDER BY
        soc.order_customer_hk,
        soc.load_timestamp DESC
),

payment_source AS (
    SELECT
        ho.order_id,
        lp.payment_sequential,

        loc.customer_id,
        lo.order_status,
        lo.order_purchase_timestamp,

        lp.payment_type,
        lp.payment_installments,
        lp.payment_value

    FROM latest_payment lp

    INNER JOIN data_vault.hub_order ho
        ON ho.order_hk = lp.order_hk

    INNER JOIN latest_order lo
        ON lo.order_hk = lp.order_hk

    INNER JOIN data_vault.link_order_customer loc_link
        ON loc_link.order_hk = lp.order_hk

    INNER JOIN latest_order_customer loc
        ON loc.order_customer_hk = loc_link.order_customer_hk
)

INSERT INTO data_mart.fact_payment (
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
    ps.order_id,
    ps.payment_sequential,

    COALESCE(dc.customer_sk, 0),
    COALESCE(dos.order_status_sk, 0),
    COALESCE(dd.date_sk, 0),

    ps.payment_type,
    ps.payment_installments,
    ps.payment_value

FROM payment_source ps

LEFT JOIN data_mart.dim_customer dc
    ON dc.customer_id = ps.customer_id

LEFT JOIN data_mart.dim_order_status dos
    ON dos.order_status = ps.order_status

LEFT JOIN data_mart.dim_date dd
    ON dd.full_date = ps.order_purchase_timestamp::DATE;