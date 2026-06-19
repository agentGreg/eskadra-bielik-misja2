#!/bin/bash

# Ustawienie zmiennych środowiskowych
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export EMBEDDING_SERVICE="embedding-gemma"
export LLM_SERVICE="bielik"
export BIGQUERY_DATASET="rag_dataset"
export BIGQUERY_TABLE="hotel_rules"

# ============================================================
#  UZUPEŁNIJ SWOJE DANE  — edytuj 4 linie poniżej, potem zapisz
# ============================================================
export WORKSHOP_NICK="TwojNick"              # nick na TABLICĘ na rzutniku (widoczny publicznie)
export WORKSHOP_FIRST_NAME="Imię"            # do OFICJALNEGO certyfikatu (NIE trafia na tablicę)
export WORKSHOP_LAST_NAME="Nazwisko"         # do certyfikatu
export WORKSHOP_EMAIL="email@przyklad.pl"    # do certyfikatu
# ============================================================
# Projekt centralny prowadzącego (postęp). Ustaw "disabled" aby nie wysyłać na tablicę.
export TRACKING_PROJECT="${TRACKING_PROJECT:-agentgreg-bielik-misja2}"

echo "Wczytano zmienne środowiskowe"
if [ "$WORKSHOP_NICK" = "TwojNick" ] || [ -z "$WORKSHOP_NICK" ]; then
  echo "  UWAGA: nie ustawiłeś swoich danych. Edytuj setup_env.sh (nick, imię, nazwisko, email),"
  echo "         zapisz i uruchom ponownie: source setup_env.sh"
else
  echo "  Nick na tablicy: $WORKSHOP_NICK   |   Certyfikat: $WORKSHOP_FIRST_NAME $WORKSHOP_LAST_NAME"
fi