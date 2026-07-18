---
name: ollama-agent-docker
description: 'Docker Compose setup for LangChain/LangGraph AI agents that need Ollama (chat or embedding). Use when: creating docker compose for AI agents, LangChain/LangGraph agents, Ollama embedding services, containerized AI agents, agent docker compose, Ollama shared service integration. DO NOT embed Ollama directly in agent compose — always use the shared Ollama service via external network ollama-net.'
argument-hint: '[agent-name] [framework: langchain|langgraph]'
---

# Ollama Agent Docker — Shared Service Pattern

This skill guides the creation of `docker-compose.yml` for **AI agents** based on LangChain / LangGraph that require **Ollama** (chat and/or embedding). Always use the **shared Ollama service** — do not embed Ollama directly in the agent compose file.

---

## When to Use

| Trigger | Action |
|---|---|
| User requests a docker compose for an AI agent | Use this skill |
| Agent uses LangChain / LangGraph | Use this skill |
| Agent needs Ollama (chat/embedding) | **Do not embed Ollama** — connect to the shared service |
| Agent does not need Ollama (uses OpenAI/Groq/etc.) | Skip the Ollama rule, still follow the compose structure |

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

> ⚠️ **Hard rule**: Do NOT create an `ollama` service inside the agent's `docker-compose.yml`. Always use the external network `ollama-net` and point `OLLAMA_BASE_URL=http://ollama:11434`.

---

## Procedure

### Step 1 — Identify Agent Requirements

Ask / identify:

| Question | Determines |
|---|---|
| Framework? | LangChain → `langchain-ollama`, LangGraph → `langgraph` |
| LLM model? | Ollama (`ChatOllama`) or cloud (`ChatOpenAI`, etc.) |
| Embedding model? | Ollama (`OllamaEmbeddings`) or cloud |
| Additional services? | PostgreSQL, Redis, Qdrant, Milvus, etc. |
| GPU? | Is GPU passthrough needed |

### Step 2 — Determine if Shared Ollama is Needed

```
Agent uses Ollama?
├─ Chat model → Yes → OLLAMA_BASE_URL=http://ollama:11434
├─ Embedding  → Yes → OLLAMA_BASE_URL=http://ollama:11434
└─ No         → ollama-net network not needed
```

If **Yes**: the agent compose MUST include `networks: [ollama-net]` as an external network.

### Step 3 — Create Agent Project Structure

Create the following files in the agent project:

```
<agent-project>/
├── .env                       # Agent environment variables
├── .env.example               # Template (without secrets)
├── docker-compose.yml         # Agent compose (NO ollama service!)
├── Dockerfile                 # Agent image
├── requirements.txt           # Python dependencies
├── src/
│   └── agent.py               # Agent code
└── README.md
```

### Step 4 — Write Agent docker-compose.yml

Use the template below. Replace `<...>` placeholders:

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
      # Ollama — point to the shared service (NOT localhost!)
      - OLLAMA_BASE_URL=http://ollama:11434
      # Models used (must already be pulled in shared Ollama)
      - LLM_MODEL=${LLM_MODEL:-llama3.2:3b}
      - EMBEDDING_MODEL=${EMBEDDING_MODEL:-nomic-embed-text}
    networks:
      - ollama-net

  # --- Additional services (only if needed) ---
  # postgres:
  #   image: pgvector/pgvector:pg17
  #   ...

networks:
  ollama-net:
    external: true  # ⬅️ Key: use the network created by Ollama
```

> **Note:** `depends_on` does not work across compose files. The agent should implement retry logic in its startup code if Ollama readiness is critical.

### Step 5 — Write Agent Dockerfile

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

### Step 6 — Write requirements.txt

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

### Step 7 — Write Agent .env.example

```bash
# Ollama (shared service)
OLLAMA_BASE_URL=http://ollama:11434
LLM_MODEL=llama3.2:3b
EMBEDDING_MODEL=nomic-embed-text

# Agent config
AGENT_PORT=8000
LOG_LEVEL=INFO
```

### Step 8 — Write Agent Code (src/agent.py)

```python
"""AI Agent with LangChain + Shared Ollama."""
import os
from dotenv import load_dotenv
from langchain_ollama import ChatOllama, OllamaEmbeddings

load_dotenv()

# ⬅️ Use OLLAMA_BASE_URL from env (points to shared service)
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

Before finalizing, verify:

- [ ] **No `ollama` service** in the agent's `docker-compose.yml`
- [ ] Network `ollama-net` is set as `external: true`
- [ ] `OLLAMA_BASE_URL=http://ollama:11434` (not `localhost`!)
- [ ] `.env` is in the agent's `.gitignore`
- [ ] Models used by the agent are registered in `llm-models.txt` or `embedding-models.txt` of the shared Ollama
- [ ] Agent does not hardcode model names — uses env vars
- [ ] `requirements.txt` includes `langchain-ollama`

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
  - OPENAI_API_KEY=${OPENAI_API_KEY}  # For OpenAI embeddings
networks:
  - ollama-net
```

### Pattern C: Agent with Qdrant / Milvus

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

## Anti-Patterns — Do Not Do

- ❌ **Embed Ollama in the agent compose** — always separate into the shared service
- ❌ **`OLLAMA_BASE_URL=http://localhost:11434`** — localhost in a container = the container itself, not Ollama
- ❌ **Hardcode model names** in code — always use environment variables
- ❌ **Forget to add models to the list** — models used by the agent MUST be in `llm-models.txt` / `embedding-models.txt`
- ❌ **`network_mode: host`** — this bypasses the shared network; the agent won't resolve the `ollama` hostname

---

## Related Files

| File | Location |
|---|---|
| Shared Ollama compose | `Infrastructure/ollama/docker-compose.yml` |
| Shared Ollama Dockerfile | `Infrastructure/ollama/Dockerfile` |
| LLM models list | `Infrastructure/ollama/llm-models.txt` |
| Embedding models list | `Infrastructure/ollama/embedding-models.txt` |
| Pull models script | `Infrastructure/ollama/scripts/pull-models.sh` |
| Ollama README | `Infrastructure/ollama/README.md` |
