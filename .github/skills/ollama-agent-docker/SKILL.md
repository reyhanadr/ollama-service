---
name: ollama-agent-docker
description: 'Docker Compose setup for LangChain/LangGraph AI agents that need Ollama (chat or embedding). Use when: creating docker compose untuk AI agent, agent AI dengan LangChain/LangGraph, service embedding Ollama, container AI agent, docker compose agent, integrasi Ollama shared service. DO NOT embed Ollama directly in agent compose — always use the shared Ollama service via external network ollama-net.'
argument-hint: '[agent-name] [framework: langchain|langgraph]'
---

# Ollama Agent Docker — Shared Service Pattern

Skill ini memandu pembuatan `docker-compose.yml` untuk **AI agent** berbasis LangChain / LangGraph yang membutuhkan **Ollama** (chat dan/atau embedding). Selalu gunakan **shared Ollama service** — jangan embed Ollama langsung di compose agent.

---

## When to Use

| Trigger | Action |
|---|---|
| User minta buat docker compose untuk AI agent | Gunakan skill ini |
| Agent pakai LangChain / LangGraph | Gunakan skill ini |
| Agent butuh Ollama (chat/embedding) | **Jangan embed Ollama** — sambungkan ke shared service |
| Agent tidak butuh Ollama (pakai OpenAI/Groq/dll) | Abaikan aturan Ollama, tetap ikuti struktur compose |

---

## Architecture Rule

```
┌──────────────────────────────────────────────┐
│  Shared Ollama Service (Infrastructure/)     │
│  Network: ollama-net                         │
│  Hostname: ollama                            │
│  Port:     11434                             │
└──────────────┬───────────────────────────────┘
               │ external network
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐
│Agent A │ │Agent B │ │Agent C │
│compose │ │compose │ │compose │
└────────┘ └────────┘ └────────┘
```

> ⚠️ **Hard rule**: JANGAN buat service `ollama` di dalam `docker-compose.yml` agent. Selalu gunakan external network `ollama-net` dan arahkan `OLLAMA_BASE_URL=http://ollama:11434`.

---

## Procedure

### Step 1 — Identifikasi Kebutuhan Agent

Tanyakan / identifikasi:

| Pertanyaan | Jawaban menentukan |
|---|---|
| Framework? | LangChain → `langchain-ollama`, LangGraph → `langgraph` |
| Model LLM? | Ollama (`ChatOllama`) atau cloud (`ChatOpenAI`, dll) |
| Model Embedding? | Ollama (`OllamaEmbeddings`) atau cloud |
| Ada service tambahan? | PostgreSQL, Redis, Qdrant, Milvus, dll |
| GPU? | Apakah perlu GPU passthrough |

### Step 2 — Tentukan Apakah Perlu Shared Ollama

```
Agent pakai Ollama?
├─ Chat model → Ya → OLLAMA_BASE_URL=http://ollama:11434
├─ Embedding  → Ya → OLLAMA_BASE_URL=http://ollama:11434
└─ Tidak      → Tidak perlu network ollama-net
```

Jika **Ya**: agent compose HARUS menyertakan `networks: [ollama-net]` sebagai external network.

### Step 3 — Buat Struktur Project Agent

Buat file-file berikut di project agent:

```
<agent-project>/
├── .env                       # Environment variables agent
├── .env.example               # Template (tanpa secrets)
├── docker-compose.yml         # Agent compose (NO ollama service!)
├── Dockerfile                 # Agent image
├── requirements.txt           # Python dependencies
├── src/
│   └── agent.py               # Agent code
└── README.md
```

### Step 4 — Tulis docker-compose.yml Agent

Gunakan template berikut. Ganti placeholder `<...>`:

```yaml
services:
  <agent-name>:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: <agent-name>
    restart: unless-stopped
    ports:
      - "<host-port>:<container-port>"
    env_file:
      - .env
    environment:
      # Ollama — arahkan ke shared service (BUKAN localhost!)
      - OLLAMA_BASE_URL=http://ollama:11434
      # Model yang digunakan (harus sudah di-pull di shared Ollama)
      - LLM_MODEL=${LLM_MODEL:-llama3.2:3b}
      - EMBEDDING_MODEL=${EMBEDDING_MODEL:-nomic-embed-text}
    networks:
      - ollama-net
    depends_on:
      ollama:
        condition: service_healthy
        required: false  # Ollama ada di compose terpisah

  # --- Service tambahan (hanya jika diperlukan) ---
  # postgres:
  #   image: pgvector/pgvector:pg17
  #   ...

networks:
  ollama-net:
    external: true  # ⬅️ Kunci: gunakan network yang sudah dibuat Ollama
```

