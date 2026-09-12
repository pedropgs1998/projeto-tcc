#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

log "Aplicando T1 / M1 - fonte de pagamentos"

ensure_container_running
wait_for_postgres


log "1/6 - Profiling da fonte de pagamentos"

run_sql "$ROOT_DIR/sql/t1_m1/00_profile_m1.sql"


log "2/6 - Kimball T1 - criação da fact_payment"

run_sql "$ROOT_DIR/sql/t1_m1/kimball/00_create_fact_payment.sql"


log "3/6 - Kimball T1 - carga da fact_payment"

run_sql "$ROOT_DIR/sql/t1_m1/kimball/01_load_fact_payment.sql"


log "4/6 - Data Vault T1 - criação do SAT_ORDER_PAYMENT"

run_sql "$ROOT_DIR/sql/t1_m1/data_vault/00_create_sat_order_payment.sql"


log "5/6 - Data Vault T1 - carga do SAT_ORDER_PAYMENT"

run_sql "$ROOT_DIR/sql/t1_m1/data_vault/01_load_sat_order_payment.sql"


log "6/6 - Data Mart T1 - criação e carga da fact_payment"

run_sql "$ROOT_DIR/sql/t1_m1/data_mart/00_create_fact_payment.sql"
run_sql "$ROOT_DIR/sql/t1_m1/data_mart/01_load_fact_payment.sql"


log "T1 / M1 aplicado com sucesso"

echo
echo "Próximo passo recomendado:"
echo "./scripts/validate_t1.sh"