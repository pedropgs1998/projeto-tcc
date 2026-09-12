#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_container_running
wait_for_postgres

log "Validando Kimball T0..."
run_sql "sql/kimball/05_validate_t0.sql"

log "Validando Data Vault T0..."
run_sql "sql/data_vault/08_validate_t0.sql"

log "Validando Data Mart T0..."
run_sql "sql/data_mart/05_validate_t0.sql"

log "Validando equivalência analítica Kimball x Data Mart..."
run_sql "sql/08_validate_t0_equivalence.sql"

log "Todas as validações T0 foram executadas sem erro de SQL."
