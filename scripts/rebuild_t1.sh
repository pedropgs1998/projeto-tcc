#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo
echo "============================================================"
echo "Reconstrução completa do estado T1"
echo "============================================================"
echo

"$SCRIPT_DIR/rebuild_t0.sh"

echo
echo "============================================================"
echo "Baseline T0 reconstruído"
echo "Aplicando M1 para alcançar T1"
echo "============================================================"
echo

"$SCRIPT_DIR/apply_t1.sh"

echo
echo "============================================================"
echo "Executando validações T1"
echo "============================================================"
echo

"$SCRIPT_DIR/validate_t1.sh"

echo
echo "============================================================"
echo "Estado T1 reconstruído e validado com sucesso"
echo "============================================================"