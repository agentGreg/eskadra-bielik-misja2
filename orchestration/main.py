import os
import csv
import io
import uuid
import requests
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
import google.auth.transport.requests
import google.oauth2.id_token
from google.cloud import bigquery

app = FastAPI(
    title="RAG API (Bielik & EmbeddingGemma)",
    description=(
        "API systemu RAG opartego o model **Bielik** (LLM) i **EmbeddingGemma** "
        "(embeddingi) z wektorową bazą **BigQuery**.\n\n"
        "- **/ask** — pytanie wsparte kontekstem RAG\n"
        "- **/ask_direct** — to samo pytanie wprost do modelu (baseline, bez RAG)\n"
        "- **/ingest**, **/ingest_text** — zasilanie bazy wiedzy\n"
        "- **/records**, **/count** — podgląd zawartości bazy\n\n"
        "Interaktywna dokumentacja: `/docs` (Swagger) oraz `/redoc`."
    ),
    version="1.0.0",
)

# Zapewnij, że katalog static istnieje
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def read_root():
    return FileResponse("static/index.html")

PROJECT_ID = os.environ.get("PROJECT_ID")
DATASET_ID = os.environ.get("BIGQUERY_DATASET", "rag_dataset")
TABLE_ID = os.environ.get("BIGQUERY_TABLE", "hotel_rules")
REGION = os.environ.get("REGION", "europe-west1")
EMBEDDING_URL = os.environ.get("EMBEDDING_URL")
LLM_URL = os.environ.get("LLM_URL")

bq_client = bigquery.Client(project=PROJECT_ID) if PROJECT_ID else None

def get_id_token(audience: str) -> str:
    """Fetch an identity token for the given external Cloud Run URL."""
    try:
        # Pobrane dla lokalnego testowania, jako fallback jeśli jesteśmy w Cloud Run
        request = google.auth.transport.requests.Request()
        token = google.oauth2.id_token.fetch_id_token(request, audience)
        return token
    except Exception as e:
        print(f"Błąd podczas pobierania tokenu za pomocą google.oauth2.id_token dla {audience}: {e}")
        # Próba bezpośredniego pobrania ze spersonalizowanego gcloud auth print-identity-token w środowisku dev
        token = os.popen("gcloud auth print-identity-token").read().strip()
        return token

def get_embedding(text: str) -> list[float]:
    if not EMBEDDING_URL:
        raise ValueError("EMBEDDING_URL variable is not set")
    
    url = f"{EMBEDDING_URL}/api/embed"
    token = get_id_token(EMBEDDING_URL)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "embeddinggemma",
        "input": text
    }
    # timeout=30: embedding jest szybki, ale pierwszy request po wdrożeniu = zimny start Cloud Run
    response = requests.post(url, json=payload, headers=headers, timeout=30)
    response.raise_for_status()
    # Zakładamy odpowiedź z modelem `embed` z Ollama
    return response.json().get("embeddings", [[]])[0]

class AskRequest(BaseModel):
    query: str
    limit: int = 3  # liczba dokumentów kontekstowych (sterowane suwakiem w UI, 1-5)

class IngestTextRequest(BaseModel):
    text: str

@app.post("/ingest")
async def ingest_csv(file: UploadFile = File(...)):
    if not bq_client:
        raise HTTPException(status_code=500, detail="BigQuery client not initialized (missing PROJECT_ID)")
    
    content = await file.read()
    csv_reader = csv.DictReader(io.StringIO(content.decode("utf-8")))
    
    rows_to_insert = []
    
    for row in csv_reader:
        doc_id = row.get("id")
        text = row.get("text")
        
        if not doc_id or not text:
            continue
            
        try:
            embedding = get_embedding(text)
            rows_to_insert.append({
                "id": doc_id,
                "content": text,
                "embedding": embedding
            })
        except Exception as e:
            print(f"Błąd w generowaniu osadzenia dla '{text}': {e}")
            
    if rows_to_insert:
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
        errors = bq_client.insert_rows_json(table_ref, rows_to_insert)
        if errors:
            raise HTTPException(status_code=500, detail=f"Błąd wstawiania do BigQuery: {errors}")
            
    return {"status": "success", "inserted_count": len(rows_to_insert)}

