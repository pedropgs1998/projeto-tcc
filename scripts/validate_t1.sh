#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

ensure_container_running
wait_for_postgres


log "Validando Kimball T1"

run_sql "$ROOT_DIR/sql/t1_m1/kimball/02_validate_t1.sql"


log "Validando Data Vault T1"

run_sql "$ROOT_DIR/sql/t1_m1/data_vault/02_validate_t1.sql"


log "Validando Data Mart T1"

run_sql "$ROOT_DIR/sql/t1_m1/data_mart/02_validate_t1.sql"


log "Validando equivalência Kimball x Data Mart"

run_sql "$ROOT_DIR/sql/t1_m1/validation/00_validate_t1_equivalence.sql"


log "Validação T1 concluída"