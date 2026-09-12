-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Kimball
-- Criação da tabela fato de pagamentos
--
-- Grão:
--   1 linha por (order_id, payment_sequential)
-- ============================================================================

DROP TABLE IF EXISTS kimball.fact_payment CASCADE;

CREATE TABLE kimball.fact_payment (
    order_id            VARCHAR(32) NOT NULL,
    payment_sequential  INTEGER NOT NULL,

    customer_sk         BIGINT NOT NULL,
    order_status_sk     BIGINT NOT NULL,
    purchase_date_sk    INTEGER NOT NULL,

    payment_type        VARCHAR(30) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value       NUMERIC(18,2) NOT NULL,

    load_timestamp      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_fact_payment
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_fact_payment_customer
        FOREIGN KEY (customer_sk)
        REFERENCES kimball.dim_customer(customer_sk),

    CONSTRAINT fk_fact_payment_order_status
        FOREIGN KEY (order_status_sk)
        REFERENCES kimball.dim_order_status(order_status_sk),

    CONSTRAINT fk_fact_payment_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES kimball.dim_date(date_sk)
);

CREATE INDEX idx_fact_payment_customer_sk
    ON kimball.fact_payment(customer_sk);

CREATE INDEX idx_fact_payment_order_status_sk
    ON kimball.fact_payment(order_status_sk);

CREATE INDEX idx_fact_payment_purchase_date_sk
    ON kimball.fact_payment(purchase_date_sk);

CREATE INDEX idx_fact_payment_order_id
    ON kimball.fact_payment(order_id);