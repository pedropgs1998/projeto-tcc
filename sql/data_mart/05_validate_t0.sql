/*
 * Validação formal do Data Mart — Estado T0
 *
 * Objetivos:
 * - validar os grãos das dimensões e fatos;
 * - validar integridade dimensional;
 * - reconciliar Data Mart com o Raw Vault;
 * - comparar Data Mart com o modelo Kimball T0;
 * - garantir equivalência funcional antes da execução
 *   das consultas analíticas Q1, Q2 e Q3.
 */


/* ============================================================
 * 1. CONTAGEM DAS DIMENSÕES
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
 * 2. COMPARAÇÃO DAS DIMENSÕES COM KIMBALL
 * ============================================================
 */

SELECT
    'dim_date' AS tabela,

    (SELECT COUNT(*)
     FROM kimball.dim_date)
        AS kimball,

    (SELECT COUNT(*)
     FROM data_mart.dim_date)
        AS data_mart,

    (SELECT COUNT(*)
     FROM data_mart.dim_date)
    -
    (SELECT COUNT(*)
     FROM kimball.dim_date)
        AS diferenca

UNION ALL

SELECT
    'dim_customer',

    (SELECT COUNT(*)
     FROM kimball.dim_customer),

    (SELECT COUNT(*)
     FROM data_mart.dim_customer),

    (SELECT COUNT(*)
     FROM data_mart.dim_customer)
    -
    (SELECT COUNT(*)
     FROM kimball.dim_customer)

UNION ALL

SELECT
    'dim_order_status',

    (SELECT COUNT(*)
     FROM kimball.dim_order_status),

    (SELECT COUNT(*)
     FROM data_mart.dim_order_status),

    (SELECT COUNT(*)
     FROM data_mart.dim_order_status)
    -
    (SELECT COUNT(*)
     FROM kimball.dim_order_status)

UNION ALL

SELECT
    'dim_product',

    (SELECT COUNT(*)
     FROM kimball.dim_product),

    (SELECT COUNT(*)
     FROM data_mart.dim_product),

    (SELECT COUNT(*)
     FROM data_mart.dim_product)
    -
    (SELECT COUNT(*)
     FROM kimball.dim_product)

UNION ALL

SELECT
    'dim_seller',

    (SELECT COUNT(*)
     FROM kimball.dim_seller),

    (SELECT COUNT(*)
     FROM data_mart.dim_seller),

    (SELECT COUNT(*)
     FROM data_mart.dim_seller)
    -
    (SELECT COUNT(*)
     FROM kimball.dim_seller);


/* ============================================================
 * 3. CONTEÚDO DE DIM_CUSTOMER
 * ============================================================
 *
 * A comparação utiliza Business Keys e atributos,
 * não customer_sk, pois as surrogate keys podem assumir
 * valores diferentes entre as arquiteturas.
 * ============================================================
 */

SELECT
    COUNT(*) AS customers_diferentes

FROM (

    (
        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state

        FROM kimball.dim_customer

        WHERE customer_sk <> 0

        EXCEPT

        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state

        FROM data_mart.dim_customer

        WHERE customer_sk <> 0
    )

    UNION ALL

    (
        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state

        FROM data_mart.dim_customer

        WHERE customer_sk <> 0

        EXCEPT

        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state

        FROM kimball.dim_customer

        WHERE customer_sk <> 0
    )

) x;


/* ============================================================
 * 4. CONTEÚDO DE DIM_ORDER_STATUS
 * ============================================================
 */

SELECT
    COUNT(*) AS statuses_diferentes

FROM (

    (
        SELECT
            order_status

        FROM kimball.dim_order_status

        WHERE order_status_sk <> 0

        EXCEPT

        SELECT
            order_status

        FROM data_mart.dim_order_status

        WHERE order_status_sk <> 0
    )

    UNION ALL

    (
        SELECT
            order_status

        FROM data_mart.dim_order_status

        WHERE order_status_sk <> 0

        EXCEPT

        SELECT
            order_status

        FROM kimball.dim_order_status

        WHERE order_status_sk <> 0
    )

) x;


/* ============================================================
 * 5. CONTEÚDO DE DIM_PRODUCT
 * ============================================================
 */

SELECT
    COUNT(*) AS products_diferentes

FROM (

    (
        SELECT
            product_id,
            product_category_name

        FROM kimball.dim_product

        WHERE product_sk <> 0

        EXCEPT

        SELECT
            product_id,
            product_category_name

        FROM data_mart.dim_product

        WHERE product_sk <> 0
    )

    UNION ALL

    (
        SELECT
            product_id,
            product_category_name

        FROM data_mart.dim_product

        WHERE product_sk <> 0

        EXCEPT

        SELECT
            product_id,
            product_category_name

        FROM kimball.dim_product

        WHERE product_sk <> 0
    )

) x;


