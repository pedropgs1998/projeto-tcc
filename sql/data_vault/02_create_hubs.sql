/*
 * Criação dos Hubs
 * Data Vault 2.0 — Estado T0
 *
 * Hubs:
 * - hub_order
 * - hub_customer
 * - hub_product
 * - hub_seller
 *
 * Cada Hub contém:
 * - Hash Key determinística
 * - Business Key
 * - load_timestamp
 * - record_source
 */


/* ============================================================
 * 1. HUB_ORDER
 * ============================================================
 *
 * Entidade:
 * Pedido
 *
 * Business Key:
 * order_id
 *
 * Grão:
 * uma linha por order_id
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.hub_order (

    order_hk CHAR(64) PRIMARY KEY,

    order_id VARCHAR(32) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT uq_hub_order_order_id
        UNIQUE (order_id)
);


/* ============================================================
 * 2. HUB_CUSTOMER
 * ============================================================
 *
 * Entidade:
 * Cliente lógico
 *
 * Business Key:
 * customer_unique_id
 *
 * Grão:
 * uma linha por customer_unique_id
 *
 * Observação:
 * customer_id não é utilizado como Business Key neste Hub.
 * Ele será preservado posteriormente no contexto do
 * relacionamento Pedido–Cliente.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.hub_customer (

    customer_hk CHAR(64) PRIMARY KEY,

    customer_unique_id VARCHAR(32) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT uq_hub_customer_customer_unique_id
        UNIQUE (customer_unique_id)
);


/* ============================================================
 * 3. HUB_PRODUCT
 * ============================================================
 *
 * Entidade:
 * Produto
 *
 * Business Key:
 * product_id
 *
 * Grão:
 * uma linha por product_id
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.hub_product (

    product_hk CHAR(64) PRIMARY KEY,

    product_id VARCHAR(32) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT uq_hub_product_product_id
        UNIQUE (product_id)
);


/* ============================================================
 * 4. HUB_SELLER
 * ============================================================
 *
 * Entidade:
 * Vendedor
 *
 * Business Key:
 * seller_id
 *
 * Grão:
 * uma linha por seller_id
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.hub_seller (

    seller_hk CHAR(64) PRIMARY KEY,

    seller_id VARCHAR(32) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT uq_hub_seller_seller_id
        UNIQUE (seller_id)
);