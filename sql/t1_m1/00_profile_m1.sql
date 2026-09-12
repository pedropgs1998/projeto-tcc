-- ============================================================================
-- TCC UNICAMP
-- M1 / T1 - Profiling da fonte de pagamentos
--
-- Objetivo:
--   Caracterizar raw.order_payments antes da incorporação da fonte às
--   arquiteturas Kimball e Data Vault 2.0.
--
-- Grão esperado:
--   (order_id, payment_sequential)
--
-- Relação esperada:
--   ORDER 1:N PAYMENT
-- ============================================================================


-- ============================================================================
-- 1. VOLUME E GRÃO
-- ============================================================================

SELECT
    COUNT(*) AS total_linhas,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM raw.order_payments;


-- Verifica unicidade do grão (order_id, payment_sequential).
SELECT
    COUNT(*) AS total_linhas,
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)) AS duplicidades_grao
FROM raw.order_payments;


-- Caso existam duplicidades, apresenta os registros.
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS quantidade
FROM raw.order_payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1
ORDER BY quantidade DESC, order_id, payment_sequential;


-- ============================================================================
-- 2. INTEGRIDADE EM RELAÇÃO A PEDIDOS
-- ============================================================================

-- Pagamentos cujo pedido não existe em raw.orders.
SELECT
    COUNT(*) AS pagamentos_sem_pedido
FROM raw.order_payments p
LEFT JOIN raw.orders o
    ON o.order_id = p.order_id
WHERE o.order_id IS NULL;


-- Pedidos sem nenhum pagamento.
SELECT
    COUNT(*) AS pedidos_sem_pagamento
FROM raw.orders o
LEFT JOIN raw.order_payments p
    ON p.order_id = o.order_id
WHERE p.order_id IS NULL;


-- Identifica quais pedidos não possuem pagamento.
SELECT
    o.order_id,
    o.order_status
FROM raw.orders o
LEFT JOIN raw.order_payments p
    ON p.order_id = o.order_id
WHERE p.order_id IS NULL
ORDER BY o.order_id;


-- ============================================================================
-- 3. CARDINALIDADE ORDER -> PAYMENT
-- ============================================================================

WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        COUNT(*) AS quantidade_pagamentos
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    MIN(quantidade_pagamentos) AS minimo_pagamentos,
    MAX(quantidade_pagamentos) AS maximo_pagamentos,
    AVG(quantidade_pagamentos::numeric) AS media_pagamentos
FROM pagamentos_por_pedido;


-- Distribuição da quantidade de pagamentos por pedido.
WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        COUNT(*) AS quantidade_pagamentos
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    quantidade_pagamentos,
    COUNT(*) AS quantidade_pedidos
FROM pagamentos_por_pedido
GROUP BY quantidade_pagamentos
ORDER BY quantidade_pagamentos;


