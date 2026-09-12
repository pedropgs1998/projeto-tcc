-- ============================================================================
-- TCC UNICAMP
-- T1 / M1
-- Métricas estruturais do impacto T0 -> T1
--
-- Como M1 adicionou objetos sem alterar os objetos físicos de T0,
-- o estado T0 pode ser reconstruído para fins de contagem excluindo:
--
--   kimball.fact_payment
--   data_vault.sat_order_payment
--   data_mart.fact_payment
-- ============================================================================


-- ============================================================================
-- 1. INVENTÁRIO ESTRUTURAL T0 x T1
-- ============================================================================

WITH layers(schema_name) AS (
    VALUES
        ('kimball'),
        ('data_vault'),
        ('data_mart')
),

tables_t1 AS (
    SELECT
        table_schema AS schema_name,
        COUNT(*) AS quantidade_tabelas
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema IN ('kimball', 'data_vault', 'data_mart')
    GROUP BY table_schema
),

tables_t0 AS (
    SELECT
        table_schema AS schema_name,
        COUNT(*) AS quantidade_tabelas
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema IN ('kimball', 'data_vault', 'data_mart')
      AND NOT (
            (table_schema = 'kimball' AND table_name = 'fact_payment')
         OR (table_schema = 'data_vault' AND table_name = 'sat_order_payment')
         OR (table_schema = 'data_mart' AND table_name = 'fact_payment')
      )
    GROUP BY table_schema
),

columns_t1 AS (
    SELECT
        table_schema AS schema_name,
        COUNT(*) AS quantidade_colunas
    FROM information_schema.columns
    WHERE table_schema IN ('kimball', 'data_vault', 'data_mart')
    GROUP BY table_schema
),

columns_t0 AS (
    SELECT
        table_schema AS schema_name,
        COUNT(*) AS quantidade_colunas
    FROM information_schema.columns
    WHERE table_schema IN ('kimball', 'data_vault', 'data_mart')
      AND NOT (
            (table_schema = 'kimball' AND table_name = 'fact_payment')
         OR (table_schema = 'data_vault' AND table_name = 'sat_order_payment')
         OR (table_schema = 'data_mart' AND table_name = 'fact_payment')
      )
    GROUP BY table_schema
),

pk_t1 AS (
    SELECT
        tc.table_schema AS schema_name,
        COUNT(*) AS quantidade_pk
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema IN ('kimball', 'data_vault', 'data_mart')
    GROUP BY tc.table_schema
),

pk_t0 AS (
    SELECT
        tc.table_schema AS schema_name,
        COUNT(*) AS quantidade_pk
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema IN ('kimball', 'data_vault', 'data_mart')
      AND NOT (
            (tc.table_schema = 'kimball' AND tc.table_name = 'fact_payment')
         OR (tc.table_schema = 'data_vault' AND tc.table_name = 'sat_order_payment')
         OR (tc.table_schema = 'data_mart' AND tc.table_name = 'fact_payment')
      )
    GROUP BY tc.table_schema
),

fk_t1 AS (
    SELECT
        tc.table_schema AS schema_name,
        COUNT(*) AS quantidade_fk
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema IN ('kimball', 'data_vault', 'data_mart')
    GROUP BY tc.table_schema
),

fk_t0 AS (
    SELECT
        tc.table_schema AS schema_name,
        COUNT(*) AS quantidade_fk
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema IN ('kimball', 'data_vault', 'data_mart')
      AND NOT (
            (tc.table_schema = 'kimball' AND tc.table_name = 'fact_payment')
         OR (tc.table_schema = 'data_vault' AND tc.table_name = 'sat_order_payment')
         OR (tc.table_schema = 'data_mart' AND tc.table_name = 'fact_payment')
      )
    GROUP BY tc.table_schema
)

SELECT
    l.schema_name AS camada,

    t0.quantidade_tabelas AS tabelas_t0,
    t1.quantidade_tabelas AS tabelas_t1,
    t1.quantidade_tabelas - t0.quantidade_tabelas AS delta_tabelas,

    c0.quantidade_colunas AS colunas_t0,
    c1.quantidade_colunas AS colunas_t1,
    c1.quantidade_colunas - c0.quantidade_colunas AS delta_colunas,

    p0.quantidade_pk AS pk_t0,
    p1.quantidade_pk AS pk_t1,
    p1.quantidade_pk - p0.quantidade_pk AS delta_pk,

    f0.quantidade_fk AS fk_t0,
    f1.quantidade_fk AS fk_t1,
    f1.quantidade_fk - f0.quantidade_fk AS delta_fk

