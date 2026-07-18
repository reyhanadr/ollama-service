#!/usr/bin/env bash
# =============================================================================
# Ollama Auto-Pull Startup Script
# =============================================================================
# 1. Start Ollama server di background
# 2. Tunggu sampai Ollama siap menerima request
# 3. Pull semua model dari llm-models.txt dan embedding-models.txt
# 4. Keep container alive
#
# Model dari HuggingFace (hf.co/...) menggunakan HF_TOKEN env var.
# =============================================================================

set -euo pipefail

MODELS_DIR="/models"
LLM_MODELS_FILE="${MODELS_DIR}/llm-models.txt"
EMBED_MODELS_FILE="${MODELS_DIR}/embedding-models.txt"

echo "=============================================="
echo " Ollama Shared Service — Starting Up"
echo "=============================================="

# --- Step 1: Start Ollama server in background ---
echo ""
echo "[1/4] Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# --- Step 2: Wait until Ollama is ready ---
echo "[2/4] Waiting for Ollama to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

until curl -s --fail http://localhost:11434/api/tags > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "ERROR: Ollama failed to start after ${MAX_RETRIES} attempts."
        exit 1
    fi
    sleep 2
done

echo "      Ollama is ready on port 11434."

# --- Step 3: Pull models ---
pull_models_from_file() {
    local MODEL_FILE="$1"
    local CATEGORY="$2"

    if [ ! -f "$MODEL_FILE" ]; then
        echo "      [SKIP] ${MODEL_FILE} not found — skipping ${CATEGORY} models."
        return
    fi

    echo ""
    echo "[3/4] Pulling ${CATEGORY} models from ${MODEL_FILE}..."

    while IFS= read -r MODEL || [ -n "$MODEL" ]; do
        # Skip empty lines and comments
        MODEL=$(echo "$MODEL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -z "$MODEL" || "$MODEL" =~ ^# ]] && continue

        echo ""
        echo "      >>> Pulling: ${MODEL}"

        if ollama pull "$MODEL"; then
            echo "      ✓ Successfully pulled: ${MODEL}"
        else
            echo "      ✗ FAILED to pull: ${MODEL} — continuing..."
        fi
    done < "$MODEL_FILE"
}

pull_models_from_file "$LLM_MODELS_FILE" "LLM"
pull_models_from_file "$EMBED_MODELS_FILE" "Embedding"

# --- Step 4: Keep container alive ---
echo ""
echo "[4/4] All models processed. Ollama is running."
echo "=============================================="
echo ""
echo "  Endpoint:    http://localhost:11434"
echo "  List models: ollama list"
echo ""
echo "=============================================="

# Wait for the Ollama server process — keeps container alive
wait $OLLAMA_PID
