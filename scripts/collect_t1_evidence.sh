#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

EVIDENCE_DIR="$ROOT_DIR/evidence/t1"

log "Coletando evidências do estado T1"

ensure_container_running
wait_for_postgres

mkdir -p \
    "$EVIDENCE_DIR/profile" \
    "$EVIDENCE_DIR/queries" \
    "$EVIDENCE_DIR/validation" \
    "$EVIDENCE_DIR/metrics" \
    "$EVIDENCE_DIR/environment"


log "Profiling M1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/00_profile_m1.sql" \
    "$EVIDENCE_DIR/profile/profile_m1.txt"


log "Queries Kimball T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/kimball/03_queries_t1.sql" \
    "$EVIDENCE_DIR/queries/queries_kimball_t1.txt"


log "Queries Data Mart T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/data_mart/03_queries_t1.sql" \
    "$EVIDENCE_DIR/queries/queries_data_mart_t1.txt"


log "Validação Kimball T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/kimball/02_validate_t1.sql" \
    "$EVIDENCE_DIR/validation/validate_kimball_t1.txt"


log "Validação Data Vault T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/data_vault/02_validate_t1.sql" \
    "$EVIDENCE_DIR/validation/validate_data_vault_t1.txt"


log "Validação Data Mart T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/data_mart/02_validate_t1.sql" \
    "$EVIDENCE_DIR/validation/validate_data_mart_t1.txt"


log "Equivalência analítica T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/validation/00_validate_t1_equivalence.sql" \
    "$EVIDENCE_DIR/validation/validate_t1_equivalence.txt"


log "Métricas estruturais T0 -> T1"

capture_sql \
    "$ROOT_DIR/sql/t1_m1/validation/01_collect_t1_metrics.sql" \
    "$EVIDENCE_DIR/metrics/impact_t0_t1.txt"


log "Snapshot dos objetos do banco"

docker exec -i "$CONTAINER" \
    psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema IN (
    'raw',
    'kimball',
    'data_vault',
    'data_mart',
    'control'
)
AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;
" \
    > "$EVIDENCE_DIR/environment/database_objects_t1.txt" 2>&1


log "Versão PostgreSQL"

docker exec -i "$CONTAINER" \
    psql \
    -A -t \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "SELECT version();" \
    > "$EVIDENCE_DIR/environment/postgresql_version.txt" 2>&1


log "Versões Docker"

docker --version \
    > "$EVIDENCE_DIR/environment/docker_version.txt" 2>&1

docker compose version \
    > "$EVIDENCE_DIR/environment/docker_compose_version.txt" 2>&1


log "Descrição do ambiente T1"

cat > "$EVIDENCE_DIR/environment/environment_t1.txt" <<EOF
Estado experimental: T1
Mudança aplicada: M1 - incorporação da fonte de pagamentos

Data da coleta:
$(date --iso-8601=seconds)

Container:
$CONTAINER

Database:
$DB_NAME

Usuário:
$DB_USER

Fonte adicionada:
raw.order_payments

Objetos introduzidos em T1:
kimball.fact_payment
data_vault.sat_order_payment
data_mart.fact_payment
EOF


log "Coleta de evidências T1 concluída"

echo
echo "Diretório:"
echo "$EVIDENCE_DIR"