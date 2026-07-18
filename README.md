# Ollama Shared Service — Docker Compose

Layanan **Ollama** yang berjalan sebagai container Docker mandiri dan dapat digunakan bersama oleh container lain melalui **shared Docker network**.

---

## 📁 Struktur File

```
Infrastructure/ollama/
├── .env.example              # Template environment variables
├── .gitignore                # Abaikan .env dan data model
├── docker-compose.yml        # Service definition + shared network
├── Dockerfile                # Custom image (extends ollama/ollama)
├── llm-models.txt            # Daftar model LLM
├── embedding-models.txt      # Daftar model embedding
├── scripts/
│   └── pull-models.sh        # Auto-pull models saat startup
├── .github/skills/
│   └── ollama-agent-docker/  # Copilot Skill — otomatisasi agent compose
│       └── SKILL.md
└── README.md                 # File ini
```

---

## 🚀 Quick Start

### Prasyarat

- Docker & Docker Compose v2 terinstall
- (Opsional) NVIDIA GPU + [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

### 1. Setup Environment

```bash
# Copy template environment
cp .env.example .env

# (Opsional) Edit .env — isi HUGGINGFACE_TOKEN jika pakai model dari HuggingFace
```

### 2. Pilih Model yang Ingin Di-pull

Edit `llm-models.txt` dan `embedding-models.txt` sesuai kebutuhan. Uncomment model yang ingin digunakan.

### 3. Jalankan

```bash
# Build & start
docker compose up -d

# Pantau proses pull model
docker compose logs -f
```

Tunggu semua model selesai di-pull (bisa beberapa menit tergantung ukuran model).

### 4. Verifikasi

```bash
# Cek model yang tersedia
docker compose exec ollama ollama list

# Test chat
docker compose exec ollama ollama run llama3.2:3b "Hello!"
```

---

## 🔗 Menghubungkan Container Lain

Semua container yang bergabung ke network `ollama-net` bisa mengakses Ollama di `http://ollama:11434`.

### Contoh: Project Python dengan LangChain

**`docker-compose.yml` di project Anda:**

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
    external: true  # Pakai network yang sudah dibuat oleh Ollama service
```

**Python code:**

```python
from langchain_ollama import ChatOllama

llm = ChatOllama(
    model="llama3.2:3b",
    base_url="http://ollama:11434",  # Nama service = hostname
)
```

### Contoh: Cek koneksi dari container lain

```bash
docker run --rm -it --network ollama-net curlimages/curl \
  curl -s http://ollama:11434/api/tags
```

---

## 🤖 Copilot Skill — Otomatisasi Pembuatan Agent Docker

Repo ini dilengkapi **Copilot Skill** (`ollama-agent-docker`) yang secara otomatis memandu pembuatan `docker-compose.yml` untuk project **AI agent** (LangChain/LangGraph) agar terhubung ke shared Ollama service ini.

### Cara Kerja Skill

Skill ini aktif dalam dua mode:

| Mode | Trigger |
|---|---|
| **Slash command** | Ketik `/ollama-agent-docker` di chat Copilot |
| **Auto-detection** | Copilot otomatis memuat skill saat Anda meminta: "buat docker compose untuk AI agent", "bikinin compose LangChain pakai Ollama", "dockerize agent LangGraph dengan embedding" |

### Apa yang Dihasilkan Skill

Skill akan menghasilkan file-file berikut di project agent Anda:

```
<agent-project>/
├── docker-compose.yml    # Agent compose (dengan external network ollama-net)
├── Dockerfile            # Agent image
├── requirements.txt      # langchain, langchain-ollama, langgraph, dll
├── .env.example          # OLLAMA_BASE_URL=http://ollama:11434
└── src/agent.py          # Kode agent dengan ChatOllama / OllamaEmbeddings
```

### Aturan Utama yang Diterapkan Skill

| Aturan | Detail |
|---|---|
| **No embedded Ollama** | Agent compose TIDAK boleh punya service `ollama` sendiri |
| **External network** | Selalu pakai `networks: ollama-net → external: true` |
| **Hostname, bukan localhost** | `OLLAMA_BASE_URL=http://ollama:11434` (bukan `localhost`!) |
| **Model via env var** | Nama model tidak di-hardcode — pakai `LLM_MODEL` / `EMBEDDING_MODEL` env |

### Contoh Prompt yang Memicu Skill

```
"Buatkan docker compose untuk RAG agent pakai LangGraph dan Ollama embedding"
"Dockerize chatbot agent LangChain yang pakai qwen3:8b"
"Setup container untuk AI agent dengan Qdrant + Ollama"
"Bikinin compose untuk multi-agent LangGraph, embeddingnya pakai nomic-embed-text"
```

### Lokasi Skill

```
.github/skills/ollama-agent-docker/SKILL.md
```

---

## ➕ Menambah Model Baru

### Model dari Official Ollama

1. Tambahkan nama model ke `llm-models.txt` atau `embedding-models.txt`
2. Restart container:

```bash
docker compose restart
```

Atau pull langsung tanpa restart:

```bash
docker compose exec ollama ollama pull <nama-model>
```

### Model dari Hugging Face

1. Pastikan `HUGGINGFACE_TOKEN` sudah diisi di `.env`
2. Tambahkan ke file model dengan format `hf.co/<user>/<model>`
3. Restart container

```text
# Contoh di llm-models.txt
hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF
```

---

## ⚙️ Environment Variables

| Variable | Default | Deskripsi |
|---|---|---|
| `OLLAMA_HOST` | `0.0.0.0` | Bind address di dalam container |
| `OLLAMA_PORT` | `11434` | Port mapping di host |
| `OLLAMA_NUM_PARALLEL` | `4` | Jumlah paralel request |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Maks model di-memory |
| `HUGGINGFACE_TOKEN` | — | Token HF untuk pull model `hf.co/*` |
| `NETWORK_NAME` | `ollama-net` | Nama Docker network |
| `VOLUME_NAME` | `ollama-data` | Nama Docker volume |

---

## 🖥️ GPU Acceleration (NVIDIA)

1. Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
2. Uncomment block `deploy.resources` di `docker-compose.yml`
3. Restart:

```bash
docker compose up -d --force-recreate
```

---

## 📋 Perintah Berguna

```bash
# Lihat log
docker compose logs -f

# Masuk ke container
docker compose exec ollama bash

# List model
docker compose exec ollama ollama list

# Pull model manual
docker compose exec ollama ollama pull llama3.2:3b

# Remove model
docker compose exec ollama ollama rm llama3.2:3b

# Restart
docker compose restart

# Stop & hapus (model tetap ada di volume)
docker compose down

# Stop & hapus SEMUA termasuk volume (model hilang)
docker compose down -v
```

---

## 🔧 Troubleshooting

**Model HuggingFace gagal di-pull?**
- Pastikan `HUGGINGFACE_TOKEN` di `.env` valid dan punya akses ke model tersebut.
- Cek log: `docker compose logs ollama | grep -i "error\|fail"`

**Container lain tidak bisa konek ke Ollama?**
- Pastikan container berada di network `ollama-net` (`docker network inspect ollama-net`)
- Gunakan hostname `ollama` (nama service), bukan `localhost`
- Test: `docker run --rm --network ollama-net curlimages/curl curl http://ollama:11434/api/tags`

**Ollama lambat?**
- Aktifkan GPU acceleration jika tersedia
- Naikkan `OLLAMA_NUM_PARALLEL`
- Kurangi `OLLAMA_MAX_LOADED_MODELS` jika RAM terbatas
