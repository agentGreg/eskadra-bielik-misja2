#!/bin/bash
# Checkpoint 1 — Projekt Google Cloud
source "$(dirname "$0")/_common.sh"
_print_sep; echo " CHECKPOINT 1 — Projekt Google Cloud"; _print_sep
ERRORS=0

ACCOUNT=$(gcloud config get-value account 2>/dev/null | tr -d '[:space:]')
if [ -n "$ACCOUNT" ] && [ "$ACCOUNT" != "(unset)" ]; then _print_ok "Konto: $ACCOUNT"
else _print_fail "Brak zalogowanego konta. Uruchom: gcloud auth login"; ERRORS=$((ERRORS+1)); fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "(unset)" ]; then _print_ok "Projekt: $PROJECT_ID"
else _print_fail "Brak projektu. Uruchom: gcloud config set project <ID>"; ERRORS=$((ERRORS+1)); fi

BILLING=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || true)
if [ "$BILLING" = "True" ]; then _print_ok "Billing aktywny"
else _print_fail "Billing nieaktywny — aktywuj kredyt OnRamp i powiąż z projektem"; ERRORS=$((ERRORS+1)); fi

CONTENT="CHECKPOINT_1
project_id=${PROJECT_ID}
account=${ACCOUNT}
billing=${BILLING}
nick=$(_nick)"
_finish 1 "$ERRORS" "$CONTENT"