/* ============================================================
 * 6. CONTEÚDO DE DIM_SELLER
 * ============================================================
 */

SELECT
    COUNT(*) AS sellers_diferentes

FROM (

    (
        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state

        FROM kimball.dim_seller

        WHERE seller_sk <> 0

        EXCEPT

        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state

        FROM data_mart.dim_seller

        WHERE seller_sk <> 0
    )

    UNION ALL

    (
        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state

        FROM data_mart.dim_seller

        WHERE seller_sk <> 0

        EXCEPT

        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state

        FROM kimball.dim_seller

        WHERE seller_sk <> 0
    )

) x;


/* ============================================================
 * 7. CONTEÚDO DE DIM_DATE
 * ============================================================
 */

SELECT
    COUNT(*) AS dates_diferentes

FROM (

    (
        SELECT
            date_sk,
            full_date,
            day,
            day_of_week,
            day_name,
            month,
            month_name,
            quarter,
            year

        FROM kimball.dim_date

        EXCEPT

        SELECT
            date_sk,
            full_date,
            day,
            day_of_week,
            day_name,
            month,
            month_name,
            quarter,
            year

        FROM data_mart.dim_date
    )

    UNION ALL

    (
        SELECT
            date_sk,
            full_date,
            day,
            day_of_week,
            day_name,
            month,
            month_name,
            quarter,
            year

        FROM data_mart.dim_date

        EXCEPT

        SELECT
            date_sk,
            full_date,
            day,
            day_of_week,
            day_name,
            month,
            month_name,
            quarter,
            year

        FROM kimball.dim_date
    )

) x;


/* ============================================================
 * 8. CONTAGEM E GRÃO DAS FATOS
 * ============================================================
 */

SELECT
    'fact_order' AS tabela,
    COUNT(*) AS quantidade
FROM data_mart.fact_order

UNION ALL

SELECT
    'fact_order_item',
    COUNT(*)
FROM data_mart.fact_order_item;


/* fact_order */

SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS orders_distintos,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicidades

FROM data_mart.fact_order;


/* fact_order_item */

SELECT
    COUNT(*) AS total_linhas,

    COUNT(
        DISTINCT (
            order_id,
            order_item_id
        )
    ) AS graos_distintos,

    COUNT(*) - COUNT(
        DISTINCT (
            order_id,
            order_item_id
        )
    ) AS duplicidades

FROM data_mart.fact_order_item;


/* ============================================================
 * 9. COMPARAÇÃO DAS CONTAGENS DAS FATOS COM KIMBALL
 * ============================================================
 */

SELECT
    'fact_order' AS tabela,

    (SELECT COUNT(*)
     FROM kimball.fact_order)
        AS kimball,

    (SELECT COUNT(*)
     FROM data_mart.fact_order)
        AS data_mart,

    (SELECT COUNT(*)
     FROM data_mart.fact_order)
    -
    (SELECT COUNT(*)
     FROM kimball.fact_order)
        AS diferenca

UNION ALL

SELECT
    'fact_order_item',

    (SELECT COUNT(*)
     FROM kimball.fact_order_item),

    (SELECT COUNT(*)
     FROM data_mart.fact_order_item),

    (SELECT COUNT(*)
     FROM data_mart.fact_order_item)
    -
    (SELECT COUNT(*)
     FROM kimball.fact_order_item);


/* ============================================================
 * 10. INTEGRIDADE DIMENSIONAL
 * ============================================================
 */


/* FACT_ORDER */

SELECT
    COUNT(*) FILTER (
        WHERE customer_sk = 0
    ) AS customer_desconhecido,

    COUNT(*) FILTER (
        WHERE order_status_sk = 0
    ) AS status_desconhecido,

    COUNT(*) FILTER (
        WHERE purchase_date_sk = 0
    ) AS purchase_date_desconhecida,

    COUNT(*) FILTER (
        WHERE delivered_date_sk = 0
    ) AS delivered_date_desconhecida,

    COUNT(*) FILTER (
        WHERE estimated_delivery_date_sk = 0
    ) AS estimated_date_desconhecida

FROM data_mart.fact_order;


/* FACT_ORDER_ITEM */

SELECT
    COUNT(*) FILTER (
        WHERE customer_sk = 0
    ) AS customer_desconhecido,

    COUNT(*) FILTER (
        WHERE order_status_sk = 0
    ) AS status_desconhecido,

    COUNT(*) FILTER (
        WHERE purchase_date_sk = 0
    ) AS purchase_date_desconhecida,

    COUNT(*) FILTER (
        WHERE product_sk = 0
    ) AS product_desconhecido,

    COUNT(*) FILTER (
        WHERE seller_sk = 0
    ) AS seller_desconhecido

