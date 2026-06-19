#!/bin/bash
# Checkpoint 7 — Zasilanie bazy i wyszukiwanie RAG
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 7 — Zasilanie i wyszukiwanie RAG"; _print_sep
ERRORS=0

ORCH_URL=$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -z "$ORCH_URL" ]; then _print_fail "Brak orchestration-api (zalicz checkpoint 6)"; _finish 7 1 ""; fi

CNT=$(curl -s --max-time 30 "$ORCH_URL/count" 2>/dev/null | (command -v jq >/dev/null 2>&1 && jq -r '.count' || cat))
if [ -n "$CNT" ] && [ "$CNT" != "0" ] && [ "$CNT" != "null" ]; then _print_ok "Baza zasilona ($CNT reguł)"
else _print_fail "Baza pusta — zasil: curl -X POST \"$ORCH_URL/ingest\" -F \"file=@vector_store/hotel_rules.csv\""; ERRORS=$((ERRORS+1)); fi

ANS=$(curl -s --max-time 120 -H "Content-Type: application/json" \
  -d '{"query":"O ktorej godzinie jest sniadanie?","limit":3}' "$ORCH_URL/ask" 2>/dev/null)
if echo "$ANS" | grep -q '"context_used"'; then _print_ok "RAG /ask zwraca odpowiedź z kontekstem"
else _print_fail "/ask nie zwrócił kontekstu — sprawdź modele i bazę"; ERRORS=$((ERRORS+1)); fi

CONTENT="CHECKPOINT_7
count=${CNT}
nick=$(_nick)"
_finish 7 "$ERRORS" "$CONTENT"
