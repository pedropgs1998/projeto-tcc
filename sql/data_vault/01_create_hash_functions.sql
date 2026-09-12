/*
 * Funções auxiliares para geração de hashes
 * Data Vault 2.0 — Estado T0
 *
 * Regras:
 * - algoritmo: SHA-256
 * - representação: hexadecimal CHAR(64)
 * - texto normalizado com TRIM + UPPER
 * - NULL representado por ^^
 * - componentes separados por ||
 */

CREATE EXTENSION IF NOT EXISTS pgcrypto;


/* ============================================================
 * 1. NORMALIZAÇÃO DE VALOR INDIVIDUAL
 * ============================================================
 *
 * Converte qualquer valor textual em uma representação estável
 * para utilização na geração de hashes.
 *
 * Regras:
 * - TRIM remove espaços externos;
 * - UPPER evita diferença de caixa;
 * - NULL utiliza marcador ^^.
 * ============================================================
 */

CREATE OR REPLACE FUNCTION data_vault.normalize_hash_value(
    value TEXT
)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT COALESCE(
        NULLIF(
            UPPER(TRIM(value)),
            ''
        ),
        '^^'
    );
$$;


/* ============================================================
 * 2. HASH DE UM ÚNICO VALOR
 * ============================================================
 *
 * Utilizado principalmente para Hubs com Business Key simples.
 *
 * Exemplo:
 *
 * hash_key('abc123')
 *
 * equivale ao SHA-256 de:
 *
 * ABC123
 * ============================================================
 */

CREATE OR REPLACE FUNCTION data_vault.hash_key(
    value TEXT
)
RETURNS CHAR(64)
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT encode(
        digest(
            data_vault.normalize_hash_value(value),
            'sha256'
        ),
        'hex'
    )::CHAR(64);
$$;


/* ============================================================
 * 3. HASH DE MÚLTIPLOS COMPONENTES
 * ============================================================
 *
 * Utilizado para:
 * - Hash Keys de Links;
 * - HashDiffs de Satellites;
 * - outras chaves compostas.
 *
 * Os componentes são recebidos como ARRAY de TEXT.
 *
 * Cada valor é normalizado individualmente e depois concatenado
 * utilizando o separador fixo:
 *
 * ||
 *
 * Exemplo:
 *
 * ['abc', 'xyz']
 *
 * torna-se:
 *
 * ABC||XYZ
 * ============================================================
 */

CREATE OR REPLACE FUNCTION data_vault.hash_values(
    values_array TEXT[]
)
RETURNS CHAR(64)
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT encode(
        digest(
            array_to_string(
                ARRAY(
                    SELECT data_vault.normalize_hash_value(v)
                    FROM unnest(values_array) WITH ORDINALITY AS t(v, ord)
                    ORDER BY ord
                ),
                '||'
            ),
            'sha256'
        ),
        'hex'
    )::CHAR(64);
$$;


/* ============================================================
 * 4. TESTES BÁSICOS DE CONSISTÊNCIA
 * ============================================================
 *
 * Estes SELECTs servem para verificar se:
 * - a mesma entrada gera sempre o mesmo hash;
 * - caixa e espaços externos são normalizados;
 * - NULL recebe representação consistente;
 * - hashes compostos preservam a ordem dos componentes.
 * ============================================================
 */

SELECT
    data_vault.hash_key('ABC123') AS hash_1,
    data_vault.hash_key(' abc123 ') AS hash_2,
    data_vault.hash_key('ABC123')
        =
    data_vault.hash_key(' abc123 ')
        AS normalizacao_consistente;


SELECT
    data_vault.hash_key(NULL) AS hash_null_1,
    data_vault.hash_key(NULL) AS hash_null_2,
    data_vault.hash_key(NULL)
        =
    data_vault.hash_key(NULL)
        AS null_consistente;


SELECT
    data_vault.hash_values(
        ARRAY['ORDER1', 'CUSTOMER1']
    ) AS hash_composto_1,

    data_vault.hash_values(
        ARRAY[' order1 ', 'customer1']
    ) AS hash_composto_2,

    data_vault.hash_values(
        ARRAY['ORDER1', 'CUSTOMER1']
    )
        =
    data_vault.hash_values(
        ARRAY[' order1 ', 'customer1']
    )
        AS hash_composto_consistente;


SELECT
    data_vault.hash_values(
        ARRAY['A', 'B']
    ) AS hash_ab,

    data_vault.hash_values(
        ARRAY['B', 'A']
    ) AS hash_ba,

    data_vault.hash_values(
        ARRAY['A', 'B']
    )
        <>
    data_vault.hash_values(
        ARRAY['B', 'A']
    )
        AS ordem_componentes_preservada;