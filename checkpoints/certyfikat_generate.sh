#!/bin/bash
# Generowanie certyfikatu ukończenia warsztatu.
# Dane do certyfikatu pochodzą z setup_env.sh (WORKSHOP_FIRST_NAME / LAST_NAME / EMAIL / NICK).
# Dane osobowe trafiają wyłącznie prywatnym kanałem do prowadzącego — NIE na publiczną tablicę.
source "$(dirname "$0")/_common.sh"

# Kolory ANSI (renderują się w terminalu; w potoku po prostu znikają)
C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
C_CYAN=$'\033[0;36m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'; C_TEAL=$'\033[38;5;30m'

_print_sep; echo " CERTYFIKAT — Eskadra Bielika Misja 2"; _print_sep

# 1) Weryfikacja wszystkich checkpointów
MISSING=()
for i in $(seq 1 $TOTAL_STEPS); do
  [ -f "${_CERT_DIR}/checkpoint_${i}.enc" ] || MISSING+=("$i")
done
if [ ${#MISSING[@]} -ne 0 ]; then
  echo "  Brakuje checkpointów: ${MISSING[*]} — uruchom je i spróbuj ponownie."
  _print_sep; exit 1
fi
EARNED=$(_earned_points)
_print_ok "Wszystkie $TOTAL_STEPS checkpointów zaliczone ($EARNED / 100 pkt)"

# 2) Dane z env (z fallbackiem do pytania, gdyby ktoś nie uzupełnił setup_env.sh)
FIRST="${WORKSHOP_FIRST_NAME:-}"; LAST="${WORKSHOP_LAST_NAME:-}"
EMAIL="${WORKSHOP_EMAIL:-}"; NICK="$(_nick)"
[ -z "$FIRST" ] || [ "$FIRST" = "Imię" ] && read -r -p "  Imię: " FIRST
[ -z "$LAST" ]  || [ "$LAST" = "Nazwisko" ] && read -r -p "  Nazwisko: " LAST
[ -z "$EMAIL" ] || [ "$EMAIL" = "email@przyklad.pl" ] && read -r -p "  Email: " EMAIL

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 3) Przekazanie danych prowadzącemu (z finalną punktacją). Idempotentne.
if [ -n "$TRACKING_PROJECT" ] && [ "$TRACKING_PROJECT" != "disabled" ]; then
  MSG=$(printf '{"first_name":"%s","last_name":"%s","email":"%s","nick":"%s","project_id":"%s","points":%s,"timestamp":"%s"}' \
    "$FIRST" "$LAST" "$EMAIL" "$NICK" "$PROJECT_ID" "$EARNED" "$TS")
  if gcloud pubsub topics publish "projects/${TRACKING_PROJECT}/topics/certificate-requests" \
       --message="$MSG" --quiet >/dev/null 2>&1; then
    _print_ok "Dane przekazane prowadzącemu — oficjalny certyfikat wyśle organizator (Bielik AI)"
  else
    _print_fail "Nie udało się przekazać danych (sieć?). Zgłoś prowadzącemu."
  fi
fi

# 4) EFEKT WIEŃCZĄCY — bielik macha skrzydłami, duży napis, podsumowanie, pasek 100%
echo ""
_anim_eagle
echo ""
printf "%b" "$C_BOLD$C_YELLOW"
cat <<'BANNER'
 ██████╗ ██████╗  █████╗ ████████╗██╗   ██╗██╗      █████╗  ██████╗     ██╗███████╗
██╔════╝ ██╔══██╗██╔══██╗╚══██╔══╝██║   ██║██║     ██╔══██╗██╔════╝     ██║██╔════╝
██║  ███╗██████╔╝███████║   ██║   ██║   ██║██║     ███████║██║          ██║█████╗
██║   ██║██╔══██╗██╔══██║   ██║   ██║   ██║██║     ██╔══██║██║     ██   ██║██╔══╝
╚██████╔╝██║  ██║██║  ██║   ██║   ╚██████╔╝███████╗██║  ██║╚██████╗╚█████╔╝███████╗
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚════╝ ╚══════╝
BANNER
printf "%b\n" "$C_RESET"
printf "%s  WARSZTAT ESKADRA BIELIKA — MISJA 2 — UKOŃCZONY!%s\n\n" "$C_BOLD$C_CYAN" "$C_RESET"
printf "  Uczestnik : %s %s  (nick: %s)\n" "$FIRST" "$LAST" "$NICK"
printf "  Projekt   : %s\n" "$PROJECT_ID"
printf "  Data      : %s\n\n" "$TS"
printf "  %sWynik: %d / 100 pkt%s\n" "$C_BOLD$C_GREEN" "$EARNED" "$C_RESET"
printf "  %s\n\n" "$(_draw_bar "$EARNED")"
echo "  Zaliczone kroki:"
for i in $(seq 1 $TOTAL_STEPS); do
  printf "  %s[OK]%s Krok %d  +%2d pkt  %s\n" "$C_GREEN" "$C_RESET" "$i" "${_STEP_POINTS[$i]}" "${_STEP_LABELS[$i]}"
done
echo ""
printf "  %sSuwerenne AI po polsku — Bielik + Google Cloud%s\n" "$C_TEAL" "$C_RESET"
_print_sep

# 5) Lokalny certyfikat (plik tekstowy do wysłania/zachowania)
CERT="${_CERT_DIR}/certyfikat.txt"
cat > "$CERT" <<EOF
============================================================
   ESKADRA BIELIKA — MISJA 2
   Certyfikat ukończenia warsztatu RAG (Bielik + Google Cloud)
------------------------------------------------------------
   Uczestnik : ${FIRST} ${LAST}  (nick: ${NICK})
   Wynik     : ${EARNED} / 100 pkt — wszystkie ${TOTAL_STEPS} kroków
   Projekt   : ${PROJECT_ID}
   Data      : ${TS}
============================================================
EOF
echo ""
_print_ok "Certyfikat lokalny zapisany: cert_artifacts/certyfikat.txt"
echo "  Oficjalny, podpisany certyfikat otrzymasz mailem od organizatora (Bielik AI)."
_print_sep