FROM data_mart.fact_order_item;


/* ============================================================
 * 11. COMPARAÇÃO FACT_ORDER COM KIMBALL
 * ============================================================
 *
 * Não comparamos surrogate keys diretamente.
 *
 * Elas são resolvidas para suas Business Keys antes
 * da comparação.
 * ============================================================
 */

WITH kimball_orders AS (

    SELECT
        fo.order_id,

        dc.customer_id,

        dos.order_status,

        fo.purchase_date_sk,
        fo.delivered_date_sk,
        fo.estimated_delivery_date_sk,

        fo.order_purchase_timestamp,
        fo.order_delivered_customer_date,
        fo.order_estimated_delivery_date,

        fo.valor_calculado_pedido,
        fo.tempo_entrega_dias,
        fo.indicador_atraso

    FROM kimball.fact_order fo

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk
),

mart_orders AS (

    SELECT
        fo.order_id,

        dc.customer_id,

        dos.order_status,

        fo.purchase_date_sk,
        fo.delivered_date_sk,
        fo.estimated_delivery_date_sk,

        fo.order_purchase_timestamp,
        fo.order_delivered_customer_date,
        fo.order_estimated_delivery_date,

        fo.valor_calculado_pedido,
        fo.tempo_entrega_dias,
        fo.indicador_atraso

    FROM data_mart.fact_order fo

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = fo.customer_sk

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk
)

SELECT
    COUNT(*) AS orders_diferentes

FROM (

    (
        SELECT *
        FROM kimball_orders

        EXCEPT

        SELECT *
        FROM mart_orders
    )

    UNION ALL

    (
        SELECT *
        FROM mart_orders

        EXCEPT

        SELECT *
        FROM kimball_orders
    )

) x;


/* ============================================================
 * 12. COMPARAÇÃO FACT_ORDER_ITEM COM KIMBALL
 * ============================================================
 */

WITH kimball_items AS (

    SELECT
        foi.order_id,
        foi.order_item_id,

        dc.customer_id,
        dos.order_status,

        foi.purchase_date_sk,

        dp.product_id,
        ds.seller_id,

        foi.price,
        foi.freight_value

    FROM kimball.fact_order_item foi

    JOIN kimball.dim_customer dc
        ON dc.customer_sk = foi.customer_sk

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    JOIN kimball.dim_product dp
        ON dp.product_sk = foi.product_sk

    JOIN kimball.dim_seller ds
        ON ds.seller_sk = foi.seller_sk
),

mart_items AS (

    SELECT
        foi.order_id,
        foi.order_item_id,

        dc.customer_id,
        dos.order_status,

        foi.purchase_date_sk,

        dp.product_id,
        ds.seller_id,

        foi.price,
        foi.freight_value

    FROM data_mart.fact_order_item foi

    JOIN data_mart.dim_customer dc
        ON dc.customer_sk = foi.customer_sk

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

    JOIN data_mart.dim_product dp
        ON dp.product_sk = foi.product_sk

    JOIN data_mart.dim_seller ds
        ON ds.seller_sk = foi.seller_sk
)

SELECT
    COUNT(*) AS itens_diferentes

FROM (

    (
        SELECT *
        FROM kimball_items

        EXCEPT

        SELECT *
        FROM mart_items
    )

    UNION ALL

    (
        SELECT *
        FROM mart_items

        EXCEPT

        SELECT *
        FROM kimball_items
    )

) x;


/* ============================================================
 * 13. PEDIDOS SEM ITENS
 * ============================================================
 */

SELECT
    (SELECT COUNT(*)
     FROM kimball.fact_order
     WHERE valor_calculado_pedido IS NULL)
        AS kimball_pedidos_sem_itens,

    (SELECT COUNT(*)
     FROM data_mart.fact_order
     WHERE valor_calculado_pedido IS NULL)
        AS mart_pedidos_sem_itens;


/* ============================================================
 * 14. RECONCILIAÇÃO FINANCEIRA GERAL
 * ============================================================
 */

SELECT
    (SELECT SUM(price)
     FROM kimball.fact_order_item)
        AS kimball_price,

    (SELECT SUM(price)
     FROM data_mart.fact_order_item)
        AS mart_price,

    ABS(
        (SELECT SUM(price)
         FROM kimball.fact_order_item)
        -
        (SELECT SUM(price)
         FROM data_mart.fact_order_item)
    ) AS diferenca;


SELECT
    (SELECT SUM(freight_value)
     FROM kimball.fact_order_item)
        AS kimball_freight,

    (SELECT SUM(freight_value)
     FROM data_mart.fact_order_item)
        AS mart_freight,

    ABS(
        (SELECT SUM(freight_value)
         FROM kimball.fact_order_item)
        -
        (SELECT SUM(freight_value)
         FROM data_mart.fact_order_item)
    ) AS diferenca;


