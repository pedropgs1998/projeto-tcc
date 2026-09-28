#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTAINER="tcc-postgres"
DB_USER="olist_dw"
DB_NAME="olist_dw"

LOG_DIR="${ROOT_DIR}/evidence/t2/logs"
LOG_FILE="${LOG_DIR}/rebuild_t2.log"

mkdir -p "${LOG_DIR}"

exec > >(tee "${LOG_FILE}") 2>&1


timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}


log() {
    echo
    echo "[$(timestamp)] $1"
    echo
}


run_sql() {
    local sql_file="$1"

    log "Executando ${sql_file}"

    docker exec -i "${CONTAINER}" \
        psql \
        -v ON_ERROR_STOP=1 \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        < "${ROOT_DIR}/${sql_file}"
}


echo
echo "============================================================"
echo "Reconstrução completa do estado T2"
echo "============================================================"
echo


log "Reconstruindo estado T1"

"${ROOT_DIR}/scripts/rebuild_t1.sh"


log "Aplicando M2 no modelo Kimball"

run_sql "sql/t2_m2/kimball/00_alter_fact_order.sql"
run_sql "sql/t2_m2/kimball/01_load_temporal_attributes.sql"


log "Aplicando M2 no Data Vault"

run_sql "sql/t2_m2/data_vault/00_alter_sat_order.sql"
run_sql "sql/t2_m2/data_vault/01_load_temporal_attributes.sql"


log "Aplicando M2 no Data Mart"

run_sql "sql/t2_m2/data_mart/00_alter_fact_order.sql"
run_sql "sql/t2_m2/data_mart/01_load_temporal_attributes.sql"


log "Validando Kimball T2"

run_sql "sql/t2_m2/kimball/02_validate_t2.sql"


log "Validando Data Vault T2"

run_sql "sql/t2_m2/data_vault/02_validate_t2.sql"


log "Validando Data Mart T2"

run_sql "sql/t2_m2/data_mart/02_validate_t2.sql"


log "Validando equivalência Kimball x Data Mart em T2"

run_sql "sql/t2_m2/validation/00_validate_t2_equivalence.sql"


log "Reconstrução e validação de T2 concluídas"


echo
echo "============================================================"
echo "Estado T2 reconstruído e validado com sucesso"
echo "============================================================"
echo
echo "Log completo:"
echo "${LOG_FILE}"