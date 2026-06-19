#!/bin/bash

# Sprawdza, czy wszystkie komponenty warsztatu są gotowe do pracy.
# Uruchom po wdrożeniu wszystkich usług na Cloud Run.
#
# Użycie: bash preflight_check.sh

echo ""
echo "=== Sprawdzanie srodowiska Google Cloud ==="
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "OK" ]; then
        echo "  [OK]   $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
}

# 1. Zmienne srodowiskowe
if [ -n "$PROJECT_ID" ] && [ -n "$REGION" ] && [ -n "$LLM_SERVICE" ] && [ -n "$EMBEDDING_SERVICE" ]; then
    check "Zmienne srodowiskowe (source setup_env.sh)" "OK"
else
    check "Zmienne srodowiskowe (source setup_env.sh)" "FAIL"
    echo "         Uruchom: source setup_env.sh"
    echo ""
    echo "=== Nie mozna kontynuowac bez zmiennych srodowiskowych ==="
    exit 1
fi

# 2. Projekt Google Cloud
PROJECT_CHECK=$(gcloud config get-value project 2>/dev/null)
if [ -n "$PROJECT_CHECK" ]; then
    check "Projekt Google Cloud ($PROJECT_CHECK)" "OK"
else
    check "Projekt Google Cloud" "FAIL"
fi

# 3. Usluga Bielik (LLM)
LLM_URL=$(gcloud run services describe "$LLM_SERVICE" --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$LLM_URL" ]; then
    check "Cloud Run: $LLM_SERVICE ($LLM_URL)" "OK"
else
    check "Cloud Run: $LLM_SERVICE" "FAIL"
    echo "         Wdroz: cd llm && ./cloud_run.sh"
fi

# 4. Usluga EmbeddingGemma
EMB_URL=$(gcloud run services describe "$EMBEDDING_SERVICE" --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$EMB_URL" ]; then
    check "Cloud Run: $EMBEDDING_SERVICE ($EMB_URL)" "OK"
else
    check "Cloud Run: $EMBEDDING_SERVICE" "FAIL"
    echo "         Wdroz: cd embedding_model && ./cloud_run.sh"
fi

# 5. Usluga Orchestration
ORCH_URL=$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)" 2>/dev/null)
if [ -n "$ORCH_URL" ]; then
    check "Cloud Run: orchestration-api ($ORCH_URL)" "OK"
else
    check "Cloud Run: orchestration-api" "FAIL"
    echo "         Wdroz: cd orchestration && ./cloud_run.sh"
fi

# 6. BigQuery dataset
if bq show --format=none "$PROJECT_ID:$BIGQUERY_DATASET" >/dev/null 2>&1; then
    check "BigQuery dataset: $BIGQUERY_DATASET" "OK"
else
    check "BigQuery dataset: $BIGQUERY_DATASET" "FAIL"
    echo "         Uruchom: cd vector_store && python init_db.py"
fi

# 7. BigQuery table
if bq show --format=none "$PROJECT_ID:$BIGQUERY_DATASET.$BIGQUERY_TABLE" >/dev/null 2>&1; then
    check "BigQuery tabela: $BIGQUERY_TABLE" "OK"
else
    check "BigQuery tabela: $BIGQUERY_TABLE" "FAIL"
    echo "         Uruchom: cd vector_store && python init_db.py"
fi

# 8. Test polaczenia z Orchestration (jesli wdrozona)
if [ -n "$ORCH_URL" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ORCH_URL/" --max-time 10 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        check "Orchestration odpowiada (HTTP 200)" "OK"
    else
        check "Orchestration odpowiada (HTTP $HTTP_CODE)" "FAIL"
        echo "         Sprawdz logi: gcloud run services logs read orchestration-api --region $REGION"
    fi
fi

echo ""
echo "=== Wynik: $PASS OK, $FAIL FAIL ==="

if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo "Wszystko gotowe! Otworz w przegladarce:"
    echo "  $ORCH_URL"
    echo ""
    echo "Jesli baza jest pusta, zasil ja danymi:"
    echo "  export ORCHESTRATION_URL=$ORCH_URL"
    echo "  curl -X POST \"\$ORCHESTRATION_URL/ingest\" -F \"file=@vector_store/hotel_rules.csv\""
fi
echo ""
