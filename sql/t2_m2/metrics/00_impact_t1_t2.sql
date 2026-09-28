-- ============================================================================
-- TCC UNICAMP
-- T2 / M2
-- Impacto estrutural e operacional T1 -> T2
-- ============================================================================


-- ============================================================================
-- 1. Estado estrutural atual de T2
-- ============================================================================

WITH tabelas AS (
    SELECT
        table_schema,
        COUNT(*) AS quantidade_tabelas
    FROM information_schema.tables
    WHERE table_type = 'BASE TABLE'
      AND table_schema IN (
          'kimball',
          'data_vault',
          'data_mart'
      )
    GROUP BY table_schema
),

colunas AS (
    SELECT
        table_schema,
        COUNT(*) AS quantidade_colunas
    FROM information_schema.columns
    WHERE table_schema IN (
        'kimball',
        'data_vault',
        'data_mart'
    )
    GROUP BY table_schema
),

pks AS (
    SELECT
        table_schema,
        COUNT(*) AS quantidade_pk
    FROM information_schema.table_constraints
    WHERE constraint_type = 'PRIMARY KEY'
      AND table_schema IN (
          'kimball',
          'data_vault',
          'data_mart'
      )
    GROUP BY table_schema
),

fks AS (
    SELECT
        table_schema,
        COUNT(*) AS quantidade_fk
    FROM information_schema.table_constraints
    WHERE constraint_type = 'FOREIGN KEY'
      AND table_schema IN (
          'kimball',
          'data_vault',
          'data_mart'
      )
    GROUP BY table_schema
)

SELECT
    t.table_schema,
    t.quantidade_tabelas,
    c.quantidade_colunas,
    COALESCE(p.quantidade_pk, 0) AS quantidade_pk,
    COALESCE(f.quantidade_fk, 0) AS quantidade_fk
FROM tabelas t
JOIN colunas c
    ON c.table_schema = t.table_schema
LEFT JOIN pks p
    ON p.table_schema = t.table_schema
LEFT JOIN fks f
    ON f.table_schema = t.table_schema
ORDER BY
    CASE t.table_schema
        WHEN 'kimball' THEN 1
        WHEN 'data_vault' THEN 2
        WHEN 'data_mart' THEN 3
    END;


-- ============================================================================
-- 2. Comparação estrutural T1 -> T2
--
-- Em M2:
--   nenhuma tabela foi criada
--   nenhuma PK foi criada
--   nenhuma FK foi criada
--   duas colunas foram adicionadas em cada camada
-- ============================================================================

WITH metricas_t2 AS (
    SELECT
        s.table_schema,

        (
            SELECT COUNT(*)
            FROM information_schema.tables t
            WHERE t.table_schema = s.table_schema
              AND t.table_type = 'BASE TABLE'
        ) AS tabelas_t2,

        (
            SELECT COUNT(*)
            FROM information_schema.columns c
            WHERE c.table_schema = s.table_schema
        ) AS colunas_t2,

        (
            SELECT COUNT(*)
            FROM information_schema.table_constraints tc
            WHERE tc.table_schema = s.table_schema
              AND tc.constraint_type = 'PRIMARY KEY'
        ) AS pk_t2,

        (
            SELECT COUNT(*)
            FROM information_schema.table_constraints tc
            WHERE tc.table_schema = s.table_schema
              AND tc.constraint_type = 'FOREIGN KEY'
        ) AS fk_t2

    FROM (
        VALUES
            ('kimball'),
            ('data_vault'),
            ('data_mart')
    ) AS s(table_schema)
)

SELECT
    table_schema,

    tabelas_t2 AS tabelas_t1,
    tabelas_t2,
    0 AS delta_tabelas,

    colunas_t2 - 2 AS colunas_t1,
    colunas_t2,
    2 AS delta_colunas,

    pk_t2 AS pk_t1,
    pk_t2,
    0 AS delta_pk,

    fk_t2 AS fk_t1,
    fk_t2,
    0 AS delta_fk

FROM metricas_t2

ORDER BY
    CASE table_schema
        WHEN 'kimball' THEN 1
        WHEN 'data_vault' THEN 2
        WHEN 'data_mart' THEN 3
    END;


-- ============================================================================
-- 3. Verificação das colunas introduzidas por M2
-- ============================================================================

SELECT
    table_schema,
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE (
        (
            table_schema = 'kimball'
            AND table_name = 'fact_order'
        )
        OR (
            table_schema = 'data_vault'
            AND table_name = 'sat_order'
        )
        OR (
            table_schema = 'data_mart'
            AND table_name = 'fact_order'
        )
    )
  AND column_name IN (
      'order_approved_at',
      'order_delivered_carrier_date'
  )
ORDER BY
    CASE table_schema
        WHEN 'kimball' THEN 1
        WHEN 'data_vault' THEN 2
        WHEN 'data_mart' THEN 3
    END,
    column_name;


-- ============================================================================
-- 4. Registro controlado das alterações realizadas em M2
-- ============================================================================

SELECT *
FROM (
    VALUES
        (
            'kimball',
            'fact_order',
            'ALTERACAO',
            2,
            'Inclusao de order_approved_at e order_delivered_carrier_date; carga alterada'
        ),

        (
            'data_vault',
            'sat_order',
            'ALTERACAO',
            2,
            'Inclusao de order_approved_at e order_delivered_carrier_date; carga e logica de hashdiff alteradas'
        ),

        (
            'data_mart',
            'fact_order',
            'ALTERACAO',
            2,
            'Inclusao de order_approved_at e order_delivered_carrier_date; carga a partir do Data Vault alterada'
        )

) AS impacto(
    camada,
    objeto,
    tipo_alteracao,
    colunas_adicionadas,
    observacao
);


-- ============================================================================
-- 5. Impacto nas consultas analíticas
-- ============================================================================

SELECT *
FROM (
    VALUES
        (
            'Q1',
            'NAO ALTERADA',
            'Valor bruto de itens vendidos preservado'
        ),

        (
            'Q2',
            'NAO ALTERADA',
            'Ticket medio calculado e ticket medio pago preservados'
        ),

        (
            'Q3',
            'ALTERADA',
            'Inclusao de media_horas_aprovacao, media_horas_preparacao e media_horas_transporte'
        )

) AS impacto_consultas(
    consulta,
    impacto,
    descricao
);


-- ============================================================================
-- 6. Resumo quantitativo de M2
-- ============================================================================

SELECT *
FROM (
    VALUES
        (
            'kimball',
            0,
            1,
            2,
            0,
            0,
            1,
            1,
            0
        ),

        (
            'data_vault',
            0,
            1,
            2,
            0,
            0,
            1,
            0,
            1
        ),

        (
            'data_mart',
            0,
            1,
            2,
            0,
            0,
            1,
            1,
            0
        )

) AS resumo(
    camada,
    tabelas_adicionadas,
    tabelas_alteradas,
    colunas_adicionadas,
    pk_adicionadas,
    fk_adicionadas,
    rotinas_carga_alteradas,
    consultas_analiticas_alteradas,
    logicas_hashdiff_alteradas
);