/* ============================================================
 * 15. VALOR_CALCULADO_PEDIDO
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_valor_diferente

FROM kimball.fact_order k

JOIN data_mart.fact_order m
    ON m.order_id = k.order_id

WHERE k.valor_calculado_pedido
      IS DISTINCT FROM
      m.valor_calculado_pedido;


/* ============================================================
 * 16. TEMPO DE ENTREGA
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_tempo_diferente

FROM kimball.fact_order k

JOIN data_mart.fact_order m
    ON m.order_id = k.order_id

WHERE k.tempo_entrega_dias
      IS DISTINCT FROM
      m.tempo_entrega_dias;


/* ============================================================
 * 17. INDICADOR DE ATRASO
 * ============================================================
 */

SELECT
    COUNT(*) AS pedidos_atraso_diferente

FROM kimball.fact_order k

JOIN data_mart.fact_order m
    ON m.order_id = k.order_id

WHERE k.indicador_atraso
      IS DISTINCT FROM
      m.indicador_atraso;


/* ============================================================
 * 18. POPULAÇÃO DELIVERED
 * ============================================================
 */

SELECT
    (SELECT COUNT(*)

     FROM kimball.fact_order fo

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_delivered,

    (SELECT COUNT(*)

     FROM data_mart.fact_order fo

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_delivered;


/* ============================================================
 * 19. ITENS DELIVERED
 * ============================================================
 */

SELECT
    (SELECT COUNT(*)

     FROM kimball.fact_order_item foi

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_itens_delivered,

    (SELECT COUNT(*)

     FROM data_mart.fact_order_item foi

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_itens_delivered;


/* ============================================================
 * 20. VALOR BRUTO DELIVERED
 * ============================================================
 */

SELECT
    (SELECT SUM(foi.price)

     FROM kimball.fact_order_item foi

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_valor_bruto,

    (SELECT SUM(foi.price)

     FROM data_mart.fact_order_item foi

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_valor_bruto;


/* ============================================================
 * 21. FRETE DELIVERED
 * ============================================================
 */

SELECT
    (SELECT SUM(foi.freight_value)

     FROM kimball.fact_order_item foi

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_frete,

    (SELECT SUM(foi.freight_value)

     FROM data_mart.fact_order_item foi

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = foi.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_frete;


/* ============================================================
 * 22. VALOR CALCULADO DELIVERED
 * ============================================================
 */

SELECT
    (SELECT SUM(fo.valor_calculado_pedido)

     FROM kimball.fact_order fo

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_valor_calculado,

    (SELECT SUM(fo.valor_calculado_pedido)

     FROM data_mart.fact_order fo

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_valor_calculado;


/* ============================================================
 * 23. TICKET MÉDIO DELIVERED
 * ============================================================
 */

SELECT
    (SELECT AVG(fo.valor_calculado_pedido)

     FROM kimball.fact_order fo

     JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS kimball_ticket_medio,

    (SELECT AVG(fo.valor_calculado_pedido)

     FROM data_mart.fact_order fo

     JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

     WHERE dos.order_status = 'delivered')
        AS mart_ticket_medio;


/* ============================================================
 * 24. DISTRIBUIÇÃO DE STATUS
 * ============================================================
 */

WITH kimball_status AS (

    SELECT
        dos.order_status,
        COUNT(*) AS quantidade

    FROM kimball.fact_order fo

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    GROUP BY dos.order_status
),

mart_status AS (

    SELECT
        dos.order_status,
        COUNT(*) AS quantidade

    FROM data_mart.fact_order fo

    JOIN data_mart.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    GROUP BY dos.order_status
)

SELECT
    k.order_status,

    k.quantidade AS kimball,

    m.quantidade AS data_mart,

    k.quantidade
        - m.quantidade AS diferenca

FROM kimball_status k

JOIN mart_status m
    ON m.order_status = k.order_status

ORDER BY k.order_status;


/* ============================================================
 * 25. RESUMO DE CONTROLE
 * ============================================================
 *
 * Valores esperados:
 *
 * dimensões:
 *
 * dim_date          = 801
 * dim_customer      = 99.442
 * dim_order_status  = 9
 * dim_product       = 32.952
 * dim_seller        = 3.096
 *
 * fatos:
 *
 * fact_order        = 99.441
 * fact_order_item   = 112.650
 *
 * delivered:
 *
 * pedidos           = 96.478
 * itens             = 110.197
 *
 * valor bruto       = 13.221.498,11
 * frete             = 2.198.275,64
 *
 * valor calculado   = 15.419.773,75
 *
 * ticket médio      = 159,8268387611683493
 *
 * Todas as diferenças não explicadas entre Kimball e
 * Data Mart devem ser iguais a zero.
 * ============================================================
 */