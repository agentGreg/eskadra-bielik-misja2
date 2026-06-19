#!/bin/bash
# Checkpoint 6 — API Orchestration na Cloud Run
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 6 — API Orchestration (Cloud Run)"; _print_sep
ERRORS=0

ORCH_URL=$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$ORCH_URL" ]; then _print_ok "Usługa orchestration-api wdrożona: $ORCH_URL"
else _print_fail "Brak usługi — wdróż: cd orchestration && ./cloud_run.sh"; ERRORS=$((ERRORS+1)); fi

if [ -n "$ORCH_URL" ]; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$ORCH_URL/health" 2>/dev/null)
  if [ "$CODE" = "200" ]; then _print_ok "Endpoint /health odpowiada (HTTP 200)"
  else _print_fail "/health nie odpowiada (HTTP $CODE)"; ERRORS=$((ERRORS+1)); fi
fi

CONTENT="CHECKPOINT_6
orch_url=${ORCH_URL}
nick=$(_nick)"
_finish 6 "$ERRORS" "$CONTENT"