FROM layers l

JOIN tables_t0 t0
    ON t0.schema_name = l.schema_name

JOIN tables_t1 t1
    ON t1.schema_name = l.schema_name

JOIN columns_t0 c0
    ON c0.schema_name = l.schema_name

JOIN columns_t1 c1
    ON c1.schema_name = l.schema_name

JOIN pk_t0 p0
    ON p0.schema_name = l.schema_name

JOIN pk_t1 p1
    ON p1.schema_name = l.schema_name

LEFT JOIN fk_t0 f0
    ON f0.schema_name = l.schema_name

LEFT JOIN fk_t1 f1
    ON f1.schema_name = l.schema_name

ORDER BY
    CASE l.schema_name
        WHEN 'kimball' THEN 1
        WHEN 'data_vault' THEN 2
        WHEN 'data_mart' THEN 3
    END;


-- ============================================================================
-- 2. OBJETOS CRIADOS POR M1
-- ============================================================================

SELECT
    table_schema AS camada,
    table_name AS objeto_criado
FROM information_schema.tables
WHERE
       (table_schema = 'kimball'
        AND table_name = 'fact_payment')

    OR (table_schema = 'data_vault'
        AND table_name = 'sat_order_payment')

    OR (table_schema = 'data_mart'
        AND table_name = 'fact_payment')

ORDER BY table_schema, table_name;


-- ============================================================================
-- 3. COLUNAS DOS OBJETOS CRIADOS
-- ============================================================================

SELECT
    table_schema AS camada,
    table_name,
    COUNT(*) AS colunas_adicionadas
FROM information_schema.columns
WHERE
       (table_schema = 'kimball'
        AND table_name = 'fact_payment')

    OR (table_schema = 'data_vault'
        AND table_name = 'sat_order_payment')

    OR (table_schema = 'data_mart'
        AND table_name = 'fact_payment')

GROUP BY
    table_schema,
    table_name

ORDER BY
    table_schema,
    table_name;


-- ============================================================================
-- 4. CONSTRAINTS INTRODUZIDAS POR M1
-- ============================================================================

SELECT
    table_schema AS camada,
    table_name,
    constraint_type,
    COUNT(*) AS quantidade
FROM information_schema.table_constraints
WHERE
       (table_schema = 'kimball'
        AND table_name = 'fact_payment')

    OR (table_schema = 'data_vault'
        AND table_name = 'sat_order_payment')

    OR (table_schema = 'data_mart'
        AND table_name = 'fact_payment')

GROUP BY
    table_schema,
    table_name,
    constraint_type

ORDER BY
    table_schema,
    table_name,
    constraint_type;


-- ============================================================================
-- 5. ÍNDICES DOS OBJETOS CRIADOS
--
-- O PostgreSQL cria automaticamente índice para PRIMARY KEY.
-- Esta consulta identifica todos os índices físicos para manter a evidência
-- transparente. A interpretação posterior pode separar PK dos índices
-- explicitamente criados.
-- ============================================================================

SELECT
    schemaname AS camada,
    tablename,
    indexname
FROM pg_indexes
WHERE
       (schemaname = 'kimball'
        AND tablename = 'fact_payment')

    OR (schemaname = 'data_vault'
        AND tablename = 'sat_order_payment')

    OR (schemaname = 'data_mart'
        AND tablename = 'fact_payment')

ORDER BY
    schemaname,
    tablename,
    indexname;


-- ============================================================================
-- 6. RESUMO DO IMPACTO FUNCIONAL
-- ============================================================================

SELECT *
FROM (
    VALUES
        ('Q1', 'preservada', 'nenhuma nova metrica'),
        ('Q2', 'alterada', 'ticket_medio_pago'),
        ('Q3', 'alterada', 'valor_pago; ticket_medio_pago')
) AS impacto(consulta, situacao, impacto);