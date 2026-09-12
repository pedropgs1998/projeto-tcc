/*
 * Validação do modelo Kimball — Estado T0
 *
 * Objetivos:
 * - validar os grãos das fatos;
 * - validar integridade dimensional;
 * - reconciliar valores com a camada raw;
 * - validar medidas derivadas;
 * - identificar diferenças inesperadas antes das consultas analíticas.
 */


/* ============================================================
 * 1. CONTAGEM DAS TABELAS FATO
 * ============================================================
 */

SELECT
    'fact_order' AS tabela,
    COUNT(*) AS quantidade
FROM kimball.fact_order

UNION ALL

SELECT
    'fact_order_item',
    COUNT(*)
FROM kimball.fact_order_item;


/* ============================================================
 * 2. UNICIDADE DOS GRÃOS
 * ============================================================
 */


/* fact_order:
 * deve existir exatamente uma linha por order_id.
 */

SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS total_order_id,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicidades
FROM kimball.fact_order;


/* fact_order_item:
 * a combinação (order_id, order_item_id) deve ser única.
 */

SELECT
    COUNT(*) AS total_linhas,
    COUNT(*) - COUNT(
        DISTINCT (order_id, order_item_id)
    ) AS duplicidades
FROM kimball.fact_order_item;


/* ============================================================
 * 3. SURROGATE KEYS NÃO RESOLVIDAS
 * ============================================================
 */


/* fact_order */

SELECT
    COUNT(*) FILTER (WHERE customer_sk = 0)
        AS customer_desconhecido,

    COUNT(*) FILTER (WHERE order_status_sk = 0)
        AS status_desconhecido,

    COUNT(*) FILTER (WHERE purchase_date_sk = 0)
        AS purchase_date_desconhecida,

    COUNT(*) FILTER (WHERE delivered_date_sk = 0)
        AS delivered_date_desconhecida,

    COUNT(*) FILTER (WHERE estimated_delivery_date_sk = 0)
        AS estimated_date_desconhecida

FROM kimball.fact_order;


/* fact_order_item */

SELECT
    COUNT(*) FILTER (WHERE customer_sk = 0)
        AS customer_desconhecido,

    COUNT(*) FILTER (WHERE order_status_sk = 0)
        AS status_desconhecido,

    COUNT(*) FILTER (WHERE purchase_date_sk = 0)
        AS purchase_date_desconhecida,

    COUNT(*) FILTER (WHERE product_sk = 0)
        AS product_desconhecido,

    COUNT(*) FILTER (WHERE seller_sk = 0)
        AS seller_desconhecido

FROM kimball.fact_order_item;


/* ============================================================
 * 4. PEDIDOS SEM ITENS
 * ============================================================
 *
 * Esperado a partir do profiling:
 * 775 pedidos.
 */

SELECT
    COUNT(*) AS pedidos_sem_itens
FROM kimball.fact_order fo
WHERE fo.valor_calculado_pedido IS NULL;


/* Comparação direta com raw. */

SELECT
    COUNT(*) AS pedidos_sem_itens_raw
FROM raw.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM raw.order_items oi
    WHERE oi.order_id = o.order_id
);


/* ============================================================
 * 5. RECONCILIAÇÃO DE VALOR_CALCULADO_PEDIDO
 * ============================================================
 *
 * Compara o valor calculado armazenado em fact_order
 * com o cálculo direto em raw.order_items.
 */

WITH raw_order_values AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS raw_value

    FROM raw.order_items

    GROUP BY order_id

)

SELECT
    COUNT(*) AS pedidos_com_diferenca,

    MAX(
        ABS(
            fo.valor_calculado_pedido
            -
            rov.raw_value
        )
    ) AS maior_diferenca

FROM kimball.fact_order fo

JOIN raw_order_values rov
    ON rov.order_id = fo.order_id

WHERE ABS(
    fo.valor_calculado_pedido
    -
    rov.raw_value
) > 0.01;


/* ============================================================
 * 6. RECONCILIAÇÃO DAS MEDIDAS DE ITEM
 * ============================================================
 */


/* price */

SELECT
    (SELECT SUM(price)
     FROM raw.order_items) AS raw_price,

    (SELECT SUM(price)
     FROM kimball.fact_order_item) AS kimball_price,

    ABS(
        (SELECT SUM(price) FROM raw.order_items)
        -
        (SELECT SUM(price) FROM kimball.fact_order_item)
    ) AS diferenca;


/* freight_value */

SELECT
    (SELECT SUM(freight_value)
     FROM raw.order_items) AS raw_freight,

    (SELECT SUM(freight_value)
     FROM kimball.fact_order_item) AS kimball_freight,

    ABS(
        (SELECT SUM(freight_value) FROM raw.order_items)
        -
        (SELECT SUM(freight_value) FROM kimball.fact_order_item)
    ) AS diferenca;


/* ============================================================
 * 7. RECONCILIAÇÃO DE STATUS
 * ============================================================
 *
 * Compara a distribuição de status na origem e na fact_order.
 */

SELECT
    raw_status.order_status,
    raw_status.quantidade_raw,
    kimball_status.quantidade_kimball,
    raw_status.quantidade_raw
        - kimball_status.quantidade_kimball AS diferenca

FROM (

    SELECT
        order_status,
        COUNT(*) AS quantidade_raw

    FROM raw.orders

    GROUP BY order_status

) raw_status