-- Quantos pedidos possuem mais de um registro de pagamento.
WITH pagamentos_por_pedido AS (
    SELECT
        order_id,
        COUNT(*) AS quantidade_pagamentos
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS pedidos_com_multiplos_pagamentos
FROM pagamentos_por_pedido
WHERE quantidade_pagamentos > 1;


-- ============================================================================
-- 4. TIPOS DE PAGAMENTO
-- ============================================================================

SELECT
    payment_type,
    COUNT(*) AS quantidade_registros,
    COUNT(DISTINCT order_id) AS quantidade_pedidos,
    SUM(payment_value) AS valor_pago
FROM raw.order_payments
GROUP BY payment_type
ORDER BY quantidade_registros DESC;


-- Pedidos que utilizaram mais de um tipo de pagamento.
WITH tipos_por_pedido AS (
    SELECT
        order_id,
        COUNT(DISTINCT payment_type) AS quantidade_tipos
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS pedidos_com_multiplos_tipos_pagamento
FROM tipos_por_pedido
WHERE quantidade_tipos > 1;


-- ============================================================================
-- 5. QUALIDADE DOS CAMPOS
-- ============================================================================

SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS order_id_null,
    COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS payment_sequential_null,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS payment_type_null,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS payment_installments_null,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS payment_value_null
FROM raw.order_payments;


SELECT
    COUNT(*) FILTER (WHERE payment_value < 0) AS valores_negativos,
    COUNT(*) FILTER (WHERE payment_value = 0) AS valores_zerados,
    MIN(payment_value) AS menor_pagamento,
    MAX(payment_value) AS maior_pagamento,
    SUM(payment_value) AS valor_total_pagamentos
FROM raw.order_payments;


-- Perfil das parcelas.
SELECT
    MIN(payment_installments) AS minimo_parcelas,
    MAX(payment_installments) AS maximo_parcelas,
    AVG(payment_installments::numeric) AS media_parcelas
FROM raw.order_payments;


-- ============================================================================
-- 6. AGREGAÇÃO DE PAGAMENTOS NO GRÃO DO PEDIDO
-- ============================================================================

-- Esta será a regra utilizada para obter valor_pago_pedido no M1.
WITH pagamento_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS quantidade_pedidos,
    SUM(valor_pago_pedido) AS valor_pago_total,
    AVG(valor_pago_pedido) AS ticket_medio_pago
FROM pagamento_por_pedido;


-- ============================================================================
-- 7. RECONCILIAÇÃO:
--    pagamento registrado x valor calculado a partir dos itens
--
-- IMPORTANTE:
--   Itens e pagamentos são relações 1:N com pedidos.
--   Eles devem ser agregados separadamente por order_id ANTES do JOIN.
--   Isso evita fan-out.
-- ============================================================================

WITH itens_por_pedido AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS valor_calculado_pedido
    FROM raw.order_items
    GROUP BY order_id
),
pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM raw.order_payments
    GROUP BY order_id
),
comparacao AS (
    SELECT
        i.order_id,
        i.valor_calculado_pedido,
        p.valor_pago_pedido,
        ABS(i.valor_calculado_pedido - p.valor_pago_pedido) AS diferenca
    FROM itens_por_pedido i
    INNER JOIN pagamentos_por_pedido p
        ON p.order_id = i.order_id
)
SELECT
    COUNT(*) AS pedidos_com_itens_e_pagamento,

    COUNT(*) FILTER (
        WHERE diferenca <= 0.01
    ) AS diferenca_ate_1_centavo,

    COUNT(*) FILTER (
        WHERE diferenca > 0.01
    ) AS diferenca_maior_1_centavo,

    MAX(diferenca) AS maior_diferenca,

    SUM(valor_calculado_pedido) AS total_calculado,

    SUM(valor_pago_pedido) AS total_pago

FROM comparacao;


-- Maiores diferenças encontradas.
WITH itens_por_pedido AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS valor_calculado_pedido
    FROM raw.order_items
    GROUP BY order_id
),
pagamentos_por_pedido AS (
    SELECT
        order_id,
        SUM(payment_value) AS valor_pago_pedido
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    i.order_id,
    i.valor_calculado_pedido,
    p.valor_pago_pedido,
    ABS(i.valor_calculado_pedido - p.valor_pago_pedido) AS diferenca
FROM itens_por_pedido i
INNER JOIN pagamentos_por_pedido p
    ON p.order_id = i.order_id
WHERE ABS(i.valor_calculado_pedido - p.valor_pago_pedido) > 0.01
ORDER BY diferenca DESC
LIMIT 20;


-- ============================================================================
-- 8. RECONCILIAÇÃO RESTRITA A PEDIDOS DELIVERED
--
-- Essa população é particularmente importante porque Q1, Q2 e Q3 utilizam
-- pedidos entregues como população analítica principal.
-- ============================================================================

WITH itens_por_pedido AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS valor_calculado_pedido
    FROM raw.order_items oi
    GROUP BY oi.order_id
),
pagamentos_por_pedido AS (
    SELECT
        op.order_id,
        SUM(op.payment_value) AS valor_pago_pedido
    FROM raw.order_payments op
    GROUP BY op.order_id
)
SELECT
    COUNT(*) AS pedidos_delivered,
    SUM(i.valor_calculado_pedido) AS valor_calculado,
    SUM(p.valor_pago_pedido) AS valor_pago,
    AVG(i.valor_calculado_pedido) AS ticket_medio_calculado,
    AVG(p.valor_pago_pedido) AS ticket_medio_pago
FROM raw.orders o
INNER JOIN itens_por_pedido i
    ON i.order_id = o.order_id
INNER JOIN pagamentos_por_pedido p
    ON p.order_id = o.order_id
WHERE o.order_status = 'delivered';