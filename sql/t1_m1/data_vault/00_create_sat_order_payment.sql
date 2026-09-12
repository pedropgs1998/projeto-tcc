-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Vault 2.0
-- Multi-Active Satellite de pagamentos
--
-- Pai:
--   data_vault.hub_order
--
-- Grão:
--   1 versão por
--   (order_hk, payment_sequential, load_timestamp)
--
-- payment_sequential funciona como discriminador multi-active,
-- permitindo múltiplos pagamentos associados ao mesmo pedido.
-- ============================================================================

DROP TABLE IF EXISTS data_vault.sat_order_payment CASCADE;

CREATE TABLE data_vault.sat_order_payment (
    order_hk             CHAR(64) NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    load_timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    payment_type         VARCHAR(30) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value        NUMERIC(18,2) NOT NULL,

    hashdiff             CHAR(64) NOT NULL,
    record_source        VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_order_payment
        PRIMARY KEY (
            order_hk,
            payment_sequential,
            load_timestamp
        ),

    CONSTRAINT fk_sat_order_payment_hub_order
        FOREIGN KEY (order_hk)
        REFERENCES data_vault.hub_order(order_hk)
);

CREATE INDEX idx_sat_order_payment_parent
    ON data_vault.sat_order_payment (
        order_hk,
        payment_sequential
    );

CREATE INDEX idx_sat_order_payment_load_timestamp
    ON data_vault.sat_order_payment(load_timestamp);