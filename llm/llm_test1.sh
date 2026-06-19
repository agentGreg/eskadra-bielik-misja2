#!/bin/bash
# Test modelu LLM Bielik na Cloud Run.
# Wyświetla sformatowaną odpowiedź + czas (czy GPU działa, czy zimny start).

set -euo pipefail

echo "======================================================"
echo " TEST 1/1 — Bielik LLM (Cloud Run)"
echo "======================================================"

# [1/3] URL usługi
echo "[1/3] Pobieram URL usługi '$LLM_SERVICE'..."
LLM_SERVICE_URL=$(gcloud run services describe "$LLM_SERVICE" --region "$REGION" --format="value(status.url)")
echo "      $LLM_SERVICE_URL"

# [2/3] Token autoryzacyjny
echo "[2/3] Pobieram token identyfikacyjny..."
ID_TOKEN=$(gcloud auth print-identity-token)

# [3/3] Zapytanie
QUESTION="Jak często powinien być mierzony poziom chloru w basenie?"
echo "[3/3] Wysyłam pytanie: \"$QUESTION\""
echo "      (pierwsze zapytanie po wdrożeniu = zimny start, może potrwać 30-120 s)"
echo "------------------------------------------------------"

START=$(date +%s)
RESPONSE=$(curl -sS -X POST "$LLM_SERVICE_URL/api/chat" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0\",
        \"messages\": [{ \"role\": \"user\", \"content\": \"$QUESTION\" }],
        \"stream\": false
    }")
END=$(date +%s)

if command -v jq >/dev/null 2>&1; then
    echo "Odpowiedź modelu:"
    echo "$RESPONSE" | jq -r '.message.content // "(brak pola .message.content — pełna odpowiedź poniżej)"'
    echo "$RESPONSE" | jq -e '.message.content' >/dev/null 2>&1 || echo "$RESPONSE"
else
    echo "(jq nie jest zainstalowany — surowa odpowiedź; instalacja: 'apt-get install -y jq' lub 'brew install jq')"
    echo "$RESPONSE"
fi

echo "------------------------------------------------------"
echo "Czas odpowiedzi: $((END - START)) s"
echo "======================================================"
