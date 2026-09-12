/*
 * Criação dos Satellites
 * Data Vault 2.0 — Estado T0
 *
 * Satellites:
 * - sat_order
 * - sat_order_customer
 * - sat_product
 * - sat_seller
 * - sat_order_item
 *
 * Os Satellites armazenam atributos descritivos associados
 * aos Hubs ou Links.
 *
 * A chave primária utiliza:
 *
 * parent_hash_key + load_timestamp
 *
 * permitindo múltiplas versões do mesmo objeto ao longo
 * das cargas.
 *
 * hashdiff é utilizado para detectar alterações no payload.
 */


/* ============================================================
 * 1. SAT_ORDER
 * ============================================================
 *
 * Parent:
 * hub_order
 *
 * Payload T0:
 * - order_status
 * - order_purchase_timestamp
 * - order_delivered_customer_date
 * - order_estimated_delivery_date
 *
 * Deliberadamente ausentes no T0:
 * - order_approved_at
 * - order_delivered_carrier_date
 *
 * Esses atributos pertencem à mudança M2.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.sat_order (

    order_hk CHAR(64) NOT NULL,

    order_status VARCHAR(30),

    order_purchase_timestamp TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,

    hashdiff CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_order
        PRIMARY KEY (
            order_hk,
            load_timestamp
        ),

    CONSTRAINT fk_sat_order_hub_order
        FOREIGN KEY (order_hk)
        REFERENCES data_vault.hub_order (order_hk)
);


/* ============================================================
 * 2. SAT_ORDER_CUSTOMER
 * ============================================================
 *
 * Parent:
 * link_order_customer
 *
 * Objetivo:
 * preservar a ocorrência customer_id utilizada naquele pedido,
 * incluindo seu contexto de localização.
 *
 * Payload:
 * - customer_id
 * - customer_zip_code_prefix
 * - customer_city
 * - customer_state
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.sat_order_customer (

    order_customer_hk CHAR(64) NOT NULL,

    customer_id VARCHAR(32) NOT NULL,

    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),

    hashdiff CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_order_customer
        PRIMARY KEY (
            order_customer_hk,
            load_timestamp
        ),

    CONSTRAINT fk_sat_order_customer_link
        FOREIGN KEY (order_customer_hk)
        REFERENCES data_vault.link_order_customer (
            order_customer_hk
        )
);


/* ============================================================
 * 3. SAT_PRODUCT
 * ============================================================
 *
 * Parent:
 * hub_product
 *
 * Payload T0:
 * - product_category_name
 *
 * Neste estado não existe ainda regra específica de
 * temporalidade efetiva da categoria.
 *
 * M3 será responsável pela introdução do requisito histórico.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.sat_product (

    product_hk CHAR(64) NOT NULL,

    product_category_name VARCHAR(100),

    hashdiff CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_product
        PRIMARY KEY (
            product_hk,
            load_timestamp
        ),

    CONSTRAINT fk_sat_product_hub_product
        FOREIGN KEY (product_hk)
        REFERENCES data_vault.hub_product (product_hk)
);


/* ============================================================
 * 4. SAT_SELLER
 * ============================================================
 *
 * Parent:
 * hub_seller
 *
 * Payload:
 * - seller_zip_code_prefix
 * - seller_city
 * - seller_state
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.sat_seller (

    seller_hk CHAR(64) NOT NULL,

    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),

    hashdiff CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_seller
        PRIMARY KEY (
            seller_hk,
            load_timestamp
        ),

    CONSTRAINT fk_sat_seller_hub_seller
        FOREIGN KEY (seller_hk)
        REFERENCES data_vault.hub_seller (seller_hk)
);


/* ============================================================
 * 5. SAT_ORDER_ITEM
 * ============================================================
 *
 * Parent:
 * link_order_item
 *
 * Payload:
 * - price
 * - freight_value
 *
 * Os valores descrevem a ocorrência específica do item,
 * representada pelo Link.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.sat_order_item (

    order_item_hk CHAR(64) NOT NULL,

    price NUMERIC(18,2) NOT NULL,
    freight_value NUMERIC(18,2) NOT NULL,

    hashdiff CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT pk_sat_order_item
        PRIMARY KEY (
            order_item_hk,
            load_timestamp
        ),

    CONSTRAINT fk_sat_order_item_link
        FOREIGN KEY (order_item_hk)
        REFERENCES data_vault.link_order_item (
            order_item_hk
        )
);