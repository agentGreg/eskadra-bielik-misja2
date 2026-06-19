#!/bin/bash
# Checkpoint 8 — Przegląd API (dokumentacja /docs)
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 8 — Przegląd API (/docs)"; _print_sep
ERRORS=0

ORCH_URL=$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -z "$ORCH_URL" ]; then _print_fail "Brak orchestration-api (zalicz checkpoint 6)"; _finish 8 1 ""; fi

CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$ORCH_URL/docs" 2>/dev/null)
if [ "$CODE" = "200" ]; then _print_ok "Dokumentacja /docs dostępna (HTTP 200)"
else _print_fail "/docs niedostępne (HTTP $CODE)"; ERRORS=$((ERRORS+1)); fi

if curl -s --max-time 30 "$ORCH_URL/openapi.json" 2>/dev/null | grep -q '"/ask"'; then
  _print_ok "OpenAPI zawiera endpoint /ask"
else _print_fail "Brak /ask w OpenAPI"; ERRORS=$((ERRORS+1)); fi

CONTENT="CHECKPOINT_8
docs=${ORCH_URL}/docs
nick=$(_nick)"
_finish 8 "$ERRORS" "$CONTENT"
