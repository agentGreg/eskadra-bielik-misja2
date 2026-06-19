#!/bin/bash
# Checkpoint 5 — Wektorowa baza danych w BigQuery
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 5 — Wektorowa baza BigQuery"; _print_sep
ERRORS=0

if bq show --format=none "$PROJECT_ID:$BIGQUERY_DATASET" >/dev/null 2>&1; then
  _print_ok "Dataset istnieje: $BIGQUERY_DATASET"
else _print_fail "Brak datasetu — uruchom: cd vector_store && python init_db.py"; ERRORS=$((ERRORS+1)); fi

if bq show --format=none "$PROJECT_ID:$BIGQUERY_DATASET.$BIGQUERY_TABLE" >/dev/null 2>&1; then
  _print_ok "Tabela istnieje: $BIGQUERY_TABLE"
else _print_fail "Brak tabeli — uruchom: cd vector_store && python init_db.py"; ERRORS=$((ERRORS+1)); fi

CONTENT="CHECKPOINT_5
dataset=${BIGQUERY_DATASET}
table=${BIGQUERY_TABLE}
nick=$(_nick)"
_finish 5 "$ERRORS" "$CONTENT"
