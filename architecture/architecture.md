# Architektura systemu RAG — Eskadra Bielika Misja 2

Interaktywną wersję tego diagramu znajdziesz w aplikacji: zakładka **Architektura**
w Web UI (`/`), albo bezpośrednio pod `/static/architecture.html`.

## Komponenty

| Komponent | Rola | Gdzie działa |
|-----------|------|--------------|
| **Web UI** (`static/index.html`) | interfejs, porównanie baseline vs RAG | serwowany przez FastAPI |
| **FastAPI** (`main.py`) | orkiestracja: embedding → wyszukiwanie → LLM | Cloud Run `orchestration-api` |
| **EmbeddingGemma** | tekst → wektor (768 wymiarów) | Cloud Run `embedding-gemma` |
| **BigQuery Vector Search** | semantyczne wyszukiwanie kontekstu (COSINE) | BigQuery `rag_dataset.hotel_rules` |
| **Bielik LLM** | generowanie odpowiedzi w języku polskim | Cloud Run `bielik` (GPU) |

## Przepływ 1 — Zapytanie RAG (`POST /ask`)
1. Użytkownik → Web UI: pytanie + suwak liczby dokumentów (1–5).
2. Web UI → FastAPI: `POST /ask {query, limit}`.
3. FastAPI → EmbeddingGemma: tekst → wektor 768D.
4. FastAPI → BigQuery: `VECTOR_SEARCH(..., top_k => limit, COSINE)`.
5. FastAPI → Bielik: prompt zbudowany z odnalezionego kontekstu.
6. FastAPI → Web UI: `answer`, `context_used`, `context_scores` (trafność 0–100%).

## Przepływ 2 — Baseline (`POST /ask_direct`)
Pytanie trafia wprost do Bielika, z pominięciem RAG — do porównania jakości odpowiedzi.

## Przepływ 3 — Zasilanie bazy (`POST /ingest_text`, `POST /ingest`)
Treść reguły → embedding (EmbeddingGemma) → zapis `{id, content, embedding}` do BigQuery.
`/ingest` przyjmuje plik CSV (kolumny `id`, `text`); `/ingest_text` — pojedynczą regułę na żywo z UI.

## Endpointy pomocnicze
- `GET /health` — stan usługi.
- `GET /count` — liczba reguł w bazie (licznik w UI).
- `GET /records?limit=N` — podgląd reguł bez SQL.
- `/docs`, `/redoc` — interaktywna dokumentacja OpenAPI.
