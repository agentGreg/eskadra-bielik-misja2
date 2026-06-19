#!/bin/bash
# Checkpoint 9 — Interfejs Web UI
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 9 — Interfejs Web UI"; _print_sep
ERRORS=0

ORCH_URL=$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -z "$ORCH_URL" ]; then _print_fail "Brak orchestration-api (zalicz checkpoint 6)"; _finish 9 1 ""; fi

HTML=$(curl -s --max-time 30 "$ORCH_URL/" 2>/dev/null)
if echo "$HTML" | grep -qi "Bielik"; then _print_ok "Web UI serwuje stronę (zawiera 'Bielik')"
else _print_fail "Web UI nie zwróciło oczekiwanej strony"; ERRORS=$((ERRORS+1)); fi

echo ""
echo "  Gratulacje! To ostatni krok. Wygeneruj certyfikat:"
echo "    ./checkpoints/certyfikat_generate.sh"

CONTENT="CHECKPOINT_9
web_ui=${ORCH_URL}/
nick=$(_nick)"
_finish 9 "$ERRORS" "$CONTENT"
