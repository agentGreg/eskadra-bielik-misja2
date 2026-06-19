#!/bin/bash
# Wspólne funkcje checkpointów. NIE uruchamiaj bezpośrednio — sourcowany przez checkpoint_N.sh.

_HEADER_TEXT="Eskadra Bielik - Misja 2 - RAG w oparciu o model Bielik i Google Cloud"
_CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cert_artifacts"

TOTAL_STEPS=9
# Projekt centralny, do którego trafia postęp (tablica na rzutniku). Override: export TRACKING_PROJECT=...
TRACKING_PROJECT="${TRACKING_PROJECT:-agentgreg-bielik-misja2}"

_STEP_LABELS=(
  ""                                  # indeks 0 nieużywany
  "Projekt Google Cloud"
  "Konfiguracja env i usług"
  "Model Bielik (Cloud Run)"
  "Model EmbeddingGemma (Cloud Run)"
  "Wektorowa baza BigQuery"
  "API Orchestration (Cloud Run)"
  "Zasilanie i wyszukiwanie RAG"
  "Przegląd API (/docs)"
  "Interfejs Web UI"
)
_STEP_POINTS=(0 5 10 15 10 10 15 15 5 15)   # suma = 100

_print_sep()  { echo "======================================================"; }
_print_ok()   { echo "  [OK]  $1"; }
_print_fail() { echo "  [!!]  $1"; }

_nick() {
  local n="${WORKSHOP_NICK:-}"
  if [ -z "$n" ] || [ "$n" = "TwojNick" ]; then n="anonim"; fi
  echo "$n" | tr -d '\n' | cut -c1-40
}

# Rejestracja danych do oficjalnego certyfikatu (PII) — RAZ, prywatnym kanałem.
# Nigdy nie trafia na publiczną tablicę. Pomija, jeśli dane nieuzupełnione.
_register_pii() {
  local marker="${_CERT_DIR}/.registered"
  [ -f "$marker" ] && return 0
  local first="${WORKSHOP_FIRST_NAME:-}" last="${WORKSHOP_LAST_NAME:-}" email="${WORKSHOP_EMAIL:-}"
  if [ -z "$first" ] || [ "$first" = "Imię" ]; then
    echo "  Certyfikat: dane nieuzupełnione (uzupełnij imię/nazwisko/email w setup_env.sh)"
    return 0
  fi
  [ -z "$TRACKING_PROJECT" ] && return 0
  [ "$TRACKING_PROJECT" = "disabled" ] && return 0
  local project_id nick msg
  project_id=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
  nick=$(_nick)
  msg=$(printf '{"first_name":"%s","last_name":"%s","email":"%s","nick":"%s","project_id":"%s","timestamp":"%s"}' \
    "$first" "$last" "$email" "$nick" "$project_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
  if gcloud pubsub topics publish "projects/${TRACKING_PROJECT}/topics/certificate-requests" \
       --message="$msg" --quiet >/dev/null 2>&1; then
    mkdir -p "$_CERT_DIR"; touch "$marker"
    echo "  Certyfikat: dane zarejestrowane u prowadzącego"
  fi
}

_earned_points() {
  local sum=0 i
  for i in $(seq 1 $TOTAL_STEPS); do
    [ -f "${_CERT_DIR}/checkpoint_${i}.enc" ] && sum=$(( sum + _STEP_POINTS[i] ))
  done
  echo "$sum"
}

# Publikacja postępu na dashboard (tylko nick — bez PII). Fail-silent: nie blokuje uczestnika.
_publish_progress() {
  local num="$1" project_id nick msg pub_status="pominięto"
  project_id=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
  nick=$(_nick)
  if [ -z "$TRACKING_PROJECT" ] || [ "$TRACKING_PROJECT" = "disabled" ]; then
    echo "  Dashboard: wyłączony (TRACKING_PROJECT=disabled)"; return 0
  fi
  msg=$(printf '{"nick":"%s","checkpoint_num":%d,"total_steps":%d,"project_id":"%s","timestamp":"%s"}' \
    "$nick" "$num" "$TOTAL_STEPS" "$project_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
  if gcloud pubsub topics publish "projects/${TRACKING_PROJECT}/topics/checkpoint-events" \
       --message="$msg" --quiet >/dev/null 2>&1; then
    pub_status="wysłano (nick: ${nick})"
  else
    pub_status="niedostępny (nie blokuje warsztatu)"
  fi
  echo "  Dashboard: $pub_status"
}

# Zapis lokalnego, zaszyfrowanego artefaktu (dowód ukończenia kroku) + publikacja postępu.
_save_artifact() {
  local num="$1" content="$2" project_id account key hashtool
  project_id=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
  account=$(gcloud config get-value account 2>/dev/null | tr -d '[:space:]')
  # Przenośny SHA-512: sha512sum (Linux/Cloud Shell) lub shasum -a 512 (macOS) — ten sam wynik
  hashtool="shasum -a 512"
  command -v sha512sum >/dev/null 2>&1 && hashtool="sha512sum"
  key=$(echo -n "${_HEADER_TEXT}|${project_id}|${account}" | $hashtool | awk '{print $1}')
  mkdir -p "$_CERT_DIR"
  local enc
  enc=$(echo "$content" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass "pass:${key}" -base64 2>/dev/null)
  cat > "${_CERT_DIR}/checkpoint_${num}.enc" <<EOF
PROJECT_ID: ${project_id}
CHECKPOINT: ${num}
TIMESTAMP: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---BEGIN ENCRYPTED---
${enc}
---END ENCRYPTED---
EOF
}

# Domknięcie checkpointu: jeśli brak błędów → zapis + publikacja + komunikat; inaczej exit 1.
_finish() {
  local num="$1" errors="$2" content="$3"
  echo ""
  _print_sep
  if [ "$errors" -gt 0 ]; then
    echo "  CHECKPOINT $num — $errors błąd(ów). Popraw powyższe i uruchom ponownie."
    _print_sep
    exit 1
  fi
  _save_artifact "$num" "$content"
  local earned; earned=$(_earned_points)
  printf "  CHECKPOINT %d ZALICZONY — %s\n" "$num" "${_STEP_LABELS[$num]}"
  printf "  Punkty: +%d  (łącznie %d / 100)\n" "${_STEP_POINTS[$num]}" "$earned"
  _publish_progress "$num"
  _register_pii
  printf "  Artefakt: cert_artifacts/checkpoint_%d.enc\n" "$num"
  _print_sep
}
