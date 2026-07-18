# =============================================================================
# Ollama Shared Service — Dockerfile
# =============================================================================
# Extends official Ollama image dengan:
#   - Startup script for auto-pulling models
#   - Hugging Face support (HF_TOKEN)
#
# Official image: https://hub.docker.com/r/ollama/ollama
# =============================================================================

FROM ollama/ollama:latest

# Install curl (needed for health check wait loop)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy model list files
COPY llm-models.txt embedding-models.txt /models/

# Copy startup script
COPY scripts/pull-models.sh /usr/local/bin/pull-models.sh
RUN chmod +x /usr/local/bin/pull-models.sh

# Ollama serve di port 11434
EXPOSE 11434

# ENTRYPOINT overridden — start Ollama server then auto-pull models
ENTRYPOINT ["/usr/local/bin/pull-models.sh"]
