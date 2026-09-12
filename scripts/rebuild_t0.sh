#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

log "Reconstrução completa do estado T0"

require_file "docker-compose.yaml"
require_dir "data/raw"

# Arquivos RAW necessários para reconstrução do banco.
RAW_FILES=(
  "data/raw/olist_customers_dataset.csv"
  "data/raw/olist_geolocation_dataset.csv"
  "data/raw/olist_order_items_dataset.csv"
  "data/raw/olist_order_payments_dataset.csv"
  "data/raw/olist_order_reviews_dataset.csv"
  "data/raw/olist_orders_dataset.csv"
  "data/raw/olist_products_dataset.csv"
  "data/raw/olist_sellers_dataset.csv"
  "data/raw/product_category_name_translation.csv"
)

for f in "${RAW_FILES[@]}"; do
  require_file "$f"
done

ensure_container_running
wait_for_postgres

log "Removendo schemas do experimento para reconstrução limpa..."
docker exec -i "$CONTAINER" \
  psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" <<'SQL'
DROP SCHEMA IF EXISTS data_mart CASCADE;
DROP SCHEMA IF EXISTS data_vault CASCADE;
DROP SCHEMA IF EXISTS kimball CASCADE;
DROP SCHEMA IF EXISTS control CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
SQL

log "Criando e carregando camada RAW..."
run_sql "sql/00_create_schemas.sql"
run_sql "sql/01_create_raw_tables.sql"
run_sql "sql/02_load_raw_data.sql"

log "Construindo Kimball T0..."
run_sql "sql/kimball/00_create_schema.sql"
run_sql "sql/kimball/01_create_dimensions.sql"
run_sql "sql/kimball/02_create_facts.sql"
run_sql "sql/kimball/03_load_dimensions.sql"
run_sql "sql/kimball/04_load_facts.sql"

log "Construindo Data Vault T0..."
run_sql "sql/data_vault/00_create_schema.sql"
run_sql "sql/data_vault/01_create_hash_functions.sql"
run_sql "sql/data_vault/02_create_hubs.sql"
run_sql "sql/data_vault/03_create_links.sql"
run_sql "sql/data_vault/04_create_satellites.sql"
run_sql "sql/data_vault/05_load_hubs.sql"
run_sql "sql/data_vault/06_load_links.sql"
run_sql "sql/data_vault/07_load_satellites.sql"

log "Construindo Data Mart T0..."
run_sql "sql/data_mart/00_create_schema.sql"
run_sql "sql/data_mart/01_create_dimensions.sql"
run_sql "sql/data_mart/02_create_facts.sql"
run_sql "sql/data_mart/03_load_dimensions.sql"
run_sql "sql/data_mart/04_load_facts.sql"

log "T0 reconstruído com sucesso."
log "Próximo passo recomendado: ./scripts/validate_t0.sh"
