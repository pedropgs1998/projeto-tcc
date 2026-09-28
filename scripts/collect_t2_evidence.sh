#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTAINER="tcc-postgres"
DB_USER="olist_dw"
DB_NAME="olist_dw"

EVIDENCE_DIR="${ROOT_DIR}/evidence/t2"

PROFILE_DIR="${EVIDENCE_DIR}/profile"
QUERIES_DIR="${EVIDENCE_DIR}/queries"
VALIDATION_DIR="${EVIDENCE_DIR}/validation"
METRICS_DIR="${EVIDENCE_DIR}/metrics"
ENVIRONMENT_DIR="${EVIDENCE_DIR}/environment"
LOG_DIR="${EVIDENCE_DIR}/logs"

mkdir -p "${PROFILE_DIR}"
mkdir -p "${QUERIES_DIR}"
mkdir -p "${VALIDATION_DIR}"
mkdir -p "${METRICS_DIR}"
mkdir -p "${ENVIRONMENT_DIR}"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/collect_t2_evidence.log"

exec > >(tee "${LOG_FILE}") 2>&1


timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}


log() {
    echo
    echo "[$(timestamp)] $1"
    echo
}


collect_sql() {
    local sql_file="$1"
    local output_file="$2"

    log "Executando ${sql_file} -> ${output_file}"

    docker exec -i "${CONTAINER}" \
        psql \
        -v ON_ERROR_STOP=1 \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        < "${ROOT_DIR}/${sql_file}" \
        > "${ROOT_DIR}/${output_file}"
}


log "Coletando evidências do estado T2"


log "Profiling M2"

collect_sql \
    "sql/t2_m2/00_profile_m2.sql" \
    "evidence/t2/profile/profile_m2.txt"


log "Queries Kimball T2"

collect_sql \
    "sql/t2_m2/kimball/03_queries_t2.sql" \
    "evidence/t2/queries/queries_kimball_t2.txt"


log "Queries Data Mart T2"

collect_sql \
    "sql/t2_m2/data_mart/03_queries_t2.sql" \
    "evidence/t2/queries/queries_data_mart_t2.txt"


log "Validação Kimball T2"

collect_sql \
    "sql/t2_m2/kimball/02_validate_t2.sql" \
    "evidence/t2/validation/validate_kimball_t2.txt"


log "Validação Data Vault T2"

collect_sql \
    "sql/t2_m2/data_vault/02_validate_t2.sql" \
    "evidence/t2/validation/validate_data_vault_t2.txt"


log "Validação Data Mart T2"

collect_sql \
    "sql/t2_m2/data_mart/02_validate_t2.sql" \
    "evidence/t2/validation/validate_data_mart_t2.txt"


log "Equivalência analítica T2"

collect_sql \
    "sql/t2_m2/validation/00_validate_t2_equivalence.sql" \
    "evidence/t2/validation/validate_t2_equivalence.txt"


log "Métricas estruturais T1 -> T2"

collect_sql \
    "sql/t2_m2/metrics/00_impact_t1_t2.sql" \
    "evidence/t2/metrics/impact_t1_t2.txt"


log "Snapshot dos objetos do banco"

docker exec -i "${CONTAINER}" \
    psql \
    -v ON_ERROR_STOP=1 \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -c "
        SELECT
            table_schema,
            table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_schema IN (
              'raw',
              'kimball',
              'data_vault',
              'data_mart',
              'control'
          )
        ORDER BY
            table_schema,
            table_name;
    " > "${ENVIRONMENT_DIR}/database_objects_t2.txt"


log "Versão PostgreSQL"

docker exec -i "${CONTAINER}" \
    psql \
    -v ON_ERROR_STOP=1 \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    -c "SELECT version();" \
    > "${ENVIRONMENT_DIR}/postgres_version.txt"


log "Versões Docker"

{
    docker --version
    docker compose version
} > "${ENVIRONMENT_DIR}/docker_versions.txt"


log "Estado Git utilizado na coleta"

{
    echo "Commit:"
    git rev-parse HEAD
    echo
    echo "Branch:"
    git branch --show-current
    echo
    echo "Status:"
    git status --short
} > "${ENVIRONMENT_DIR}/git_state.txt"


log "Coleta de evidências T2 concluída"

echo
echo "Diretório:"
echo "${EVIDENCE_DIR}"
echo
echo "Log da coleta:"
echo "${LOG_FILE}"