#!/bin/bash
# Checkpoint 2 — Konfiguracja zmiennych środowiskowych i usług
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 2 — Konfiguracja env i usług"; _print_sep
ERRORS=0

# Zmienne środowiskowe
if [ -n "$PROJECT_ID" ] && [ -n "$REGION" ] && [ -n "$LLM_SERVICE" ] && [ -n "$EMBEDDING_SERVICE" ] \
   && [ -n "$BIGQUERY_DATASET" ] && [ -n "$BIGQUERY_TABLE" ]; then
  _print_ok "Zmienne środowiskowe wczytane (source setup_env.sh)"
else
  _print_fail "Brak zmiennych — uruchom: source setup_env.sh"; ERRORS=$((ERRORS+1))
fi

# Włączone API
ENABLED=$(gcloud services list --enabled --format="value(config.name)" 2>/dev/null)
for API in run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com bigquery.googleapis.com; do
  if echo "$ENABLED" | grep -q "$API"; then _print_ok "API włączone: $API"
  else _print_fail "API wyłączone: $API — uruchom: gcloud services enable $API"; ERRORS=$((ERRORS+1)); fi
done

# Uprawnienie run.invoker
ACCOUNT=$(gcloud config get-value account 2>/dev/null | tr -d '[:space:]')
if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" \
     --filter="bindings.role:roles/run.invoker AND bindings.members:user:${ACCOUNT}" \
     --format="value(bindings.role)" 2>/dev/null | grep -q "run.invoker"; then
  _print_ok "Uprawnienie roles/run.invoker nadane"
else
  _print_fail "Brak roles/run.invoker — nadaj zgodnie z krokiem 2 README"; ERRORS=$((ERRORS+1))
fi

CONTENT="CHECKPOINT_2
region=${REGION}
nick=$(_nick)"
_finish 2 "$ERRORS" "$CONTENT"
