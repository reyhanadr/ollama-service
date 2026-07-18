# Ollama Shared Service — Docker Compose

A standalone **Ollama** service running as a Docker container, accessible by other containers via a **shared Docker network**.

---

## 📁 File Structure

```
Infrastructure/ollama/
├── .env.example              # Environment variables template
├── .gitignore                # Ignore .env and model data
├── docker-compose.yml        # Service definition + shared network
├── Dockerfile                # Custom image (extends ollama/ollama)
├── llm-models.txt            # LLM model list
├── embedding-models.txt      # Embedding model list
├── scripts/
│   └── pull-models.sh        # Auto-pull models on startup
├── .github/skills/
│   └── ollama-agent-docker/  # Copilot Skill — automated agent compose scaffolding
│       └── SKILL.md
└── README.md                 # This file
```

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose v2 installed
- (Optional) NVIDIA GPU + [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

### 1. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# (Optional) Edit .env — fill in HUGGINGFACE_TOKEN if using HuggingFace models
```

### 2. Select Models to Pull

Edit `llm-models.txt` and `embedding-models.txt` as needed. Uncomment the models you want to use.

### 3. Run

```bash
# Build & start
docker compose up -d

# Monitor the model pull process
docker compose logs -f
```

Wait for all models to finish pulling (may take several minutes depending on model size).

### 4. Verify

```bash
# Check available models
docker compose exec ollama ollama list

# Test chat
docker compose exec ollama ollama run llama3.2:3b "Hello!"
```

---

## 🔗 Connecting Other Containers

Any container joined to the `ollama-net` network can access Ollama at `http://ollama:11434`.

### Example: Python Project with LangChain

**`docker-compose.yml` in your project:**

```yaml
services:
  my-app:
    build: .
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    networks:
      - ollama-net

networks:
  ollama-net:
    external: true  # Use the network created by the Ollama service
```

**Python code:**

```python
from langchain_ollama import ChatOllama

llm = ChatOllama(
    model="llama3.2:3b",
    base_url="http://ollama:11434",  # Service name = hostname
)
```

### Example: Test connectivity from another container

```bash
docker run --rm -it --network ollama-net curlimages/curl \
  curl -s http://ollama:11434/api/tags
```

---

## 🤖 Copilot Skill — Automated Agent Docker Setup

This repository includes a **Copilot Skill** (`ollama-agent-docker`) that automatically scaffolds `docker-compose.yml` for **AI agent** projects (LangChain/LangGraph) to connect to this shared Ollama service.

### How the Skill Works

The skill activates in two modes:

| Mode | Trigger |
|---|---|
| **Slash command** | Type `/ollama-agent-docker` in Copilot Chat |
| **Auto-detection** | Copilot auto-loads the skill when you request: "create docker compose for an AI agent", "scaffold a LangChain compose with Ollama", "dockerize a LangGraph agent with embeddings" |

### What the Skill Produces

The skill generates the following files in your agent project:

```
<agent-project>/
├── docker-compose.yml    # Agent compose (with external network ollama-net)
├── Dockerfile            # Agent image
├── requirements.txt      # langchain, langchain-ollama, langgraph, etc.
├── .env.example          # OLLAMA_BASE_URL=http://ollama:11434
└── src/agent.py          # Agent code with ChatOllama / OllamaEmbeddings
```

### Core Rules Enforced by the Skill

| Rule | Detail |
|---|---|
| **No embedded Ollama** | Agent compose MUST NOT define its own `ollama` service |
| **External network** | Always use `networks: ollama-net → external: true` |
| **Hostname, not localhost** | `OLLAMA_BASE_URL=http://ollama:11434` (not `localhost`!) |
| **Model via env var** | Model names are never hardcoded — use `LLM_MODEL` / `EMBEDDING_MODEL` env vars |

### Example Prompts That Trigger the Skill

```
"Create a docker compose for a RAG agent using LangGraph with Ollama embeddings"
"Dockerize a LangChain chatbot agent using qwen3:8b"
"Set up a container for an AI agent with Qdrant + Ollama"
"Scaffold a compose for a multi-agent LangGraph setup, embeddings using nomic-embed-text"
```

### Skill Location

```
.github/skills/ollama-agent-docker/SKILL.md
```

---

## ➕ Adding New Models

### Official Ollama Models

1. Add the model name to `llm-models.txt` or `embedding-models.txt`
2. Restart the container:

```bash
docker compose restart
```

Or pull directly without restarting:

```bash
docker compose exec ollama ollama pull <model-name>
```

### Hugging Face Models

1. Ensure `HUGGINGFACE_TOKEN` is set in `.env`
2. Add to the model file using the format `hf.co/<user>/<model>`
3. Restart the container

```text
# Example in llm-models.txt
hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF
```

---

## ⚙️ Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_HOST` | `0.0.0.0` | Bind address inside the container |
| `OLLAMA_PORT` | `11434` | Host port mapping |
| `OLLAMA_NUM_PARALLEL` | `4` | Number of concurrent requests |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Max models loaded in memory |
| `HUGGINGFACE_TOKEN` | — | HF token for pulling `hf.co/*` models |
| `NETWORK_NAME` | `ollama-net` | Docker network name |
| `VOLUME_NAME` | `ollama-data` | Docker volume name |

---

## 🖥️ GPU Acceleration (NVIDIA)

1. Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
2. Uncomment the `deploy.resources` block in `docker-compose.yml`
3. Restart:

```bash
docker compose up -d --force-recreate
```

---

## 📋 Useful Commands

```bash
# View logs
docker compose logs -f

# Access container shell
docker compose exec ollama bash

# List models
docker compose exec ollama ollama list

# Manually pull a model
docker compose exec ollama ollama pull llama3.2:3b

# Remove a model
docker compose exec ollama ollama rm llama3.2:3b

# Restart
docker compose restart

# Stop & remove (models persist in volume)
docker compose down

# Stop & remove EVERYTHING including volume (models deleted)
docker compose down -v
```

---

## 🔧 Troubleshooting

**HuggingFace models fail to pull?**
- Ensure `HUGGINGFACE_TOKEN` in `.env` is valid and has access to the model.
- Check logs: `docker compose logs ollama | grep -i "error\|fail"`

**Other containers cannot connect to Ollama?**
- Ensure the container is on the `ollama-net` network (`docker network inspect ollama-net`)
- Use hostname `ollama` (the service name), not `localhost`
- Test: `docker run --rm --network ollama-net curlimages/curl curl http://ollama:11434/api/tags`

**Ollama is slow?**
- Enable GPU acceleration if available
- Increase `OLLAMA_NUM_PARALLEL`
- Decrease `OLLAMA_MAX_LOADED_MODELS` if RAM is limited

