#!/bin/bash
set -e

# Usuwa zasoby utworzone podczas warsztatu (Cloud Run + BigQuery).
# Uruchom PO zakończeniu warsztatu, aby uniknąć niepotrzebnych kosztów.
#
# Użycie:
#   source setup_env.sh
#   bash cleanup.sh
#
# UWAGA o kosztach: usługi LLM i Embedding korzystają z GPU (NVIDIA L4).
# Cloud Run skaluje się do zera, gdy nikt ich nie odpytuje, więc w trybie idle
# zwykle nie generują kosztu — ale jeśli ustawiono min-instances > 0 lub usługa
# jest pod ciągłym obciążeniem, GPU to realny wydatek (rzędu kilku USD/godzinę).
# Ten skrypt usuwa usługi całkowicie, żeby mieć pewność.

if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
    echo "[FAIL] Brak zmiennych srodowiskowych. Uruchom najpierw: source setup_env.sh"
    exit 1
fi

echo ""
echo "!!! UWAGA: Ten skrypt NIEODWRACALNIE usuwa zasoby w projekcie: $PROJECT_ID !!!"
echo ""
read -r -p "Kontynuowac? Wpisz 'tak' aby potwierdzic: " CONFIRM
if [ "$CONFIRM" != "tak" ]; then
    echo "Anulowano."
    exit 0
fi

echo ""
echo "=== Usuwanie uslug Cloud Run ==="
SERVICES=("orchestration-api" "${EMBEDDING_SERVICE:-embedding-gemma}" "${LLM_SERVICE:-bielik}")
for SVC in "${SERVICES[@]}"; do
    if gcloud run services describe "$SVC" --region "$REGION" --format="value(status.url)" >/dev/null 2>&1; then
        echo "  Usuwanie Cloud Run: $SVC..."
        gcloud run services delete "$SVC" --region "$REGION" --quiet
        echo "  [OK] Usunieto $SVC"
    else
        echo "  [--] $SVC nie istnieje"
    fi
done

echo ""
echo "=== Usuwanie BigQuery ==="
DATASET="${BIGQUERY_DATASET:-rag_dataset}"
if bq show --format=none "$PROJECT_ID:$DATASET" >/dev/null 2>&1; then
    echo "  Usuwanie BigQuery dataset: $DATASET (wraz z tabelami)..."
    bq rm -r -f "$PROJECT_ID:$DATASET"
    echo "  [OK] Usunieto dataset $DATASET"
else
    echo "  [--] Dataset $DATASET nie istnieje"
fi

echo ""
echo "  Uwaga: obrazy zbudowane podczas wdrozenia pozostaja w Artifact Registry"
echo "  (staly koszt ~\$0.01/mies.). Aby je obejrzec / usunac:"
echo "    gcloud artifacts docker images list $REGION-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy"
echo ""
echo "=== Sprzatanie zakonczone ==="
echo ""