@app.post("/ask")
async def ask_question(request_data: AskRequest):
    if not bq_client:
        raise HTTPException(status_code=500, detail="BigQuery client not initialized (missing PROJECT_ID)")
        
    query = request_data.query
    top_k = max(1, min(request_data.limit, 5))  # ogranicz do bezpiecznego zakresu 1-5

    try:
        query_embedding = get_embedding(query)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd generowania wektora zapytania: {e}")

    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    # Krok 1: Wyszukiwanie Wektorowe w BigQuery
    bq_query = f"""
    SELECT base.content, distance
    FROM VECTOR_SEARCH(
      TABLE `{table_ref}`,
      'embedding',
      (SELECT {query_embedding} as embedding),
      top_k => {top_k},
      distance_type => 'COSINE'
    )
    """
    try:
        query_job = bq_client.query(bq_query)
        results = query_job.result()
        context_docs = []
        context_scores = []
        for row in results:
            context_docs.append(row.content)
            # COSINE distance (0-2) -> podobieństwo (0-1); im wyżej tym trafniej
            context_scores.append(round(max(0.0, 1.0 - row.distance), 4))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd przeszukiwania wektorowego w BigQuery: {e}")
        
    # Krok 2: Przygotowanie Kontekstu i Wiadomości do LLM
    context_text = "\\n\\n".join(context_docs)
    
    prompt = (
        f"Jesteś pomocnym asystentem odpowiadającym na pytania dotyczące zasad hotelowych. "
        f"Odpowiedz na poniższe pytanie bazując TYLKO na dostarczonym kontekście.\\n\\n"
        f"KONTEKST:\\n{context_text}\\n\\n"
        f"PYTANIE:\\n{query}"
    )
    
    if not LLM_URL:
        raise HTTPException(status_code=500, detail="LLM_URL variable is not set")
        
    token = get_id_token(LLM_URL)
    url = f"{LLM_URL}/api/chat"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0",
        "messages": [{"role": "user", "content": prompt}],
        "stream": False
    }
    
    try:
        # timeout=120: generowanie LLM bywa wolne, a pierwszy request po wdrożeniu to zimny start Cloud Run
        response = requests.post(url, json=payload, headers=headers, timeout=120)
        response.raise_for_status()
        answer = response.json().get("message", {}).get("content", "")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd podczas komunikacji z modelem LLM: {e}")
        
    return {
        "answer": answer,
        "context_used": context_docs,
        "context_scores": context_scores
    }

@app.post("/ask_direct")
async def ask_direct(request_data: AskRequest):
    query = request_data.query

    if not LLM_URL:
        raise HTTPException(status_code=500, detail="LLM_URL variable is not set")
        
    token = get_id_token(LLM_URL)
    url = f"{LLM_URL}/api/chat"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    prompt = f"Odpowiedz na poniższe pytanie w sposób jasny i zwięzły:\\n\\nPYTANIE:\\n{query}"
    
    payload = {
        "model": "SpeakLeash/bielik-4.5b-v3.0-instruct:Q8_0",
        "messages": [{"role": "user", "content": prompt}],
        "stream": False
    }
    
    try:
        # timeout=120: generowanie LLM bywa wolne, a pierwszy request po wdrożeniu to zimny start Cloud Run
        response = requests.post(url, json=payload, headers=headers, timeout=120)
        response.raise_for_status()
        answer = response.json().get("message", {}).get("content", "")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd podczas komunikacji z modelem LLM: {e}")
        
    return {
        "answer": answer
    }


@app.get("/health", tags=["Status"], summary="Stan usługi")
def health():
    """Prosty health-check — zwraca status i czy klient BigQuery jest gotowy."""
    return {"status": "ok", "bigquery": bool(bq_client)}


@app.get("/count", tags=["Baza wiedzy"], summary="Liczba reguł w bazie")
def count_records():
    """Zwraca liczbę dokumentów (reguł) w tabeli BigQuery — używane przez licznik w UI."""
    if not bq_client:
        return {"count": 0}
    try:
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
        result = list(bq_client.query(f"SELECT COUNT(*) AS cnt FROM `{table_ref}`").result())
        return {"count": result[0].cnt if result else 0}
    except Exception:
        return {"count": 0}


@app.get("/records", tags=["Baza wiedzy"], summary="Podgląd reguł w bazie")
def list_records(limit: int = 100):
    """Zwraca dokumenty z bazy (id + treść, bez wektora) — wygodny podgląd bez SQL."""
    if not bq_client:
        raise HTTPException(status_code=500, detail="BigQuery client not initialized")
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    safe_limit = max(1, min(limit, 1000))
    try:
        rows = list(bq_client.query(
            f"SELECT id, content FROM `{table_ref}` LIMIT {safe_limit}"
        ).result())
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd pobierania rekordów: {e}")
    return {"total": len(rows), "records": [{"id": r.id, "content": r.content} for r in rows]}


@app.post("/ingest_text", tags=["Baza wiedzy"], summary="Dodaj pojedynczą regułę")
async def ingest_text(data: IngestTextRequest):
    """Dodaje jedną regułę do bazy na żywo: generuje embedding i wstawia do BigQuery."""
    if not bq_client:
        raise HTTPException(status_code=500, detail="BigQuery client not initialized")
    text = data.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Tekst nie może być pusty")
    try:
        embedding = get_embedding(text)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd generowania wektora: {e}")
    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    row_id = str(uuid.uuid4())
    errors = bq_client.insert_rows_json(
        table_ref, [{"id": row_id, "content": text, "embedding": embedding}]
    )
    if errors:
        raise HTTPException(status_code=500, detail=f"Błąd wstawiania do BigQuery: {errors}")
    return {"status": "success", "id": row_id, "text": text}