### Step 5 — Tulis Dockerfile Agent

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY src/ ./src/

# Run agent
CMD ["python", "-m", "src.agent"]
```

### Step 6 — Tulis requirements.txt

```text
# Core
langchain>=0.3.0
langchain-ollama>=0.2.0
langgraph>=0.2.0

# Utilities
python-dotenv>=1.0.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
```

### Step 7 — Tulis .env.example Agent

```bash
# Ollama (shared service)
OLLAMA_BASE_URL=http://ollama:11434
LLM_MODEL=llama3.2:3b
EMBEDDING_MODEL=nomic-embed-text

# Agent config
AGENT_PORT=8000
LOG_LEVEL=INFO
```

### Step 8 — Tulis Kode Agent (src/agent.py)

```python
"""AI Agent dengan LangChain + Shared Ollama."""
import os
from dotenv import load_dotenv
from langchain_ollama import ChatOllama, OllamaEmbeddings

load_dotenv()

# ⬅️ Gunakan OLLAMA_BASE_URL dari env (mengarah ke shared service)
BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://ollama:11434")

llm = ChatOllama(
    model=os.getenv("LLM_MODEL", "llama3.2:3b"),
    base_url=BASE_URL,
    temperature=0.7,
)

embeddings = OllamaEmbeddings(
    model=os.getenv("EMBEDDING_MODEL", "nomic-embed-text"),
    base_url=BASE_URL,
)
```

---

## Quality Checklist

Sebelum menyelesaikan, verifikasi:

- [ ] **Tidak ada service `ollama`** di `docker-compose.yml` agent
- [ ] Network `ollama-net` di-set sebagai `external: true`
- [ ] `OLLAMA_BASE_URL=http://ollama:11434` (bukan `localhost`!)
- [ ] `.env` ada di `.gitignore` agent
- [ ] Model yang digunakan agent sudah terdaftar di `llm-models.txt` atau `embedding-models.txt` shared Ollama
- [ ] Agent tidak hardcode model name — pakai env var
- [ ] `requirements.txt` mencakup `langchain-ollama`

---

## Common Patterns

### Pattern A: Agent Chat + Embedding (full Ollama)

```yaml
environment:
  - OLLAMA_BASE_URL=http://ollama:11434
  - LLM_MODEL=llama3.2:3b
  - EMBEDDING_MODEL=nomic-embed-text
networks:
  - ollama-net
```

### Pattern B: Agent Chat Ollama + Embedding Cloud

```yaml
environment:
  - OLLAMA_BASE_URL=http://ollama:11434
  - LLM_MODEL=qwen3:8b
  - OPENAI_API_KEY=${OPENAI_API_KEY}  # Untuk embedding OpenAI
networks:
  - ollama-net
```

### Pattern C: Agent dengan Qdrant / Milvus

```yaml
services:
  agent:
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - QDRANT_URL=http://qdrant:6333
    networks:
      - ollama-net
  qdrant:
    image: qdrant/qdrant:latest
    networks:
      - ollama-net

networks:
  ollama-net:
    external: true
```

---

## Anti-Patterns — Jangan Lakukan

- ❌ **Embed Ollama di agent compose** — selalu pisah ke shared service
- ❌ **`OLLAMA_BASE_URL=http://localhost:11434`** — localhost di container = container itu sendiri, bukan Ollama
- ❌ **Hardcode model name** di kode — selalu lewat environment variable
- ❌ **Lupa tambah model ke list** — model yang dipakai agent HARUS ada di `llm-models.txt` / `embedding-models.txt`
- ❌ **`network_mode: host`** — ini bypass shared network, agent tidak akan bisa resolve `ollama` hostname

---

## Related Files

| File | Lokasi |
|---|---|
| Shared Ollama compose | `Infrastructure/ollama/docker-compose.yml` |
| Shared Ollama Dockerfile | `Infrastructure/ollama/Dockerfile` |
| LLM models list | `Infrastructure/ollama/llm-models.txt` |
| Embedding models list | `Infrastructure/ollama/embedding-models.txt` |
| Pull models script | `Infrastructure/ollama/scripts/pull-models.sh` |
| Ollama README | `Infrastructure/ollama/README.md` |
