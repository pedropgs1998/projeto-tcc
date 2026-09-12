CREATE TABLE kimball.fact_order (
    order_id                       VARCHAR(32) PRIMARY KEY,

    customer_sk                    BIGINT NOT NULL,
    order_status_sk                BIGINT NOT NULL,

    purchase_date_sk               INTEGER NOT NULL,
    delivered_date_sk              INTEGER NOT NULL,
    estimated_delivery_date_sk     INTEGER NOT NULL,

    order_purchase_timestamp       TIMESTAMP NOT NULL,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP,

    valor_calculado_pedido         NUMERIC(18, 2),
    tempo_entrega_dias             NUMERIC(12, 6),
    indicador_atraso               BOOLEAN,

    load_timestamp                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_fact_order_customer
        FOREIGN KEY (customer_sk)
        REFERENCES kimball.dim_customer (customer_sk),

    CONSTRAINT fk_fact_order_status
        FOREIGN KEY (order_status_sk)
        REFERENCES kimball.dim_order_status (order_status_sk),

    CONSTRAINT fk_fact_order_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES kimball.dim_date (date_sk),

    CONSTRAINT fk_fact_order_delivered_date
        FOREIGN KEY (delivered_date_sk)
        REFERENCES kimball.dim_date (date_sk),

    CONSTRAINT fk_fact_order_estimated_delivery_date
        FOREIGN KEY (estimated_delivery_date_sk)
        REFERENCES kimball.dim_date (date_sk)
);


CREATE TABLE kimball.fact_order_item (
    order_id            VARCHAR(32) NOT NULL,
    order_item_id       INTEGER NOT NULL,

    customer_sk         BIGINT NOT NULL,
    order_status_sk     BIGINT NOT NULL,
    purchase_date_sk    INTEGER NOT NULL,
    product_sk          BIGINT NOT NULL,
    seller_sk           BIGINT NOT NULL,

    price               NUMERIC(18, 2) NOT NULL,
    freight_value       NUMERIC(18, 2) NOT NULL,

    load_timestamp      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_fact_order_item
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_fact_order_item_customer
        FOREIGN KEY (customer_sk)
        REFERENCES kimball.dim_customer (customer_sk),

    CONSTRAINT fk_fact_order_item_status
        FOREIGN KEY (order_status_sk)
        REFERENCES kimball.dim_order_status (order_status_sk),

    CONSTRAINT fk_fact_order_item_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES kimball.dim_date (date_sk),

    CONSTRAINT fk_fact_order_item_product
        FOREIGN KEY (product_sk)
        REFERENCES kimball.dim_product (product_sk),

    CONSTRAINT fk_fact_order_item_seller
        FOREIGN KEY (seller_sk)
        REFERENCES kimball.dim_seller (seller_sk)
);