/*
 * Carga das dimensões do Data Mart — Estado T0
 *
 * Regra principal:
 *
 * TODAS as dimensões devem ser reconstruídas a partir
 * do schema data_vault.
 *
 * A camada raw não participa diretamente desta carga.
 *
 * Dimensões:
 * - dim_date
 * - dim_customer
 * - dim_order_status
 * - dim_product
 * - dim_seller
 */


/* ============================================================
 * 1. MEMBROS DESCONHECIDOS
 * ============================================================
 *
 * Mantemos a mesma convenção utilizada no modelo Kimball:
 *
 * surrogate key = 0
 *
 * para referências dimensionais desconhecidas.
 * ============================================================
 */


/* DIM_DATE */

INSERT INTO data_mart.dim_date (
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


/* DIM_CUSTOMER */

INSERT INTO data_mart.dim_customer (
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


/* DIM_ORDER_STATUS */

INSERT INTO data_mart.dim_order_status (
    order_status_sk,
    order_status
)
VALUES (
    0,
    'UNKNOWN'
)
ON CONFLICT (order_status_sk) DO NOTHING;


/* DIM_PRODUCT */

INSERT INTO data_mart.dim_product (
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


/* DIM_SELLER */

INSERT INTO data_mart.dim_seller (
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
 * 2. DIM_DATE
 * ============================================================
 *
 * A dimensão de data é reconstruída a partir dos timestamps
 * preservados em sat_order.
 *
 * T0 utiliza:
 *
 * - order_purchase_timestamp
 * - order_delivered_customer_date
 * - order_estimated_delivery_date
 *
 * Não utilizamos ainda:
 *
 * - order_approved_at
 * - order_delivered_carrier_date
 *
 * pois pertencem à mudança M2.
 * ============================================================
 */

WITH date_limits AS (

    SELECT
        MIN(dt) AS min_date,
        MAX(dt) AS max_date

    FROM (

        SELECT
            order_purchase_timestamp::DATE AS dt
        FROM data_vault.sat_order

        UNION ALL

        SELECT
            order_delivered_customer_date::DATE
        FROM data_vault.sat_order
        WHERE order_delivered_customer_date IS NOT NULL

        UNION ALL

        SELECT
            order_estimated_delivery_date::DATE
        FROM data_vault.sat_order
        WHERE order_estimated_delivery_date IS NOT NULL

    ) dates

),

generated_dates AS (

    SELECT
        generate_series(
            min_date,
            max_date,
            INTERVAL '1 day'
        )::DATE AS full_date

    FROM date_limits
)

INSERT INTO data_mart.dim_date (
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
    TO_CHAR(
        gd.full_date,
        'YYYYMMDD'
    )::INTEGER AS date_sk,

    gd.full_date,

    EXTRACT(
        DAY FROM gd.full_date
    )::SMALLINT AS day,

    EXTRACT(
        ISODOW FROM gd.full_date
    )::SMALLINT AS day_of_week,

    CASE EXTRACT(
        ISODOW FROM gd.full_date
    )::INTEGER

        WHEN 1 THEN 'SEGUNDA-FEIRA'
        WHEN 2 THEN 'TERCA-FEIRA'
        WHEN 3 THEN 'QUARTA-FEIRA'
        WHEN 4 THEN 'QUINTA-FEIRA'
        WHEN 5 THEN 'SEXTA-FEIRA'
        WHEN 6 THEN 'SABADO'
        WHEN 7 THEN 'DOMINGO'

    END AS day_name,

    EXTRACT(
        MONTH FROM gd.full_date
    )::SMALLINT AS month,

    CASE EXTRACT(
        MONTH FROM gd.full_date
    )::INTEGER

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

    EXTRACT(
        QUARTER FROM gd.full_date
    )::SMALLINT AS quarter,

    EXTRACT(
        YEAR FROM gd.full_date
    )::SMALLINT AS year

FROM generated_dates gd

ON CONFLICT (date_sk) DO NOTHING;


/* ============================================================
 * 3. DIM_CUSTOMER
 * ============================================================
 *
 * Objetivo:
 *
 * reconstruir uma dimensão com grão customer_id,
 * mesmo que o Hub possua grão customer_unique_id.
 *
 * Caminho:
 *
 * hub_customer
 *     ↓
 * link_order_customer
 *     ↓
 * sat_order_customer
 *
 * O mesmo customer_id pode aparecer associado a vários pedidos,
 * portanto usamos DISTINCT para obter uma linha por customer_id.
 * ============================================================
 */

INSERT INTO data_mart.dim_customer (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)

SELECT DISTINCT
    soc.customer_id,

    hc.customer_unique_id,

    soc.customer_zip_code_prefix,

    soc.customer_city,

    soc.customer_state

FROM data_vault.link_order_customer loc

JOIN data_vault.hub_customer hc
    ON hc.customer_hk = loc.customer_hk

JOIN data_vault.sat_order_customer soc
    ON soc.order_customer_hk = loc.order_customer_hk

WHERE soc.customer_id IS NOT NULL

ON CONFLICT (customer_id) DO NOTHING;


/* ============================================================
 * 4. DIM_ORDER_STATUS
 * ============================================================
 *
 * Origem:
 * sat_order.order_status
 *
 * Uma linha por valor distinto.
 * ============================================================
 */

INSERT INTO data_mart.dim_order_status (
    order_status
)

SELECT DISTINCT
    so.order_status

FROM data_vault.sat_order so

WHERE so.order_status IS NOT NULL

ON CONFLICT (order_status) DO NOTHING;


/* ============================================================
 * 5. DIM_PRODUCT
 * ============================================================
 *
 * Caminho:
 *
 * hub_product
 *     ↓
 * sat_product
 *
 * No T0 existe apenas uma versão por produto.
 *
 * Nenhuma regra histórica específica de M3 é aplicada.
 * ============================================================
 */

INSERT INTO data_mart.dim_product (
    product_id,
    product_category_name
)

SELECT
    hp.product_id,

    sp.product_category_name

FROM data_vault.hub_product hp

JOIN data_vault.sat_product sp
    ON sp.product_hk = hp.product_hk

ON CONFLICT (product_id) DO NOTHING;


/* ============================================================
 * 6. DIM_SELLER
 * ============================================================
 *
 * Caminho:
 *
 * hub_seller
 *     ↓
 * sat_seller
 * ============================================================
 */

INSERT INTO data_mart.dim_seller (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)

SELECT
    hs.seller_id,

    ss.seller_zip_code_prefix,

    ss.seller_city,

    ss.seller_state

FROM data_vault.hub_seller hs

JOIN data_vault.sat_seller ss
    ON ss.seller_hk = hs.seller_hk

ON CONFLICT (seller_id) DO NOTHING;


/* ============================================================
 * 7. CONTAGEM DAS DIMENSÕES
 * ============================================================
 */

SELECT
    'dim_date' AS tabela,
    COUNT(*) AS quantidade
FROM data_mart.dim_date

UNION ALL

SELECT
    'dim_customer',
    COUNT(*)
FROM data_mart.dim_customer

UNION ALL

SELECT
    'dim_order_status',
    COUNT(*)
FROM data_mart.dim_order_status

UNION ALL

SELECT
    'dim_product',
    COUNT(*)
FROM data_mart.dim_product

UNION ALL

SELECT
    'dim_seller',
    COUNT(*)
FROM data_mart.dim_seller;


/* ============================================================
 * 8. VALIDAÇÃO DO GRÃO DE DIM_CUSTOMER
 * ============================================================
 */

SELECT
    COUNT(*) AS total_linhas,

    COUNT(
        DISTINCT customer_id
    ) AS customer_ids_distintos,

    COUNT(*) - COUNT(
        DISTINCT customer_id
    ) AS duplicidades

FROM data_mart.dim_customer

WHERE customer_sk <> 0;


/* ============================================================
 * 9. VALIDAÇÃO DE CUSTOMER_UNIQUE_ID
 * ============================================================
 *
 * Mesmo com grão customer_id, devemos preservar as 96.096
 * identidades lógicas distintas.
 * ============================================================
 */

SELECT
    COUNT(
        DISTINCT customer_unique_id
    ) AS customer_unique_ids_distintos

FROM data_mart.dim_customer

WHERE customer_sk <> 0;


/* ============================================================
 * 10. VALIDAÇÃO DE CATEGORIAS NULL
 * ============================================================
 *
 * Esperado:
 * 610 produtos reais com categoria NULL.
 *
 * O membro UNKNOWN não participa da contagem.
 * ============================================================
 */

SELECT
    COUNT(*) AS produtos_categoria_null

FROM data_mart.dim_product

WHERE product_sk <> 0
  AND product_category_name IS NULL;


/* ============================================================
 * 11. MEMBROS DESCONHECIDOS
 * ============================================================
 */

SELECT
    'dim_date' AS tabela,
    COUNT(*) AS quantidade
FROM data_mart.dim_date
WHERE date_sk = 0

UNION ALL

SELECT
    'dim_customer',
    COUNT(*)
FROM data_mart.dim_customer
WHERE customer_sk = 0

UNION ALL

SELECT
    'dim_order_status',
    COUNT(*)
FROM data_mart.dim_order_status
WHERE order_status_sk = 0

UNION ALL

SELECT
    'dim_product',
    COUNT(*)
FROM data_mart.dim_product
WHERE product_sk = 0

UNION ALL

SELECT
    'dim_seller',
    COUNT(*)
FROM data_mart.dim_seller
WHERE seller_sk = 0;