JOIN (

    SELECT
        dos.order_status,
        COUNT(*) AS quantidade_kimball

    FROM kimball.fact_order fo

    JOIN kimball.dim_order_status dos
        ON dos.order_status_sk = fo.order_status_sk

    GROUP BY dos.order_status

) kimball_status
    ON kimball_status.order_status = raw_status.order_status

ORDER BY
    raw_status.order_status;


/* ============================================================
 * 8. CONSISTÊNCIA DIMENSIONAL ENTRE AS DUAS FATOS
 * ============================================================
 *
 * Para cada item, cliente, status e data de compra devem
 * representar os mesmos valores utilizados na fact_order
 * do respectivo pedido.
 *
 * Esse join é usado somente para validação do modelo.
 * Não representa a estratégia normal de consulta analítica.
 */

SELECT
    COUNT(*) AS itens_inconsistentes

FROM kimball.fact_order_item foi

JOIN kimball.fact_order fo
    ON fo.order_id = foi.order_id

WHERE
       foi.customer_sk <> fo.customer_sk
    OR foi.order_status_sk <> fo.order_status_sk
    OR foi.purchase_date_sk <> fo.purchase_date_sk;


/* ============================================================
 * 9. VALIDAÇÃO DAS DATAS
 * ============================================================
 */


/* Data de entrega desconhecida deve corresponder
 * a order_delivered_customer_date NULL.
 */

SELECT
    COUNT(*) AS inconsistencias_delivered_date

FROM kimball.fact_order

WHERE
       (order_delivered_customer_date IS NULL
        AND delivered_date_sk <> 0)

    OR (order_delivered_customer_date IS NOT NULL
        AND delivered_date_sk = 0);


/* Data estimada. */

SELECT
    COUNT(*) AS inconsistencias_estimated_date

FROM kimball.fact_order

WHERE
       (order_estimated_delivery_date IS NULL
        AND estimated_delivery_date_sk <> 0)

    OR (order_estimated_delivery_date IS NOT NULL
        AND estimated_delivery_date_sk = 0);


/* ============================================================
 * 10. VALIDAÇÃO DE TEMPO_ENTREGA_DIAS
 * ============================================================
 *
 * Recalcula diretamente a duração a partir das datas da fato.
 */

SELECT
    COUNT(*) AS tempos_inconsistentes

FROM kimball.fact_order

WHERE
    order_purchase_timestamp IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL

    AND ABS(
        tempo_entrega_dias
        -
        (
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    -
                    order_purchase_timestamp
                )
            ) / 86400.0
        )
    ) > 0.000001;


/* Quando alguma das datas necessárias está ausente,
 * tempo_entrega_dias deve ser NULL.
 */

SELECT
    COUNT(*) AS tempos_presentes_sem_datas

FROM kimball.fact_order

WHERE
    (
        order_purchase_timestamp IS NULL
        OR order_delivered_customer_date IS NULL
    )
    AND tempo_entrega_dias IS NOT NULL;


/* ============================================================
 * 11. VALIDAÇÃO DO INDICADOR DE ATRASO
 * ============================================================
 */

SELECT
    COUNT(*) AS atrasos_inconsistentes

FROM kimball.fact_order

WHERE
    indicador_atraso IS DISTINCT FROM

    CASE
        WHEN order_delivered_customer_date IS NULL
          OR order_estimated_delivery_date IS NULL
        THEN NULL

        ELSE
            order_delivered_customer_date
            >
            order_estimated_delivery_date
    END;


/* ============================================================
 * 12. POPULAÇÃO DELIVERED
 * ============================================================
 *
 * Esperado a partir do profiling:
 * 96.478 pedidos entregues.
 */

SELECT
    COUNT(*) AS pedidos_delivered

FROM kimball.fact_order fo

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk

WHERE dos.order_status = 'delivered';


/* Quantidade de itens associados a pedidos delivered. */

SELECT
    COUNT(*) AS itens_delivered

FROM kimball.fact_order_item foi

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = foi.order_status_sk

WHERE dos.order_status = 'delivered';


/* ============================================================
 * 13. RESUMO DE CONTROLE FINANCEIRO — DELIVERED
 * ============================================================
 *
 * Valores que posteriormente serão utilizados nas consultas
 * analíticas do baseline.
 */


/* Valor bruto dos itens vendidos. */

SELECT
    SUM(foi.price) AS valor_bruto_itens_delivered

FROM kimball.fact_order_item foi

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = foi.order_status_sk

WHERE dos.order_status = 'delivered';


/* Valor de frete. */

SELECT
    SUM(foi.freight_value) AS valor_frete_delivered

FROM kimball.fact_order_item foi

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = foi.order_status_sk

WHERE dos.order_status = 'delivered';


/* Valor calculado dos pedidos. */

SELECT
    SUM(fo.valor_calculado_pedido)
        AS valor_calculado_pedidos_delivered

FROM kimball.fact_order fo

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk

WHERE dos.order_status = 'delivered';


/* Ticket médio calculado. */

SELECT
    AVG(fo.valor_calculado_pedido)
        AS ticket_medio_calculado_delivered

FROM kimball.fact_order fo

JOIN kimball.dim_order_status dos
    ON dos.order_status_sk = fo.order_status_sk

WHERE dos.order_status = 'delivered';