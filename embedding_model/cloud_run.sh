#!/bin/bash
# Wdrożenie modelu EmbeddingGemma na Cloud Run.
#
# Domyślnie używa GOTOWEGO, publicznego obrazu z wpieczonym modelem (bez budowania).
# Chcesz zbudować własny obraz ze źródła? export BUILD_FROM_SOURCE=1 przed uruchomieniem.

PREBAKED_IMAGE="${PREBAKED_IMAGE:-europe-west1-docker.pkg.dev/agentgreg-bielik-misja2/bielik-public/embedding-gemma:latest}"

if [ "${BUILD_FROM_SOURCE:-0}" = "1" ]; then
  SRC_ARGS=(--source .)
  echo "Tryb: budowanie obrazu ze źródła (Dockerfile)"
else
  SRC_ARGS=(--image "$PREBAKED_IMAGE")
  echo "Tryb: gotowy obraz publiczny ($PREBAKED_IMAGE)"
fi

gcloud run deploy "$EMBEDDING_SERVICE" \
  "${SRC_ARGS[@]}" \
  --region "$REGION" \
  --concurrency 4 \
  --cpu 8 \
  --no-allow-unauthenticated \
  --set-env-vars OLLAMA_NUM_PARALLEL=4 \
  --max-instances 1 \
  --memory 8Gi \
  --timeout=600 \
  --labels dev-tutorial=dos-codelab-bielik-rag
