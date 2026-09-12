#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_container_running
wait_for_postgres

EVIDENCE_DIR="evidence/t0"

mkdir -p \
  "$EVIDENCE_DIR/environment" \
  "$EVIDENCE_DIR/profile" \
  "$EVIDENCE_DIR/queries" \
  "$EVIDENCE_DIR/validation"

log "Coletando profiling do T0..."
capture_sql "sql/03_profile_raw_data.sql" \
  "$EVIDENCE_DIR/profile/profile_raw_data.txt"

capture_sql "sql/04_profile_experiment.sql" \
  "$EVIDENCE_DIR/profile/profile_experiment_t0.txt"

log "Coletando consultas analíticas..."
capture_sql "sql/kimball/06_queries_t0.sql" \
  "$EVIDENCE_DIR/queries/queries_kimball_t0.txt"

capture_sql "sql/data_mart/06_queries_t0.sql" \
  "$EVIDENCE_DIR/queries/queries_data_mart_t0.txt"

log "Coletando validações..."
capture_sql "sql/kimball/05_validate_t0.sql" \
  "$EVIDENCE_DIR/validation/validate_kimball_t0.txt"

capture_sql "sql/data_vault/08_validate_t0.sql" \
  "$EVIDENCE_DIR/validation/validate_data_vault_t0.txt"

capture_sql "sql/data_mart/05_validate_t0.sql" \
  "$EVIDENCE_DIR/validation/validate_data_mart_t0.txt"

capture_sql "sql/08_validate_t0_equivalence.sql" \
  "$EVIDENCE_DIR/validation/validate_t0_equivalence.txt"

log "Registrando ambiente..."

docker --version \
  > "$EVIDENCE_DIR/environment/docker_version.txt" 2>&1

docker compose version \
  > "$EVIDENCE_DIR/environment/docker_compose_version.txt" 2>&1

docker exec "$CONTAINER" \
  psql -X -A -t -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT version();" \
  > "$EVIDENCE_DIR/environment/postgresql_version.txt" 2>&1

docker exec "$CONTAINER" \
  psql -X -U "$DB_USER" -d "$DB_NAME" \
  -c "
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('raw', 'kimball', 'data_vault', 'data_mart', 'control')
  AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;
" > "$EVIDENCE_DIR/environment/database_objects.txt" 2>&1

{
  echo "Estado experimental: T0"
  echo "Coletado em: $(date --iso-8601=seconds)"
  echo "Container: $CONTAINER"
  echo "Banco: $DB_NAME"
  echo "Usuário: $DB_USER"
  echo
  echo "Schemas:"
  echo "- raw"
  echo "- kimball"
  echo "- data_vault"
  echo "- data_mart"
  echo "- control"
  echo
  echo "Fluxos:"
  echo "- Arquitetura A: RAW -> Kimball"
  echo "- Arquitetura B: RAW -> Data Vault -> Data Mart"
} > "$EVIDENCE_DIR/environment/environment.txt"

log "Evidências T0 atualizadas em $EVIDENCE_DIR."
