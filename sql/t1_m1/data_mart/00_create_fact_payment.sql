-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Mart derivado do Data Vault 2.0
-- Criação da tabela fato de pagamentos
--
-- Grão:
--   1 linha por (order_id, payment_sequential)
-- ============================================================================

DROP TABLE IF EXISTS data_mart.fact_payment CASCADE;

CREATE TABLE data_mart.fact_payment (
    order_id             VARCHAR(32) NOT NULL,
    payment_sequential   INTEGER NOT NULL,

    customer_sk          BIGINT NOT NULL,
    order_status_sk      BIGINT NOT NULL,
    purchase_date_sk     INTEGER NOT NULL,

    payment_type         VARCHAR(30) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value        NUMERIC(18,2) NOT NULL,

    load_timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_dm_fact_payment
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_dm_fact_payment_customer
        FOREIGN KEY (customer_sk)
        REFERENCES data_mart.dim_customer(customer_sk),

    CONSTRAINT fk_dm_fact_payment_order_status
        FOREIGN KEY (order_status_sk)
        REFERENCES data_mart.dim_order_status(order_status_sk),

    CONSTRAINT fk_dm_fact_payment_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES data_mart.dim_date(date_sk)
);

CREATE INDEX idx_dm_fact_payment_customer_sk
    ON data_mart.fact_payment(customer_sk);

CREATE INDEX idx_dm_fact_payment_order_status_sk
    ON data_mart.fact_payment(order_status_sk);

CREATE INDEX idx_dm_fact_payment_purchase_date_sk
    ON data_mart.fact_payment(purchase_date_sk);

CREATE INDEX idx_dm_fact_payment_order_id
    ON data_mart.fact_payment(order_id);