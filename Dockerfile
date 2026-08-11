FROM nvcr.io/nvidia/tensorflow:24.04-tf2-py3

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY pyproject.docker.toml pyproject.toml
COPY uv.docker.lock uv.lock

RUN uv sync --frozen --python 3.11 --no-install-project

ENV PATH="/app/.venv/bin:$PATH"

# COPY . .
