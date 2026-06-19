#!/bin/bash
# Checkpoint 4 — Model EmbeddingGemma na Cloud Run
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 4 — Model EmbeddingGemma (Cloud Run)"; _print_sep
ERRORS=0

EMB_URL=$(gcloud run services describe "${EMBEDDING_SERVICE:-embedding-gemma}" --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$EMB_URL" ]; then _print_ok "Usługa ${EMBEDDING_SERVICE:-embedding-gemma} wdrożona: $EMB_URL"
else _print_fail "Brak usługi — wdróż: cd embedding_model && ./cloud_run.sh"; ERRORS=$((ERRORS+1)); fi

DIM=""
if [ -n "$EMB_URL" ]; then
  RESP=$(curl -s --max-time 120 -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
    -H "Content-Type: application/json" -d '{"model":"embeddinggemma","input":"test"}' "$EMB_URL/api/embed" 2>/dev/null)
  if command -v jq >/dev/null 2>&1; then DIM=$(echo "$RESP" | jq -r '.embeddings[0]|length' 2>/dev/null); fi
  if [ "$DIM" = "768" ]; then _print_ok "Embedding ma poprawny wymiar (768)"
  elif [ -n "$RESP" ]; then _print_ok "Usługa odpowiada (wymiar: ${DIM:-?})"
  else _print_fail "Brak odpowiedzi z modelu embeddingowego"; ERRORS=$((ERRORS+1)); fi
fi

CONTENT="CHECKPOINT_4
emb_url=${EMB_URL}
dim=${DIM}
nick=$(_nick)"
_finish 4 "$ERRORS" "$CONTENT"
