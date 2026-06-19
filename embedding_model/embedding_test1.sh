#!/bin/bash
# Test modelu embeddingowego EmbeddingGemma na Cloud Run.
# Weryfikuje, że zwracany wektor ma poprawny wymiar (powinno być 768).

set -euo pipefail

echo "======================================================"
echo " TEST 1/1 — EmbeddingGemma (Cloud Run)"
echo "======================================================"

# [1/3] URL usługi
echo "[1/3] Pobieram URL usługi '$EMBEDDING_SERVICE'..."
EMBEDDING_SERVICE_URL=$(gcloud run services describe "$EMBEDDING_SERVICE" --region "$REGION" --format="value(status.url)")
echo "      $EMBEDDING_SERVICE_URL"

# [2/3] Token autoryzacyjny
echo "[2/3] Pobieram token identyfikacyjny..."
ID_TOKEN=$(gcloud auth print-identity-token)

# [3/3] Zapytanie
SAMPLE="Przykładowy tekst do zamiany na wektor."
echo "[3/3] Generuję embedding dla: \"$SAMPLE\""
echo "      (pierwsze zapytanie po wdrożeniu = zimny start, może potrwać 30-120 s)"
echo "------------------------------------------------------"

START=$(date +%s)
RESPONSE=$(curl -sS -X POST "$EMBEDDING_SERVICE_URL/api/embed" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"embeddinggemma\",
        \"input\": \"$SAMPLE\"
    }")
END=$(date +%s)

if command -v jq >/dev/null 2>&1; then
    DIM=$(echo "$RESPONSE" | jq -r '.embeddings[0] | length' 2>/dev/null || echo "?")
    echo "Wymiar wektora : $DIM   (oczekiwane: 768)"
    if [ "$DIM" = "768" ]; then
        echo "Status         : OK — model działa poprawnie"
    else
        echo "Status         : UWAGA — nieoczekiwany wymiar. Surowa odpowiedź:"
        echo "$RESPONSE"
    fi
    echo "Pierwsze 5 wartości:"
    echo "$RESPONSE" | jq -c '.embeddings[0][0:5]' 2>/dev/null || true
else
    echo "(jq nie jest zainstalowany — surowa odpowiedź; instalacja: 'apt-get install -y jq' lub 'brew install jq')"
    echo "$RESPONSE"
fi

echo "------------------------------------------------------"
echo "Czas odpowiedzi: $((END - START)) s"
echo "======================================================"
