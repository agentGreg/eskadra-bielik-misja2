#!/bin/bash
# Checkpoint 3 — Model Bielik (LLM) na Cloud Run
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 3 — Model Bielik (Cloud Run)"; _print_sep
ERRORS=0

LLM_URL=$(gcloud run services describe "${LLM_SERVICE:-bielik}" --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$LLM_URL" ]; then _print_ok "Usługa ${LLM_SERVICE:-bielik} wdrożona: $LLM_URL"
else _print_fail "Brak usługi ${LLM_SERVICE:-bielik} — wdróż: cd llm && ./cloud_run.sh"; ERRORS=$((ERRORS+1)); fi

if [ -n "$LLM_URL" ]; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 120 \
    -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$LLM_URL/" 2>/dev/null)
  if [ "$CODE" = "200" ]; then _print_ok "Usługa odpowiada (HTTP 200)"
  else _print_fail "Usługa nie odpowiada (HTTP $CODE) — sprawdź logi / zimny start"; ERRORS=$((ERRORS+1)); fi
fi

CONTENT="CHECKPOINT_3
llm_url=${LLM_URL}
nick=$(_nick)"
_finish 3 "$ERRORS" "$CONTENT"
