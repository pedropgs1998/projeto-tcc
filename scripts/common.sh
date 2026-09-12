#!/usr/bin/env bash
set -euo pipefail

# Diretório raiz do projeto (scripts/ fica diretamente abaixo da raiz).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTAINER="${CONTAINER:-tcc-postgres}"
DB_NAME="${DB_NAME:-olist_dw}"
DB_USER="${DB_USER:-olist_dw}"

cd "$ROOT_DIR"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "ERRO: arquivo não encontrado: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [[ ! -d "$1" ]]; then
    echo "ERRO: diretório não encontrado: $1" >&2
    exit 1
  fi
}

ensure_container_running() {
  if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q '^true$'; then
    log "Subindo ambiente Docker definido em docker-compose.yaml..."
    docker compose up -d
  fi
}

wait_for_postgres() {
  log "Aguardando PostgreSQL ficar disponível..."
  for _ in {1..60}; do
    if docker exec "$CONTAINER" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "ERRO: PostgreSQL não ficou disponível em até 60 segundos." >&2
  exit 1
}

run_sql() {
  local file="$1"
  require_file "$file"

  log "Executando $file"
  docker exec -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    < "$file"
}

capture_sql() {
  local file="$1"
  local output="$2"
  require_file "$file"

  mkdir -p "$(dirname "$output")"

  log "Executando $file -> $output"
  docker exec -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    < "$file" \
    > "$output" 2>&1
}
