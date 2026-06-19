#!/bin/bash
# Wdrożenie modelu Bielik (LLM) na Cloud Run.
#
# Domyślnie używa GOTOWEGO, publicznego obrazu z wpieczonym modelem — uczestnik nie buduje
# obrazu i nie pobiera modelu z ollama.com (szybki, niezawodny start dla całej grupy naraz).
#
# Chcesz zbudować własny obraz ze źródła (Dockerfile w tym katalogu)?
#   export BUILD_FROM_SOURCE=1   przed uruchomieniem tego skryptu.

PREBAKED_IMAGE="${PREBAKED_IMAGE:-europe-west1-docker.pkg.dev/agentgreg-bielik-misja2/bielik-public/bielik:latest}"

if [ "${BUILD_FROM_SOURCE:-0}" = "1" ]; then
  SRC_ARGS=(--source .)
  echo "Tryb: budowanie obrazu ze źródła (Dockerfile)"
else
  SRC_ARGS=(--image "$PREBAKED_IMAGE")
  echo "Tryb: gotowy obraz publiczny ($PREBAKED_IMAGE)"
fi

gcloud run deploy "$LLM_SERVICE" \
  "${SRC_ARGS[@]}" \
  --region "$REGION" \
  --concurrency 4 \
  --cpu 8 \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --no-allow-unauthenticated \
  --no-cpu-throttling \
  --no-gpu-zonal-redundancy \
  --set-env-vars OLLAMA_NUM_PARALLEL=4 \
  --max-instances 1 \
  --memory 16Gi \
  --timeout=600 \
  --labels dev-tutorial=dos-codelab-bielik-rag
