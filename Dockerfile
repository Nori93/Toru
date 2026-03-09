# Simple Dockerfile to run Toru Brain as a FastAPI web API

FROM python:3.11-slim

WORKDIR /app

# Install system deps (if needed by ollama client or other libs)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . .

# Install Python dependencies
# NOTE: you may want to replace this with a requirements.txt if available.
RUN pip install --no-cache-dir fastapi uvicorn ollama sqlalchemy psycopg2-binary

# Expose the FastAPI port
EXPOSE 8000

# Environment can configure DB/JSON paths inside the container
ENV TORU_DB_FILE=/app/toru_memory.db \
    TORU_MEMORY_JSON=/app/toru_memory.json

# Start the API using Uvicorn
CMD ["uvicorn", "api_app:app", "--host", "0.0.0.0", "--port", "8000"]
