-- ============================================================================
-- TCC UNICAMP
-- T1 / M1 - Data Vault 2.0
-- Validação do SAT_ORDER_PAYMENT
-- ============================================================================


-- ============================================================================
-- 1. VOLUME
-- ============================================================================

SELECT
    COUNT(*) AS sat_order_payment
FROM data_vault.sat_order_payment;


-- ============================================================================
-- 2. GRÃO ATIVO NO T1
--
-- No primeiro estado T1 esperamos uma única versão para cada combinação
-- (order_hk, payment_sequential).
-- ============================================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT (order_hk, payment_sequential)) AS graos_distintos,
    COUNT(*) - COUNT(DISTINCT (order_hk, payment_sequential)) AS versoes_adicionais
FROM data_vault.sat_order_payment;


-- ============================================================================
-- 3. NÚMERO DE VERSÕES POR PAGAMENTO
-- ============================================================================

WITH versoes AS (
    SELECT
        order_hk,
        payment_sequential,
        COUNT(*) AS quantidade_versoes
    FROM data_vault.sat_order_payment
    GROUP BY
        order_hk,
        payment_sequential
)
SELECT
    MIN(quantidade_versoes) AS min_versoes,
    MAX(quantidade_versoes) AS max_versoes
FROM versoes;


-- ============================================================================
-- 4. INTEGRIDADE REFERENCIAL
-- ============================================================================

SELECT
    COUNT(*) AS referencias_invalidas
FROM data_vault.sat_order_payment s
LEFT JOIN data_vault.hub_order h
    ON h.order_hk = s.order_hk
WHERE h.order_hk IS NULL;


-- ============================================================================
-- 5. RAW x VAULT - QUANTIDADE
-- ============================================================================

SELECT
    (SELECT COUNT(*)
     FROM raw.order_payments) AS raw_payments,

    (SELECT COUNT(*)
     FROM data_vault.sat_order_payment) AS vault_payments;


-- ============================================================================
-- 6. RAW x VAULT - PEDIDOS DISTINTOS
-- ============================================================================

SELECT
    (
        SELECT COUNT(DISTINCT order_id)
        FROM raw.order_payments
    ) AS raw_orders,

    (
        SELECT COUNT(DISTINCT h.order_id)
        FROM data_vault.sat_order_payment s
        JOIN data_vault.hub_order h
            ON h.order_hk = s.order_hk
    ) AS vault_orders;


-- ============================================================================
-- 7. RAW x VAULT - VALOR TOTAL
-- ============================================================================

SELECT
    (
        SELECT SUM(payment_value)
        FROM raw.order_payments
    ) AS raw_total,

    (
        SELECT SUM(payment_value)
        FROM data_vault.sat_order_payment
    ) AS vault_total,

    (
        SELECT SUM(payment_value)
        FROM raw.order_payments
    )
    -
    (
        SELECT SUM(payment_value)
        FROM data_vault.sat_order_payment
    ) AS diferenca;


-- ============================================================================
-- 8. PAYLOAD
-- ============================================================================

SELECT
    COUNT(*) AS pagamentos_com_payload_diferente
FROM raw.order_payments p

JOIN data_vault.hub_order h
    ON h.order_id = p.order_id

JOIN data_vault.sat_order_payment s
    ON s.order_hk = h.order_hk
   AND s.payment_sequential = p.payment_sequential

WHERE s.payment_type IS DISTINCT FROM p.payment_type
   OR s.payment_installments IS DISTINCT FROM p.payment_installments
   OR s.payment_value IS DISTINCT FROM p.payment_value;


-- ============================================================================
-- 9. REGISTROS RAW NÃO ENCONTRADOS NO VAULT
-- ============================================================================

SELECT
    COUNT(*) AS pagamentos_raw_sem_satellite
FROM raw.order_payments p

JOIN data_vault.hub_order h
    ON h.order_id = p.order_id

LEFT JOIN data_vault.sat_order_payment s
    ON s.order_hk = h.order_hk
   AND s.payment_sequential = p.payment_sequential

WHERE s.order_hk IS NULL;


-- ============================================================================
-- 10. HASHDIFF
-- ============================================================================

SELECT
    COUNT(*) AS hashdiffs_inconsistentes
FROM data_vault.sat_order_payment s

WHERE s.hashdiff <> data_vault.hash_values(
    ARRAY[
        s.payment_type::TEXT,
        s.payment_installments::TEXT,
        s.payment_value::TEXT
    ]
);


-- ============================================================================
-- 11. TIPOS DE PAGAMENTO
-- ============================================================================

SELECT
    payment_type,
    COUNT(*) AS quantidade,
    SUM(payment_value) AS valor_pago
FROM data_vault.sat_order_payment
GROUP BY payment_type
ORDER BY payment_type;


-- ============================================================================
-- 12. CARDINALIDADE POR PEDIDO
-- ============================================================================

WITH pagamentos_por_pedido AS (
    SELECT
        order_hk,
        COUNT(*) AS quantidade_pagamentos
    FROM data_vault.sat_order_payment
    GROUP BY order_hk
)
SELECT
    MIN(quantidade_pagamentos) AS minimo_pagamentos,
    MAX(quantidade_pagamentos) AS maximo_pagamentos,
    AVG(quantidade_pagamentos::NUMERIC) AS media_pagamentos
FROM pagamentos_por_pedido;


-- ============================================================================
-- 13. RESUMO
-- ============================================================================

SELECT
    COUNT(*) AS sat_order_payment,
    COUNT(DISTINCT order_hk) AS pedidos_com_pagamento,
    SUM(payment_value) AS valor_pago_total
FROM data_vault.sat_order_payment;