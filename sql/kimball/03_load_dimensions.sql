/*
 * Carga das dimensões do modelo Kimball — T0
 *
 * Ordem:
 * 1. registros técnicos desconhecidos;
 * 2. dimensão de data;
 * 3. dimensão de cliente;
 * 4. dimensão de status;
 * 5. dimensão de produto;
 * 6. dimensão de vendedor.
 */


/* ============================================================
 * 1. REGISTROS DESCONHECIDOS
 * ============================================================
 *
 * A surrogate key 0 é reservada para relacionamentos
 * desconhecidos ou não resolvidos.
 */


/* ---------- dim_date ---------- */

INSERT INTO kimball.dim_date (
    date_sk,
    full_date,
    day,
    day_of_week,
    day_name,
    month,
    month_name,
    quarter,
    year
)
VALUES (
    0,
    NULL,
    0,
    0,
    'DESCONHECIDO',
    0,
    'DESCONHECIDO',
    0,
    0
)
ON CONFLICT (date_sk) DO NOTHING;


/* ---------- dim_customer ---------- */

INSERT INTO kimball.dim_customer (
    customer_sk,
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
VALUES (
    0,
    'UNKNOWN',
    'UNKNOWN',
    NULL,
    NULL,
    NULL
)
ON CONFLICT (customer_sk) DO NOTHING;


/* ---------- dim_order_status ---------- */

INSERT INTO kimball.dim_order_status (
    order_status_sk,
    order_status
)
VALUES (
    0,
    'UNKNOWN'
)
ON CONFLICT (order_status_sk) DO NOTHING;


/* ---------- dim_product ---------- */

INSERT INTO kimball.dim_product (
    product_sk,
    product_id,
    product_category_name
)
VALUES (
    0,
    'UNKNOWN',
    'DESCONHECIDO'
)
ON CONFLICT (product_sk) DO NOTHING;


/* ---------- dim_seller ---------- */

INSERT INTO kimball.dim_seller (
    seller_sk,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
VALUES (
    0,
    'UNKNOWN',
    NULL,
    NULL,
    NULL
)
ON CONFLICT (seller_sk) DO NOTHING;


/* ============================================================
 * 2. DIMENSÃO DE DATA
 * ============================================================
 *
 * A dimensão será gerada utilizando todo o intervalo necessário
 * para as datas disponíveis no baseline T0:
 *
 * - order_purchase_timestamp;
 * - order_delivered_customer_date;
 * - order_estimated_delivery_date.
 *
 * Não são utilizados ainda:
 *
 * - order_approved_at;
 * - order_delivered_carrier_date.
 *
 * Esses atributos pertencem à M2.
 */


WITH source_dates AS (

    SELECT
        order_purchase_timestamp::DATE AS full_date
    FROM raw.orders
    WHERE order_purchase_timestamp IS NOT NULL

    UNION ALL

    SELECT
        order_delivered_customer_date::DATE
    FROM raw.orders
    WHERE order_delivered_customer_date IS NOT NULL

    UNION ALL

    SELECT
        order_estimated_delivery_date::DATE
    FROM raw.orders
    WHERE order_estimated_delivery_date IS NOT NULL

),

date_bounds AS (

    SELECT
        MIN(full_date) AS min_date,
        MAX(full_date) AS max_date
    FROM source_dates

),

calendar AS (

    SELECT
        generated_date::DATE AS full_date
    FROM date_bounds
    CROSS JOIN LATERAL generate_series(
        min_date,
        max_date,
        INTERVAL '1 day'
    ) AS generated_date

)

INSERT INTO kimball.dim_date (
    date_sk,
    full_date,
    day,
    day_of_week,
    day_name,
    month,
    month_name,
    quarter,
    year
)
SELECT
    TO_CHAR(full_date, 'YYYYMMDD')::INTEGER AS date_sk,

    full_date,

    EXTRACT(DAY FROM full_date)::SMALLINT AS day,

    EXTRACT(ISODOW FROM full_date)::SMALLINT AS day_of_week,

    CASE EXTRACT(ISODOW FROM full_date)::INTEGER
        WHEN 1 THEN 'SEGUNDA-FEIRA'
        WHEN 2 THEN 'TERCA-FEIRA'
        WHEN 3 THEN 'QUARTA-FEIRA'
        WHEN 4 THEN 'QUINTA-FEIRA'
        WHEN 5 THEN 'SEXTA-FEIRA'
        WHEN 6 THEN 'SABADO'
        WHEN 7 THEN 'DOMINGO'
    END AS day_name,

    EXTRACT(MONTH FROM full_date)::SMALLINT AS month,

    CASE EXTRACT(MONTH FROM full_date)::INTEGER
        WHEN 1  THEN 'JANEIRO'
        WHEN 2  THEN 'FEVEREIRO'
        WHEN 3  THEN 'MARCO'
        WHEN 4  THEN 'ABRIL'
        WHEN 5  THEN 'MAIO'
        WHEN 6  THEN 'JUNHO'
        WHEN 7  THEN 'JULHO'
        WHEN 8  THEN 'AGOSTO'
        WHEN 9  THEN 'SETEMBRO'
        WHEN 10 THEN 'OUTUBRO'
        WHEN 11 THEN 'NOVEMBRO'
        WHEN 12 THEN 'DEZEMBRO'
    END AS month_name,

    EXTRACT(QUARTER FROM full_date)::SMALLINT AS quarter,

    EXTRACT(YEAR FROM full_date)::SMALLINT AS year

FROM calendar

ON CONFLICT (date_sk) DO NOTHING;


/* ============================================================
 * 3. DIMENSÃO DE CLIENTE
 * ============================================================
 *
 * Grão:
 * uma linha por customer_id.
 *
 * customer_unique_id permanece como atributo para permitir
 * identificar o mesmo cliente entre diferentes ocorrências.
 */


INSERT INTO kimball.dim_customer (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state

FROM raw.customers

ON CONFLICT (customer_id) DO NOTHING;


/* ============================================================
 * 4. DIMENSÃO DE STATUS DO PEDIDO
 * ============================================================
 *
 * Grão:
 * uma linha por valor distinto de order_status.
 */


INSERT INTO kimball.dim_order_status (
    order_status
)
SELECT DISTINCT
    order_status

FROM raw.orders

WHERE order_status IS NOT NULL

ON CONFLICT (order_status) DO NOTHING;


/* ============================================================
 * 5. DIMENSÃO DE PRODUTO
 * ============================================================
 *
 * Grão:
 * uma linha por product_id.
 *
 * Em T0 não existe versionamento histórico.
 * A M3 será responsável por introduzir esse requisito.
 */


INSERT INTO kimball.dim_product (
    product_id,
    product_category_name
)
SELECT
    product_id,
    product_category_name

FROM raw.products

ON CONFLICT (product_id) DO NOTHING;


/* ============================================================
 * 6. DIMENSÃO DE VENDEDOR
 * ============================================================
 *
 * Grão:
 * uma linha por seller_id.
 */


INSERT INTO kimball.dim_seller (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state

FROM raw.sellers

ON CONFLICT (seller_id) DO NOTHING;