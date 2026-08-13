FROM nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN uv venv --python 3.11 /app/.venv

ENV PATH="/app/.venv/bin:$PATH"

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-install-project
