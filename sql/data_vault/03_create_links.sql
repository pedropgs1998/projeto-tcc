/*
 * Criação dos Links
 * Data Vault 2.0 — Estado T0
 *
 * Links:
 * - link_order_customer
 * - link_order_item
 *
 * Os Links representam relacionamentos entre Hubs.
 */


/* ============================================================
 * 1. LINK_ORDER_CUSTOMER
 * ============================================================
 *
 * Relacionamento:
 * Pedido ↔ Cliente
 *
 * Participantes:
 * - hub_order
 * - hub_customer
 *
 * Grão:
 * uma linha por relacionamento:
 *
 * order_id + customer_unique_id
 *
 * No dataset Olist, cada pedido possui um único cliente.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.link_order_customer (

    order_customer_hk CHAR(64) PRIMARY KEY,

    order_hk CHAR(64) NOT NULL,
    customer_hk CHAR(64) NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT fk_link_order_customer_order
        FOREIGN KEY (order_hk)
        REFERENCES data_vault.hub_order (order_hk),

    CONSTRAINT fk_link_order_customer_customer
        FOREIGN KEY (customer_hk)
        REFERENCES data_vault.hub_customer (customer_hk),

    CONSTRAINT uq_link_order_customer_relationship
        UNIQUE (
            order_hk,
            customer_hk
        )
);


/* ============================================================
 * 2. LINK_ORDER_ITEM
 * ============================================================
 *
 * Relacionamento:
 *
 * Pedido ↔ Produto ↔ Vendedor
 *
 * com:
 *
 * order_item_id
 *
 * atuando como Dependent Child.
 *
 * Participantes:
 * - hub_order
 * - hub_product
 * - hub_seller
 *
 * Grão preservado:
 *
 * (order_id, order_item_id)
 *
 * A Hash Key do Link deverá considerar:
 *
 * order_id
 * product_id
 * seller_id
 * order_item_id
 *
 * Isso permite distinguir diferentes itens de um mesmo pedido,
 * inclusive quando produto e vendedor se repetem.
 * ============================================================
 */

CREATE TABLE IF NOT EXISTS data_vault.link_order_item (

    order_item_hk CHAR(64) PRIMARY KEY,

    order_hk CHAR(64) NOT NULL,
    product_hk CHAR(64) NOT NULL,
    seller_hk CHAR(64) NOT NULL,

    order_item_id INTEGER NOT NULL,

    load_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    record_source VARCHAR(100) NOT NULL,

    CONSTRAINT fk_link_order_item_order
        FOREIGN KEY (order_hk)
        REFERENCES data_vault.hub_order (order_hk),

    CONSTRAINT fk_link_order_item_product
        FOREIGN KEY (product_hk)
        REFERENCES data_vault.hub_product (product_hk),

    CONSTRAINT fk_link_order_item_seller
        FOREIGN KEY (seller_hk)
        REFERENCES data_vault.hub_seller (seller_hk),

    CONSTRAINT uq_link_order_item_grain
        UNIQUE (
            order_hk,
            order_item_id
        )
);