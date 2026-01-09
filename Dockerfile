FROM rayproject/ray:nightly-extra

ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TORCH_CUDA_ARCH_LIST=6.0;7.0;7.5;8.0;8.6;8.9;9.0 \
    MAX_JOBS=4

RUN pip install --no-cache-dir --upgrade pip wheel setuptools && \
    pip install --no-cache-dir \
    torch==2.1.0 \
    torchvision==0.16.0 \
    torchaudio==2.1.0 \
    transformers==4.35.0 \
    accelerate==0.24.0 \
    peft==0.7.0 \
    bitsandbytes==0.41.0 \
    sentence-transformers==2.2.2 \
    vllm==0.4.0 \
    openai==1.3.0 \
    langchain==0.1.0 \
    langchain-community==0.1.0 \
    tiktoken==0.5.0 \
    faiss-cpu==1.7.4 \
    slowapi==0.1.8 \
    uvicorn==0.24.0 \
    fastapi==0.109.0 \
    pydantic==2.5.0 \
    python-multipart==0.0.6 \
    loguru==0.7.2 \
    pyyaml==6.0.1 \
    redis==5.0.0 \
    prometheus-client==0.19.0

WORKDIR /app

COPY agents/ /app/agents/
COPY models/ /app/models/
COPY start-ray-agent.sh /app/start-ray-agent.sh

RUN chmod +x /app/start-ray-agent.sh

EXPOSE 8200 8265 8000

ENV PYTHONPATH=/app \
    RAY_DEDUP_LOGS=0 \
    RAY_BACKLOG_LOG_INTERVAL_MS=100

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8265/api/health || exit 1

CMD ["/app/start-ray-agent.sh"]
